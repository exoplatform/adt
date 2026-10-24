package pages

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/gitx"
	"github.com/exoplatform/adt/web/internal/phpx"
)

// Data functions of the Git Activity page.

var gaIgnoredAuthors = map[string]bool{"exo-swf": true, "Crowdin Bot": true, "eXo CI server": true, "eXo": true}

func gaEmpty(s string) bool { return s == "" || s == "0" }

// githubAPI is the GitHub REST base URL (ADT_GITHUB_API_URL, like the Crowdin page; replaced in tests).
var githubAPI = func() string {
	if v := os.Getenv("ADT_GITHUB_API_URL"); v != "" {
		return strings.TrimRight(v, "/")
	}
	return "https://api.github.com"
}()

// gaGet fetches a GitHub API URL, bounded by timeout.
func gaGet(rawurl, token string, timeout time.Duration) ([]byte, int, error) {
	req, err := http.NewRequest(http.MethodGet, rawurl, nil)
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("User-Agent", "ADT-Git-Activity")
	if token != "" {
		req.Header.Set("Authorization", "token "+token)
	}
	resp, err := (&http.Client{Timeout: timeout}).Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	return b, resp.StatusCode, err
}

// gaDates is the list of the "Y-m-d" dates of the last days+1 days (oldest first).
func gaDates(now time.Time, days int) []string {
	res := make([]string, 0, days+1)
	for i := days; i >= 0; i-- {
		res = append(res, now.UTC().AddDate(0, 0, -i).Format("2006-01-02"))
	}
	return res
}

// gaSource opens ADT_DATA/sources/<repo>.git when it is a directory holding a valid repository.
func gaSource(dataDir, repo string) *gitx.Repository {
	p, err := gitx.SourcesPath(dataDir, repo)
	if err != nil {
		return nil
	}
	if fi, err := os.Stat(p); err != nil || !fi.IsDir() {
		return nil
	}
	r, err := gitx.Open(p)
	if err != nil {
		return nil
	}
	return r
}

func gaLines(out string) []string {
	if gaEmpty(out) {
		return nil
	}
	return strings.Split(out, "\n")
}

type gaDay struct {
	Date  string
	Count int
}

// gaActivityByDay returns the commit activity by day.
func gaActivityByDay(dataDir string, repos []string, days int, now time.Time) []gaDay {
	dates := gaDates(now, days)
	idx := map[string]int{}
	act := make([]gaDay, len(dates))
	for i, d := range dates {
		idx[d] = i
		act[i] = gaDay{Date: d}
	}
	since := now.UTC().AddDate(0, 0, -days).Format("2006-01-02")
	for _, repo := range repos {
		r := gaSource(dataDir, repo)
		if r == nil {
			continue
		}
		out, err := r.Log(gitx.LogOptions{Since: since, Date: "short", Format: "%ad|%cn", NoMerges: true, Ref: targetBranchOf(r)})
		if err != nil {
			continue
		}
		for _, line := range gaLines(out) {
			date, committer, _ := strings.Cut(line, "|")
			date, committer = gaTrim(date), gaTrim(committer)
			if i, ok := idx[date]; ok && !gaIgnoredAuthors[committer] {
				act[i].Count++
			}
		}
	}
	return act
}

func targetBranchOf(r *gitx.Repository) string { return gaTargetBranch(r) }

func gaTrim(s string) string { return strings.Trim(s, " \t\n\r\x00\x0b") }

type gaSeries struct {
	Label  string
	Counts []int
}

type gaTrend struct {
	Dates  []string
	Series []gaSeries
}

