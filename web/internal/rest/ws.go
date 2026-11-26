package rest

import (
	"encoding/json"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/events"
	"github.com/exoplatform/adt/web/internal/sessions"
	"github.com/exoplatform/adt/web/internal/ws"
)

const (
	wsPing = 25 * time.Second // keeps proxies from closing an idle socket
	wsIdle = 75 * time.Second // the page answers every ping: silent for that long, it is gone
	// Apache authenticates the handshake only: a session revoked later (or a user removed from the LDAP group) would
	// keep its socket. Closing it now and then makes the page come back through Apache, which checks again.
	wsLifetime = 30 * time.Minute
)

// wsMax is the number of open sockets; more are refused with 503 so that they cannot exhaust the file descriptors.
var wsOpen atomic.Int32

// wsRecheck is how often an open socket checks that its session was not evicted (and its user not blocked) from
// /debug-sessions: a socket must not outlive an eviction by the 30 minutes of its lifetime.
var wsRecheck atomic.Int64 // nanoseconds

func init() { wsRecheck.Store(int64(30 * time.Second)) }

// wsEvent is the ONLY thing the socket sends, field by field. Access: /ws sits under Apache's <Location />, so any
// signed-in employee can open it, exactly like /events and the dashboard pages that show these same instances. It
// must therefore never carry what only an administrator may see (the /debug* pages are a stricter Apache rule), the
// identity of a visitor or the content of a page: a page refreshes itself by fetching its own URL with its own
// cookies, where every access rule applies. A new field is added here deliberately, never inherited from
// events.Event (TestWSMessageFields fails when the set of fields changes).
type wsEvent struct {
	Type string `json:"type"`
	ID   string `json:"id"`
	Key  string `json:"key"`
	Host string `json:"host,omitempty"`
	// Alias: the friendlier address of the instance, when it has one (the toast shows it first)
	Alias string `json:"alias,omitempty"`
	Date  string `json:"date,omitempty"`
	At    int64  `json:"at"`
}

// wsBranches is the message that says the feature branches were refreshed: no key, no host, nothing about an instance; the
// names of the repositories whose branches moved (public: they are listed on the dashboard), when they are known.
type wsBranches struct {
	Type  string   `json:"type"`
	ID    string   `json:"id"`
	At    int64    `json:"at"`
	Repos []string `json:"repos,omitempty"`
}

// eventMessage is what a socket sends for an event of the hub.
func eventMessage(e events.Event) []byte {
	if e.Kind == events.KindBranches {
		b, _ := json.Marshal(wsBranches{Type: "branches", ID: e.ID, At: e.At, Repos: e.Repos})
		return b
	}
	return deployedMessage(e)
}

func deployedMessage(e events.Event) []byte {
	b, _ := json.Marshal(wsEvent{Type: "deployed", ID: e.ID, Key: e.Key, Host: e.Host, Alias: e.Alias, Date: e.Date, At: e.At})
	return b
}

func init() { wsMax.Store(512) }

var wsMax atomic.Int32

// GET /ws: the live channel of the pages. The server pushes one JSON text message per deployment (of any
// acceptance server, see package events) and the page decides what to do with it: update itself, notify the user.
//
//	{"type":"deployed","id":"...","key":"INSTANCE_KEY","host":"...","date":"20060102.150405","at":1700000000}
//
// It replaces the reload every 2 minutes the pages used to do (autorefresh.js now updates them in place). /events
// (server-sent events) stays for other clients.
func init() {
	app.HandleFunc("GET /ws", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		if wsOpen.Add(1) > wsMax.Load() {
			wsOpen.Add(-1)
			http.Error(w, "too many connections", http.StatusServiceUnavailable)
			return
		}
		defer wsOpen.Add(-1)
		store, user := sessions.For(a.Cfg.DataDir), auth.From(r).User
		// Asked for BEFORE the first check: an eviction between the check and the wait for it would otherwise be
		// noticed only by the backup check
		chg := store.Changed()
		// Apache has already refused an evicted session; this is the same check, for a request that reached us another way
		if evicted(store, r, user) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		c, err := ws.Upgrade(w, r)
		if err != nil {
			return // Upgrade has answered
		}
		defer c.Close()
		ch, cancel := a.Events.All.Subscribe()
		defer cancel()
		gone := make(chan struct{})
		go func() { _ = c.Drain(wsIdle); close(gone) }()
		if c.Send([]byte(`{"type":"hello"}`)) != nil {
			return
		}
		tick := time.NewTicker(wsPing)
		defer tick.Stop()
		life := time.NewTimer(wsLifetime)
		defer life.Stop()
		// The recheck is the backup (revoked.txt edited by hand, another process); an eviction made here arrives on chg
		recheck := time.NewTicker(time.Duration(wsRecheck.Load()))
		defer recheck.Stop()
		for {
			select {
			case <-gone:
				return
			case <-r.Context().Done():
				return
			case e := <-ch:
				if c.Send(eventMessage(e)) != nil {
					return
				}
			case <-chg:
				chg = store.Changed()
				if evicted(store, r, user) {
					logout(c)
					return
				}
			case <-recheck.C:
				if evicted(store, r, user) {
					logout(c)
					return
				}
			case <-life.C:
				_ = c.CloseNormal() // nothing was missed: the page reconnects at once and quietly (live.js)
				return
			case <-tick.C:
				if c.Ping() != nil {
					return
				}
			}
		}
	})
}

// evicted tells whether the session of the request was evicted, or its user blocked, from /debug-sessions. It follows
// the 403 page (pages/forbidden.go): the entry of a block that has expired stays in revoked.txt until the list is
// regenerated, and must not keep out somebody who logged in again after it.
func evicted(store *sessions.Store, r *http.Request, user string) bool {
	if store.IsRevoked(r) {
		return true
	}
	if user == "" {
		return false
	}
	if store.UserBlock(user) != nil { // also drops the expired blocks
		return true
	}
	if store.IsUserListed(user) {
		store.List() // stale entry: regenerate revoked.txt
		return store.IsUserListed(user)
	}
	return false
}

// logout tells the page its session is over and ends the socket with 1008 (policy violation). The page then asks
// Apache for its own URL again (the login page comes back) and does not reconnect: see live.js.
func logout(c *ws.Conn) {
	_ = c.Send([]byte(`{"type":"logout"}`))
	_ = c.CloseWith(1008)
}
