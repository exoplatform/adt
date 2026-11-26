package rest

import (
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/config"
)

func pushPost(h http.Handler, path, body string, headers map[string]string) *httptest.ResponseRecorder {
	r := httptest.NewRequest("POST", path, strings.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	for k, v := range headers {
		r.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}

func TestPushEndpoints(t *testing.T) {
	a := app.New(config.Config{})
	h := a.Handler()
	k, _ := ecdh.P256().GenerateKey(rand.Reader)
	enc := base64.RawURLEncoding
	body := `{"endpoint":"https://push.example/abc","keys":{"p256dh":"` + enc.EncodeToString(k.PublicKey().Bytes()) +
		`","auth":"` + enc.EncodeToString(make([]byte, 16)) + `"},"instances":["exo-7.0.x-SNAPSHOT"]}`
	in := map[string]string{"X-Remote-User": "alice", "Sec-Fetch-Site": "same-origin", "X-Session-Hash": "0123456789abcdef0123456789abcdef01234567"}

	// the key is what the browser subscribes with
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest("GET", "/push/key", nil))
	if w.Code != 200 || w.Body.String() != a.Push.PublicKey() || len(w.Body.String()) != 87 {
		t.Fatalf("/push/key: %d %q", w.Code, w.Body.String())
	}

	for name, hdr := range map[string]map[string]string{
		"not signed in": {"Sec-Fetch-Site": "same-origin"},
		"cross-site":    {"X-Remote-User": "alice", "Sec-Fetch-Site": "cross-site", "Origin": "https://evil.example"},
	} {
		if w := pushPost(h, "/push/subscribe", body, hdr); w.Code != http.StatusForbidden {
			t.Errorf("%s: %d, want 403", name, w.Code)
		}
	}
	if a.Push.Count() != 0 {
		t.Fatal("a refused request subscribed a browser")
	}
	if w := pushPost(h, "/push/subscribe", `{not json`, in); w.Code != http.StatusBadRequest {
		t.Errorf("bad json: %d", w.Code)
	}
	if w := pushPost(h, "/push/subscribe", strings.Replace(body, "https://push.example", "https://127.0.0.1", 1), in); w.Code != http.StatusBadRequest {
		t.Errorf("loopback endpoint: %d", w.Code)
	}
	if w := pushPost(h, "/push/subscribe", body, in); w.Code != http.StatusNoContent || a.Push.Count() != 1 {
		t.Fatalf("subscribe: %d, %d subscriptions", w.Code, a.Push.Count())
	}
	// the subscription is tied to the login session
	for _, sub := range a.Push.Subscriptions() {
		if sub.Session != "0123456789abcdef0123456789abcdef01234567" || sub.User != "alice" {
			t.Errorf("session %q user %q", sub.Session, sub.User)
		}
	}
	if w := pushPost(h, "/push/unsubscribe", `{"endpoint":"https://push.example/abc"}`, in); w.Code != http.StatusNoContent || a.Push.Count() != 0 {
		t.Fatalf("unsubscribe: %d, %d subscriptions", w.Code, a.Push.Count())
	}
}
