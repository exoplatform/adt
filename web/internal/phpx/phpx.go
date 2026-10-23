// Package phpx holds the few string helpers (escaping, natural sort, truthiness) whose exact output the pages depend on.
package phpx

import (
	"net/url"
	"sort"
	"strings"
	"unicode"
)

var specialChars = strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&#039;")

// HTMLSpecialChars escapes & < > " and ' (as &#039;, which html.EscapeString does not); invalid UTF-8 is replaced.
func HTMLSpecialChars(s string) string { return specialChars.Replace(strings.ToValidUTF8(s, "�")) }

// Esc is the short name used in templates and renderers.
func Esc(s string) string { return HTMLSpecialChars(s) }

// URLEncode encodes a string: spaces become "+", everything but [A-Za-z0-9_.-] is percent-encoded.
func URLEncode(s string) string { return url.QueryEscape(s) }

// RawURLEncode encodes per RFC 3986: spaces become %20, "~" is kept.
func RawURLEncode(s string) string {
	return strings.ReplaceAll(url.QueryEscape(s), "+", "%20")
}

// NatSort sorts in natural order: digit runs compare numerically.
func NatSort(s []string) {
	sort.SliceStable(s, func(i, j int) bool { return StrNatCmp(s[i], s[j]) < 0 })
}

// StrNatCmp is a natural-order comparison (case-sensitive, like strnatcmp).
func StrNatCmp(a, b string) int {
	ra, rb := []rune(a), []rune(b)
	i, j := 0, 0
	for i < len(ra) && j < len(rb) {
		if unicode.IsDigit(ra[i]) && unicode.IsDigit(rb[j]) {
			si := i
			for i < len(ra) && unicode.IsDigit(ra[i]) {
				i++
			}
			sj := j
			for j < len(rb) && unicode.IsDigit(rb[j]) {
				j++
			}
			na, nb := strings.TrimLeft(string(ra[si:i]), "0"), strings.TrimLeft(string(rb[sj:j]), "0")
			if len(na) != len(nb) {
				if len(na) < len(nb) {
					return -1
				}
				return 1
			}
			if na != nb {
				if na < nb {
					return -1
				}
				return 1
			}
			continue
		}
		if ra[i] != rb[j] {
			if ra[i] < rb[j] {
				return -1
			}
			return 1
		}
		i++
		j++
	}
	switch {
	case i < len(ra):
		return 1
	case j < len(rb):
		return -1
	}
	return 0
}

// Truthy reports whether a value found in descriptors is set: "", "0", nil, false, 0 are false.
func Truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case string:
		return x != "" && x != "0"
	case float64:
		return x != 0
	case int:
		return x != 0
	case []any:
		return len(x) > 0
	case []string:
		return len(x) > 0
	case map[string]any:
		return len(x) > 0
	}
	return true
}
