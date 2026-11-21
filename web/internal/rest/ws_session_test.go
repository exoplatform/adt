package rest

import (
	"bufio"
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
	_ "github.com/exoplatform/adt/web/internal/pages" // registers /debug-sessions
	"github.com/exoplatform/adt/web/internal/sessions"
)

// Session hijacking against the live socket, for an administrator and for an ordinary user. Apache decides who
// may reach /debug* (LDAP group) and strips the identity headers a client sends; these tests cover what this
// process owns: a session is evicted for everyone who holds it, a stolen cookie is useless from another site, a
// logout reaches the evicted session only, and the socket says the same to an admin and to anybody else.

type person struct {
	user, cookie string
	admin        bool
}

var (
	alice = person{"alice", "cookie-of-alice", true}
	bob   = person{"bob", "cookie-of-bob", false}
)

type sessionEnv struct {
	t     *testing.T
	a     *app.App
	srv   *httptest.Server
	store *sessions.Store
	dir   string
}

func newSessionEnv(t *testing.T) *sessionEnv {
	t.Helper()
	dir := t.TempDir()
	a := app.New(config.Config{DataDir: dir, AdminUsers: []string{"alice"}}) // production mode: the identity comes from the headers
	srv := httptest.NewServer(a.Handler())
	t.Cleanup(srv.Close)
	store := sessions.For(dir)
	if err := os.MkdirAll(store.Dir(), 0o755); err != nil {
		t.Fatal(err)
	}
	old := wsRecheck.Swap(int64(time.Hour)) // only the push may end a socket in these tests
	t.Cleanup(func() { wsRecheck.Store(old) })
	e := &sessionEnv{t: t, a: a, srv: srv, store: store, dir: dir}
	for _, p := range []person{alice, bob} {
		store.Track(e.request(p), auth.Identity{User: p.user, Expiry: time.Now().Add(time.Hour)})
	}
	return e
}

// request is what Apache forwards for the person: the identity headers and the session cookie
func (e *sessionEnv) request(p person) *http.Request {
	r := httptest.NewRequest("GET", "/", nil)
	r.Header.Set("Cookie", "adt_session="+p.cookie)
	r.Header.Set(auth.HeaderUser, p.user)
	return r
}

func (e *sessionEnv) headers(p person) []string {
	return []string{"Cookie: adt_session=" + p.cookie, auth.HeaderUser + ": " + p.user}
}

func (e *sessionEnv) open(p person, origin string) (string, net.Conn, *bufio.Reader) {
	return wsDial(e.t, e.srv, origin, e.headers(p)...)
}

// connect opens a socket that must be accepted and reads its hello
func (e *sessionEnv) connect(p person) *bufio.Reader {
	e.t.Helper()
	status, _, br := e.open(p, "")
	if !strings.Contains(status, "101") {
		e.t.Fatalf("%s: handshake %q", p.user, status)
	}
	skipHandshake(e.t, br)
	if m := wsMessage(e.t, br); m != `{"type":"hello"}` {
		e.t.Fatalf("%s: first message %q", p.user, m)
	}
	return br
}

func (e *sessionEnv) evict(p person) {
	e.t.Helper()
	admin := httptest.NewRequest("POST", "/debug-sessions", nil)
	if !e.store.Evict(admin, sessions.ID(e.request(p))) {
		e.t.Fatalf("session of %s not evicted", p.user)
	}
}

func expectLogout(t *testing.T, who string, br *bufio.Reader) {
	t.Helper()
	if m := wsMessage(t, br); m != `{"type":"logout"}` {
		t.Fatalf("%s: message %q, want logout", who, m)
	}
	h := make([]byte, 4)
	if _, err := io.ReadFull(br, h); err != nil || h[0] != 0x88 || h[2] != 0x03 || h[3] != 0xf0 {
		t.Fatalf("%s: close frame %v (%v), want 1008", who, h, err)
	}
}

