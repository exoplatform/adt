package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/debugx"
)

// /debug: the index of the debug pages. Apache restricts /debug* to the LDAP
// admin group; this server relies on that.
func init() {
	app.HandleFunc("GET /debug", debugIndex)
}

func debugIndex(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	debugx.Open(c, "debug", true)
	c.WriteString(tpl.Must("debug_index.tmpl", map[string]string{"Menu": debugx.Menu(c)}))
	dbgEnd(c)
}
