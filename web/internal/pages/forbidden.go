package pages

import (
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/phpx"
	"github.com/exoplatform/adt/web/internal/sessions"
	"github.com/exoplatform/adt/web/static"
)

// The 403 page (ErrorDocument 403 /errors/frontend/403.html).
//
//   - A session evicted from /debug-sessions is rejected by Apache with a 403: send that user back to the
//     login page instead of showing "Access Forbidden".
//   - A user blocked from /debug-sessions gets a 403 once logged in: say so, and retry the request as soon as
//     the block has expired (its entry is then dropped from revoked.txt).
//
// On an ErrorDocument request Apache has lost REMOTE_USER and the URL, so the handler works from the headers
// documented in package auth: X-Request-Line (original request), X-Remote-User or X-Session-User, and the
// session hash (X-Session-Hash or the Cookie header).
func init() {
	// An ErrorDocument keeps the method of the request that was refused (a method-less pattern would
	// conflict with the "GET /" fallback of the app, so list them).
	for _, m := range []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"} {
		app.HandleFunc(m+" /errors/frontend/403.html", forbidden)
	}
}

func forbidden(a *app.App, w http.ResponseWriter, r *http.Request) {
	store := sessions.For(a.Cfg.DataDir)
	orig := originalURL(r)
	if store.IsRevoked(r) {
		redirect(w, "/login?next="+phpx.RawURLEncode(orig))
		return
	}
	html := forbiddenHTML(a)
	user := auth.SessionUser(r)
	if user != "" {
		if block := store.UserBlock(user); block != nil { // drops the expired blocks
			notice := `<p class="sub" role="alert">Your access has been blocked by an administrator until ` +
				phpx.Esc(time.Unix(block.Until, 0).UTC().Format("15:04")) + ` UTC.</p>`
			html = strings.ReplaceAll(html, `<div class="cards">`, notice+`<div class="cards">`)
		} else if store.IsUserListed(user) {
			// Stale entry of an expired block: regenerate revoked.txt, then retry once it is gone
			store.List()
			if !store.IsUserListed(user) {
				redirect(w, orig)
				return
			}
		}
	}
	w.Header().Set("Content-Type", "text/html; charset=UTF-8")
	a.StaticPageCSP(w, []byte(html))
	w.WriteHeader(http.StatusForbidden)
	_, _ = w.Write([]byte(html))
}

// originalURL is the URL the visitor asked for, recovered from the request line
// "GET /path?query HTTP/1.1" Apache passes in X-Request-Line. Only a local path is returned (never a
// protocol-relative "//host" or a backslash form), else "/": it ends up in a Location header.
func originalURL(r *http.Request) string {
	u := r.URL.RequestURI()
	if f := strings.Fields(r.Header.Get(auth.HeaderRequestLine)); len(f) >= 2 {
		u = f[1]
	}
	if !strings.HasPrefix(u, "/") || strings.HasPrefix(u, "//") || strings.ContainsAny(u, "\\\r\n") {
		return "/"
	}
	return u
}

func forbiddenHTML(a *app.App) string {
	var b []byte
	var err error
	if a.Cfg.StaticDir != "" {
		b, err = os.ReadFile(filepath.Join(a.Cfg.StaticDir, "errors", "403.html"))
	} else {
		b, err = fs.ReadFile(static.FS, "errors/403.html")
	}
	if err != nil {
		return "<h1>403 Forbidden</h1>"
	}
	return string(b)
}

// redirect sends a bare 302, no body, the target untouched.
func redirect(w http.ResponseWriter, to string) {
	w.Header().Set("Location", to)
	w.WriteHeader(http.StatusFound)
}