// gaActivityByDayAndRepo returns the commit activity by day and repository (top 5).
func gaActivityByDayAndRepo(dataDir string, projects []gitx.Repo, days int, now time.Time) gaTrend {
	dates := gaDates(now, days)
	since := dates[0]
	type daily struct {
		label string
		by    map[string]int
	}
	var order []*daily
	byLabel := map[string]*daily{}
	for _, p := range projects {
		r := gaSource(dataDir, p.Name)
		if r == nil {
			continue
		}
		out, err := r.Log(gitx.LogOptions{Since: since, Date: "short", Format: "%ad|%cn", NoMerges: true, Ref: gaTargetBranch(r)})
		if err != nil || gaEmpty(out) {
			continue
		}
		for _, line := range gaLines(out) {
			date, committer, _ := strings.Cut(line, "|")
			date, committer = gaTrim(date), gaTrim(committer)
			if gaIgnoredAuthors[committer] {
				continue
			}
			d := byLabel[p.Label]
			if d == nil {
				d = &daily{label: p.Label, by: map[string]int{}}
				byLabel[p.Label] = d
				order = append(order, d)
			}
			d.by[date]++
		}
	}
	type total struct {
		d *daily
		n int
	}
	totals := make([]total, len(order))
	for i, d := range order {
		n := 0
		for _, c := range d.by {
			n += c
		}
		totals[i] = total{d, n}
	}
	sort.SliceStable(totals, func(i, j int) bool { return totals[i].n > totals[j].n }) // arsort
	t := gaTrend{Dates: dates}
	for i, tt := range totals {
		if i >= 5 {
			break
		}
		counts := make([]int, len(dates))
		for k, date := range dates {
			counts[k] = tt.d.by[date]
		}
		t.Series = append(t.Series, gaSeries{tt.d.label, counts})
	}
	return t
}

type gaRepoStat struct {
	Repo, Label string
	Commits     int
	GithubURL   string
}

// gaCommitsByRepo returns the commits by repository.
func gaCommitsByRepo(dataDir string, projects []gitx.Repo, days int, now time.Time) []gaRepoStat {
	var res []gaRepoStat
	since := now.UTC().AddDate(0, 0, -days).Format("2006-01-02")
	for _, p := range projects {
		r := gaSource(dataDir, p.Name)
		if r == nil {
			continue
		}
		base := gaRepoGithubURL(r)
		out, err := r.Log(gitx.LogOptions{Since: since, Format: "%cn", NoMerges: true, Ref: gaTargetBranch(r)})
		if err != nil {
			continue
		}
		n := 0
		for _, c := range gaLines(out) {
			if c = gaTrim(c); !gaEmpty(c) && !gaIgnoredAuthors[c] {
				n++
			}
		}
		res = append(res, gaRepoStat{p.Name, p.Label, n, base})
	}
	sort.SliceStable(res, func(i, j int) bool { return res[i].Commits > res[j].Commits })
	return res
}

type gaAuthorStat struct {
	Author    string
	Commits   int
	GithubURL string
	AvatarURL string
}

// gaResolver resolves GitHub users, with a per-request rate-limit flag.
type gaResolver struct {
	token   string
	limited bool
}

var gaNoreplyRe = regexp.MustCompile(`(?i)^(?:\d+\+)?([a-z0-9\-]+)@users\.noreply\.github\.com$`)

func gaGithubUsername(email string) string {
	if m := gaNoreplyRe.FindStringSubmatch(gaTrim(email)); m != nil {
		return m[1]
	}
	return ""
}

func gaAvatarURL(user string) string {
	if user == "" {
		return ""
	}
	return "https://avatars.githubusercontent.com/" + user + "?size=48"
}

var (
	gaRepoURLRe = regexp.MustCompile(`^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$`)
	gaShaRe     = regexp.MustCompile(`^[0-9a-f]{40}$`)
)

