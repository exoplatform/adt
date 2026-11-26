package rest

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// wsDial opens /ws on srv with a raw handshake; it returns the status line, the connection and its reader.
func wsDial(t *testing.T, srv *httptest.Server, origin string, extra ...string) (string, net.Conn, *bufio.Reader) {
	t.Helper()
	host := strings.TrimPrefix(srv.URL, "http://")
	c, err := net.Dial("tcp", host)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	req := "GET /ws HTTP/1.1\r\nHost: " + host + "\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" +
		"Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n"
	if origin != "" {
		req += "Origin: " + origin + "\r\n"
	}
	for _, h := range extra {
		req += h + "\r\n"
	}
	io.WriteString(c, req+"\r\n")
	_ = c.SetReadDeadline(time.Now().Add(3 * time.Second))
	br := bufio.NewReader(c)
	status, err := br.ReadString('\n')
	if err != nil {
		t.Fatal(err)
	}
	return status, c, br
}

func wsMessage(t *testing.T, br *bufio.Reader) string {
	t.Helper()
	h := make([]byte, 2)
	if _, err := io.ReadFull(br, h); err != nil {
		t.Fatal(err)
	}
	n := int(h[1])
	if h[0] != 0x81 || n > 126 {
		t.Fatalf("unexpected frame header %v", h)
	}
	if n == 126 { // 16-bit length
		l := make([]byte, 2)
		if _, err := io.ReadFull(br, l); err != nil {
			t.Fatal(err)
		}
		n = int(l[0])<<8 | int(l[1])
	}
	b := make([]byte, n)
	if _, err := io.ReadFull(br, b); err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func skipHandshake(t *testing.T, br *bufio.Reader) {
	t.Helper()
	for {
		l, err := br.ReadString('\n')
		if err != nil {
			t.Fatal(err)
		}
		if l == "\r\n" {
			return
		}
	}
}

// The page hears about a deployment on the socket: hello, then one message per event, with the fields of the event.
func TestWSPushesDeployments(t *testing.T) {
	a := app.New(config.Config{DevMode: true})
	srv := httptest.NewServer(a.Handler())
	defer srv.Close()

	status, _, br := wsDial(t, srv, "")
	if !strings.Contains(status, "101") {
		t.Fatalf("status %q", status)
	}
	skipHandshake(t, br)
	if m := wsMessage(t, br); m != `{"type":"hello"}` {
		t.Fatalf("first message %q", m)
	}
	if w := post(a.Handler(), url.Values{"key": {"plf-7.3.x"}, "host": {"h.example.org"}, "date": {"20261121.101500"}}, nil); w.Code != 204 {
		t.Fatalf("post: %d", w.Code)
	}
	m := wsMessage(t, br)
	for _, want := range []string{`"type":"deployed"`, `"key":"plf-7.3.x"`, `"date":"20261121.101500"`} {
		if !strings.Contains(m, want) {
			t.Fatalf("message %q lacks %s", m, want)
		}
	}
}

// A page of another site must not get the socket, and the socket count is bounded. Without the checks this fails.
func TestWSRefusals(t *testing.T) {
	a := app.New(config.Config{DevMode: true})
	srv := httptest.NewServer(a.Handler())
	defer srv.Close()

	if status, _, _ := wsDial(t, srv, "https://evil.example"); !strings.Contains(status, "403") {
		t.Fatalf("cross-origin: %q", status)
	}

	wsMax.Store(1)
	defer wsMax.Store(512)
	status, _, br := wsDial(t, srv, "")
	if !strings.Contains(status, "101") {
		t.Fatalf("first socket: %q", status)
	}
	skipHandshake(t, br)
	if status, _, _ := wsDial(t, srv, ""); !strings.Contains(status, "503") {
		t.Fatalf("second socket over the cap: %q", status)
	}
}

// Any signed-in employee may open the socket (it is under Apache's <Location />, not the admin rule of /debug*), so
// what it sends is exactly this set of fields: nothing an administrator alone may see, no identity, no page content.
// Adding a field to events.Event does not change the message; adding one to the message fails this test on purpose.
func TestWSMessageFields(t *testing.T) {
	a := app.New(config.Config{DevMode: true})
	srv := httptest.NewServer(a.Handler())
	defer srv.Close()
	_, _, br := wsDial(t, srv, "")
	skipHandshake(t, br)
	wsMessage(t, br) // hello
	post(a.Handler(), url.Values{"key": {"plf-7.3.x"}, "host": {"h.example.org"}, "alias": {"try.example.org"}, "date": {"20261121.101500"}}, nil)
	var got map[string]any
	if err := json.Unmarshal([]byte(wsMessage(t, br)), &got); err != nil {
		t.Fatal(err)
	}
	want := map[string]bool{"type": true, "id": true, "key": true, "host": true, "alias": true, "date": true, "at": true}
	for k := range got {
		if !want[k] {
			t.Errorf("the socket sends %q: not in the reviewed set of fields", k)
		}
	}
	for k := range want {
		if _, ok := got[k]; !ok {
			t.Errorf("field %q missing", k)
		}
	}
}

// An evicted session gets no socket, and a socket that is open when its session is evicted from /debug-sessions is
// told to log out AT ONCE (the periodic check is set to an hour here: only the push can make this pass), then
// closed with 1008. Without it the person would keep a live page, and a socket, for the rest of its lifetime.
func TestWSEvictedSession(t *testing.T) {
	dir := t.TempDir()
	a := app.New(config.Config{DevMode: true, DataDir: dir})
	srv := httptest.NewServer(a.Handler())
	defer srv.Close()
	old := wsRecheck.Swap(int64(time.Hour))
	defer wsRecheck.Store(old)

	// the session as the dashboard tracks it
	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set("Cookie", "adt_session=abc")
	store := sessions.For(dir)
	if err := os.MkdirAll(store.Dir(), 0o755); err != nil {
		t.Fatal(err)
	}
	store.Track(req, auth.Identity{User: "someone", Name: "Some One", Expiry: time.Now().Add(time.Hour)})
	id := sessions.ID(req)

	status, _, br := wsDial(t, srv, "", "Cookie: adt_session=abc")
	if !strings.Contains(status, "101") {
		t.Fatalf("before the eviction: %q", status)
	}
	skipHandshake(t, br)
	wsMessage(t, br) // hello

	admin := httptest.NewRequest("POST", "/debug-sessions", nil)
	if !store.Evict(admin, id) {
		t.Fatal("the session was not evicted")
	}

	if m := wsMessage(t, br); m != `{"type":"logout"}` {
		t.Fatalf("message after the eviction: %q", m)
	}
	h := make([]byte, 4)
	if _, err := io.ReadFull(br, h); err != nil {
		t.Fatalf("socket not closed after the eviction: %v", err)
	}
	if h[0] != 0x88 || h[2] != 0x03 || h[3] != 0xf0 { // close, code 1008
		t.Fatalf("frame %v, want close 1008", h)
	}
	if status, _, _ := wsDial(t, srv, "", "Cookie: adt_session=abc"); !strings.Contains(status, "403") {
		t.Fatalf("new socket for the evicted session: %q", status)
	}
	if status, _, _ := wsDial(t, srv, "", "Cookie: adt_session=another"); !strings.Contains(status, "101") {
		t.Fatalf("another session: %q", status)
	}
}

// POST /internal/refresh (adt.sh fetched the repositories): the pages are told with a message that carries no instance, no host
// and no key, only its type, an id and the time; a request that came through Apache is refused and tells nobody.
func TestInternalRefreshTellsThePages(t *testing.T) {
	a := app.New(config.Config{DevMode: true})
	h := a.Handler()
	srv := httptest.NewServer(h)
	defer srv.Close()
	status, _, br := wsDial(t, srv, "")
	if !strings.Contains(status, "101") {
		t.Fatalf("status %q", status)
	}
	skipHandshake(t, br)
	wsMessage(t, br) // hello

	// through the proxy: refused, nothing is sent
	r := httptest.NewRequest("POST", "/internal/refresh", nil)
	r.Header.Set("X-Forwarded-For", "10.0.0.1")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusForbidden {
		t.Fatalf("proxied refresh: %d, want 403", w.Code)
	}

	// direct (the socket): answered at once, and the page hears of it
	w = httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest("POST", "/internal/refresh", nil))
	if w.Code != http.StatusNoContent {
		t.Fatalf("refresh: %d, want 204", w.Code)
	}
	var got map[string]any
	if err := json.Unmarshal([]byte(wsMessage(t, br)), &got); err != nil {
		t.Fatal(err)
	}
	if got["type"] != "branches" {
		t.Fatalf("message %v", got)
	}
	for k := range got {
		if k != "type" && k != "id" && k != "at" && k != "repos" {
			t.Errorf("the branches message carries %q", k)
		}
	}
	for _, k := range []string{"type", "id", "at"} {
		if _, ok := got[k]; !ok {
			t.Errorf("the branches message lacks %q", k)
		}
	}
}

