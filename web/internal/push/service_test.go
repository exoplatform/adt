package push

import (
	"bytes"
	"context"
	"crypto/ecdh"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/exoplatform/adt/web/internal/events"
)

type browser struct {
	priv *ecdh.PrivateKey
	auth []byte
}

func newBrowser(t *testing.T) browser {
	t.Helper()
	k, err := ecdh.P256().GenerateKey(randReader{})
	if err != nil {
		t.Fatal(err)
	}
	return browser{k, bytes.Repeat([]byte{3}, 16)}
}

func (b browser) sub(endpoint string) Subscription {
	return Subscription{Endpoint: endpoint, P256dh: b64.EncodeToString(b.priv.PublicKey().Bytes()), Auth: b64.EncodeToString(b.auth)}
}

func TestSetValidation(t *testing.T) {
	s := Open("")
	b := newBrowser(t)
	ok := b.sub("https://push.example/abc")
	if err := s.Set("alice", "", ok, []string{"exo-7.0.x-SNAPSHOT"}); err != nil {
		t.Fatal(err)
	}
	for name, c := range map[string]struct {
		sub  Subscription
		keys []string
		user string
	}{
		"http endpoint":      {b.sub("http://push.example/x"), []string{"k"}, "alice"},
		"shared address":     {b.sub("https://100.64.1.1/x"), []string{"k"}, "alice"},
		"loopback endpoint":  {b.sub("https://127.0.0.1/x"), []string{"k"}, "alice"},
		"private endpoint":   {b.sub("https://10.0.0.5/x"), []string{"k"}, "alice"},
		"credentials":        {b.sub("https://u:p@push.example/x"), []string{"k"}, "alice"},
		"bad key":            {ok, []string{"a b"}, "alice"},
		"anonymous":          {ok, []string{"k"}, ""},
		"bad p256dh":         {Subscription{Endpoint: ok.Endpoint, P256dh: "AAAA", Auth: ok.Auth}, []string{"k"}, "alice"},
		"too many instances": {ok, make([]string, MaxInstances+1), "alice"},
	} {
		if s.Set(c.user, "", c.sub, c.keys) == nil {
			t.Errorf("%s: accepted", name)
		}
	}
	// the limit of browsers per login
	for i := 0; i < MaxPerUser; i++ {
		_ = s.Set("bob", "", b.sub("https://push.example/bob"+strings.Repeat("x", i)), []string{"k"})
	}
	if err := s.Set("bob", "", b.sub("https://push.example/one-too-many"), []string{"k"}); err == nil {
		t.Error("more than MaxPerUser browsers accepted")
	}
	// an empty list is an unsubscription
	if err := s.Set("alice", "", ok, nil); err != nil || s.Count() != MaxPerUser {
		t.Errorf("unsubscribe: %v, %d left", err, s.Count())
	}
}

func TestNotifySendsToTheFollowersOnly(t *testing.T) {
	var mu sync.Mutex
	got := map[string][]byte{}
	headers := map[string]http.Header{}
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		mu.Lock()
		got[r.URL.Path], headers[r.URL.Path] = b, r.Header.Clone()
		mu.Unlock()
		if r.URL.Path == "/gone" {
			w.WriteHeader(http.StatusGone)
			return
		}
		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()
	s := Open("")
	s.Client = srv.Client()
	s.Subject = "https://adt.example"
	follower, other, gone := newBrowser(t), newBrowser(t), newBrowser(t)
	// stored directly: the test server listens on a loopback address, which Set refuses on purpose
	for path, c := range map[string]struct {
		b    browser
		keys []string
	}{"/follower": {follower, []string{"a-1", "exo-7.0.x-SNAPSHOT"}}, "/other": {other, []string{"a-1"}}, "/gone": {gone, []string{"exo-7.0.x-SNAPSHOT"}}} {
		sub := c.b.sub(srv.URL + path)
		sub.User, sub.Instances = "u", c.keys
		s.subs[sub.Endpoint] = sub
	}
	s.Notify(context.Background(), events.Event{Key: "exo-7.0.x-SNAPSHOT", Host: "h.example.org"})

	if _, ok := got["/other"]; ok {
		t.Error("a browser that does not follow the instance was notified")
	}
	body, ok := got["/follower"]
	if !ok {
		t.Fatal("the follower was not notified")
	}
	h := headers["/follower"]
	if h.Get("Content-Encoding") != "aes128gcm" || h.Get("TTL") == "" || !strings.HasPrefix(h.Get("Authorization"), "vapid t=") ||
		!strings.HasSuffix(h.Get("Authorization"), ", k="+s.PublicKey()) {
		t.Errorf("headers: %v", h)
	}
	salt, idlen := body[:16], int(body[20])
	asPub, _ := ecdh.P256().NewPublicKey(body[21 : 21+idlen])
	secret, _ := follower.priv.ECDH(asPub)
	plain := string(decrypt(t, body[21+idlen:], secret, follower.auth, follower.priv.PublicKey().Bytes(), body[21:21+idlen], salt))
	for _, want := range []string{`"title":"exo-7.0.x-SNAPSHOT has been deployed"`, `"body":"Deployed on h.example.org"`, `"key":"exo-7.0.x-SNAPSHOT"`} {
		if !strings.Contains(plain, want) {
			t.Errorf("payload %s lacks %s", plain, want)
		}
	}
	// 410 Gone: the browser unsubscribed, it is forgotten
	if _, still := s.subs[srv.URL+"/gone"]; still {
		t.Error("a subscription the push service reports gone was kept")
	}
	if len(s.subs) != 2 {
		t.Errorf("%d subscriptions left, want 2", len(s.subs))
	}
}

