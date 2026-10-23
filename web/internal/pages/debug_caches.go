package pages

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/debugx"
)

// /debug-caches: state of the in-process cache. Deleting an entry is a POST with the anti-CSRF token; the two GET links of the
// UI (refreshInstances, clearCaches) refuse requests the browser marks as cross-site.
func init() {
	app.HandleFunc("GET /debug-caches", debugCaches)
	app.HandleFunc("POST /debug-caches", debugCaches)
}

// cacheKeyText shows a key as text: NUL bytes (the branch caches use them as separators) become U+2400.
func cacheKeyText(k string) string { return strings.ReplaceAll(k, "\x00", "␀") }

func debugCaches(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	cc := cache.Default
	if r.Method == http.MethodPost && r.PostFormValue("action") == "delete-key" {
		if !c.Sessions.CheckCSRF(r, r.PostFormValue("token")) {
			http.Error(w, "Invalid token", http.StatusForbidden)
			return
		}
		want := r.PostFormValue("key")
		list, _ := cc.Inspect()
		for _, e := range list {
			if cacheKeyText(e.Key) == want {
				cc.Delete(e.Key)
				c.Audit.Add(r, "cache.delete-key", "key", want)
				break
			}
		}
		redirect(w, "/debug-caches")
		return
	}
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	if dbgCheckCaches(c) {
		return
	}
	if _, ok := r.URL.Query()["refreshInstances"]; ok {
		if crossSite(r) {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}
		c.Audit.Add(r, "cache.refresh-instances")
		// Drop both copies so the next read fetches the servers again (and waits for the answer)
		cc.Delete("all_instances")
		cc.Delete("all_instances_stale")
		a.Instances.Global(r.Context(), c.Origin)
		redirect(w, "/debug-caches")
		return
	}

	list, stats := cc.Inspect()
	now := time.Now()
	byKey := map[string]cache.Info{}
	for _, e := range list {
		byKey[e.Key] = e
	}
	left := func(e cache.Info) string {
		if e.TTL <= 0 {
			return "never"
		}
		d := e.Created.Add(e.TTL).Sub(now)
		return strconv.FormatInt(max(0, int64(d.Seconds())), 10) + "s"
	}
	age := func(e cache.Info) string { return strconv.FormatInt(int64(now.Sub(e.Created).Seconds()), 10) + "s" }

	type wellRow struct{ Key, Role, Age, Left string }
	var well []wellRow
	for _, wk := range [][2]string{
		{"all_instances", "Fresh instances (all servers)"},
		{"all_instances_stale", "Stale instances, served while refreshing"},
		{"all_instances_refreshing", "Background refresh scheduled"},
		{"all_server_stats", "Server stats"},
	} {
		ageS, leftS := "-", "not cached"
		if e, ok := byKey[wk[0]]; ok {
			ageS, leftS = age(e), left(e)
		}
		well = append(well, wellRow{wk[0], wk[1], ageS, leftS})
	}
	hits, misses := stats.Hits, stats.Misses
	rate := ""
	if hits+misses > 0 {
		rate = " (" + strconv.FormatInt(int64(100*float64(hits)/float64(hits+misses)+0.5), 10) + "% hit rate)"
	}
	type entryRow struct {
		Key, Age, Left string
		Hits           int64
	}
	var rows []entryRow
	for i, e := range list {
		if i >= 300 {
			break
		}
		rows = append(rows, entryRow{cacheKeyText(e.Key), age(e), left(e), e.Hits})
	}

	debugx.Open(c, "debug - caches", true)
	c.WriteString(tpl.Must("debug_caches.tmpl", map[string]any{
		"Menu":    debugx.Menu(c),
		"Well":    well,
		"Entries": stats.Entries,
		"Hits":    hits,
		"Misses":  misses,
		"Rate":    rate,
		"Started": stats.Started.UTC().Format("2006-01-02 15:04"),
		"List":    rows,
		"Count":   len(list),
		"Token":   c.CSRFToken(),
		"Dump": debugx.Var(debugx.Array{
			{Key: "num_slots", Val: 4096}, {Key: "ttl", Val: 0}, {Key: "num_hits", Val: hits}, {Key: "num_misses", Val: misses},
			{Key: "num_inserts", Val: stats.Inserts}, {Key: "num_entries", Val: stats.Entries}, {Key: "expunges", Val: 0},
			{Key: "start_time", Val: stats.Started.Unix()}, {Key: "mem_size", Val: 0}, {Key: "memory_type", Val: "in-process (Go)"},
		}),
	}))
	dbgEnd(c)
}
