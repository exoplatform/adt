package rest

import (
	"log"
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/events"
)

// The deployment notifications (see package events):
//
//	POST /internal/deployed   adt.sh, on the local socket only: the instance has been deployed and started
//	GET  /rest/local-events   the deployments of this server, as server-sent events (the other servers relay it)
//	GET  /events              the deployments of every server, for the pages
func init() {
	app.HandleFunc("POST /internal/deployed", internalDeployed)
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
	host, date := r.PostFormValue("host"), r.PostFormValue("date")
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