func expectNothing(t *testing.T, who string, c net.Conn, br *bufio.Reader) {
	t.Helper()
	_ = c.SetReadDeadline(time.Now().Add(300 * time.Millisecond))
	if b, err := br.Peek(1); err == nil {
		t.Fatalf("%s received %v, want silence", who, b)
	}
	_ = c.SetReadDeadline(time.Now().Add(3 * time.Second))
}

// A valid session on a page of ANOTHER site: the browser attaches the cookie, but the handshake carries that
// site's Origin. Refused for the administrator and for the ordinary user alike.
func TestSessionHijackFromAnotherSite(t *testing.T) {
	e := newSessionEnv(t)
	for _, p := range []person{alice, bob} {
		for _, origin := range []string{"https://evil.example", "http://" + strings.TrimPrefix(e.srv.URL, "http://") + ".evil.example", "null"} {
			if status, _, _ := e.open(p, origin); !strings.Contains(status, "403") {
				t.Errorf("%s from origin %q: %q, want 403", p.user, origin, status)
			}
		}
		if status, _, _ := e.open(p, e.srv.URL); !strings.Contains(status, "101") {
			t.Errorf("%s from the site itself: %q, want 101", p.user, status)
		}
	}
}

// Replaying a session that was evicted (a stolen cookie, or the X-Session-Hash Apache derives from it) gets nothing,
// for an administrator and for an ordinary user, and an open socket is told to log out at once.
func TestSessionEvictedIsDeadEverywhere(t *testing.T) {
	for _, victim := range []person{alice, bob} {
		t.Run(victim.user, func(t *testing.T) {
			e := newSessionEnv(t)
			open := e.connect(victim)
			e.evict(victim)
			expectLogout(t, victim.user, open)

			if status, _, _ := e.open(victim, ""); !strings.Contains(status, "403") {
				t.Errorf("replay of the cookie: %q, want 403", status)
			}
			// the same through the hash header Apache sets (the cookie may be stripped before it reaches us)
			id := sessions.ID(e.request(victim))
			status, _, _ := wsDial(t, e.srv, "", auth.HeaderSession+": "+id, auth.HeaderUser+": "+victim.user)
			if !strings.Contains(status, "403") {
				t.Errorf("replay of the session hash: %q, want 403", status)
			}
		})
	}
}

// An eviction reaches the sessions it names and no other: evicting the user must not disconnect the administrator,
// and evicting the administrator must not disconnect the user (nor the reverse through a block).
func TestSessionEvictionIsPerSession(t *testing.T) {
	for _, tc := range []struct{ victim, bystander person }{{bob, alice}, {alice, bob}} {
		t.Run("evict "+tc.victim.user, func(t *testing.T) {
			e := newSessionEnv(t)
			v, b := e.connect(tc.victim), e.connect(tc.bystander)
			e.evict(tc.victim)
			expectLogout(t, tc.victim.user, v)
			// the bystander is still connected and still hears the deployments
			post(e.a.Handler(), url.Values{"key": {"plf-7.3.x"}, "host": {"h.example.org"}, "date": {"20261121.101500"}}, nil)
			if m := wsMessage(t, b); !strings.Contains(m, `"type":"deployed"`) {
				t.Fatalf("%s lost the socket: %q", tc.bystander.user, m)
			}
		})
		t.Run("block "+tc.victim.user, func(t *testing.T) {
			e := newSessionEnv(t)
			v, b := e.connect(tc.victim), e.connect(tc.bystander)
			e.store.BlockUser(httptest.NewRequest("POST", "/debug-sessions", nil), tc.victim.user, 15, "")
			expectLogout(t, tc.victim.user, v)
			if status, _, _ := e.open(tc.victim, ""); !strings.Contains(status, "403") {
				t.Errorf("blocked %s opens a socket: %q", tc.victim.user, status)
			}
			post(e.a.Handler(), url.Values{"key": {"plf-7.3.x"}, "host": {"h.example.org"}, "date": {"20261121.101500"}}, nil)
			if m := wsMessage(t, b); !strings.Contains(m, `"type":"deployed"`) {
				t.Fatalf("%s lost the socket: %q", tc.bystander.user, m)
			}
		})
	}
}

