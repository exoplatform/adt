package pages

import (
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/gitx"
	"github.com/exoplatform/adt/web/internal/phpx"
	"github.com/exoplatform/adt/web/internal/ui"
)

// /features: Git feature branches with branch health overview.
func init() { app.HandleFunc("GET /features", featuresPage) }

// featuresAcceptanceBranches returns the SCM_BRANCH of every acceptance instance,
// cached for 2 minutes (not in dev mode).
func featuresAcceptanceBranches(a *app.App, r *http.Request, c *ui.Ctx) []string {
	if v, ok := cache.Default.Get("acceptance_branches"); ok && !a.Cfg.DevMode {
		if b, ok := v.([]string); ok && len(b) > 0 {
			return b
		}
	}
	var branches []string
	all := a.Instances.Global(r.Context(), c.Origin)
	for _, br := range all.Keys() {
		for _, inst := range all.Get(br) {
			if s := inst.Str("SCM_BRANCH"); s != "" && s != "0" {
				branches = append(branches, s)
			}
		}
	}
	cache.Default.Set("acceptance_branches", branches, 120*time.Second)
	return branches
}

// featuresJSONString is the JSON encoding of a string with the default flags: "/" and non-ASCII are escaped.
func featuresJSONString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range strings.ToValidUTF8(s, "") {
		switch {
		case r == '"':
			b.WriteString(`\"`)
		case r == '\\':
			b.WriteString(`\\`)
		case r == '/':
			b.WriteString(`\/`)
		case r == '\b':
			b.WriteString(`\b`)
		case r == '\f':
			b.WriteString(`\f`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\t':
			b.WriteString(`\t`)
		case r < 0x20 || (r >= 0x7f && r < 0x80) || r > 0x7f:
			if r > 0xffff {
				r1, r2 := utf16.EncodeRune(r)
				b.WriteString(`\u` + featuresHex4(int(r1)) + `\u` + featuresHex4(int(r2)))
			} else {
				b.WriteString(`\u` + featuresHex4(int(r)))
			}
		default:
			b.WriteRune(r)
		}
	}
	b.WriteByte('"')
	return b.String()
}

func featuresHex4(n int) string {
	const h = "0123456789abcdef"
	return string([]byte{h[n>>12&15], h[n>>8&15], h[n>>4&15], h[n&15]})
}

func featuresLower(s string) string {
	b := []byte(s)
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			b[i] = c + 32
		}
	}
	return string(b)
}

