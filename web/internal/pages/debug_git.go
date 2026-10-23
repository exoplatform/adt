package pages

import (
	"net/http"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/gitx"
)

// /debug-git: repositories and the feature/translation/acceptance branch discovery.
// Read only: gitx runs git with an argv after validating every name.
func init() {
	app.HandleFunc("GET /debug-git", debugGit)
}

// branchesDump is the array branch => [project => [http_url, ..., ahead_commits]].
func branchesDump(groups []gitx.BranchGroup) debugx.Array {
	out := debugx.Array{}
	for _, g := range groups {
		projects := debugx.Array{}
		for _, p := range g.Projects {
			projects = append(projects, debugx.Item{Key: p.Project, Val: debugx.Array{
				{Key: "http_url", Val: p.HTTPURL},
				{Key: "http_url_behind", Val: p.HTTPURLBehind},
				{Key: "http_url_ahead", Val: p.HTTPURLAhead},
				{Key: "behind_commits", Val: p.BehindCommits},
				{Key: "ahead_commits", Val: p.AheadCommits},
			}})
		}
		out = append(out, debugx.Item{Key: g.Name, Val: projects})
	}
	return out
}

func debugGit(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	repos := debugx.Array{}
	for _, rp := range gitx.Repositories() {
		repos = append(repos, debugx.Item{Key: rp.Name, Val: rp.Label})
	}
	projects := gitx.RepositoryNames()
	features := gitx.FeatureBranches(a.Cfg.DataDir, projects)
	translation := gitx.TranslationBranches(a.Cfg.DataDir, projects)
	acceptance := a.Instances.AcceptanceBranches(r.Context(), c.Origin)

	var translationNames []string
	for _, g := range translation {
		translationNames = append(translationNames, g.Name)
	}
	debugx.Open(c, "debug - git", true)
	c.WriteString(tpl.Must("debug_git.tmpl", map[string]any{
		"Menu":             debugx.Menu(c),
		"Repos":            debugx.VarToggle(repos),
		"Features":         debugx.VarToggle(branchesDump(features)),
		"TranslationNames": translationNames,
		"Translation":      debugx.VarToggle(branchesDump(translation)),
		"Acceptance":       acceptance,
		"AcceptanceDump":   debugx.VarToggle(acceptance),
	}))
	dbgEnd(c)
}
