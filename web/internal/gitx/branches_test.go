package gitx

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// git runs a git command in dir (no signing, no hooks, a fixed identity).
func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null"}, args...)...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// newSource creates dataDir/sources/<project>.git with origin/develop and the given feature branches, each a number of
// commits ahead of develop; origin is the url.
func newSource(t *testing.T, dataDir, project, url string, features map[string]int) string {
	t.Helper()
	dir := filepath.Join(dataDir, "sources", project+".git")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	git(t, dir, "init", "-q", ".")
	git(t, dir, "remote", "add", "origin", url)
	if err := os.WriteFile(filepath.Join(dir, "f"), []byte("base"), 0o644); err != nil {
		t.Fatal(err)
	}
	git(t, dir, "add", "f")
	git(t, dir, "commit", "-q", "-m", "base")
	base := git(t, dir, "rev-parse", "HEAD")
	git(t, dir, "update-ref", "refs/remotes/origin/develop", base)
	for name, ahead := range features {
		addFeature(t, dir, name, ahead)
	}
	return dir
}

// addFeature sets origin/feature/<name> ahead commits after origin/develop.
func addFeature(t *testing.T, dir, name string, ahead int) {
	t.Helper()
	git(t, dir, "checkout", "-q", "-B", "work-"+name, "refs/remotes/origin/develop")
	for i := 0; i < ahead; i++ {
		if err := os.WriteFile(filepath.Join(dir, "f_"+name), []byte(strings.Repeat("x", i+1)), 0o644); err != nil {
			t.Fatal(err)
		}
		git(t, dir, "add", "f_"+name)
		git(t, dir, "commit", "-q", "-m", name)
	}
	git(t, dir, "update-ref", "refs/remotes/origin/feature/"+name, git(t, dir, "rev-parse", "HEAD"))
}

func aheadOf(t *testing.T, groups []BranchGroup, feature, project string) int {
	t.Helper()
	for _, g := range groups {
		if g.Name != feature {
			continue
		}
		for _, p := range g.Projects {
			if p.Project == project {
				return p.AheadCommits
			}
		}
	}
	return -1
}

func needGit(t *testing.T) {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git")
	}
}

// The listing is cached per project: the fetch of one repository recomputes that one and nothing else. The other project is
// not asked again (it still shows what it showed), until everything is refreshed.
func TestRefreshFeatureBranchesIsPerProject(t *testing.T) {
	needGit(t)
	dir := t.TempDir()
	commons := newSource(t, dir, "commons", "git@github.com:Meeds-io/commons.git", map[string]int{"alpha": 2})
	social := newSource(t, dir, "social", "git@github.com:Meeds-io/social.git", map[string]int{"alpha": 3})
	projects := []string{"commons", "social"}

	first := FeatureBranches(dir, projects)
	if aheadOf(t, first, "alpha", "commons") != 2 || aheadOf(t, first, "alpha", "social") != 3 {
		t.Fatalf("first listing: %+v", first)
	}

	// both repositories move (as a fetch would do) and commons gets a new branch
	addFeature(t, commons, "alpha", 3)
	addFeature(t, commons, "gamma", 1)
	addFeature(t, social, "alpha", 4)

	// nothing is refreshed yet: the cached listing is served
	if got := FeatureBranches(dir, projects); aheadOf(t, got, "alpha", "commons") != 2 {
		t.Fatalf("a cached project was recomputed by itself: %+v", got)
	}

	RefreshFeatureBranches(dir, []string{"commons"})
	got := FeatureBranches(dir, projects)
	if aheadOf(t, got, "alpha", "commons") != 3 || aheadOf(t, got, "gamma", "commons") != 1 {
		t.Fatalf("commons was refreshed, the listing shows %+v", got)
	}
	if aheadOf(t, got, "alpha", "social") != 3 {
		t.Fatalf("social was recomputed although only commons was named (ahead %d, it moved to 4)", aheadOf(t, got, "alpha", "social"))
	}

	// unknown names change nothing and cost nothing
	RefreshFeatureBranches(dir, []string{"no-such-project", "../etc"})
	if aheadOf(t, FeatureBranches(dir, projects), "alpha", "social") != 3 {
		t.Fatal("an unknown name refreshed a project")
	}

	// no name: everything that was asked for
	RefreshFeatureBranches(dir, nil)
	if got := FeatureBranches(dir, projects); aheadOf(t, got, "alpha", "social") != 4 {
		t.Fatalf("a full refresh left social at %d, want 4", aheadOf(t, got, "alpha", "social"))
	}

	// a branch that is gone leaves the listing at the next refresh of its project
	git(t, commons, "update-ref", "-d", "refs/remotes/origin/feature/gamma")
	RefreshFeatureBranches(dir, []string{"commons"})
	if aheadOf(t, FeatureBranches(dir, projects), "gamma", "commons") != -1 {
		t.Fatal("a deleted branch is still listed")
	}
}

// What a listing holds is what the listing of all the projects at once always held: the links, the order, and the GitHub org/repo of
// a previous match that survives a project whose origin is not on GitHub.
func TestFeatureBranchesLinksAndOrder(t *testing.T) {
	needGit(t)
	dir := t.TempDir()
	newSource(t, dir, "commons", "git@github.com:Meeds-io/commons.git", map[string]int{"beta": 1, "alpha": 2})
	newSource(t, dir, "elsewhere", "https://example.org/other.git", map[string]int{"alpha": 1})
	got := FeatureBranches(dir, []string{"commons", "elsewhere"})

	if len(got) != 2 || got[0].Name != "alpha" || got[1].Name != "beta" {
		t.Fatalf("order: %+v", got)
	}
	alpha := got[0].Projects
	if len(alpha) != 2 || alpha[0].Project != "commons" || alpha[1].Project != "elsewhere" {
		t.Fatalf("projects of alpha: %+v", alpha)
	}
	c := alpha[0]
	if c.HTTPURL != "https://github.com/Meeds-io/commons/tree/feature/alpha" ||
		c.HTTPURLBehind != "https://github.com/Meeds-io/commons/compare/feature/alpha...develop" ||
		c.HTTPURLAhead != "https://github.com/Meeds-io/commons/compare/develop...feature/alpha" ||
		c.BehindCommits != 0 || c.AheadCommits != 2 {
		t.Fatalf("commons/alpha: %+v", c)
	}
	// "elsewhere" is not on GitHub: it keeps the org/repo of the project before it, as before
	if want := "https://github.com/Meeds-io/commons/tree/feature/alpha"; alpha[1].HTTPURL != want {
		t.Fatalf("the org/repo of the previous match did not survive: %q", alpha[1].HTTPURL)
	}
}
