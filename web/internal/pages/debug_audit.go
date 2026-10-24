package pages

import (
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/debugx"
)

// /debug-audit: the audit log of the administrative actions.
func init() {
	app.HandleFunc("GET /debug-audit", debugAudit)
}

func uniqueSorted(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range in {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	sort.Strings(out)
	return out
}

func debugAudit(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	f := audit.Filters{
		Action: strings.TrimSpace(dbgQuery(r, "action")),
		User:   strings.TrimSpace(dbgQuery(r, "user")),
		Q:      strings.TrimSpace(dbgQuery(r, "q")),
	}
	entries := c.Audit.Read(500, f)
	all := c.Audit.Read(2000, audit.Filters{})
	var actions, users []string
	for _, e := range all {
		actions = append(actions, e.Action)
		users = append(users, e.User)
	}
	actions, users = uniqueSorted(actions), uniqueSorted(users)

	debugx.PageBegin(c, "audit", "Debug Audit", "Administrative actions done from the dashboard", false)
	type row struct{ Time, User, IP, Action, Detail string }
	rows := make([]row, len(entries))
	for i, e := range entries {
		rows[i] = row{time.Unix(e.TS, 0).UTC().Format("2006-01-02 15:04:05"), e.User, e.IP, e.Action, e.DetailString()}
	}
	c.WriteString(tpl.Must("debug_audit.tmpl", map[string]any{
		"Shown":   len(entries),
		"Actions": debugOptions(actions, f.Action),
		"Users":   debugOptions(users, f.User),
		"Q":       f.Q,
		"Entries": rows,
	}))
	debugx.PageEnd(c)
}
