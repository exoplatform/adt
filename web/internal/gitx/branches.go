package gitx

import (
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/exoplatform/adt/web/internal/cache"
)

// BranchProject is the status of one branch in one project: GitHub links and the number of commits the
// branch is behind/ahead of the base branch.
type BranchProject struct {
	Project                              string
	HTTPURL, HTTPURLBehind, HTTPURLAhead string
	BehindCommits, AheadCommits          int
}

// BranchGroup is one branch name (without its "feature/" or "integration/" prefix) and the projects
// having it.
type BranchGroup struct {
	Name     string
	Projects []BranchProject
}

var (
	branchTTL = 5 * time.Minute // a branch listing is refreshed when it is older than this
	githubSSH = regexp.MustCompile(`git@github\.com:(.*)/(.*)\.git`)

	// branchLists keeps every listing: an out-of-date one keeps being served while a background refresh runs, so a
	// visitor does not wait for the git commands (about 2.5 s over all the clones). Only the first computation is
	// waited for. cache.InvalidateAll refreshes them.
	branchLists = cache.NewStale[[]BranchGroup]()
)

// Warm computes the listings the pages show, so that the first visitor does not wait for them.
func Warm(dataDir string) {
	projects := RepositoryNames()
	FeatureBranches(dataDir, projects)
	TranslationBranches(dataDir, projects)
}

// forEach runs f(0) .. f(n-1) on a few goroutines and waits for all of them.
func forEach(n int, f func(i int)) {
	workers := min(n, 8)
	next := make(chan int)
	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range next {
				f(i)
			}
		}()
	}
	for i := 0; i < n; i++ {
		next <- i
	}
	close(next)
	wg.Wait()
}

// strcasecmp orders strings bytewise after ASCII case folding.
func strcasecmp(a, b string) int {
	n := min(len(a), len(b))
	for i := 0; i < n; i++ {
		x, y := lower(a[i]), lower(b[i])
		if x != y {
			return int(x) - int(y)
		}
	}
	return len(a) - len(b)
}

func lower(c byte) byte {
	if c >= 'A' && c <= 'Z' {
		return c + 32
	}
	return c
}

// remoteBranches returns, for each "git branch -r" line containing marker, what follows the last
// "/<kind>/", skipping empty/"0" results.
func remoteBranches(r *Repository, marker, kind string) []string {
	out, err := r.Git("branch", "-r")
	if err != nil {
		return nil
	}
	var res []string
	for _, l := range strings.Split(out, "\n") {
		if !strings.Contains(l, marker) {
			continue
		}
		if kind == "integration" && !strings.Contains(l, "translation") {
			continue
		}
		if i := strings.LastIndex(l, "/"+kind+"/"); i >= 0 {
			l = l[i+len(kind)+2:]
		}
		if l != "" && l != "0" {
			res = append(res, l)
		}
	}
	return res
}

type groupSet struct {
	order  []string
	groups map[string][]BranchProject
}

func (g *groupSet) add(branch string, p BranchProject) {
	if g.groups == nil {
		g.groups = map[string][]BranchProject{}
	}
	if _, ok := g.groups[branch]; !ok {
		g.order = append(g.order, branch)
	}
	g.groups[branch] = append(g.groups[branch], p)
}

func (g *groupSet) sorted() []BranchGroup {
	sort.SliceStable(g.order, func(i, j int) bool { return strcasecmp(g.order[i], g.order[j]) < 0 })
	res := make([]BranchGroup, 0, len(g.order))
	for _, n := range g.order {
		res = append(res, BranchGroup{Name: n, Projects: g.groups[n]})
	}
	return res
}

func cached(key string, build func() []BranchGroup) []BranchGroup {
	return branchLists.Get(key, branchTTL, build)
}

// FeatureBranches lists the origin/feature/* branches of the projects.
func FeatureBranches(dataDir string, projects []string) []BranchGroup {
	return cached("features\x00"+dataDir+"\x00"+strings.Join(projects, "\x00"), func() []BranchGroup {
		return buildFeatureBranches(dataDir, projects)
	})
}

// branchTask is one branch of one project whose distance to the base branch is to be counted.
type branchTask struct {
	project, branch                   string
	org, repo, integrationOrg, remote string
	base                              string
	r                                 *Repository
	behind, ahead                     int
	ok                                bool
}

// countBranches fills behind/ahead of every task, in parallel (two git commands each).
func countBranches(tasks []*branchTask, ref string) {
	forEach(len(tasks), func(i int) {
		t := tasks[i]
		head := "origin/" + ref + "/" + t.branch
		base := t.remote + "/" + t.base
		var err1, err2 error
		t.behind, err1 = t.r.CountCommits(head, base)
		t.ahead, err2 = t.r.CountCommits(base, head)
		t.ok = err1 == nil && err2 == nil
	})
}