// What the socket says does not depend on who listens: an administrator gets nothing an ordinary user does not
// (the instances are the ones every employee sees on the dashboard; the admin pages are not on the socket).
func TestSocketSaysTheSameToAdminAndUser(t *testing.T) {
	e := newSessionEnv(t)
	a, b := e.connect(alice), e.connect(bob)
	post(e.a.Handler(), url.Values{"key": {"plf-7.3.x"}, "host": {"h.example.org"}, "date": {"20261121.101500"}}, nil)
	ma, mb := wsMessage(t, a), wsMessage(t, b)
	if ma != mb {
		t.Fatalf("admin gets %q, user gets %q", ma, mb)
	}
	for _, leak := range []string{"alice", "bob", "cookie", "admin", "token", "mail"} {
		if strings.Contains(strings.ToLower(ma), leak) {
			t.Errorf("the message mentions %q: %s", leak, ma)
		}
	}
}

// The anti-CSRF token of /debug-sessions is bound to the session it was issued to: the token of the ordinary
// user's session does not let anybody evict the administrator, and a token replayed from another session is
// refused. (Who may open the page at all is Apache's LDAP rule.)
func TestSessionTokenIsBoundToItsSession(t *testing.T) {
	e := newSessionEnv(t)
	bobToken := e.store.CSRFToken(e.request(bob))
	aliceToken := e.store.CSRFToken(e.request(alice))
	if bobToken == aliceToken || bobToken == "" {
		t.Fatalf("tokens: %q %q", bobToken, aliceToken)
	}
	// the user's token presented with the administrator's session (or the reverse): refused
	for _, tc := range []struct {
		name  string
		as    person
		token string
	}{{"bob's token on alice's session", alice, bobToken}, {"alice's token on bob's session", bob, aliceToken}} {
		form := url.Values{"action": {"evict"}, "id": {sessions.ID(e.request(alice))}, "token": {tc.token}}
		r := httptest.NewRequest("POST", "/debug-sessions", strings.NewReader(form.Encode()))
		r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		r.Header.Set("Cookie", "adt_session="+tc.as.cookie)
		r.Header.Set(auth.HeaderUser, tc.as.user)
		w := httptest.NewRecorder()
		e.a.Handler().ServeHTTP(w, r)
		if w.Code != http.StatusForbidden {
			t.Errorf("%s: %d, want 403", tc.name, w.Code)
		}
	}
	if e.store.IsRevoked(e.request(alice)) {
		t.Fatal("the administrator's session was evicted with a foreign token")
	}
}

// ...and the right token, from the session that owns it, does work (the refusals above are not a broken page).
func TestSessionTokenOfTheOwnerWorks(t *testing.T) {
	e := newSessionEnv(t)
	form := url.Values{"action": {"evict"}, "id": {sessions.ID(e.request(bob))}, "token": {e.store.CSRFToken(e.request(alice))}}
	r := httptest.NewRequest("POST", "/debug-sessions", strings.NewReader(form.Encode()))
	r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Set("Cookie", "adt_session="+alice.cookie)
	r.Header.Set(auth.HeaderUser, alice.user)
	w := httptest.NewRecorder()
	e.a.Handler().ServeHTTP(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("%d, want 200", w.Code)
	}
	if !e.store.IsRevoked(e.request(bob)) {
		t.Fatal("bob's session was not evicted by the administrator")
	}
	if e.store.IsRevoked(e.request(alice)) {
		t.Fatal("the administrator evicted their own session")
	}
}

