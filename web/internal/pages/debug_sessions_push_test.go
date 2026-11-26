package pages

import (
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/push"
	"github.com/exoplatform/adt/web/internal/sessions"
	"github.com/exoplatform/adt/web/internal/view"
)

// /debug-sessions tells which login sessions have browsers registered for push notifications.
func TestDebugSessionsShowsPushSubscriptions(t *testing.T) {
	if err := view.ParseAll(); err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "var", "sessions"), 0o755); err != nil { // sessions are only tracked where this exists
		t.Fatal(err)
	}
	a := app.New(config.Config{DataDir: dir})
	const withPush, without, evicted = "0123456789abcdef0123456789abcdef01234567", "1111111111111111111111111111111111111111", "2222222222222222222222222222222222222222"
	req := func(user, session string) *httptest.ResponseRecorder {
		r := httptest.NewRequest("GET", "/debug-sessions", nil)
		r.Header.Set("X-Remote-User", user)
		r.Header.Set("X-Remote-Name", strings.ToUpper(user[:1])+user[1:])
		r.Header.Set("X-Session-Hash", session)
		r.Header.Set("X-Session-Expiry", "4102444800")
		sessions.For(dir).Track(r, auth.FromHeaders(r))
		w := httptest.NewRecorder()
		a.Handler().ServeHTTP(w, r)
		return w
	}
	// three sessions, tracked by their own visits; the admin looking at the page is the first one
	req("admin", "ffffffffffffffffffffffffffffffffffffffff")
	req("alice", withPush)
	req("bob", without)
	req("carol", evicted)
	p256dh, authSecret := validKeys(t)
	for i, s := range []string{withPush, withPush, evicted} {
		sub := push.Subscription{Endpoint: "https://push.example/" + string(rune('a'+i)), P256dh: p256dh, Auth: authSecret}
		if err := a.Push.Set("u", s, sub, []string{"k1", "k2"}); err != nil {
			t.Fatal(err)
		}
	}
	// carol's session is evicted: her browser would not get a push, so the page must not claim it does
	if !sessions.For(dir).Evict(httptest.NewRequest("GET", "/", nil), evicted) {
		t.Fatal("the session was not evicted")
	}

	body := req("admin", "ffffffffffffffffffffffffffffffffffffffff").Body.String()
	row := func(user string) string {
		i := strings.Index(body, "("+user+")")
		if i < 0 {
			t.Fatalf("no row for %s in:\n%s", user, body)
		}
		return body[i : i+strings.Index(body[i:], "</tr>")]
	}
	// the label sits in its own <span>: a badge whose only element child is the <i> is styled as a round icon-only badge
	// (style.css, .badge:has(> i:only-child)) and the text spills out of it
	if r := row("alice"); !strings.Contains(r, "<span>subscribed ×2</span>") || !strings.Contains(r, "follow 4 instance(s)") {
		t.Errorf("alice's row lacks the push badge:\n%s", r)
	}
	for _, u := range []string{"bob", "carol", "admin"} {
		if r := row(u); strings.Contains(r, "subscribed") {
			t.Errorf("%s's row shows a push badge:\n%s", u, r)
		}
	}
	if strings.Contains(body, "push.example") {
		t.Error("the page shows a push endpoint")
	}
}
