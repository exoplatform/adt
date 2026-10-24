package rest

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
)

// /rest/all-instances: the instances of all the acceptance servers as JSON.
// Secrets are filtered here too: the data may come from servers that still publish them.
func init() {
	for _, p := range []string{"/rest/all-instances.php", "/rest/all-instances"} {
		app.HandleFunc("GET "+p, func(a *app.App, w http.ResponseWriter, r *http.Request) {
			o := instances.OriginFromRequest(r)
			if checkInstanceCaches(a, w, r) {
				return
			}
			writeInstancesJSON(w, a.Instances.Global(r.Context(), o).Public())
		})
	}
}
