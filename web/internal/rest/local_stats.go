package rest

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/stats"
)

// /rest/local-stats.php: live resource usage of this server.
// Other acceptance servers fetch it at this exact path, hence the .php name; the extension-less alias is
// served too.
func init() {
	app.HandleFunc("GET /rest/local-stats.php", localStats)
	app.HandleFunc("GET /rest/local-stats", localStats)
}

func localStats(a *app.App, w http.ResponseWriter, r *http.Request) {
	writeJSON(w, stats.LocalFor(a, r))
}

func writeJSON(w http.ResponseWriter, v any) {
	b, err := stats.Marshal(v)
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(b)
}