func TestPersistence(t *testing.T) {
	dir := t.TempDir()
	s := Open(dir)
	b := newBrowser(t)
	if err := s.Set("alice", "", b.sub("https://push.example/abc"), []string{"k2", "k1"}); err != nil {
		t.Fatal(err)
	}
	again := Open(dir)
	if again.PublicKey() != s.PublicKey() {
		t.Error("the VAPID key changed at restart: every subscription would be lost")
	}
	if again.Count() != 1 || strings.Join(again.subs["https://push.example/abc"].Instances, ",") != "k1,k2" {
		t.Errorf("subscriptions after a restart: %+v", again.subs)
	}
	for _, f := range []string{"vapid.key", "subscriptions.json"} {
		st, err := os.Stat(dir + "/" + f)
		if err != nil || st.Mode().Perm() != 0o600 {
			t.Errorf("%s: %v %v", f, st, err)
		}
	}
}

// The endpoint is chosen by the visitor: the server must not connect to its own network on its behalf.
func TestClientRefusesPrivateAddresses(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("the server was reached")
	}))
	defer srv.Close()
	c := &http.Client{Transport: publicOnlyTransport()}
	resp, err := c.Get(srv.URL)
	if err == nil {
		resp.Body.Close()
		t.Fatal("a loopback address was reached")
	}
	if !strings.Contains(err.Error(), "non-public") {
		t.Errorf("unexpected error: %v", err)
	}
}

