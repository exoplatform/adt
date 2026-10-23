package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/ui"
)

// The company environments page.
func init() { app.HandleFunc("GET /company", company) }

func company(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	b := a.Instances.Company(r.Context(), c.Origin)
	c.Begin("Company environments", true)
	type branch struct{ Branch, Cards string }
	var branches []branch
	found := instances.InCategory(b)
	if found {
		for _, br := range b.Keys() {
			var cards string
			for _, inst := range b.Get(br) {
				o := ui.NewCardOpts()
				o.ShowVisibilityIcon = true
				if inst.Truthy("DEPLOYMENT_APACHE_VHOST_ALIAS") {
					o.VisibilityIcon = "success"
				}
				o.EnforceSSL = true
				o.ActionsTop = ui.EditNoteIcon(c, inst)
				o.ShowBuiltAge = true
				o.Badges = []string{"upgrade", "patch", "certbot", "dev", "staging", "debug"}
				o.BadgesAddonStyle = false
				cards += c.InstanceCard(inst, o)
			}
			branches = append(branches, branch{br, cards})
		}
	}
	c.WriteString(tpl.Must("list_company.tmpl", map[string]any{"Found": found, "Branches": branches, "Info": ui.AccessInfoCards()}))
	c.End()
}
