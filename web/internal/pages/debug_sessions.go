package pages

import (
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// /debug-sessions: connected users, session time, eviction and blocking.
// Apache restricts /debug* to the LDAP admin group.
// Every POST needs the anti-CSRF token; nobody can evict their own session or block themselves.
func init() {
	app.HandleFunc("GET /debug-sessions", debugSessions)
	app.HandleFunc("POST /debug-sessions", debugSessions)
}

// A login name as LDAP and Apache give it: no control characters, bounded length.
var validLogin = regexp.MustCompile(`^[^\x00-\x1f\x7f]{1,256}$`)

type notice struct{ kind, text string }

func debugSessions(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	store := c.Sessions
	var n *notice
	current := c.SessionID()
	me := strings.ToLower(audit.Actor(r))
	if r.Method == http.MethodPost {
		r.Body = http.MaxBytesReader(w, r.Body, 64<<10)
		if r.ParseForm() != nil || !store.CheckCSRF(r, r.PostForm.Get("token")) {
			http.Error(w, "Invalid token", http.StatusForbidden)
			return
		}
		id := r.PostForm.Get("id")
		user := strings.TrimSpace(r.PostForm.Get("user"))
		if user != "" && !validLogin.MatchString(user) {
			n = &notice{"warning", "Invalid user name."}
		} else {
			switch r.PostForm.Get("action") {
			case "evict-all":
				k := store.EvictAll(r, current)
				n = &notice{"success", strconv.Itoa(k) + " session(s) evicted (yours was kept): those users are sent back to the login page on their next request."}
			case "evict-user":
				k := 0
				if user != "" {
					k = store.EvictUser(r, user, current)
				}
				n = &notice{"success", strconv.Itoa(k) + " session(s) of " + user + " evicted."}
			case "block":
				minutes := 60
				switch m := phpIntval(r.PostForm.Get("minutes")); m {
				case 15, 60, 480, 1440:
					minutes = int(m)
				}
				if user == "" || strings.ToLower(user) == me {
					n = &notice{"warning", "You cannot block yourself."}
				} else {
					store.BlockUser(r, user, minutes, current)
					n = &notice{"success", user + " is blocked for " + strconv.Itoa(minutes) + " minute(s): their sessions are evicted and they cannot log in again meanwhile."}
				}
			case "unblock":
				if store.UnblockUser(r, r.PostForm.Get("hash")) {
					n = &notice{"success", "User unblocked."}
				} else {
					n = &notice{"danger", "Block not found."}
				}
			default:
				if id == current {
					n = &notice{"warning", "You cannot evict your own session (use Logout)."}
				} else if store.Evict(r, id) {
					n = &notice{"success", "Session evicted: the user is sent back to the login page on the next request."}
				} else {
					n = &notice{"danger", "Session not found."}
				}
			}
		}
	}
	list := store.List()
	blocked := store.ListBlocked()
	now := time.Now().Unix()
	token := c.CSRFToken()

	// Users with at least one live session, with their session count
	type byUser struct {
		user, name string
		count      int
	}
	users := map[string]*byUser{}
	for _, s := range list {
		if !s.Evicted {
			k := strings.ToLower(s.User)
			if users[k] == nil {
				users[k] = &byUser{user: s.User, name: s.Name}
			}
			users[k].count++
		}
	}
	keys := make([]string, 0, len(users))
	for k := range users {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	debugx.Open(c, "debug - sessions", false)
	type sessionRow struct {
		Name, User, IP, UA, ID, Connected, LastSeen, Expires string
		You, Evicted                                         bool
	}
	sessionRows := make([]sessionRow, len(list))
	for i, s := range list {
		sessionRows[i] = sessionRow{s.Name, s.User, s.IP, s.UA, s.ID,
			sessions.DurationLabel(now - s.FirstSeen), sessions.DurationLabel(now - s.LastSeen), sessions.DurationLabel(s.Expiry - now),
			s.ID == current, s.Evicted}
	}
	type userRow struct {
		Name, User     string
		Count          int
		IsMe, Disabled bool
	}
	userRows := make([]userRow, 0, len(keys))
	for _, k := range keys {
		u := users[k]
		isMe := strings.ToLower(u.user) == me
		userRows = append(userRows, userRow{u.name, u.user, u.count, isMe, isMe && u.count < 2})
	}
	type blockedRow struct{ User, By, Hash, Remaining string }
	blockedRows := make([]blockedRow, len(blocked))
	for i, b := range blocked {
		blockedRows[i] = blockedRow{b.User, b.By, b.Hash, sessions.DurationLabel(b.Until - now)}
	}
	var notice any
	if n != nil {
		notice = map[string]string{"Kind": n.kind, "Text": n.text}
	}
	c.WriteString(tpl.Must("debug_sessions.tmpl", map[string]any{
		"Menu":     debugx.Menu(c),
		"Notice":   notice,
		"Token":    token,
		"Sessions": sessionRows,
		"Users":    userRows,
		"Blocked":  blockedRows,
	}))
	dbgEnd(c)
}