// Run pushes the deployments, not the refresh of the branches, and a slow push service does not hold up the next event.
func TestRunPushesDeploymentsOnly(t *testing.T) {
	var mu sync.Mutex
	hits := 0
	release := make(chan struct{})
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		hits++
		mu.Unlock()
		<-release // the first push service answer is slow
		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()
	defer close(release)
	s := Open("")
	s.Client = srv.Client()
	b := newBrowser(t)
	sub := b.sub(srv.URL + "/x")
	sub.User, sub.Instances = "u", []string{"k1", "k2"}
	s.subs[sub.Endpoint] = sub

	hub := events.NewHub()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Run(ctx, hub)
	time.Sleep(50 * time.Millisecond)
	hub.Publish(events.Event{ID: "0", Kind: events.KindBranches, Repos: []string{"k1"}})
	hub.Publish(events.Event{ID: "1", Key: "k1"})
	hub.Publish(events.Event{ID: "2", Key: "k2"}) // read while the first push is still waiting for its answer
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		mu.Lock()
		n := hits
		mu.Unlock()
		if n == 2 {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	mu.Lock()
	defer mu.Unlock()
	t.Fatalf("%d pushes reached the push service, want 2 (the branches event is not a deployment, the second one must not wait for the first)", hits)
}

// A push service answers directly: a redirect (to an internal address, say) is not followed.
func TestClientDoesNotFollowRedirects(t *testing.T) {
	c := newClient()
	if err := c.CheckRedirect(nil, nil); err != http.ErrUseLastResponse {
		t.Fatalf("CheckRedirect: %v", err)
	}
}

// The endpoint is a secret (whoever has it can push to the browser): an error that reaches the log must not carry it.
func TestSendErrorDoesNotLeakTheEndpoint(t *testing.T) {
	srv := httptest.NewTLSServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	client := srv.Client()
	endpoint := srv.URL + "/fcm/send/very-secret-token"
	srv.Close() // the connection is refused
	s := Open("")
	s.Client = client
	b := newBrowser(t)
	err := s.send(context.Background(), b.sub(endpoint), []byte("{}"))
	if err == nil {
		t.Fatal("no error for a push service that is down")
	}
	if strings.Contains(err.Error(), "very-secret-token") {
		t.Fatalf("the error carries the endpoint: %v", err)
	}
}

func TestSetDeduplicatesAndOldSubscriptionsAreDropped(t *testing.T) {
	dir := t.TempDir()
	s := Open(dir)
	b := newBrowser(t)
	if err := s.Set("alice", "", b.sub("https://push.example/new"), []string{"b", "a", "b", "a"}); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(s.subs["https://push.example/new"].Instances, ","); got != "a,b" {
		t.Errorf("instances %q, want a,b", got)
	}
	// a browser that has not been seen for more than staleAfter is forgotten at the next start
	old := b.sub("https://push.example/old")
	old.User, old.Instances, old.Updated = "bob", []string{"a"}, time.Now().Add(-staleAfter-time.Hour)
	s.subs[old.Endpoint] = old
	s.mu.Lock()
	err := s.saveLocked()
	s.mu.Unlock()
	if err != nil {
		t.Fatal(err)
	}
	again := Open(dir)
	if _, ok := again.subs[old.Endpoint]; ok || again.Count() != 1 {
		t.Errorf("after a restart: %d subscriptions, the old one kept: %v", again.Count(), ok)
	}
}

// Signing out (or an eviction, a block) stops the notifications to the browsers of that session.
func TestSubscriptionsFollowTheirLoginSession(t *testing.T) {
	var mu sync.Mutex
	hits := map[string]int{}
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		hits[r.URL.Path]++
		mu.Unlock()
		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()
	s := Open("")
	s.Client = srv.Client()
	revoked := map[string]bool{"evicted": true}
	s.Revoked = func(session, user string) bool { return revoked[session] || revoked["user:"+user] }
	for path, c := range map[string]struct{ user, session string }{
		"/alive": {"alice", "s1"}, "/evicted": {"bob", "evicted"}, "/blocked": {"mallory", "s3"}, "/nosession": {"dev", ""},
	} {
		sub := newBrowser(t).sub(srv.URL + path)
		sub.User, sub.Session, sub.Instances = c.user, c.session, []string{"k"}
		s.subs[sub.Endpoint] = sub
	}
	revoked["user:mallory"] = true
	s.Notify(context.Background(), events.Event{Key: "k"})
	mu.Lock()
	defer mu.Unlock()
	if hits["/alive"] != 1 || hits["/nosession"] != 1 {
		t.Errorf("live sessions were not notified: %v", hits)
	}
	for _, p := range []string{"/evicted", "/blocked"} {
		if hits[p] != 0 {
			t.Errorf("%s: a session that ended was notified", p)
		}
		if _, kept := s.subs[srv.URL+p]; kept {
			t.Errorf("%s: its subscription was kept", p)
		}
	}
	// the sign-out itself
	if err := s.RemoveSession("s1"); err != nil {
		t.Fatal(err)
	}
	if _, kept := s.subs[srv.URL+"/alive"]; kept || s.Count() != 1 {
		t.Errorf("RemoveSession left %d subscriptions", s.Count())
	}
	if err := s.RemoveSession(""); err != nil || s.Count() != 1 {
		t.Error("an empty session id must remove nothing")
	}
}

// BySession is what /debug-sessions shows: counts per login session, never the endpoints.
func TestBySession(t *testing.T) {
	s := Open("")
	b := newBrowser(t)
	for _, c := range []struct{ session, endpoint string }{{"s1", "https://push.example/1"}, {"s1", "https://push.example/2"}, {"s2", "https://push.example/3"}, {"", "https://push.example/4"}} {
		if err := s.Set("u", c.session, b.sub(c.endpoint), []string{"a", "b"}); err != nil {
			t.Fatal(err)
		}
	}
	got := s.BySession()
	if len(got) != 2 || got["s1"] != (SessionSummary{2, 4}) || got["s2"] != (SessionSummary{1, 2}) {
		t.Errorf("BySession: %+v", got)
	}
}

// A file written by hand (or by an older version) may hold an unsorted list: the instance is still found.
func TestUnsortedInstancesInTheFileAreStillFound(t *testing.T) {
	dir := t.TempDir()
	b := newBrowser(t)
	sub := b.sub("https://push.example/x")
	sub.User, sub.Updated, sub.Instances = "u", time.Now(), []string{"zzz", "mmm", "aaa"}
	data, _ := json.Marshal([]Subscription{sub})
	if err := os.WriteFile(filepath.Join(dir, "subscriptions.json"), data, 0o600); err != nil {
		t.Fatal(err)
	}
	s := Open(dir)
	got := s.subs["https://push.example/x"].Instances
	i := sort.SearchStrings(got, "mmm")
	if i >= len(got) || got[i] != "mmm" {
		t.Errorf("instances %v: mmm not found", got)
	}
}
