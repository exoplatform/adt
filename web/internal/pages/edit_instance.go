package pages

import (
	"net/http"
	"path/filepath"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/confedit"
)

// editInstance: POST handler of the "edit note" modal.
// Fields: key, from, note. The note is stored in conf/instances/<key>.note; an empty note ("" or "0")
// removes the file. A missing or invalid key is a 400.
func init() {
	for _, m := range []string{"GET", "POST"} {
		app.HandleFunc(m+" /editInstance", editInstance)
		app.HandleFunc(m+" /editInstance.php", editInstance)
	}
}

func editInstance(a *app.App, w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		comeBack(a, w, r)
		return
	}
	form, ok := editGuard(a, w, r)
	if !ok {
		return
	}
	get := func(k string) string {
		if v := form[k]; len(v) > 0 {
			return v[0]
		}
		return ""
	}
	key, note := get("key"), get("note")
	if !confedit.ValidKey(key) {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	state := "removed"
	if !editValueEmpty(note) {
		state = "set"
	}
	audit.For(a.Cfg.DataDir).Add(r, "instance.edit", "key", key, "note", state)
	st := confedit.Store{Dir: filepath.Join(a.Cfg.DataDir, "conf", "instances")}
	var err error
	if state == "set" {
		err = st.Put(key, ".note", note)
	} else {
		err = st.Remove(key, ".note")
	}
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	cache.Default.Clear()
	redirect(w, confedit.WithClearCaches(confedit.ResolveFrom(get("from"), r.Host, a.Cfg.FormServers())))
}
