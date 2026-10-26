package gitx

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// DefaultBaseBranch is the branch the feature branches are compared with unless one is set for them.
const DefaultBaseBranch = "develop"

// FeatureBasesDir is where the base branch of each feature branch is kept (conf/feature-bases/<key>.base).
func FeatureBasesDir(dataDir string) string { return filepath.Join(dataDir, "conf", "feature-bases") }

// FeatureBaseKey is the file name stem for the base branch of a feature branch ("/" becomes "__"); "" when the
// name cannot be one (the same characters as the other conf keys).
func FeatureBaseKey(name string) string {
	key := strings.ReplaceAll(name, "/", "__")
	if key == "" || len(key) > 128 || strings.Contains(key, "..") || !validKeyStem(key) {
		return ""
	}
	return key
}

func validKeyStem(s string) bool {
	for i, c := range s {
		alnum := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9'
		if !alnum && (i == 0 || !strings.ContainsRune("._-", c)) {
			return false
		}
	}
	return true
}

// FeatureBases reads the base branch set for each feature branch, by feature branch name key (FeatureBaseKey).
func FeatureBases(dataDir string) map[string]string {
	bases := map[string]string{}
	entries, err := os.ReadDir(FeatureBasesDir(dataDir))
	if err != nil {
		return bases
	}
	for _, e := range entries {
		key, ok := strings.CutSuffix(e.Name(), ".base")
		if !ok {
			continue
		}
		b, err := os.ReadFile(filepath.Join(FeatureBasesDir(dataDir), e.Name()))
		if v := strings.TrimSpace(string(b)); err == nil && ValidRef(v) {
			bases[key] = v
		}
	}
	return bases
}

// FeatureBase is the base branch of a feature branch: the one set for it, else DefaultBaseBranch.
func FeatureBase(bases map[string]string, name string) string {
	if b := bases[FeatureBaseKey(name)]; b != "" {
		return b
	}
	return DefaultBaseBranch
}

// basesCacheKey makes the listing cache follow the bases: a change builds a new listing.
func basesCacheKey(bases map[string]string) string {
	keys := make([]string, 0, len(bases))
	for k, v := range bases {
		keys = append(keys, k+"="+v)
	}
	sort.Strings(keys)
	return strings.Join(keys, ",")
}

// KnownBaseBranch tells whether origin/<base> exists in at least one of the projects, so that a base typed
// by a visitor is a real branch.
func KnownBaseBranch(dataDir string, projects []string, base string) bool {
	if !ValidRef(base) {
		return false
	}
	for _, p := range projects {
		if r, err := OpenSource(dataDir, p); err == nil && r.RefExists("origin/"+base) {
			return true
		}
	}
	return false
}
