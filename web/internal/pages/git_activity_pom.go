package pages

import (
	"regexp"
	"strings"

	"github.com/exoplatform/adt/web/internal/gitx"
)

// Regex-based pom.xml reader for the dependency graph.

var gaDependencyLinkPrefixes = []string{"io.meeds", "addon.meeds", "org.exoplatform", "addon.exo"}

func gaGroupIDMatchesDependencyPrefix(groupID string) bool {
	for _, p := range gaDependencyLinkPrefixes {
		if groupID == p || strings.HasPrefix(groupID, p+".") {
			return true
		}
	}
	return false
}

// gaGroupIDIsGenericPrefix: the bare vendor namespaces are shared by too many repos' parent to identify one.
func gaGroupIDIsGenericPrefix(groupID string) bool {
	for _, p := range gaDependencyLinkPrefixes {
		if groupID == p {
			return true
		}
	}
	return false
}

func gaTagRegexp(tag string) *regexp.Regexp {
	return regexp.MustCompile(`(?s)<` + regexp.QuoteMeta(tag) + `[^>]*>(.*?)</` + regexp.QuoteMeta(tag) + `>`)
}

var (
	gaTagRegexps = map[string]*regexp.Regexp{}
	gaCommentRe  = regexp.MustCompile(`(?s)<!--.*?-->`)
	gaDepRe      = regexp.MustCompile(`(?s)<dependency>(.*?)</dependency>`)
)

func init() {
	for _, t := range []string{"parent", "artifactId", "groupId", "dependencyManagement", "dependencies"} {
		gaTagRegexps[t] = gaTagRegexp(t)
	}
}

func gaPomExtractTag(xml, tag string) string {
	if m := gaTagRegexps[tag].FindStringSubmatch(xml); m != nil {
		return strings.Trim(m[1], " \t\n\r\x00\x0b")
	}
	return ""
}

// gaPomExtractBlock returns the inner text of the first <tag>...</tag>, ok=false when absent.
func gaPomExtractBlock(xml, tag string) (string, bool) {
	if m := gaTagRegexps[tag].FindStringSubmatch(xml); m != nil {
		return m[1], true
	}
	return "", false
}

// gaParsePomXml strips the XML comments; "" means no usable pom.
func gaParsePomXml(content string) string {
	if content == "" || content == "0" {
		return ""
	}
	return gaCommentRe.ReplaceAllString(content, "")
}

var gaPomBoundaryTags = []string{"properties", "dependencyManagement", "dependencies", "build",
	"modules", "profiles", "scm", "licenses", "developers", "distributionManagement"}

// gaPomOwnHeaderSegment is the part of the pom between </parent> and the first nested block, plus the
// parent block.
func gaPomOwnHeaderSegment(xml string) (header, parentBlock string, hasParent bool) {
	parentBlock, hasParent = gaPomExtractBlock(xml, "parent")
	own := xml
	if hasParent {
		own = strings.ReplaceAll(xml, "<parent>"+parentBlock+"</parent>", "")
	}
	cut := len(own)
	for _, t := range gaPomBoundaryTags {
		if pos := strings.Index(own, "<"+t+">"); pos >= 0 && pos < cut {
			cut = pos
		}
	}
	return own[:cut], parentBlock, hasParent
}

// gaPomOwnCoordinates is "groupId:artifactId" of the pom itself ("" when unknown).
func gaPomOwnCoordinates(xml string) string {
	header, parentBlock, hasParent := gaPomOwnHeaderSegment(xml)
	artifactID := gaPomExtractTag(header, "artifactId")
	groupID := gaPomExtractTag(header, "groupId")
	if groupID == "" && hasParent {
		groupID = gaPomExtractTag(parentBlock, "groupId")
	}
	if groupID != "" && artifactID != "" {
		return groupID + ":" + artifactID
	}
	return ""
}

