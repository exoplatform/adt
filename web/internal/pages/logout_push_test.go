package pages

import (
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"net/http/httptest"
	"testing"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/push"
)

// Signing out removes the push subscriptions registered under that session, and only those.
func TestLogoutDropsThePushSubscriptionsOfTheSession(t *testing.T) {
	a := app.New(config.Config{DataDir: t.TempDir()})
	const mine, other = "0123456789abcdef0123456789abcdef01234567", "ffffffffffffffffffffffffffffffffffffffff"
	for _, c := range []struct{ session, endpoint string }{{mine, "https://push.example/a"}, {other, "https://push.example/b"}} {
		p256dh, auth := validKeys(t)
		sub := push.Subscription{Endpoint: c.endpoint, P256dh: p256dh, Auth: auth}
		if err := a.Push.Set("alice", c.session, sub, []string{"k"}); err != nil {
			t.Fatal(err)
		}
	}
	r := httptest.NewRequest("GET", "/logout", nil)
	r.Header.Set("X-Session-Hash", mine)
	w := httptest.NewRecorder()
	a.Handler().ServeHTTP(w, r)
	if w.Code != 302 {
		t.Fatalf("/logout: %d", w.Code)
	}
	subs := a.Push.Subscriptions()
	if len(subs) != 1 || subs[0].Session != other {
		t.Fatalf("after the sign-out: %+v", subs)
	}
}

// key material the service accepts: a P-256 point and a 16-byte secret
func validKeys(t *testing.T) (p256dh, auth string) {
	t.Helper()
	k, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	enc := base64.RawURLEncoding
	return enc.EncodeToString(k.PublicKey().Bytes()), enc.EncodeToString(make([]byte, 16))
}