// The refresh of the branches has nothing to do with the instances: it must not drop their cached lists (a deployment does).
func TestBranchesEventDoesNotDropTheInstanceLists(t *testing.T) {
	a := app.New(config.Config{DevMode: true})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	a.StartEventRelays(ctx)
	a.Instances.Cache.Set("all_instances", 1, time.Hour)

	a.Events.PublishBranches(nil)
	time.Sleep(200 * time.Millisecond)
	if _, ok := a.Instances.Cache.Get("all_instances"); !ok {
		t.Fatal("a branches event dropped the cached instance lists")
	}
	a.Events.PublishLocal("plf-7.3.x", "h.example.org", "", "20261121.101500")
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if _, ok := a.Instances.Cache.Get("all_instances"); !ok {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("a deployment no longer drops the cached instance lists")
}

// The announcement names the repositories whose branches moved (one, several or none): only well-formed names, each once, go on
// to the pages; what is not a repository name is dropped, and without a name the message carries no list (everything moved).
func TestInternalRefreshNamesTheRepositories(t *testing.T) {
	a := app.New(config.Config{DevMode: true})
	h := a.Handler()
	srv := httptest.NewServer(h)
	defer srv.Close()
	_, _, br := wsDial(t, srv, "")
	skipHandshake(t, br)
	wsMessage(t, br) // hello

	announce := func(repos ...string) map[string]any {
		form := url.Values{"repos": repos}
		r := httptest.NewRequest("POST", "/internal/refresh", strings.NewReader(form.Encode()))
		r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != http.StatusNoContent {
			t.Fatalf("refresh: %d", w.Code)
		}
		var got map[string]any
		if err := json.Unmarshal([]byte(wsMessage(t, br)), &got); err != nil {
			t.Fatal(err)
		}
		return got
	}
	list := func(m map[string]any) []string {
		var out []string
		for _, v := range m["repos"].([]any) {
			out = append(out, v.(string))
		}
		return out
	}

	if got := list(announce("commons")); len(got) != 1 || got[0] != "commons" {
		t.Fatalf("one repository: %v", got)
	}
	if got := list(announce("commons", "social", "platform-ui")); strings.Join(got, ",") != "commons,social,platform-ui" {
		t.Fatalf("several repositories: %v", got)
	}
	bad := []string{"../etc", "a b", "x;y", "-rf", ".hidden", "a/b", "", "<script>", strings.Repeat("a", 101), "a..b"}
	got := list(announce(append([]string{"commons", "commons"}, bad...)...))
	if len(got) != 1 || got[0] != "commons" {
		t.Fatalf("hostile and repeated names: %v (want [commons])", got)
	}
	if m := announce(); m["repos"] != nil {
		t.Fatalf("no name, but a list: %v", m["repos"])
	}
	if m := announce(bad...); m["repos"] != nil {
		t.Fatalf("only hostile names, but a list: %v", m["repos"])
	}
}
