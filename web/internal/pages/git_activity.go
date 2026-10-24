package pages

import (
	"fmt"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/gitx"
	"github.com/exoplatform/adt/web/internal/ui"
)

// The Git Activity page.
func init() { app.HandleFunc("GET /git-activity", gitActivity) }

// gaDaysBack is max(1, min(365, days)), days defaulting to 30. The last "days" parameter wins and
// an array parameter ("days[]=1") counts as 1.
func gaDaysBack(rawQuery string) int {
	val, set, isArray := "", false, false
	for _, pair := range strings.Split(rawQuery, "&") {
		k, v, _ := strings.Cut(pair, "=")
		k, _ = url.QueryUnescape(k)
		switch {
		case k == "days":
			val, set, isArray = v, true, false
			if u, err := url.QueryUnescape(v); err == nil {
				val = u
			}
		case strings.HasPrefix(k, "days["):
			set, isArray = true, true
		}
	}
	n := 30
	if set {
		if isArray {
			n = 1
		} else {
			n = gaIntval(val)
		}
	}
	return max(1, min(365, n))
}

// gaIntval parses the leading numeric prefix of a string as an integer (decimals and exponents truncated).
func gaIntval(s string) int {
	s = strings.TrimLeft(s, " \t\n\r\v\f")
	end := 0
	if end < len(s) && (s[end] == '+' || s[end] == '-') {
		end++
	}
	digits := 0
	for end < len(s) && s[end] >= '0' && s[end] <= '9' {
		end++
		digits++
	}
	if end < len(s) && s[end] == '.' {
		e := end + 1
		fd := 0
		for e < len(s) && s[e] >= '0' && s[e] <= '9' {
			e++
			fd++
		}
		if digits+fd > 0 {
			end, digits = e, digits+fd
		}
	}
	if digits == 0 {
		return 0
	}
	if end < len(s) && (s[end] == 'e' || s[end] == 'E') {
		e := end + 1
		if e < len(s) && (s[e] == '+' || s[e] == '-') {
			e++
		}
		if e < len(s) && s[e] >= '0' && s[e] <= '9' {
			for e < len(s) && s[e] >= '0' && s[e] <= '9' {
				e++
			}
			end = e
		}
	}
	f, err := strconv.ParseFloat(s[:end], 64)
	if err != nil {
		return 0
	}
	if f > 1e9 {
		return 1e9
	}
	if f < -1e9 {
		return -1e9
	}
	return int(f)
}

// gaNumberFormat formats a number with thousands separated by ",".
func gaNumberFormat(n int) string {
	s := strconv.Itoa(n)
	neg := strings.HasPrefix(s, "-")
	s = strings.TrimPrefix(s, "-")
	var b strings.Builder
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(c)
	}
	if neg {
		return "-" + b.String()
	}
	return b.String()
}

// gaJSONString is the JSON encoding of a string (escaped "/" and \uXXXX for non-ASCII).
func gaJSONString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range strings.ToValidUTF8(s, "\uFFFD") {
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
		case r < 0x20, r == '<': // < too: the value is written in a <script type="application/json">
			fmt.Fprintf(&b, `\u%04x`, r)
		case r < 0x80:
			b.WriteRune(r)
		case r >= 0x10000:
			r -= 0x10000
			fmt.Fprintf(&b, `\u%04x\u%04x`, 0xd800+(r>>10), 0xdc00+(r&0x3ff))
		default:
			fmt.Fprintf(&b, `\u%04x`, r)
		}
	}
	b.WriteByte('"')
	return b.String()
}

func gaJSONStrings(a []string) string {
	p := make([]string, len(a))
	for i, s := range a {
		p[i] = gaJSONString(s)
	}
	return "[" + strings.Join(p, ",") + "]"
}

func gaJSONInts(a []int) string {
	p := make([]string, len(a))
	for i, n := range a {
		p[i] = strconv.Itoa(n)
	}
	return "[" + strings.Join(p, ",") + "]"
}

// gaStrimwidth truncates s to width, marking the cut with "...".
func gaStrimwidth(s string, width int) string {
	w := func(r rune) int {
		switch {
		case r >= 0x1100 && r <= 0x115f, r >= 0x2e80 && r <= 0xa4cf, r >= 0xac00 && r <= 0xd7a3,
			r >= 0xf900 && r <= 0xfaff, r >= 0xfe30 && r <= 0xfe6f, r >= 0xff00 && r <= 0xff60,
			r >= 0xffe0 && r <= 0xffe6, r >= 0x20000 && r <= 0x3fffd:
			return 2
		}
		return 1
	}
	total := 0
	for _, r := range s {
		total += w(r)
	}
	if total <= width {
		return s
	}
	acc := 0
	var b strings.Builder
	for _, r := range s {
		if acc+w(r) > width-3 {
			break
		}
		acc += w(r)
		b.WriteRune(r)
	}
	return b.String() + "..."
}

