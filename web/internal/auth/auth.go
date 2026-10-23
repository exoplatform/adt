// Package auth carries the identity Apache verified (mod_auth_form + LDAP) down to the handlers.
//
// Apache authenticates and authorises; this process only trusts the identity headers it sets, which is
// safe because the server listens on a unix socket Apache alone can reach (or on loopback in dev).
// Apache must unset these headers coming from the client and set them from its own variables.
//
// # What the shell, /login and the 403 page need from Apache
//
// The application never receives the decrypted mod_session payload (it holds the user's password). Apache
// extracts the few fields the app needs and passes only those, always with `RequestHeader unset <H> early`
// first so a client cannot forge them:
//
//   - X-Remote-User, X-Remote-Name, X-Remote-Mail: REMOTE_USER, AUTHENTICATE_DISPLAYNAME, AUTHENTICATE_MAIL
//     (authenticated locations).
//   - X-Session-Expiry: unix SECONDS (the session "expiry" is in microseconds: capture it with a regex that
//     drops the last six digits, e.g. /expiry=([0-9]+)[0-9]{6}/, from the SessionEnv value).
//   - X-Session-Hash: sha1 (40 lowercase hex) of the raw adt_session cookie value. Optional: when absent
//     the app computes the same hash from the Cookie header (sessions.ID). Best practice is to set it and to
//     strip adt_session from the Cookie header proxied to the app, so the app never sees the cookie either.
//   - X-Session-User: the "<realm>-user" value of the decrypted session. Needed where REMOTE_USER is empty
//     but a session may exist: /login (already signed in -> redirect) and the ErrorDocument 403 request
//     (Apache has lost REMOTE_USER there). Only those two locations need it (SessionEnv On + a regex capture
//     of /(?:^|&)[^&=]*-user=([^&]+)/); the session payload itself must NOT be forwarded.
//   - X-Request-Line: THE_REQUEST, the original request line "GET /path?query HTTP/1.1". On an
//     ErrorDocument (internal redirect) the URL is gone; the 403 handler uses it to build /login?next=...
//   - X-Forwarded-For: set by mod_proxy (client IP appended); the last entry is the client address recorded
//     in the session list and in the audit log.
package auth

import (
	"context"
	"net/http"
	"strconv"
	"time"
)

// Header names set by Apache (see dev/go-spike/proxy.conf and the infra prompt).
const (
	HeaderUser    = "X-Remote-User"    // REMOTE_USER
	HeaderName    = "X-Remote-Name"    // AUTHENTICATE_DISPLAYNAME
	HeaderMail    = "X-Remote-Mail"    // AUTHENTICATE_MAIL
	HeaderExpiry  = "X-Session-Expiry" // session "expiry" (unix seconds), never the whole session
	HeaderSession = "X-Session-Hash"   // sha1 of the adt_session cookie, as used by /debug-sessions

	// HeaderSessionUser is the login of the session, only needed on /login and on the ErrorDocument 403
	// request, where Apache has no REMOTE_USER (see the package comment).
	HeaderSessionUser = "X-Session-User"
	// HeaderRequestLine is THE_REQUEST ("GET /path HTTP/1.1"): the original request on an ErrorDocument.
	HeaderRequestLine = "X-Request-Line"
)

// SessionUser is the login Apache found in the session: X-Remote-User, else X-Session-User, else "".
// It reads the raw headers (not the dev-mode fake identity), so a page can tell "really signed in".
func SessionUser(r *http.Request) string {
	if u := r.Header.Get(HeaderUser); u != "" {
		return u
	}
	return r.Header.Get(HeaderSessionUser)
}

// Identity is the signed-in user: login, display name, mail and session expiry as Apache passed them.
type Identity struct {
	User   string
	Name   string // display name; falls back to User
	Mail   string
	Expiry time.Time // zero when unknown
}

// FullName returns the display name, else the login, else "" (not authenticated).
func (i Identity) FullName() string {
	if i.Name != "" {
		return i.Name
	}
	return i.User
}

type ctxKey struct{}

// FromHeaders reads the identity from the request headers.
func FromHeaders(r *http.Request) Identity {
	id := Identity{User: r.Header.Get(HeaderUser), Name: r.Header.Get(HeaderName), Mail: r.Header.Get(HeaderMail)}
	if n, err := strconv.ParseInt(r.Header.Get(HeaderExpiry), 10, 64); err == nil && n > 0 {
		id.Expiry = time.Unix(n, 0)
	}
	return id
}

// With stores the identity in the request context; From reads it back.
func With(r *http.Request, id Identity) *http.Request {
	return r.WithContext(context.WithValue(r.Context(), ctxKey{}, id))
}

// From returns the identity of the request (zero value when none).
func From(r *http.Request) Identity { id, _ := r.Context().Value(ctxKey{}).(Identity); return id }
