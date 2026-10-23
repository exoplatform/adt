package rest

import (
	"encoding/json"
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/crowdin"
	"github.com/exoplatform/adt/web/internal/gitx"
)

// Latest result of one GitHub Actions workflow, for the Crowdin Healthcheck page. The logic is in package crowdin.
//
// The page script calls /crowdin-status from the browser, so it is behind the usual login. /rest/ is reserved for
// the other acceptance servers and Apache only admits them by host name: the same handler is still served there,
// under both names, for anything that calls it that way. The three routes share one client and one cache.
func init() {
	var shared http.Handler
	build := func(a *app.App) http.Handler {
		if shared == nil {
			shared = crowdinStatus(a)
		}
		return shared
	}
	for _, pattern := range []string{"GET /crowdin-status", "GET /rest/crowdin-status", "GET /rest/crowdin-status.php"} {
		app.Handle(pattern, build)
	}
}

func crowdinStatus(a *app.App) http.Handler {
	client := crowdin.NewClient()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Cache-Control", "private, max-age=60")
		q := r.URL.Query()
		org, repo, workflow, branch := q.Get("org"), q.Get("repo"), q.Get("workflow"), q.Get("branch")
		if !crowdin.ValidParams(org, repo, workflow, branch) {
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"level":null,"message":"invalid parameters"}`))
			return
		}
		if !crowdin.Known(crowdin.Modules(a.Cfg.DataDir, gitx.Repositories(), crowdin.StableVersion), org, repo, workflow, branch) {
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"level":null,"message":"unknown repository or workflow"}`))
			return
		}
		_ = json.NewEncoder(w).Encode(client.Status(r.Context(), org, repo, workflow, branch))
	})
}
