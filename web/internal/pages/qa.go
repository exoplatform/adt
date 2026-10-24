package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/ui"
)

// The QA environments page.
func init() { app.HandleFunc("GET /qa", qa) }

// qaRestartLink is the restart link of a QA card: the descriptor's build URL or the acceptance job.
func qaRestartLink(inst instances.Instance) string {
	return ui.BuildRestartLink(inst, ciACC+"platform-enterprise-"+inst.Str("BASE_VERSION")+"-"+inst.Str("INSTANCE_ID")+"-acc/build?delay=0sec")
}

func qa(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	ctx := r.Context()
	c.Begin("QA environments", true)
	section := func(b *instances.Branches, icon, title string, badges []string) *listSection {
		return listSectionOf(b, icon, title, func(inst instances.Instance) string {
			o := ui.NewCardOpts()
			o.ActionsTop = qaRestartLink(inst)
			o.Badges = badges
			return c.InstanceCard(inst, o)
		})
	}
	user := section(a.Instances.QAUser(ctx, c.Origin), "fas fa-tag", "QA User Environments",
		[]string{"upgrade", "certbot", "dev", "staging", "debug", "addons"})
	auto := section(a.Instances.QAAuto(ctx, c.Origin), "fas fa-robot", "Automatic QA Environments",
		[]string{"upgrade", "patch", "certbot", "dev", "staging", "debug", "addons"})
	c.WriteString(tpl.Must("list_qa.tmpl", map[string]any{"User": user, "Auto": auto, "Info": ui.AccessInfoCards()}))
	c.End()
}