// userOfCommit asks GitHub which account a commit belongs to (GET /repos/{org}/{repo}/commits/{sha}). GitHub links a
// commit to an account by the verified e-mail addresses of its owner, private ones included, which the user search
// cannot do. trusted is false when no answer was obtained (no GitHub repository, private, rate limit, network):
// the caller may try something else and the result must not be cached. An empty user with trusted true means
// that GitHub knows no account for the address.
func (g *gaResolver) userOfCommit(repoURL, sha string) (user string, trusted bool) {
	m := gaRepoURLRe.FindStringSubmatch(repoURL)
	if m == nil || !gaShaRe.MatchString(sha) {
		return "", false
	}
	body, status, err := gaGet(githubAPI+"/repos/"+m[1]+"/"+m[2]+"/commits/"+sha, g.token, 4*time.Second)
	if err != nil {
		return "", false
	}
	switch status {
	case http.StatusOK:
	case http.StatusForbidden, http.StatusTooManyRequests:
		if strings.Contains(strings.ToLower(string(body)), "rate limit") {
			g.limited = true
		}
		return "", false
	default: // 404 for a private repository the token cannot see, 422 for a commit GitHub does not have...
		return "", false
	}
	var data struct {
		Author *struct {
			Login string `json:"login"`
		} `json:"author"`
	}
	if json.Unmarshal(body, &data) != nil {
		return "", false
	}
	if data.Author == nil {
		return "", true
	}
	return data.Author.Login, true
}

// resolve maps a commit e-mail to a GitHub username: the noreply convention, else the account GitHub links to the
// commit repoURL/sha, else GitHub's user search (public e-mail addresses only). The answers are cached a day,
// "not found" included; a rate limit or a failure is not cached.
func (g *gaResolver) resolve(email, repoURL, sha string) string {
	email = gaTrim(email)
	if gaEmpty(email) {
		return ""
	}
	if u := gaGithubUsername(email); u != "" {
		return u
	}
	sum := md5.Sum([]byte(strings.ToLower(email)))
	key := "github_user_email_" + hex.EncodeToString(sum[:])
	if v, ok := cache.Default.Get(key); ok {
		return v.(string)
	}
	if g.limited {
		return ""
	}
	if user, trusted := g.userOfCommit(repoURL, sha); trusted {
		cache.Default.Set(key, user, 86400*time.Second)
		return user
	}
	if g.limited {
		return ""
	}
	body, _, err := gaGet(githubAPI+"/search/users?q="+url.QueryEscape(email)+"+in:email", g.token, 4*time.Second)
	user, trust := "", false
	if err == nil {
		var data map[string]any
		if json.Unmarshal(body, &data) == nil {
			if msg, _ := data["message"].(string); msg != "" && strings.Contains(strings.ToLower(msg), "rate limit") {
				g.limited = true
			} else if items, ok := data["items"].([]any); ok {
				trust = true
				if len(items) > 0 {
					if m, ok := items[0].(map[string]any); ok {
						if l, _ := m["login"].(string); l != "" {
							user = l
						}
					}
				}
			}
		}
	}
	if trust {
		cache.Default.Set(key, user, 86400*time.Second)
	}
	return user
}

// gaCommitsByAuthor returns the commits by author (top 30).
func gaCommitsByAuthor(dataDir string, repos []string, days int, now time.Time, g *gaResolver) []gaAuthorStat {
	since := now.UTC().AddDate(0, 0, -days).Format("2006-01-02")
	type ac struct {
		name string
		n    int
	}
	var order []*ac
	counts := map[string]*ac{}
	emails := map[string]string{}
	type commitRef struct{ repoURL, sha string } // a commit of the address, to ask GitHub whose it is
	refs := map[string]commitRef{}
	for _, repo := range repos {
		r := gaSource(dataDir, repo)
		if r == nil {
			continue
		}
		base := gaRepoGithubURL(r)
		out, err := r.Log(gitx.LogOptions{Since: since, Format: "%an%x00%ae%x00%cn%x00%H", NoMerges: true, Ref: gaTargetBranch(r)})
		if err != nil || gaEmpty(out) {
			continue
		}
		for _, line := range gaLines(out) {
			parts := strings.SplitN(line, "\x00", 4) // NUL: git prints names as C strings, so no name can contain it
			for len(parts) < 4 {
				parts = append(parts, "")
			}
			author, email, committer := gaTrim(parts[0]), gaTrim(parts[1]), gaTrim(parts[2])
			if gaEmpty(author) || gaIgnoredAuthors[author] || gaIgnoredAuthors[committer] {
				continue
			}
			a := counts[author]
			if a == nil {
				a = &ac{name: author}
				counts[author] = a
				order = append(order, a)
			}
			a.n++
			if gaEmpty(emails[author]) && !gaEmpty(email) {
				emails[author] = email
				refs[author] = commitRef{base, gaTrim(parts[3])}
			}
		}
	}
	sort.SliceStable(order, func(i, j int) bool { return order[i].n > order[j].n }) // arsort
	var res []gaAuthorStat
	for i, a := range order {
		if i >= 30 {
			break
		}
		user := ""
		if e, ok := emails[a.name]; ok {
			user = g.resolve(e, refs[a.name].repoURL, refs[a.name].sha)
		}
		s := gaAuthorStat{Author: a.name, Commits: a.n, AvatarURL: gaAvatarURL(user)}
		if user != "" {
			s.GithubURL = "https://github.com/" + user
		}
		res = append(res, s)
	}
	return res
}