func featuresPage(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	repos := gitx.Repositories()
	names := map[string]string{}
	projects := make([]string, len(repos))
	for i, p := range repos {
		names[p.Name] = p.Label
		projects[i] = p.Name
	}
	feats := gitx.FeatureBranches(a.Cfg.DataDir, projects)
	bases := gitx.FeatureBases(a.Cfg.DataDir)
	acceptance := featuresAcceptanceBranches(a, r, c)
	inAcceptance := func(n string) bool {
		for _, b := range acceptance {
			if b == n {
				return true
			}
		}
		return false
	}
	isBackup := func(n string) bool {
		return strings.Contains(n, "backup") || strings.Contains(n, "tmp") || strings.Contains(n, "temp")
	}
	// the names have lost their "origin/integration" prefix, so they are never translation branches
	var accepted, other []gitx.BranchGroup
	for _, f := range feats {
		if inAcceptance(f.Name) {
			accepted = append(accepted, f)
		}
		if !inAcceptance(f.Name) && !isBackup(f.Name) {
			other = append(other, f)
		}
	}
	esc := phpx.Esc
	itoa := strconv.Itoa
	searchKey := func(project string) string { return featuresLower(project + " " + names[project]) }
	filterAttrs := func(f gitx.BranchGroup) string {
		var parts []string
		for _, p := range f.Projects {
			parts = append(parts, "["+featuresJSONString(searchKey(p.Project))+","+itoa(p.BehindCommits)+","+itoa(p.AheadCommits)+"]")
		}
		return `data-feature="` + esc(f.Name) + `" data-projects="` + esc("["+strings.Join(parts, ",")+"]") + `"`
	}
	status := func(p gitx.BranchProject) string {
		return ui.FeatureRepoBranchStatus(ui.RepoBranchStatus{BehindCommits: p.BehindCommits, AheadCommits: p.AheadCommits,
			HTTPURLBehind: p.HTTPURLBehind, HTTPURLAhead: p.HTTPURLAhead}, false)
	}
	slug := func(f string) string { return strings.NewReplacer("/", "-", ".", "-").Replace(f) }
	byProject := func(f gitx.BranchGroup) map[string]gitx.BranchProject {
		m := map[string]gitx.BranchProject{}
		for _, p := range f.Projects {
			m[p.Project] = p
		}
		return m
	}

	ciRebase := func(f string) string {
		return "https://ci.exoplatform.org/job/exo-" + phpx.RawURLEncode(f) + "-fb-rebase-branch/"
	}
	ciDotRebase := func(f string) string {
		return `<span class="ci-dot" title="Rebase build status (green: passing, red: failing, yellow: unstable, grey: not run)"><img src="https://ci.exoplatform.org/buildStatus/icon?job=exo-` + phpx.RawURLEncode(f) + `-fb-rebase-branch&amp;subject=&amp;status=+" loading="lazy" alt="Rebase build status for ` + esc(f) + `"></span>`
	}
	ciJob := func(project, f string) string {
		return gitx.ModuleCiPrefix(project) + phpx.RawURLEncode(project) + "-" + phpx.RawURLEncode(f)
	}
	pageURL := c.CurrentPageURL()
	// baseOf and editable: the base branch of a feature branch, and whether the visitor can set it
	baseOf := func(f string) string { return gitx.FeatureBase(bases, f) }
	admin := a.Cfg.IsAdmin(auth.From(r).User)
	editable := func(f string) bool { return admin && gitx.FeatureBaseKey(f) != "" }

	data := featuresView{Filters: len(accepted) > 0 || len(other) > 0, Empty: len(accepted) == 0 && len(other) == 0}
	for _, g := range []featuresGroup{{"Deployed", accepted}, {"Other", other}} {
		if len(g.list) == 0 {
			continue
		}
		var names []string
		for _, f := range g.list {
			names = append(names, f.Name)
		}
		data.Groups = append(data.Groups, featuresOptGroup{g.label, names})
	}
	if len(accepted) > 0 {
		d := &featuresDeployed{}
		maps := make([]map[string]gitx.BranchProject, len(accepted))
		for i, f := range accepted {
			fp := byProject(f)
			maps[i] = fp
			card := featuresCard{Slug: slug(f.Name), Name: f.Name, Attrs: filterAttrs(f), Href: pageURL + "#feature-" + slug(f.Name),
				CiRebase: ciRebase(f.Name), CiDot: ciDotRebase(f.Name), Base: baseOf(f.Name), BaseCustom: baseOf(f.Name) != gitx.DefaultBaseBranch, BaseEditable: editable(f.Name), From: pageURL}
			for _, project := range projects {
				if p, ok := fp[project]; ok {
					card.Chips = append(card.Chips, featuresChip{Search: searchKey(project), Label: names[project], Behind: p.BehindCommits,
						Ahead: p.AheadCommits, CiJob: ciJob(project, f.Name), Status: status(p)})
				}
			}
			d.Cards = append(d.Cards, card)
		}
		for _, project := range projects {
			row := featuresRow{Label: names[project]}
			any := false
			for i, f := range accepted {
				p, ok := maps[i][project]
				any = any || ok
				cell := featuresCell{Present: ok, Name: f.Name}
				if ok {
					cell.Search, cell.Label, cell.Behind, cell.Ahead = searchKey(project), names[project], p.BehindCommits, p.AheadCommits
					cell.CiJob, cell.Status = ciJob(project, f.Name), status(p)
				}
				row.Cells = append(row.Cells, cell)
			}
			if any {
				d.Rows = append(d.Rows, row)
			}
		}
		data.Deployed = d
	}
	for _, f := range other {
		n := len(f.Projects)
		o := featuresOther{Slug: slug(f.Name), Name: f.Name, Attrs: filterAttrs(f), Href: pageURL + "#feature-" + slug(f.Name), Count: n,
			Base: baseOf(f.Name), BaseCustom: baseOf(f.Name) != gitx.DefaultBaseBranch, BaseEditable: editable(f.Name), From: pageURL}
		var first []string
		for i, p := range f.Projects {
			if i < 3 {
				first = append(first, names[p.Project])
			}
			if i < 2 {
				o.Badges = append(o.Badges, status(p))
			}
		}
		o.First = strings.Join(first, ", ")
		if n > 3 {
			o.More = "..."
		}
		if n > 2 {
			o.Rest = n - 2
		}
		data.Other = append(data.Other, o)
	}

	w.Header().Set("Content-Type", "text/html; charset=UTF-8")
	c.WriteString("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n")
	c.Head("features", true)
	c.WriteString(tpl.Must("features_head.tmpl", nil))
	c.WriteString("</head>\n<body>\n")
	c.Tracker("")
	c.Navigation()
	c.WriteString(tpl.Must("features_body.tmpl", data))
	c.Footer()
	c.WriteString("</body>\n</html>")
}

// The data of the features_body template.
type featuresView struct {
	Filters, Empty bool
	Groups         []featuresOptGroup
	Deployed       *featuresDeployed
	Other          []featuresOther
}

type featuresGroup struct {
	label string
	list  []gitx.BranchGroup
}

type featuresOptGroup struct {
	Label string
	Names []string
}

// featuresDeployed is the section of the branches deployed on acceptance: a card per branch and the
// projects x branches matrix.
type featuresDeployed struct {
	Cards []featuresCard
	Rows  []featuresRow
}

type featuresCard struct {
	Slug, Name, Attrs, Href, CiRebase, CiDot string
	Base, From                               string
	BaseEditable, BaseCustom                 bool
	Chips                                    []featuresChip
}

type featuresChip struct {
	Search, Label string
	Behind, Ahead int
	CiJob, Status string
}

type featuresRow struct {
	Label string
	Cells []featuresCell
}

// featuresCell is a matrix cell; Present is false when the project is not part of the branch.
type featuresCell struct {
	Present             bool
	Name, Search, Label string
	Behind, Ahead       int
	CiJob, Status       string
}

type featuresOther struct {
	Slug, Name, Attrs, Href, First, More string
	Base, From                           string
	BaseEditable, BaseCustom             bool
	Count, Rest                          int
	Badges                               []string
}
