package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/confedit"
	"github.com/exoplatform/adt/web/internal/gitx"
)

// editFeatureBase: POST handler of the base branch field of the features page.
// Fields: name (the feature branch, without "feature/"), base, from. The base is stored in
// conf/feature-bases/<key>.base; an empty base or "develop" removes the file (back to the default). The base must
// be a branch of at least one project. Administrators only (ADT_ADMIN_USERS, and the LDAP admin group in Apache). Then the browser goes back to `from` with clearCaches=true.
func init() {
	for _, m := range []string{"GET", "POST"} {
		app.HandleFunc(m+" /editFeatureBase", editFeatureBase)
	}
}

func editFeatureBase(a *app.App, w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodGet {
		comeBack(a, w, r)
		return
	}
	form, ok := editGuard(a, w, r)
	if !ok {
		return
	}
	if !a.Cfg.IsAdmin(auth.From(r).User) { // Apache checks the LDAP group; the page only offers the control to these logins
		http.Error(w, "Forbidden", http.StatusForbidden)
		return
	}
	get := func(k string) string {
		if v := form[k]; len(v) > 0 {
			return v[0]
		}
		return ""
	}
	name, base := get("name"), get("base")
	key := gitx.FeatureBaseKey(name)
	if key == "" || !gitx.ValidRef("feature/"+name) {
		http.Error(w, "Bad Request", http.StatusBadRequest)
		return
	}
	st := confedit.Store{Dir: gitx.FeatureBasesDir(a.Cfg.DataDir)}
	var err error
	if editValueEmpty(base) || base == gitx.DefaultBaseBranch {
		err = st.Remove(key, ".base")
	} else if !gitx.KnownBaseBranch(a.Cfg.DataDir, gitx.RepositoryNames(), base) {
		http.Error(w, "Bad Request: unknown base branch", http.StatusBadRequest)
		return
	} else {
		err = st.Put(key, ".base", base)
	}
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	audit.For(a.Cfg.DataDir).Add(r, "feature.base", "name", name, "base", base)
	cache.Default.Clear()
	redirect(w, confedit.WithClearCaches(confedit.ResolveFrom(get("from"), r.Host, a.Cfg.FormServers())))
}
