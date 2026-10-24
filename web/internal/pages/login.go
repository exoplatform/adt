package pages

import (
	"net/http"
	"net/url"
	"regexp"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// The login page. Credentials are posted to /dologin, handled by Apache
// (mod_auth_form) which validates them against the LDAP backend and sets the session cookie. A failed
// attempt is redirected back here with the login form as the Referer.
func init() {
	app.HandleFunc("GET /login", login)
}

var (
	unsafeTarget = regexp.MustCompile(`[\x00-\x1f\x7f\\]`)
	loopTarget   = regexp.MustCompile(`(?i)^/(login|dologin|logout)([/?#]|$)`)
	loginPath    = regexp.MustCompile(`^/login$`)
	portSuffix   = regexp.MustCompile(`:\d+$`)
)

// rawURLDecode decodes %XX sequences; invalid ones and "+" are kept.
func rawURLDecode(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] == '%' && i+2 < len(s) && isHex(s[i+1]) && isHex(s[i+2]) {
			b.WriteByte(unhex(s[i+1])<<4 | unhex(s[i+2]))
			i += 2
			continue
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

func isHex(c byte) bool {
	return c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F'
}

func unhex(c byte) byte {
	switch {
	case c >= 'a':
		return c - 'a' + 10
	case c >= 'A':
		return c - 'A' + 10
	}
	return c - '0'
}

// followupTarget extracts the URL to return to after login from a raw query string
// ("next=<escaped path?query>"), or "" . Apache escapes the "?" but not the "&", so the whole raw string
// after "next=" is the target. Only local paths are accepted (no open redirect, no login/logout loops).
func followupTarget(rawQuery string) string {
	if !strings.HasPrefix(rawQuery, "next=") {
		return ""
	}
	t := strings.TrimRight(rawURLDecode(rawQuery[5:]), "?")
	if t == "" || t[0] != '/' || len(t) > 2048 {
		return ""
	}
	if len(t) > 1 && (t[1] == '/' || t[1] == '\\') {
		return ""
	}
	if unsafeTarget.MatchString(t) || loopTarget.MatchString(t) {
		return ""
	}
	return t
}

func login(a *app.App, w http.ResponseWriter, r *http.Request) {
	referer, _ := url.Parse(r.Header.Get("Referer")) // empty on garbage
	if referer == nil {
		referer = &url.URL{}
	}
	refHost := portSuffix.ReplaceAllString(referer.Host, "")
	refererOurs := refHost != "" && strings.EqualFold(refHost, portSuffix.ReplaceAllString(r.Host, ""))
	failed := r.Method == http.MethodGet && refererOurs && loginPath.MatchString(referer.Path)
	// The target comes from the URL, or from the login form we were redirected back from after a failed attempt
	next := followupTarget(r.URL.RawQuery)
	if next == "" && failed {
		next = followupTarget(referer.RawQuery)
	}
	w.Header().Set("X-Frame-Options", "DENY")

	// Already signed in: no need to show the form. Apache hands over the session user (auth.HeaderSessionUser)
	// and not the decrypted session. An evicted session is not signed in: show the form instead of looping back.
	if auth.SessionUser(r) != "" && !sessions.For(a.Cfg.DataDir).IsRevoked(r) {
		to := next
		if to == "" {
			to = "/"
		}
		redirect(w, to)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=UTF-8")
	_, _ = w.Write([]byte(tpl.Must("login.tmpl", struct {
		Failed bool
		Next   string
	}{failed, next})))
}
