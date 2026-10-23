package pages

import (
	"net/http"
	"path/filepath"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/confedit"
	"github.com/exoplatform/adt/web/internal/ui"
)

// editFeature: POST handler of the "edit feature branch" modal.
// Fields: key, from, description, specifications, issue, status, branch. Each value is
// stored in conf/features/<key>.{desc,spec,issue,status,branch}; an empty value ("" or "0")
// removes the file, and so does branch=UNSET. Then the caches are cleared and the browser goes back to
// `from` with clearCaches=true.
func init() {
	// GET is routed too, only to answer 405 (the catch-all "GET /" would otherwise serve the 404 page).
	for _, m := range []string{"GET", "POST"} {
		app.HandleFunc(m+" /editFeature", editFeature)
		app.HandleFunc(m+" /editFeature.php", editFeature)
	}
}

// featureFiles lists the form field -> file extension mapping.
var featureFiles = []struct{ field, ext string }{
	{"specifications", ".spec"},
	{"status", ".status"},
	{"issue", ".issue"},
	{"description", ".desc"},
}

// editValueEmpty reports whether s is "" or "0".
func editValueEmpty(s string) bool { return s == "" || s == "0" }

// editGuard runs the checks every conf-writing POST shares: signed-in user, POST, same origin, bounded
// well-formed body. It answers the error itself and returns ok=false.
func editGuard(a *app.App, w http.ResponseWriter, r *http.Request) (form map[string][]string, ok bool) {
	if r.Method != http.MethodPost {
		confedit.Fail(w, confedit.ErrBadMethod)
		return nil, false
	}
	if auth.From(r).User == "" {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return nil, false
	}
	if !confedit.SameOrigin(r, a.Cfg.Servers) {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return nil, false
	}
	f, err := confedit.ParseForm(w, r)
	if err != nil {
		confedit.Fail(w, err)
		return nil, false
	}
	return f, true
}

// comeBack answers the GET that follows a login. A form posted to another acceptance server, where the visitor had
// no session, was sent to that server's login page and then lands here with the page of the form in "from"; the
// edit itself went with the lost POST. Nothing is changed: the visitor is sent back to that page, now signed in
// on both servers, to submit the form again. The target must be this server or one of the acceptance servers.
func comeBack(a *app.App, w http.ResponseWriter, r *http.Request) {
	redirect(w, confedit.ResolveFrom(r.URL.Query().Get("from"), r.Host, a.Cfg.Servers))
}

func editFeature(a *app.App, w http.ResponseWriter, r *http.Request) {
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
	if key := get("key"); key != "" {
		if !confedit.ValidKey(key) {
			http.Error(w, "Bad Request", http.StatusBadRequest)
			return
		}
		if v := get("specifications"); !editValueEmpty(v) && !ui.IsWebURL(v) { // shown as a link on the cards
			http.Error(w, "Bad Request: the specifications link must be an http or https URL", http.StatusBadRequest)
			return
		}
		st := confedit.Store{Dir: filepath.Join(a.Cfg.DataDir, "conf", "features")}
		fields := []string{}
		for _, f := range []string{"specifications", "status", "issue", "description", "branch"} {
			if !editValueEmpty(get(f)) {
				fields = append(fields, f)
			}
		}
		audit.For(a.Cfg.DataDir).Add(r, "feature.edit", "key", key, "fields", fields)
		for _, f := range featureFiles {
			if v := get(f.field); !editValueEmpty(v) {
				if err := st.Put(key, f.ext, v); err != nil {
					http.Error(w, "Internal Server Error", http.StatusInternalServerError)
					return
				}
			} else if err := st.Remove(key, f.ext); err != nil {
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
				return
			}
		}
		// branch: UNSET (or empty) means remove the file
		var err error
		if v, set := form["branch"]; set && len(v) > 0 && v[0] != "UNSET" && v[0] != "" {
			err = st.Put(key, ".branch", v[0])
		} else {
			err = st.Remove(key, ".branch")
		}
		if err != nil {
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
	}
	cache.Default.Clear()
	redirect(w, confedit.WithClearCaches(confedit.ResolveFrom(get("from"), r.Host, a.Cfg.Servers)))
}