type gaCommit struct {
	Repo, Label, Hash, FullHash, Author, Email, Date, Message string
	GithubURL, RepoURL, AuthorURL, AvatarURL                  string
}

// gaRecentCommits returns the latest commits (limit 50). E-mails are resolved to GitHub
// users only for the commits that are kept (far fewer API calls).
func gaRecentCommits(dataDir string, projects []gitx.Repo, limit int, now time.Time, g *gaResolver) []gaCommit {
	var all []gaCommit
	since := now.UTC().AddDate(0, 0, -90).Format("2006-01-02")
	for _, p := range projects {
		r := gaSource(dataDir, p.Name)
		if r == nil {
			continue
		}
		base := gaRepoGithubURL(r)
		out, err := r.Log(gitx.LogOptions{Since: since, Format: "%H%x00%an%x00%ae%x00%ai%x00%cn%x00%s", NoMerges: true, Ref: gaTargetBranch(r), MaxCount: 100})
		if err != nil || gaEmpty(out) {
			continue
		}
		for _, line := range gaLines(out) {
			parts := strings.SplitN(line, "\x00", 6)
			if len(parts) < 6 {
				continue
			}
			if gaIgnoredAuthors[parts[1]] || gaIgnoredAuthors[parts[4]] {
				continue
			}
			c := gaCommit{Repo: p.Name, Label: p.Label, Hash: parts[0][:min(8, len(parts[0]))], FullHash: parts[0], Author: parts[1],
				Email: parts[2], Date: parts[3][:min(10, len(parts[3]))], Message: parts[5], RepoURL: base}
			if base != "" {
				c.GithubURL = base + "/commit/" + parts[0]
			}
			all = append(all, c)
		}
	}
	sort.SliceStable(all, func(i, j int) bool { return all[i].Date > all[j].Date }) // strcmp desc
	if len(all) > limit {
		all = all[:limit]
	}
	for i := range all {
		c := &all[i]
		user := g.resolve(c.Email, c.RepoURL, c.FullHash)
		c.AvatarURL = gaAvatarURL(user)
		switch {
		case user != "":
			c.AuthorURL = "https://github.com/" + user
		case c.RepoURL != "":
			c.AuthorURL = c.RepoURL + "/commits?author=" + phpx.RawURLEncode(c.Email)
		}
	}
	return all
}

type gaPR struct{ Created, Merged int }

// gaPRData returns the PR counts of a GitHub org over the last days (a failed query counts 0).
func gaPRData(org, token string, days int, now time.Time) gaPR {
	since := now.UTC().AddDate(0, 0, -days).Format("2006-01-02")
	var res gaPR
	for _, q := range []struct {
		dst  *int
		qual string
	}{{&res.Created, "created:>=" + since}, {&res.Merged, "merged:>=" + since}} {
		body, status, err := gaGet(githubAPI+"/search/issues?q=is:pr+org:"+org+"+"+q.qual+"&per_page=1", token, 10*time.Second)
		if err != nil || status >= 400 {
			continue
		}
		var data struct {
			TotalCount *float64 `json:"total_count"`
		}
		if json.Unmarshal(body, &data) == nil && data.TotalCount != nil {
			*q.dst = int(*data.TotalCount)
		}
	}
	return res
}
