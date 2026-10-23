package pages

import (
	"math"
	"net/http"
	"slices"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/phpx"
	"github.com/exoplatform/adt/web/internal/ui"
)

// The dashboard: metrics, translation and dev instances.
func init() { app.HandleFunc("GET /{$}", index) }

func index(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	ctx := r.Context()

	// Compute stats for bento grid
	total, running, stopped := 0, 0, 0
	eachInstance(a.Instances.Global(ctx, c.Origin), func(_ string, inst instances.Instance) {
		total++
		if inst.Str("DEPLOYMENT_STATUS") == "Up" {
			running++
		} else {
			stopped++
		}
	})
	translation := a.Instances.Translation(ctx, c.Origin)
	dev := a.Instances.Dev(ctx, c.Origin)
	devCount := 0
	for _, br := range dev.Keys() {
		devCount += len(dev.Get(br))
	}

	c.Begin("", true)
	pct := 0
	if running > 0 {
		pct = int(math.Round(float64(running) / float64(max(total, 1)) * 100))
	}
	branchLines := slices.Clone(dev.Keys())
	phpx.NatSort(branchLines)
	noun := "branches"
	if dev.Len() == 1 {
		noun = "branch"
	}
	var translationSection *listSection
	if instances.InCategory(translation) {
		translationSection = &listSection{Cards: listCards(translation, func(inst instances.Instance) string {
			o := ui.NewCardOpts()
			o.RichName = true
			o.MetaDownloadFirst = true
			o.ActionsTop = ui.EditNoteIcon(c, inst)
			o.ShowBuiltAge = true
			o.Badges = []string{}
			return c.InstanceCard(inst, o)
		})}
	}
	devSections := make([]listSection, 0, dev.Len())
	for _, br := range dev.Keys() {
		var cards strings.Builder
		for _, inst := range dev.Get(br) {
			o := ui.NewCardOpts()
			o.RichName = true
			o.MetaDownloadFirst = true
			o.ActionsTop = ui.SpecificationIcon(inst)
			if !instances.IsFeatureBranch(inst) {
				o.ActionsTop += ui.EditNoteIcon(c, inst)
			}
			o.ShowBuiltAge = true
			o.FeatureLabel = true
			o.FBBadges = true
			o.Labels = true
			cards.WriteString(c.InstanceCard(inst, o))
		}
		devSections = append(devSections, listSection{Title: ui.BuildTableTitleDev(br), Cards: cards.String()})
	}
	c.WriteString(tpl.Must("list_index.tmpl", map[string]any{
		"Total": total, "Running": running, "Stopped": stopped, "Pct": pct,
		"DevCount": devCount, "DevLen": dev.Len(), "Noun": noun,
		"Branches":    strings.Join(branchLines, "\n"),
		"Translation": translationSection,
		"Dev":         devSections,
		"Info":        ui.AccessInfoCards(),
	}))
	c.End()
}
