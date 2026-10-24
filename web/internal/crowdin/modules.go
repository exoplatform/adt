package crowdin

import (
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/gitx"
)

// Module is one entry of the Crowdin module list. HasCrowdin is false for the repositories without a Crowdin
// workflow on develop (only Repo and Label are then set). StableBranch is "" when the stable counterpart
// does not exist.
type Module struct {
	Repo, Label                      string
	HasCrowdin                       bool
	GithubOrg, GithubRepo, GithubURL string
	IsPrivate, HasDownload           bool
	StableBranch                     string
}

// PrivateRepos are the repositories known to be private on GitHub. A live API check turned out to be
// unreliable in production, so this static list is what decides.
var PrivateRepos = []string{"ai", "platform-private-distributions"}

func isPrivateRepo(repo string) bool {
	for _, r := range PrivateRepos {
		if r == repo {
			return true
		}
	}
	return false
}

var (
	sshRe   = regexp.MustCompile(`git@github\.com:(.+)/(.+)\.git`)
	httpsRe = regexp.MustCompile(`https://github\.com/(.+)/(.+)\.git`)
)

// GithubOrgAndURL returns the GitHub organisation, repository and URL of origin.
func GithubOrgAndURL(r *gitx.Repository) (org, repo, url string, ok bool) {
	u := r.RemoteOriginURL()
	m := sshRe.FindStringSubmatch(u)
	if m == nil {
		m = httpsRe.FindStringSubmatch(u)
	}
	if m == nil {
		return "", "", "", false
	}
	return m[1], m[2], "https://github.com/" + m[1] + "/" + m[2], true
}

func lowerASCII(s string) string {
	b := []byte(s)
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			b[i] = c + 32
		}
	}
	return string(b)
}

// StableVersion is the stable branch the Crowdin page follows ("stable/<version>").
const StableVersion = "7.2.x"

var moduleLists = cache.NewStale[[]Module]()

// Known reports whether the request is one the Crowdin page makes: a repository of the module list, one of its
// three workflows, and its develop or stable branch. Anything else is not asked from GitHub (with the token of
// this server), nor kept in the cache.
func Known(modules []Module, org, repo, workflow, branch string) bool {
	switch workflow {
	case "upload-crowdin-main.yml", "download-crowdin.yml", "upload-crowdin-branches.yml":
	default:
		return false
	}
	for _, m := range modules {
		if m.HasCrowdin && strings.EqualFold(m.GithubOrg, org) && m.GithubRepo == repo &&
			(branch == "" || branch == "develop" || (m.StableBranch != "" && branch == m.StableBranch)) {
			return true
		}
	}
	return false
}

// Modules lists which repositories have the Crowdin workflows, and which of the
// develop/stable branches exist for each. Local git only; kept for an hour and refreshed in the
// background once out of date or after a cache clear, so a visitor does not wait for it.
// The returned slice is shared: do not modify it.
func Modules(dataDir string, projects []gitx.Repo, stableVersion string) []Module {
	m := moduleLists.Get(dataDir+"\x00"+stableVersion, time.Hour, func() []Module {
		return buildModules(dataDir, projects, stableVersion)
	})
	if len(m) == 0 { // sources not cloned yet: do not keep an empty list for an hour
		moduleLists.Invalidate()
	}
	return m
}

func buildModules(dataDir string, projects []gitx.Repo, stableVersion string) []Module {
	var modules []Module
	for _, p := range projects {
		r, err := gitx.OpenSource(dataDir, p.Name)
		if err != nil {
			continue
		}
		org, repo, url, ok := GithubOrgAndURL(r)
		if !ok {
			continue
		}
		if !r.PathExists("origin/develop", ".github/workflows/upload-crowdin-main.yml") {
			modules = append(modules, Module{Repo: p.Name, Label: p.Label})
			continue
		}
		hasDownload := r.PathExists("origin/develop", ".github/workflows/download-crowdin.yml")
		stable := "stable/" + stableVersion
		if strings.Contains(strings.ToLower(org), "meeds-io") {
			stable = "stable/" + stableVersion + "-exo"
		}
		stableBranch := ""
		if r.RefExists("origin/"+stable) && r.PathExists("origin/"+stable, ".github/workflows/upload-crowdin-branches.yml") {
			stableBranch = stable
		}
		modules = append(modules, Module{
			Repo: p.Name, Label: p.Label, HasCrowdin: true,
			GithubOrg: org, GithubRepo: repo, GithubURL: url,
			IsPrivate: isPrivateRepo(p.Name), HasDownload: hasDownload, StableBranch: stableBranch,
		})
	}
	sort.SliceStable(modules, func(i, j int) bool { return lowerASCII(modules[i].Label) < lowerASCII(modules[j].Label) })
	return modules
}
