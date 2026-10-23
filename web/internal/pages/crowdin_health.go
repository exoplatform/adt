package pages

import (
	"net/http"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/crowdin"
	"github.com/exoplatform/adt/web/internal/gitx"
	"github.com/exoplatform/adt/web/internal/phpx"
	"github.com/exoplatform/adt/web/internal/ui"
)

// /crowdin-health: Crowdin Healthcheck. The module discovery (local git)
// is in package crowdin; the status dots are filled in by the page script from /crowdin-status.
func init() {
	app.HandleFunc("GET /crowdin-health", crowdinHealth)
}

const crowdinStableVersion = crowdin.StableVersion

// WarmCrowdinHealth computes the module list at startup, so the first visit does not wait for it.
func WarmCrowdinHealth(dataDir string) {
	crowdin.Modules(dataDir, gitx.Repositories(), crowdinStableVersion)
}

func crowdinHealth(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	modules := crowdin.Modules(a.Cfg.DataDir, gitx.Repositories(), crowdinStableVersion)
	var active, skipped []crowdin.Module
	for _, m := range modules {
		if m.HasCrowdin {
			active = append(active, m)
		} else {
			skipped = append(skipped, m)
		}
	}
	w.Header().Set("Content-Type", "text/html; charset=UTF-8")
	c.WriteString("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n")
	c.Head("Crowdin Healthcheck", false)
	c.WriteString(tpl.Must("crowdin_head.tmpl", nil))
	c.WriteString("</head>\n<body>\n")
	c.Tracker("")
	c.Navigation()
	c.WriteString(crowdinBody(active, skipped))
	c.Footer()
	c.WriteString(tpl.Must("crowdin_footer.tmpl", nil))
	c.WriteString("</body>\n</html>\n")
}

// crowdinModuleView is a module with the status pills of its card and of its table row.
type crowdinModuleView struct {
	crowdin.Module
	StableBranchURL                      string
	CardUpload, CardDownload, CardStable string
	RowUpload, RowDownload, RowStable    string
}

func crowdinBody(active, skipped []crowdin.Module) string {
	views := make([]crowdinModuleView, 0, len(active))
	for _, m := range active {
		v := crowdinModuleView{Module: m, StableBranchURL: phpx.RawURLEncode(m.StableBranch)}
		v.CardUpload = crowdinBadge(m, "upload-crowdin-main.yml", "develop", "develop", "upload", "Crowdin upload status for develop", false)
		v.CardDownload = crowdinBadge(m, "download-crowdin.yml", "", "", "download", "Crowdin download status (scheduled)", false)
		v.RowUpload = crowdinBadge(m, "upload-crowdin-main.yml", "develop", "develop", "develop upload", "Crowdin upload status for develop", true)
		v.RowDownload = crowdinBadge(m, "download-crowdin.yml", "", "", "develop download", "Crowdin download status (scheduled)", true)
		if m.StableBranch != "" {
			v.CardStable = crowdinBadge(m, "upload-crowdin-branches.yml", m.StableBranch, m.StableBranch, "upload", "Crowdin upload status for "+m.StableBranch, false)
			v.RowStable = crowdinBadge(m, "upload-crowdin-branches.yml", m.StableBranch, m.StableBranch, "stable upload", "Crowdin upload status for "+m.StableBranch, true)
		}
		views = append(views, v)
	}
	return tpl.Must("crowdin_body.tmpl", map[string]any{"Stable": crowdinStableVersion, "Active": views, "Skipped": skipped})
}

// crowdinStatusURL is the endpoint the page script calls to read the workflow's latest run.
func crowdinStatusURL(org, repo, workflow, branch string) string {
	u := "/crowdin-status?org=" + phpx.URLEncode(org) + "&repo=" + phpx.URLEncode(repo) + "&workflow=" + phpx.URLEncode(workflow)
	if branch != "" {
		u += "&branch=" + phpx.URLEncode(branch)
	}
	return u
}

// crowdinBadgeURL is the shields.io JSON fallback when the API gives no result.
func crowdinBadgeURL(org, repo, workflow, branch, event string) string {
	var q []string
	if branch != "" {
		q = append(q, "branch="+phpx.URLEncode(branch))
	}
	if event != "" {
		q = append(q, "event="+phpx.URLEncode(event))
	}
	u := "https://img.shields.io/github/actions/workflow/status/" + org + "/" + repo + "/" + workflow + ".json"
	if len(q) > 0 {
		u += "?" + strings.Join(q, "&")
	}
	return u
}

// crowdinBadge renders one status pill (dot + label) linking to the workflow run
// history. The dot colour is filled in by the page script from the status JSON.
func crowdinBadge(m crowdin.Module, workflow, branch, queryBranch, label, alt string, dotOnly bool) string {
	esc := phpx.Esc
	text := esc(label)
	class := "crowdin-status"
	if dotOnly {
		text = `<span class="visually-hidden">` + esc(label) + `</span>`
		class += " crowdin-status--dot"
	}
	runURL := m.GithubURL + "/actions/workflows/" + workflow
	if queryBranch != "" {
		runURL += "?query=branch%3A" + phpx.RawURLEncode(queryBranch)
	}
	if m.IsPrivate {
		return `<a href="` + esc(runURL) + `" target="_blank" class="` + class + `" title="` + esc(alt+": private repository, status not available") + `">` +
			`<span class="status-dot is-private" aria-hidden="true"></span>` + text + `</a>`
	}
	statusURL := crowdinStatusURL(m.GithubOrg, m.GithubRepo, workflow, branch)
	event := "push"
	if workflow == "download-crowdin.yml" {
		event = "schedule"
	}
	fallback := crowdinBadgeURL(m.GithubOrg, m.GithubRepo, workflow, branch, event)
	return `<a href="` + esc(runURL) + `" target="_blank" class="` + class + `" data-status-url="` + esc(statusURL) + `" data-fallback-url="` + esc(fallback) + `" data-title="` + esc(alt) + `" title="` + esc(alt+": loading...") + `">` +
		`<span class="status-dot is-loading" aria-hidden="true"></span>` + text + `</a>`
}
