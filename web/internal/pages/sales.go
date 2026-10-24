package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/ui"
)

// The sales environments page.
func init() { app.HandleFunc("GET /sales", sales) }

func sales(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	ctx := r.Context()
	c.Begin("Sales environments", true)
	// section builds a listing; trial restarts with the "trial" CI job, eval has no restart link.
	section := func(b *instances.Branches, icon, title string, restart bool, badges []string) *listSection {
		return listSectionOf(b, icon, title, func(inst instances.Instance) string {
			o := ui.NewCardOpts()
			o.EnforceSSL = true
			if restart {
				o.ActionsTop = ui.BuildRestartLink(inst, ciACC+"platform-enterprise-trial-"+inst.Str("BASE_VERSION")+"-"+inst.Str("INSTANCE_ID")+"-deploy-acc/build?delay=0sec") +
					ui.EditNoteIcon(c, inst)
			} else {
				o.ActionsTop = ui.EditNoteIcon(c, inst)
			}
			o.Badges = badges
			return c.InstanceCard(inst, o)
		})
	}
	user := section(a.Instances.SalesUser(ctx, c.Origin), "fas fa-user", "Personal Sales Environments", true,
		[]string{"upgrade", "patch", "certbot", "dev", "staging", "debug", "addons"})
	demo := section(a.Instances.SalesDemo(ctx, c.Origin), "fas fa-briefcase", "Demo Environments for Leads", true,
		[]string{"upgrade", "patch", "dev", "staging", "debug", "addons"})
	eval := section(a.Instances.SalesEval(ctx, c.Origin), "fas fa-chart-line", "Evaluation Environments for Leads", false,
		[]string{"upgrade", "patch", "dev", "staging", "debug", "addons"})
	c.WriteString(tpl.Must("list_sales.tmpl", map[string]any{"User": user, "Demo": demo, "Eval": eval, "Info": ui.AccessInfoCards()}))
	c.End()
}
