package rest

import (
	"log"
	"net/http"
	"regexp"
	"strings"
	"sync"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/events"
	"github.com/exoplatform/adt/web/internal/gitx"
)

// The deployment notifications (see package events):
//
//	POST /internal/deployed   adt.sh, on the local socket only: the instance has been deployed and started
//	POST /internal/refresh    adt.sh, on the local socket only: the repositories were fetched, the feature branches are refreshed
//	                          and the pages are told ("branches" on /ws)
//	GET  /rest/local-events   the deployments of this server, as server-sent events (the other servers relay it)
//	GET  /events              the deployments of every server, as server-sent events
//	GET  /ws                  the same for the pages, over a WebSocket (ws.go), which also tells a session it was evicted
func init() {
	app.HandleFunc("POST /internal/deployed", internalDeployed)
	app.HandleFunc("POST /internal/refresh", internalRefresh)
	app.HandleFunc("GET /rest/local-events", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		events.Stream(w, r, a.Events.Local)
	})
	app.HandleFunc("GET /events", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		events.Stream(w, r, a.Events.All)
	})
}

// proxiedHeaders are what Apache adds to a request it forwards (the proxy headers, and the identity it
// authenticated). adt.sh talks to the socket directly, so a request that carries one of them came through
// Apache, from a visitor: it must not be able to announce a deployment.
var proxiedHeaders = []string{
	"X-Forwarded-For", "X-Forwarded-Host", "X-Forwarded-Server", "X-Forwarded-Proto", "Forwarded", "X-Real-Ip",
	auth.HeaderUser, auth.HeaderName, auth.HeaderMail, auth.HeaderExpiry, auth.HeaderSession, auth.HeaderSessionUser,
	auth.HeaderRequestLine,
}

func directRequest(r *http.Request) bool {
	for _, h := range proxiedHeaders {
		if r.Header.Get(h) != "" {
			return false
		}
	}
	return true
}

func internalDeployed(a *app.App, w http.ResponseWriter, r *http.Request) {
	if !directRequest(r) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	key := r.PostFormValue("key")
	if !events.ValidKey(key) {
		http.Error(w, "invalid key", http.StatusBadRequest)
		return
	}
	// host and date are compared or shown by the pages: the alphabet of a key is enough (a date is 20060102.150405)
	// the host is shown as it is in the notifications: an address, never a URL (DEPLOYMENT_EXT_HOST has no protocol, but
	// a scheme that sneaked in must not turn the host into "unknown")
	host, date := r.PostFormValue("host"), r.PostFormValue("date")
	host = strings.TrimSuffix(strings.TrimPrefix(strings.TrimPrefix(host, "https://"), "http://"), "/")
	if host != "" && !events.ValidKey(host) {
		host = ""
	}
	if date != "" && !events.ValidKey(date) {
		date = ""
	}
	// Before the announcement: the servers that hear of it read this server's list straight away, and must not
	// get the copy cached before the deployment
	a.Instances.InvalidateInstances()
	e := a.Events.PublishLocal(key, host, date)
	log.Printf("events: %s deployed (%s)", e.Key, e.ID)
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusNoContent)
}

var (
	repoNameRe     = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$`)
	refreshMu      sync.Mutex // one refresh at a time: a burst of announcements must not pile up git commands
	maxRepoNames   = 200
	maxRefreshBody = int64(16 << 10)
)

// repoNames reads the repos= values of a refresh announcement: names of repositories, nothing else, each once, at most maxRepoNames.
func repoNames(values []string) []string {
	var out []string
	seen := map[string]bool{}
	for _, v := range values {
		if !repoNameRe.MatchString(v) || seen[v] || strings.Contains(v, "..") {
			continue
		}
		seen[v] = true
		out = append(out, v)
		if len(out) == maxRepoNames {
			break
		}
	}
	return out
}

// internalRefresh: adt.sh has fetched the repositories (init, update-repos) and names, with repos=, those whose branches moved
// (several repos= values; none means "all of them"). Only their branch listings are recomputed (the others stay as they are: no
// git work for them), then the pages are told, so that the page that asks for itself again gets the new branches and not the
// cached ones. It answers at once: adt.sh does not wait for git.
func internalRefresh(a *app.App, w http.ResponseWriter, r *http.Request) {
	if !directRequest(r) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxRefreshBody)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	repos := repoNames(r.PostForm["repos"])
	go func() {
		refreshMu.Lock()
		defer refreshMu.Unlock()
		gitx.RefreshFeatureBranches(a.Cfg.DataDir, repos)
		e := a.Events.PublishBranches(repos)
		log.Printf("events: branches refreshed (%d repositories, %s)", len(repos), e.ID)
	}()
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusNoContent)
}