// gaAvgFormat is total/days rounded to one decimal, then to an integer.
func gaAvgFormat(total, days int) string {
	v := float64(total) / float64(days)
	v = float64(int64(v*10+0.5)) / 10 // round to one decimal (values are >= 0)
	return gaNumberFormat(int(v + 0.5))
}

type gaBundle struct {
	Activity []gaDay
	Trend    gaTrend
	Repos    []gaRepoStat
	Authors  []gaAuthorStat
}

func gitActivity(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if _, ok := r.URL.Query()["clearCaches"]; ok {
		if instancePageCheckCaches(a, c) {
			return
		}
	}
	days := gaDaysBack(r.URL.RawQuery)
	projects := gitx.Repositories()
	dataDir := a.Cfg.DataDir

	bundle := gaLoadBundle(dataDir, days)
	activity, trend, repoStats, authorStats := bundle.Activity, bundle.Trend, bundle.Repos, bundle.Authors
	dow := [7]int{}
	for _, d := range activity {
		if t, err := time.Parse("2006-01-02", d.Date); err == nil {
			dow[(int(t.Weekday())+6)%7] += d.Count
		}
	}
	dowNames := []string{"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}

	recent := gaLoadRecent(dataDir)

	total := 0
	for _, d := range activity {
		total += d.Count
	}
	activeRepos := 0
	for _, s := range repoStats {
		if s.Commits > 0 {
			activeRepos++
		}
	}
	busiest := -1
	for i, d := range activity {
		if busiest < 0 || d.Count > activity[busiest].Count {
			busiest = i
		}
	}
	var topRepo *gaRepoStat
	if len(repoStats) > 0 && repoStats[0].Commits > 0 {
		topRepo = &repoStats[0]
	}
	var topAuthor *gaAuthorStat
	if len(authorStats) > 0 {
		topAuthor = &authorStats[0]
	}

	type orgPR struct {
		org string
		gaPR
	}
	var prs []orgPR
	for _, org := range gaOrgs {
		prs = append(prs, orgPR{org, gaLoadPR(org, days)})
	}

	graph := gaLoadGraph(dataDir)
	tableRepos := append([]gitx.Repo(nil), projects...)
	sort.SliceStable(tableRepos, func(i, j int) bool { return tableRepos[i].Name < tableRepos[j].Name }) // ksort
	labelOf := func(name string) string {
		if l, ok := gitx.RepositoryLabel(name); ok {
			return l
		}
		return name
	}

	ds := strconv.Itoa(days)
	active := func(n int) string {
		if days == n {
			return "active"
		}
		return ""
	}

	busiestDay, busiestChange := "—", "no data"
	if busiest >= 0 {
		if !gaEmpty(activity[busiest].Date) {
			busiestDay = activity[busiest].Date
		}
		busiestChange = gaNumberFormat(activity[busiest].Count) + " commits"
	}
	repoChange, authorChange := "no data", "no data"
	if topRepo != nil {
		repoChange = gaNumberFormat(topRepo.Commits) + " commits"
	}
	if topAuthor != nil {
		authorChange = gaNumberFormat(topAuthor.Commits) + " commits"
	}

	type prView struct {
		Org             string
		Created, Merged string
	}
	prViews := make([]prView, len(prs))
	for i, o := range prs {
		prViews[i] = prView{o.org, gaNumberFormat(o.Created), gaNumberFormat(o.Merged)}
	}

	type depTarget struct{ Repo, Label string }
	type depRow struct {
		Repo, Label, URL string
		Targets          []depTarget
	}
	depRows := make([]depRow, 0, len(tableRepos))
	for _, rp := range tableRepos {
		row := depRow{Repo: rp.Name, Label: rp.Label, URL: graph.GithubURL[rp.Name]}
		targets := append([]string(nil), graph.Links[rp.Name]...)
		sort.SliceStable(targets, func(i, j int) bool { return gaStrcasecmp(labelOf(targets[i]), labelOf(targets[j])) < 0 })
		for _, t := range targets {
			row.Targets = append(row.Targets, depTarget{t, labelOf(t)})
		}
		depRows = append(depRows, row)
	}

	type commitRow struct {
		gaCommit
		Short string
	}
	recentRows := make([]commitRow, len(recent))
	for i, cm := range recent {
		recentRows[i] = commitRow{cm, gaStrimwidth(cm.Message, 80)}
	}

	c.W.Header().Set("Content-Type", "text/html; charset=UTF-8")
	c.WriteString(tpl.Must("git_activity_open.tmpl", nil))
	c.Head("Git Activity", true)
	c.WriteString(tpl.Must("git_activity_style.tmpl", nil))
	c.Tracker("")
	c.Navigation()
	c.WriteString(tpl.Must("git_activity.tmpl", map[string]any{
		"NumRepos": len(gitx.RepositoryNames()), "Days": ds,
		"Active7": active(7), "Active14": active(14), "Active30": active(30), "Active90": active(90),
		"Total": gaNumberFormat(total), "Active": activeRepos, "Contributors": len(authorStats), "Avg": gaAvgFormat(total, days),
		"BusiestDay": busiestDay, "BusiestChange": busiestChange,
		"TopRepo": topRepo, "RepoChange": repoChange, "TopAuthor": topAuthor, "AuthorChange": authorChange,
		"PRs": prViews, "TrendCount": len(trend.Series), "DepRows": depRows, "Recent": recentRows,
	}))
	c.Footer()

	dates := make([]string, len(activity))
	counts := make([]int, len(activity))
	for i, d := range activity {
		dates[i], counts[i] = d.Date, d.Count
	}
	var series []string
	for _, s := range trend.Series {
		series = append(series, gaJSONString(s.Label)+":"+gaJSONInts(s.Counts))
	}
	jsTrendSeries := "[]" // an empty list, not an object
	if len(series) > 0 {
		jsTrendSeries = "{" + strings.Join(series, ",") + "}"
	}
	repoLabels := make([]string, len(repoStats))
	repoCommits := make([]int, len(repoStats))
	for i, s := range repoStats {
		repoLabels[i], repoCommits[i] = s.Label, s.Commits
	}
	authors := make([]string, len(authorStats))
	authorCommits := make([]int, len(authorStats))
	for i, s := range authorStats {
		authors[i], authorCommits[i] = s.Author, s.Commits
	}
	c.WriteString(tpl.Must("git_activity_charts.tmpl", map[string]string{
		"Dates": gaJSONStrings(dates), "Activity": gaJSONInts(counts),
		"TrendDates": gaJSONStrings(trend.Dates), "TrendSeries": jsTrendSeries,
		"RepoLabels": gaJSONStrings(repoLabels), "RepoCommits": gaJSONInts(repoCommits),
		"Authors": gaJSONStrings(authors), "AuthorCommits": gaJSONInts(authorCommits),
		"DowLabels": gaJSONStrings(dowNames), "DowValues": gaJSONInts(dow[:]),
	}))
}

func gaStrcasecmp(a, b string) int { return strings.Compare(strings.ToLower(a), strings.ToLower(b)) }

// What the page computes is kept and refreshed in the background (see cache.Stale): a visitor does not wait for the git
// history of all the clones, the GitHub lookups or the dependency graph, whatever the cache clearing or the restart.
var (
	gaBundles = cache.NewStale[gaBundle]()
	gaRecents = cache.NewStale[[]gaCommit]()
	gaPRs     = cache.NewStale[gaPR]()
	gaGraphs  = cache.NewStale[gaDepGraph]()
)

const gaTTL = 5 * time.Minute

func gaLoadBundle(dataDir string, days int) gaBundle {
	return gaBundles.Get(strconv.Itoa(days), gaTTL, func() gaBundle {
		now := time.Now()
		projects, names := gitx.Repositories(), gitx.RepositoryNames()
		res := &gaResolver{token: os.Getenv("GITHUB_TOKEN")}
		return gaBundle{
			Activity: gaActivityByDay(dataDir, names, days, now),
			Trend:    gaActivityByDayAndRepo(dataDir, projects, days, now),
			Repos:    gaCommitsByRepo(dataDir, projects, days, now),
			Authors:  gaCommitsByAuthor(dataDir, names, days, now, res),
		}
	})
}

func gaLoadRecent(dataDir string) []gaCommit {
	return gaRecents.Get("recent", gaTTL, func() []gaCommit {
		return gaRecentCommits(dataDir, gitx.Repositories(), 50, time.Now(), &gaResolver{token: os.Getenv("GITHUB_TOKEN")})
	})
}

func gaLoadPR(org string, days int) gaPR {
	return gaPRs.Get(org+"/"+strconv.Itoa(days), gaTTL, func() gaPR {
		return gaPRData(org, os.Getenv("GITHUB_TOKEN"), days, time.Now())
	})
}

func gaLoadGraph(dataDir string) gaDepGraph {
	return gaGraphs.Get("graph", time.Hour, func() gaDepGraph { return gaBuildDependencyGraph(dataDir, gitx.Repositories()) })
}

// WarmGitActivity computes the data of the default view of the page, so that the first visitor does not wait for it.
func WarmGitActivity(dataDir string) {
	gaLoadRecent(dataDir)
	for _, days := range []int{30, 7, 14, 90} { // the default first, then the other buttons of the page
		gaLoadBundle(dataDir, days)
		for _, org := range gaOrgs {
			gaLoadPR(org, days)
		}
	}
	gaLoadGraph(dataDir)
}

// gaOrgs are the GitHub organisations whose pull requests the page counts.
var gaOrgs = []string{"meeds-io", "exoplatform"}
