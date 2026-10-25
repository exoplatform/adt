// Package confedit holds the security helpers of the handlers that write small files under ADT_DATA/conf
// (editFeature, editInstance): strict key validation, same-origin checks, bounded form parsing and atomic
// writes. Nothing that is not a plain file name can reach the file system.
package confedit

import (
	"errors"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const (
	// MaxBody bounds the request body (the forms post a few short text fields).
	MaxBody = 64 << 10
	// MaxValue bounds one stored value (description, link, note...).
	MaxValue = 4096
	// MaxKey bounds an instance/feature key (a file name stem).
	MaxKey = 128
)

// keyRe is what an INSTANCE_KEY looks like (product-version[-branch...], dots and dashes included). It must
// start with an alphanumeric so that "." and ".." and hidden files are impossible; "/", "\", NUL, spaces,
// "%" and other odd characters are rejected, not stripped.
var keyRe = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

// ValidKey reports whether key may be used as the stem of a file name under conf/features or conf/instances.
func ValidKey(key string) bool {
	return len(key) > 0 && len(key) <= MaxKey && keyRe.MatchString(key) && !strings.Contains(key, "..")
}

// ErrBadMethod, ErrTooLarge, ErrBadValue are the failures of ParseForm.
var (
	ErrBadMethod = errors.New("method not allowed")
	ErrTooLarge  = errors.New("request too large")
	ErrBadValue  = errors.New("invalid value")
)

// ParseForm reads the urlencoded POST body (bounded) and returns the form values. Query-string parameters
// are ignored: only the body counts, as with the forms. Every value must be free of NUL bytes and at most
// MaxValue bytes.
func ParseForm(w http.ResponseWriter, r *http.Request) (url.Values, error) {
	if r.Method != http.MethodPost {
		return nil, ErrBadMethod
	}
	r.Body = http.MaxBytesReader(w, r.Body, MaxBody)
	if err := r.ParseForm(); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return nil, ErrTooLarge
		}
		return nil, ErrBadValue
	}
	form := r.PostForm
	for _, vs := range form {
		for _, v := range vs {
			if len(v) > MaxValue || strings.IndexByte(v, 0) >= 0 {
				return nil, ErrBadValue
			}
		}
	}
	return form, nil
}

// trimDefaultPort lowercases a host[:port] and drops the default ports, so that "host", "host:443" and
// "host:80" are the same server: behind Apache the page URLs carry an explicit :443 while the Host header
// and the ACCEPTANCE_SERVERS entries do not.
func trimDefaultPort(h string) string {
	h = strings.ToLower(h)
	for _, p := range []string{":443", ":80"} {
		h = strings.TrimSuffix(h, p)
	}
	return h
}

// sameHost reports whether two host[:port] values name the same server.
func sameHost(a, b string) bool { return trimDefaultPort(a) == trimDefaultPort(b) }

// SameOrigin is the anti-CSRF check of the state-changing POSTs (the forms of the cards post to the
// acceptance server that owns the instance, so the page may legitimately come from another server of
// ACCEPTANCE_SERVERS). Accepted: Sec-Fetch-Site same-origin/none, else an Origin (or, failing
// that, a Referer) whose host is this request's Host or one of the acceptance servers. A request carrying
// none of these headers is refused: browsers always send Origin on a cross-origin POST.
func SameOrigin(r *http.Request, servers []string) bool {
	switch strings.ToLower(r.Header.Get("Sec-Fetch-Site")) {
	case "same-origin", "none":
		return true
	case "same-site", "cross-site":
		// the Origin check below decides: a page of another site, or of a sibling host (any application of the
		// domain) is not this server, and only the listed acceptance servers are
	}
	src := r.Header.Get("Origin")
	if src == "" || src == "null" {
		src = r.Header.Get("Referer")
	}
	if src == "" {
		return false
	}
	u, err := url.Parse(src)
	if err != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return false
	}
	if sameHost(u.Host, r.Host) {
		return true
	}
	for _, s := range servers {
		if su, err := url.Parse(s); err == nil && su.Host != "" && sameHost(su.Host, u.Host) {
			return true
		}
	}
	return false
}