// gaPomUpperLinks is the "groupId:artifactId" of the parent and of the dependencyManagement entries under
// the tracked groupIds, in document order, without duplicates.
func gaPomUpperLinks(xml string) []string {
	var links []string
	seen := map[string]bool{}
	add := func(g, a string) {
		if g != "" && a != "" && gaGroupIDMatchesDependencyPrefix(g) && !seen[g+":"+a] {
			seen[g+":"+a] = true
			links = append(links, g+":"+a)
		}
	}
	if parent, ok := gaPomExtractBlock(xml, "parent"); ok {
		add(gaPomExtractTag(parent, "groupId"), gaPomExtractTag(parent, "artifactId"))
	}
	if dm, ok := gaPomExtractBlock(xml, "dependencyManagement"); ok {
		if deps, ok := gaPomExtractBlock(dm, "dependencies"); ok {
			for _, m := range gaDepRe.FindAllStringSubmatch(deps, -1) {
				add(gaPomExtractTag(m[1], "groupId"), gaPomExtractTag(m[1], "artifactId"))
			}
		}
	}
	return links
}

// gaRepoGithubURL returns the https GitHub URL of the origin remote, "" when none.
var gaGithubRemoteRe = regexp.MustCompile(`github\.com[:/]+([^/]+)/([^/]+?)(?:\.git)?/?$`)

func gaRepoGithubURL(r *gitx.Repository) string {
	if m := gaGithubRemoteRe.FindStringSubmatch(strings.TrimSpace(r.RemoteOriginURL())); m != nil {
		return "https://github.com/" + m[1] + "/" + m[2]
	}
	return ""
}

// gaTargetBranch returns origin/develop when it exists, else HEAD.
func gaTargetBranch(r *gitx.Repository) string {
	if r.RefExists("origin/develop") {
		return "origin/develop"
	}
	return "HEAD"
}

// gaDepGraph is the result of the dependency graph.
type gaDepGraph struct {
	Links     map[string][]string // repo -> repos it depends on
	GithubURL map[string]string   // repo -> GitHub URL ("" = null)
}

func gaBuildDependencyGraph(dataDir string, projects []gitx.Repo) gaDepGraph {
	coordinates := map[string]string{}
	groupOwners := map[string]string{}
	ambiguous := map[string]bool{}
	var order []string
	upper := map[string][]string{}
	githubURLs := map[string]string{}

	for _, p := range projects {
		repo := p.Name
		r, err := gitx.OpenSource(dataDir, repo)
		if err != nil {
			continue
		}
		githubURLs[repo] = gaRepoGithubURL(r)
		content, err := r.Show(gaTargetBranch(r), "pom.xml")
		if err != nil {
			continue
		}
		xml := gaParsePomXml(content)
		if xml == "" || xml == "0" {
			continue
		}
		if own := gaPomOwnCoordinates(xml); own != "" {
			coordinates[own] = repo
			ownGroup, _, _ := strings.Cut(own, ":")
			if !gaGroupIDIsGenericPrefix(ownGroup) {
				if _, ok := groupOwners[ownGroup]; ok || ambiguous[ownGroup] {
					ambiguous[ownGroup] = true
				} else {
					groupOwners[ownGroup] = repo
				}
			}
		}
		upper[repo] = gaPomUpperLinks(xml)
		order = append(order, repo)
	}
	for g := range ambiguous {
		delete(groupOwners, g)
	}
	links := map[string][]string{}
	for _, repo := range order {
		var resolved []string
		seen := map[string]bool{}
		for _, coord := range upper[repo] {
			target, ok := coordinates[coord]
			if !ok {
				g, _, _ := strings.Cut(coord, ":")
				target, ok = groupOwners[g]
			}
			if ok && target != repo && !seen[target] {
				seen[target] = true
				resolved = append(resolved, target)
			}
		}
		if len(resolved) > 0 {
			links[repo] = resolved
		}
	}
	return gaDepGraph{Links: links, GithubURL: githubURLs}
}
