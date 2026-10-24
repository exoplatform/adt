package pages

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/ui"
)

// Helpers shared by the debug pages and the log viewers (prefix dbg to stay clear of other pages).

// dbgCtx builds the page context of a debug page.
func dbgCtx(a *app.App, w http.ResponseWriter, r *http.Request) *ui.Ctx {
	return ui.NewCtx(w, r, a.Cfg)
}

// dbgEnd closes a page opened with debugx.Open: footer and </body></html>.
func dbgEnd(c *ui.Ctx) {
	c.Footer()
	c.WriteString("</body>\n</html>")
}

// crossSite reports a request the browser itself marks as coming from another origin (Sec-Fetch-Site, which a
// page cannot forge). A sibling host of the domain is "same-site" and counts: it can be any application. The state changing links that exist as GET in the UI (?clearCaches=true,
// ?refreshInstances) refuse such requests: that is their CSRF protection, since the links cannot carry a token.
func crossSite(r *http.Request) bool {
	return r.Header.Get("Sec-Fetch-Site") == "cross-site" || r.Header.Get("Sec-Fetch-Site") == "same-site"
}

// dbgCheckCaches handles ?clearCaches: it empties the caches (audited) and redirects to the same page
// without that parameter. It reports whether the request was handled.
func dbgCheckCaches(c *ui.Ctx) bool {
	q := c.R.URL.Query()
	if _, ok := q["clearCaches"]; !ok {
		return false
	}
	if crossSite(c.R) {
		http.Error(c.W, "Forbidden", http.StatusForbidden)
		return true
	}
	c.Audit.Add(c.R, "cache.clear", "page", c.R.URL.Path)
	cache.Default.Clear()
	cache.InvalidateAll()
	q.Del("clearCaches")
	to := c.R.URL.Path
	if len(q) > 0 {
		to += "?" + q.Encode()
	}
	redirect(c.W, to)
	return true
}

// phpIntval parses leading blanks, sign, digits, and the integer part of a decimal or exponent
// form ("1e3" is 1000); anything else is 0; out of range values saturate.
func phpIntval(s string) int64 {
	s = strings.TrimLeft(s, " \t\n\r\v\f")
	end := 0
	if end < len(s) && (s[end] == '+' || s[end] == '-') {
		end++
	}
	digits := end
	for end < len(s) && s[end] >= '0' && s[end] <= '9' {
		end++
	}
	intEnd := end
	isFloat := false
	if end < len(s) && s[end] == '.' {
		j := end + 1
		for j < len(s) && s[j] >= '0' && s[j] <= '9' {
			j++
		}
		if j > end+1 || intEnd > digits {
			isFloat, end = true, j
		}
	}
	if (intEnd > digits || isFloat) && end < len(s) && (s[end] == 'e' || s[end] == 'E') {
		j := end + 1
		if j < len(s) && (s[j] == '+' || s[j] == '-') {
			j++
		}
		k := j
		for k < len(s) && s[k] >= '0' && s[k] <= '9' {
			k++
		}
		if k > j {
			isFloat, end = true, k
		}
	}
	if intEnd == digits && !isFloat {
		return 0
	}
	if isFloat {
		f, err := strconv.ParseFloat(s[:end], 64)
		if err != nil && !strings.Contains(err.Error(), "range") {
			return 0
		}
		switch {
		case f >= 9.2233720368547758e18:
			return 1<<63 - 1
		case f <= -9.2233720368547758e18:
			return -1 << 63
		}
		return int64(f)
	}
	n, err := strconv.ParseInt(s[:intEnd], 10, 64)
	if err != nil {
		if strings.HasPrefix(s, "-") {
			return -1 << 63
		}
		return 1<<63 - 1
	}
	return n
}

// asciiLower lowercases A-Z only.
func asciiLower(s string) string {
	b := []byte(s)
	for i, ch := range b {
		if ch >= 'A' && ch <= 'Z' {
			b[i] = ch + 32
		}
	}
	return string(b)
}

// phpEmpty reports whether s is "" or "0".
func phpEmpty(s string) bool { return s == "" || s == "0" }

// dbgQuery is the value of query parameter k ("" when absent; the last value wins).
func dbgQuery(r *http.Request, k string) string {
	v := r.URL.Query()[k]
	if len(v) == 0 {
		return ""
	}
	return v[len(v)-1]
}

// debugOption is one <option> of a <select>.
type debugOption struct {
	Value    string
	Selected bool
}

// debugOptions lists values as options, marking the one equal to selected.
func debugOptions(values []string, selected string) []debugOption {
	out := make([]debugOption, len(values))
	for i, v := range values {
		out[i] = debugOption{v, v == selected}
	}
	return out
}
