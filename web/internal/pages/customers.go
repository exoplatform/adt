package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/ui"
)

// The customer projects page.
func init() { app.HandleFunc("GET /customers", customers) }

func customers(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	cp := a.Instances.CP(r.Context(), c.Origin)
	c.Begin("Customer projects", true)
	section := listSectionOf(cp, "fas fa-briefcase", "Customer Projects Integration", func(inst instances.Instance) string {
		o := ui.NewCardOpts()
		o.ActionsTop = ui.BuildRestartLink(inst, "https://ci.exoplatform.org/job/platform-enterprise-"+inst.Str("PLF_BRANCH")+"-"+inst.Str("INSTANCE_ID")+"-deploy-acc/build?delay=0sec") +
			ui.EditNoteIcon(c, inst)
		o.Badges = []string{"upgrade", "patch", "certbot", "dev", "staging", "debug", "addons"}
		return c.InstanceCard(inst, o)
	})
	c.WriteString(tpl.Must("list_customers.tmpl", map[string]any{"Section": section, "Info": ui.AccessInfoCards()}))
	c.End()
}