// buildFeatureBranches lists the branches of every project in parallel, then walks the projects in order (the
// GitHub org/repo of a previous match survives a remote that does not match), then counts the commits of all the
// branches in parallel. The result is the same, in the same order, as doing it all one after the other.
func buildFeatureBranches(dataDir string, projects []string) []BranchGroup {
	type listing struct {
		r        *Repository
		branches []string
		url      string
	}
	lists := make([]listing, len(projects))
	forEach(len(projects), func(i int) {
		r, err := OpenSource(dataDir, projects[i])
		if err != nil {
			return
		}
		var valid []string
		for _, branch := range remoteBranches(r, "origin/feature/", "feature") {
			if ValidRef("feature/" + branch) {
				valid = append(valid, branch)
			}
		}
		lists[i] = listing{r: r, branches: valid}
		if len(valid) > 0 {
			lists[i].url = r.RemoteOriginURL()
		}
	})

	var tasks []*branchTask
	var org, repo string
	for i, project := range projects {
		for _, branch := range lists[i].branches {
			if m := githubSSH.FindStringSubmatch(lists[i].url); m != nil {
				org, repo = m[1], m[2]
			}
			base := BaseBranchToCompareWith(org, repo, "feature/"+branch)
			if !ValidRef(base) {
				continue
			}
			tasks = append(tasks, &branchTask{project: project, branch: branch, org: org, repo: repo, remote: "origin", base: base, r: lists[i].r})
		}
	}
	countBranches(tasks, "feature")

	var gs groupSet
	for _, t := range tasks {
		if !t.ok {
			continue
		}
		gs.add(t.branch, BranchProject{
			Project:       t.project,
			HTTPURL:       "https://github.com/" + t.org + "/" + t.repo + "/tree/feature/" + t.branch,
			HTTPURLBehind: "https://github.com/" + t.org + "/" + t.repo + "/compare/feature/" + t.branch + "..." + t.base,
			HTTPURLAhead:  "https://github.com/" + t.org + "/" + t.repo + "/compare/" + t.base + "...feature/" + t.branch,
			BehindCommits: t.behind,
			AheadCommits:  t.ahead,
		})
	}
	return gs.sorted()
}

// TranslationBranches lists the origin/integration/*translation* branches.
func TranslationBranches(dataDir string, projects []string) []BranchGroup {
	return cached("translation\x00"+dataDir+"\x00"+strings.Join(projects, "\x00"), func() []BranchGroup {
		return buildTranslationBranches(dataDir, projects)
	})
}

// buildTranslationBranches works like buildFeatureBranches, with the extra org/repo/integrationOrg state that each
// branch updates for the next one.
func buildTranslationBranches(dataDir string, projects []string) []BranchGroup {
	type listing struct {
		r        *Repository
		branches []string
		url      string
	}
	lists := make([]listing, len(projects))
	forEach(len(projects), func(i int) {
		if translationIgnored[projects[i]] {
			return
		}
		r, err := OpenSource(dataDir, projects[i])
		if err != nil {
			return
		}
		var valid []string
		for _, branch := range remoteBranches(r, "origin/integration", "integration") {
			if ValidRef("integration/" + branch) {
				valid = append(valid, branch)
			}
		}
		lists[i] = listing{r: r, branches: valid}
		if len(valid) > 0 {
			lists[i].url = r.RemoteOriginURL()
		}
	})

	var tasks []*branchTask
	var org, repo, integrationOrg string
	for i, project := range projects {
		for _, branch := range lists[i].branches {
			remote := "origin"
			url := lists[i].url
			if m := githubSSH.FindStringSubmatch(url); m != nil {
				org, repo = m[1], m[2]
			}
			base := BaseBranchToCompareWith(org, repo, "integration/"+branch)
			if m := githubSSH.FindStringSubmatch(url); m != nil {
				repo = m[2]
				if strings.Contains(base, "stable") {
					org = "exoplatform"
					remote = "blessed"
				} else {
					org = m[1]
				}
				integrationOrg = m[1]
			}
			if !ValidRef(base) || !ValidRef(remote+"/"+base) {
				continue
			}
			tasks = append(tasks, &branchTask{project: project, branch: branch, org: org, repo: repo, integrationOrg: integrationOrg, remote: remote, base: base, r: lists[i].r})
		}
	}
	countBranches(tasks, "integration")

	var gs groupSet
	for _, t := range tasks {
		if !t.ok {
			continue
		}
		gs.add(t.branch, BranchProject{
			Project:       t.project,
			HTTPURL:       "https://github.com/" + t.integrationOrg + "/" + t.repo + "/tree/integration/" + t.branch,
			HTTPURLBehind: "https://github.com/" + t.integrationOrg + "/" + t.repo + "/compare/integration/" + t.branch + "..." + t.org + ":" + t.base,
			HTTPURLAhead:  "https://github.com/" + t.org + "/" + t.repo + "/compare/" + t.base + "..." + t.integrationOrg + ":integration/" + t.branch,
			BehindCommits: t.behind,
			AheadCommits:  t.ahead,
		})
	}
	return gs.sorted()
}
