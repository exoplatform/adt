package rest

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/config"
)

func post(h http.Handler, form url.Values, headers map[string]string) *httptest.ResponseRecorder {
	r := httptest.NewRequest("POST", "/internal/deployed", strings.NewReader(form.Encode()))
	r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	for k, v := range headers {
		r.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}

// Only adt.sh, which talks to the socket directly, may announce a deployment: a request that went through Apache
// (proxy headers, authenticated identity) is a visitor's and must be refused. Without the guard this test fails.
func TestInternalDeployedOnlyFromTheSocket(t *testing.T) {
	a := app.New(config.Config{DevMode: false})
	h := a.Handler()
	ch, cancel := a.Events.All.Subscribe()
	defer cancel()
	form := url.Values{"key": {"exo-6.5.x-SNAPSHOT"}, "host": {"h.example.org"}, "date": {"20260101.101010"}}

	for _, hdr := range []map[string]string{
		{"X-Forwarded-For": "10.0.0.1"},
		{"X-Remote-User": "someone"},
		{"X-Forwarded-Host": "acceptance.exoplatform.org"},
	} {
		if w := post(h, form, hdr); w.Code != http.StatusForbidden {
			t.Fatalf("proxied request %v: %d, want 403", hdr, w.Code)
		}
	}
	select {
	case e := <-ch:
		t.Fatalf("a proxied request published %+v", e)
	case <-time.After(100 * time.Millisecond):
	}

	if w := post(h, form, nil); w.Code != http.StatusNoContent {
		t.Fatalf("direct request: %d, want 204", w.Code)
	}
	select {
	case e := <-ch:
		if e.Key != "exo-6.5.x-SNAPSHOT" || e.Date != "20260101.101010" {
			t.Fatalf("event: %+v", e)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("direct request not published")
	}
}

func TestInternalDeployedValidatesTheKey(t *testing.T) {
	h := app.New(config.Config{}).Handler()
	for _, key := range []string{"", "a b", "a\nb", "../x"} {
		if w := post(h, url.Values{"key": {key}}, nil); w.Code != http.StatusBadRequest {
			t.Errorf("key %q: %d, want 400", key, w.Code)
		}
	}
}

// A deployment announced on one server empties the cached lists of instances on that server, and (through the
// relay) on the other ones, so that none of them keeps showing the instance as it was before.
func TestDeploymentInvalidatesTheCachesOfEveryServer(t *testing.T) {
	peer := app.New(config.Config{AcceptanceHost: "peer.example.org"})
	srv := httptest.NewServer(peer.Handler())
	defer srv.Close()
	mine := app.New(config.Config{AcceptanceHost: "me.example.org", Servers: []string{srv.URL, "https://me.example.org"}})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	mine.StartEventRelays(ctx)

	peer.Instances.Cache.Set("local_instances", 1, time.Minute)
	mine.Instances.Cache.Set("all_instances", 1, time.Minute)
	mine.Instances.Cache.Set("git_activity", 1, time.Minute)

	// The relay connects in the background and an event sent before is lost by design: announce until it is heard
	deadline := time.Now().Add(5 * time.Second)
	for {
		if w := post(peer.Handler(), url.Values{"key": {"exo-6.5.x"}}, nil); w.Code != http.StatusNoContent {
			t.Fatalf("announcement: %d", w.Code)
		}
		if _, cached := mine.Instances.Cache.Get("all_instances"); !cached {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("the other server kept its cached list")
		}
		time.Sleep(50 * time.Millisecond)
	}
	if _, cached := peer.Instances.Cache.Get("local_instances"); cached {
		t.Error("the server that deployed kept its cached list")
	}
	if _, cached := mine.Instances.Cache.Get("git_activity"); !cached {
		t.Error("an unrelated cache was dropped")
	}
}

// Events sent while a relay was down are lost: when it connects again the cached lists are dropped.
func TestRelayConnectionInvalidatesTheCaches(t *testing.T) {
	peer := httptest.NewServer(app.New(config.Config{}).Handler())
	defer peer.Close()
	mine := app.New(config.Config{AcceptanceHost: "me.example.org", Servers: []string{peer.URL}})
	mine.Instances.Cache.Set("all_instances", 1, time.Minute)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	mine.StartEventRelays(ctx)
	deadline := time.Now().Add(5 * time.Second)
	for {
		if _, cached := mine.Instances.Cache.Get("all_instances"); !cached {
			return
		}
		if time.Now().After(deadline) {
			t.Fatal("the cached list survived the connection of the relay")
		}
		time.Sleep(20 * time.Millisecond)
	}
}