// loggedAgain is the same person with a new session: a new login makes a new cookie.
func loggedAgain(p person) person { return person{p.user, p.cookie + "-second-login", p.admin} }

func (e *sessionEnv) login(p person) {
	e.store.Track(e.request(p), auth.Identity{User: p.user, Expiry: time.Now().Add(time.Hour)})
}

func deploy(e *sessionEnv) {
	post(e.a.Handler(), url.Values{"key": {"plf-7.3.x"}, "host": {"h.example.org"}, "date": {"20261121.101500"}}, nil)
}

// Logging in again after an eviction works, for an administrator and for an ordinary user: the new session gets its
// socket and its events; the evicted one stays dead (the old cookie is not revived by the new login), and an eviction
// of every session of a user ("evict user") leaves the next login alone as well.
func TestReloginAfterEviction(t *testing.T) {
	for _, p := range []person{alice, bob} {
		for _, how := range []string{"one session", "every session of the user"} {
			t.Run(p.user+" "+how, func(t *testing.T) {
				e := newSessionEnv(t)
				old := e.connect(p)
				if how == "one session" {
					e.evict(p)
				} else if e.store.EvictUser(httptest.NewRequest("POST", "/debug-sessions", nil), p.user, "") == 0 {
					t.Fatal("nothing evicted")
				}
				expectLogout(t, p.user, old)

				again := loggedAgain(p)
				e.login(again)
				fresh := e.connect(again)
				deploy(e)
				if m := wsMessage(t, fresh); !strings.Contains(m, `"type":"deployed"`) {
					t.Fatalf("the new session does not hear deployments: %q", m)
				}
				if status, _, _ := e.open(p, ""); !strings.Contains(status, "403") {
					t.Errorf("the evicted cookie works again after the new login: %q", status)
				}
			})
		}
	}
}

// A block: the login is refused while it lasts (sockets of that user too), and works again once it is lifted or has
// expired. The expired block leaves its line in revoked.txt until the list is regenerated: the socket must not be
// refused because of that stale line.
func TestReloginAfterBlock(t *testing.T) {
	for _, p := range []person{alice, bob} {
		t.Run(p.user, func(t *testing.T) {
			e := newSessionEnv(t)
			admin := httptest.NewRequest("POST", "/debug-sessions", nil)
			old := e.connect(p)
			e.store.BlockUser(admin, p.user, 15, "")
			expectLogout(t, p.user, old)

			again := loggedAgain(p)
			if status, _, _ := e.open(again, ""); !strings.Contains(status, "403") {
				t.Fatalf("a blocked user logs in again and gets a socket: %q", status)
			}

			// lifted by an administrator
			if !e.store.UnblockUser(admin, sessions.UserHash(p.user)) {
				t.Fatal("block not found")
			}
			e.login(again)
			e.connect(again)

			// a block that expires by itself: its file is gone once expired, its line stays in revoked.txt
			e.store.BlockUser(admin, p.user, 15, sessions.ID(e.request(again)))
			blocks, _ := os.ReadFile(e.store.Dir() + "/revoked.txt")
			if !strings.Contains(string(blocks), sessions.UserHash(p.user)) {
				t.Fatalf("revoked.txt lacks the block: %q", blocks)
			}
			for _, b := range e.store.ListBlocked() {
				// rewind the end of the block to the past
				_ = os.WriteFile(e.store.Dir()+"/blocked/"+b.Hash+".json", []byte(`{"hash":"`+b.Hash+`","user":"`+b.User+`","until":1,"by":"x","at":1}`), 0o644)
			}
			third := person{p.user, p.cookie + "-third-login", p.admin}
			e.login(third)
			status, _, br := e.open(third, "")
			if !strings.Contains(status, "101") {
				t.Fatalf("expired block still refuses the socket: %q", status)
			}
			skipHandshake(t, br)
		})
	}
}