// RefererIn reports whether the Referer of r is a page of one of the servers (or of this server). Unlike an Origin,
// a Referer is sent on the GET that follows a redirect, the only signal a page has that the visitor was bounced back
// by an acceptance server after an edit; a site can hide its Referer but not forge that of a server's page.
func RefererIn(r *http.Request, servers []string) bool {
	u, err := url.Parse(r.Header.Get("Referer"))
	if err != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return false
	}
	if sameHost(u.Host, r.Host) {
		return true
	}
	for _, s := range servers {
		if su, err := url.Parse(s); err == nil && su.Host != "" && sameHost(su.Host, u.Host) {
			return true
		}
	}
	return false
}

// SanitizeLocalRedirect keeps only a local absolute path, refusing
// the forms browsers treat as protocol-relative ("/\host") and control characters.
func SanitizeLocalRedirect(u string) string {
	if u == "" || u[0] != '/' || (len(u) > 1 && (u[1] == '/' || u[1] == '\\')) {
		return "/"
	}
	for i := 0; i < len(u); i++ {
		if u[i] < 0x20 || u[i] == 0x7f || u[i] == '\\' {
			return "/"
		}
	}
	return u
}

// ResolveFrom is SanitizeLocalRedirect applied to the "from" field, extended to what the forms really
// post: CurrentPageURL is an absolute URL ("http://host:port/features"). An absolute http(s) URL is kept
// when its host is this server or one of the
// acceptance servers (the form may have been rendered by another server of the farm); anything else, and
// any local path that SanitizeLocalRedirect refuses, becomes "/".
func ResolveFrom(from, host string, servers []string) string {
	if strings.HasPrefix(from, "http://") || strings.HasPrefix(from, "https://") {
		u, err := url.Parse(from)
		if err != nil || u.Host == "" || u.User != nil || strings.ContainsAny(from, "\\ \t\r\n") {
			return "/"
		}
		for i := 0; i < len(from); i++ {
			if from[i] < 0x20 || from[i] == 0x7f {
				return "/"
			}
		}
		ok := sameHost(u.Host, host)
		for _, s := range servers {
			if su, err := url.Parse(s); err == nil && su.Host != "" && sameHost(su.Host, u.Host) {
				ok = true
			}
		}
		if ok {
			return from
		}
		return "/"
	}
	return SanitizeLocalRedirect(from)
}

// WithClearCaches appends clearCaches=true (before any fragment).
func WithClearCaches(u string) string {
	frag := ""
	if i := strings.IndexByte(u, '#'); i >= 0 {
		u, frag = u[:i], u[i:]
	}
	if strings.Contains(u, "?") {
		return u + "&clearCaches=true" + frag
	}
	return u + "?clearCaches=true" + frag
}

// Store writes (or removes) the files <dir>/<key><ext>.
type Store struct{ Dir string }

// Put writes data atomically (temp file in the same directory, then rename), mode 0644: the other users of
// the host (Apache, adt.sh) read these files.
func (s Store) Put(key, ext string, data string) error {
	if !ValidKey(key) {
		return ErrBadValue
	}
	if err := os.MkdirAll(s.Dir, 0o755); err != nil {
		return err
	}
	target := filepath.Join(s.Dir, key+ext)
	tmp, err := os.CreateTemp(s.Dir, ".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	_, werr := tmp.WriteString(data)
	cerr := tmp.Close()
	if werr != nil || cerr != nil {
		_ = os.Remove(name)
		if werr != nil {
			return werr
		}
		return cerr
	}
	if err := os.Chmod(name, 0o644); err != nil {
		_ = os.Remove(name)
		return err
	}
	if err := os.Rename(name, target); err != nil {
		_ = os.Remove(name)
		return err
	}
	return nil
}

// Remove deletes the file; a missing file is not an error.
func (s Store) Remove(key, ext string) error {
	if !ValidKey(key) {
		return ErrBadValue
	}
	err := os.Remove(filepath.Join(s.Dir, key+ext))
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

// Fail answers a ParseForm error with the right status and a plain, constant body (nothing from the
// request is echoed).
func Fail(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrBadMethod):
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
	case errors.Is(err, ErrTooLarge):
		http.Error(w, "Request Entity Too Large", http.StatusRequestEntityTooLarge)
	default:
		http.Error(w, "Bad Request", http.StatusBadRequest)
	}
}
