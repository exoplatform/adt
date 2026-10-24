package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/stats"
)

// /server-stats: live usage of all acceptance servers, polled by the servers page.
// Unlike /rest/, it sits behind the usual login. /server-stats.php is
// redirected to the extension-less URL.
func init() {
	app.HandleFunc("GET /server-stats", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		b, err := stats.Marshal(stats.For(a, r))
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write(b)
	})
	app.HandleFunc("GET /server-stats.php", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		target := "/server-stats"
		if r.URL.RawQuery != "" {
			target += "?" + r.URL.RawQuery
		}
		http.Redirect(w, r, target, http.StatusMovedPermanently)
	})
}
