package rest

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/confedit"
	"github.com/exoplatform/adt/web/internal/push"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// Web Push (see package push). Apache has already signed the visitor in (these paths are not public):
//
//	GET  /push/key          the VAPID public key (applicationServerKey of pushManager.subscribe)
//	POST /push/subscribe    {"endpoint", "keys": {"p256dh", "auth"}, "instances": [...]}: this browser follows these
//	                        instances (replaces its previous list; an empty list unsubscribes it)
//	POST /push/unsubscribe  {"endpoint"}
func init() {
	app.HandleFunc("GET /push/key", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte(a.Push.PublicKey()))
	})
	app.HandleFunc("POST /push/subscribe", pushSubscribe)
	app.HandleFunc("POST /push/unsubscribe", pushUnsubscribe)
}

type subscribeRequest struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256dh string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
	Instances []string `json:"instances"`
}

// pushRequest runs the checks of both POSTs: signed in, same origin, bounded JSON body.
func pushRequest(a *app.App, w http.ResponseWriter, r *http.Request, into any) (user string, ok bool) {
	user = auth.From(r).User
	if user == "" || !confedit.SameOrigin(r, a.Cfg.FormServers()) {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return "", false
	}
	r.Body = http.MaxBytesReader(w, r.Body, 64<<10)
	if err := json.NewDecoder(r.Body).Decode(into); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return "", false
	}
	return user, true
}

func pushSubscribe(a *app.App, w http.ResponseWriter, r *http.Request) {
	var req subscribeRequest
	user, ok := pushRequest(a, w, r, &req)
	if !ok {
		return
	}
	sub := push.Subscription{Endpoint: req.Endpoint, P256dh: req.Keys.P256dh, Auth: req.Keys.Auth}
	// tied to the login session: signing out (or an eviction) ends the notifications, its expiry does not
	if err := a.Push.Set(user, sessions.ID(r), sub, req.Instances); err != nil {
		if errors.Is(err, push.ErrInvalid) {
			http.Error(w, "invalid subscription", http.StatusBadRequest)
			return
		}
		log.Printf("push: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func pushUnsubscribe(a *app.App, w http.ResponseWriter, r *http.Request) {
	var req subscribeRequest
	if _, ok := pushRequest(a, w, r, &req); !ok {
		return
	}
	if err := a.Push.Remove(req.Endpoint); err != nil {
		log.Printf("push: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
