package gitx

import (
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
	"unicode/utf8"
)

// ErrInvalid is wrapped by every error caused by a rejected name or argument.
var ErrInvalid = errors.New("gitx: invalid argument")

func invalid(what, v string) error { return fmt.Errorf("%w: %s %q", ErrInvalid, what, v) }

// ValidRepoName reports whether name is a plain repository name ([A-Za-z0-9][A-Za-z0-9._-]*, no "..").
func ValidRepoName(name string) bool {
	if name == "" || len(name) > 200 || strings.Contains(name, "..") {
		return false
	}
	for i := 0; i < len(name); i++ {
		c := name[i]
		alnum := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9'
		if alnum {
			continue
		}
		if i > 0 && (c == '.' || c == '_' || c == '-') {
			continue
		}
		return false
	}
	return true
}

var revSuffix = regexp.MustCompile(`([~^][0-9]*)+$`)

const refForbidden = " ~^:?*[" + "\\" + ";&|$()<>\"'!`{}"

// ValidRef reports whether ref is safe to hand to git as a branch/revision argument: it cannot be read
// as an option (leading "-"), cannot contain control characters, whitespace, shell metacharacters or
// the revision syntax characters (: ? * [ \ { } and ~ ^ except as a trailing ~N / ^N ancestor suffix), nor "..", "//", a leading or trailing "/", a
// trailing "." or ".lock".
func ValidRef(ref string) bool {
	if ref == "" || len(ref) > 1024 || !utf8.ValidString(ref) {
		return false
	}
	ref = revSuffix.ReplaceAllString(ref, "") // HEAD~3, origin/develop^2
	if ref == "" {
		return false
	}
	if ref[0] == '-' || ref[0] == '/' || ref[0] == '.' || strings.HasSuffix(ref, "/") || strings.HasSuffix(ref, ".") ||
		strings.HasSuffix(ref, ".lock") || strings.Contains(ref, "..") || strings.Contains(ref, "//") {
		return false
	}
	for _, r := range ref {
		if r < 0x20 || r == 0x7f || r < 0x80 && strings.ContainsRune(refForbidden, r) {
			return false
		}
	}
	return true
}

// ValidPath reports whether p is a relative path inside a git tree: not empty, not absolute, no ".."
// segment, no control characters.
func ValidPath(p string) bool {
	if p == "" || len(p) > 4096 || p[0] == '/' || !utf8.ValidString(p) {
		return false
	}
	for _, r := range p {
		if r < 0x20 || r == 0x7f {
			return false
		}
	}
	for _, seg := range strings.Split(p, "/") {
		if seg == ".." {
			return false
		}
	}
	return true
}

// SourcesPath returns dataDir/sources/<project>.git after validating the project name.
func SourcesPath(dataDir, project string) (string, error) {
	if !ValidRepoName(project) {
		return "", invalid("repository name", project)
	}
	return filepath.Join(dataDir, "sources", project+".git"), nil
}

// validOption accepts a plain git option such as "-r" or "--merged" (no value, no shell characters).
func validOption(o string) bool {
	if len(o) < 2 || o[0] != '-' {
		return false
	}
	for i := 1; i < len(o); i++ {
		c := o[i]
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '-') {
			return false
		}
	}
	return true
}

// validConfigKey accepts "section.key" / "section.sub.key" style names.
func validConfigKey(k string) bool {
	if k == "" || len(k) > 200 || k[0] == '-' || !strings.Contains(k, ".") || strings.Contains(k, "..") || k[0] == '.' || k[len(k)-1] == '.' {
		return false
	}
	for i := 0; i < len(k); i++ {
		c := k[i]
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '.' || c == '-' || c == '_') {
			return false
		}
	}
	return true
}

func hasControl(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] < 0x20 || s[i] == 0x7f {
			return true
		}
	}
	return false
}
