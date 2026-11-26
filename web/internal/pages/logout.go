package pages

import (
	"log"
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// GET /logout: "Sign out". The sessions are encrypted cookies, and Apache's form-logout-handler only clears the cookie in
// the browser: a copy of it would stay valid until it expires (up to 7 days with "remember me"). So the sign-out goes
// through here first: the session is ended on the server (see sessions.Store.Logout: it joins revoked.txt, which Apache
// checks on every request, and the sockets and tabs of that session are told at once), then the browser is sent to
// /do-logout, the Apache handler that clears the cookie and lands on the login page.
//
// /logout stays public (Apache), so that a session that has already expired can still sign out. It changes nothing
// for a request without a session of its own: only the holder of the cookie can name it.
func init() {
	app.HandleFunc("GET /logout", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		sessions.For(a.Cfg.DataDir).Logout(r)
		// the browsers that registered for push notifications under this session stop receiving them
		if err := a.Push.RemoveSession(sessions.ID(r)); err != nil {
			log.Printf("logout: push: %v", err)
		}
		w.Header().Set("Cache-Control", "no-store")
		http.Redirect(w, r, "/do-logout", http.StatusFound)
	})
}
