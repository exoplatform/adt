package rest

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
)

// /rest/local-instances: the instances of this server as JSON. The other
// acceptance servers fetch <server>/rest/local-instances.php, so that path is served as well as the
// extension-less one. Secrets of the descriptors are not published (see instances.Instance.Public).
func init() {
	for _, p := range []string{"/rest/local-instances.php", "/rest/local-instances"} {
		app.HandleFunc("GET "+p, func(a *app.App, w http.ResponseWriter, r *http.Request) {
			o := instances.OriginFromRequest(r)
			if checkInstanceCaches(a, w, r) {
				return
			}
			writeInstancesJSON(w, a.Instances.Local(o).Public())
		})
	}
}

// checkInstanceCaches handles ?clearCaches, see instances.Store.CheckCaches.
func checkInstanceCaches(a *app.App, w http.ResponseWriter, r *http.Request) bool {
	return a.Instances.CheckCaches(w, r)
}

// writeInstancesJSON answers with the JSON of the instances (default
// text/html type; consumers only parse the body).
func writeInstancesJSON(w http.ResponseWriter, v *instances.Branches) {
	body, err := v.MarshalJSON() // not json.Marshal: it would re-escape <, > and & in the output
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_, _ = w.Write(body)
}