func (e *sessionEnv) get(p *person, path string) *httptest.ResponseRecorder {
	r := httptest.NewRequest("GET", path, nil)
	if p != nil {
		r.Header.Set("Cookie", "adt_session="+p.cookie)
		r.Header.Set(auth.HeaderUser, p.user)
	}
	w := httptest.NewRecorder()
	e.a.Handler().ServeHTTP(w, r)
	return w
}

// "Sign out" ends the session on the server: Apache's own logout only clears the cookie in the browser, and the cookie is
// encrypted and stateless, so a copy of it (shared computer, proxy log, backup) would stay valid until it expires. The
// session joins revoked.txt (which Apache checks on every request), its open socket is told to log out at once, and the
// sessions of other people (an administrator, or the same person elsewhere) are not touched.
func TestLogoutEndsTheSessionOnTheServer(t *testing.T) {
	for _, p := range []person{alice, bob} {
		t.Run(p.user, func(t *testing.T) {
			e := newSessionEnv(t)
			other := alice
			if p == alice {
				other = bob
			}
			mine, theirs := e.connect(p), e.connect(other)

			w := e.get(&p, "/logout")
			if w.Code != http.StatusFound || w.Header().Get("Location") != "/do-logout" {
				t.Fatalf("/logout: %d -> %q, want 302 /do-logout (Apache clears the cookie there)", w.Code, w.Header().Get("Location"))
			}
			if !e.store.IsRevoked(e.request(p)) {
				t.Fatal("the session is not in revoked.txt: a copy of the cookie still works")
			}
			expectLogout(t, p.user, mine) // the tabs of that session leave at once
			if status, _, _ := e.open(p, ""); !strings.Contains(status, "403") {
				t.Errorf("the signed-out cookie opens a socket: %q", status)
			}
			// nobody else is affected
			if e.store.IsRevoked(e.request(other)) {
				t.Fatalf("the session of %s was revoked too", other.user)
			}
			deploy(e)
			if m := wsMessage(t, theirs); !strings.Contains(m, `"type":"deployed"`) {
				t.Fatalf("%s lost the socket: %q", other.user, m)
			}
			// signing in again is a new session
			again := loggedAgain(p)
			e.login(again)
			e.connect(again)
		})
	}
}

// A request that has no session of its own (a visitor, an unknown cookie, a second sign-out) changes nothing and still
// ends on /do-logout: the page must never answer an error to someone trying to sign out.
func TestLogoutWithoutSessionIsHarmless(t *testing.T) {
	e := newSessionEnv(t)
	unknown := person{"mallory", "never-seen-cookie", false}
	for name, p := range map[string]*person{"no cookie": nil, "unknown cookie": &unknown} {
		w := e.get(p, "/logout")
		if w.Code != http.StatusFound || w.Header().Get("Location") != "/do-logout" {
			t.Errorf("%s: %d -> %q", name, w.Code, w.Header().Get("Location"))
		}
	}
	if e.store.IsRevoked(e.request(alice)) || e.store.IsRevoked(e.request(bob)) {
		t.Fatal("a stranger's sign-out revoked a session")
	}
	// twice in a row
	if w := e.get(&bob, "/logout"); w.Code != http.StatusFound {
		t.Fatal(w.Code)
	}
	if w := e.get(&bob, "/logout"); w.Code != http.StatusFound || w.Header().Get("Location") != "/do-logout" {
		t.Fatalf("second sign-out: %d", w.Code)
	}
	// only GET: nothing else is registered on the path
	r := httptest.NewRequest("POST", "/logout", nil)
	r.Header.Set("Cookie", "adt_session="+alice.cookie)
	w := httptest.NewRecorder()
	e.a.Handler().ServeHTTP(w, r)
	if w.Code == http.StatusFound || e.store.IsRevoked(e.request(alice)) {
		t.Fatalf("POST /logout: %d, the session is revoked: %v", w.Code, e.store.IsRevoked(e.request(alice)))
	}
}
