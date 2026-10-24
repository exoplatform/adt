package ui

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// Ctx is what a page works with: the output, the request, the configuration, the identity.
// Build it with NewCtx at the top of the handler; every shell function writes to it.
type Ctx struct {
	// W receives the page; Ctx itself is an io.Writer writing to it.
	W http.ResponseWriter
	// R is the request.
	R *http.Request
	// Cfg is the process configuration.
	Cfg config.Config
	// Origin is scheme, SERVER_NAME and SERVER_PORT of the dashboard being served.
	Origin instances.Origin
	// Identity is the signed-in user (REMOTE_USER, display name, mail, session expiry).
	Identity auth.Identity
	// Sessions tracks and revokes the login sessions; Audit is the audit log.
	Sessions *sessions.Store
	Audit    *audit.Log
	// RemoteDebugModal asks Footer to render the remote-debug modal ($GLOBALS['adtRemoteDebugModal']).
	RemoteDebugModal bool
	// Now overrides the clock (tests); nil means time.Now.
	Now func() time.Time
}

// NewCtx builds the context of a request. The identity is auth.From(r).
func NewCtx(w http.ResponseWriter, r *http.Request, cfg config.Config) *Ctx {
	return &Ctx{
		W: w, R: r, Cfg: cfg,
		Origin:   instances.OriginFromRequest(r, cfg),
		Identity: auth.From(r),
		Sessions: sessions.For(cfg.DataDir),
		Audit:    audit.For(cfg.DataDir),
	}
}

// Write implements io.Writer (so components can take an io.Writer or a *Ctx).
func (c *Ctx) Write(p []byte) (int, error) { return c.W.Write(p) }

// WriteString writes s to the page.
func (c *Ctx) WriteString(s string) { _, _ = io.WriteString(c.W, s) }

// Printf is a formatted echo.
func (c *Ctx) Printf(format string, a ...any) { _, _ = fmt.Fprintf(c.W, format, a...) }

func (c *Ctx) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

// Begin writes the standard page opening:
//
//	<!DOCTYPE html><html lang="en"><head> Head </head><body> Tracker Navigation
//	<div id="wrap"><div id="main" role="main">
//
// It also sets the Content-Type header. Close the page with End.
func (c *Ctx) Begin(title string, autoRefresh bool) {
	c.W.Header().Set("Content-Type", "text/html; charset=UTF-8")
	c.WriteString(tpl.Must("shell_page_open", nil))
	c.Head(title, autoRefresh)
	c.WriteString(tpl.Must("shell_page_body", nil))
	c.Tracker("")
	c.Navigation()
	c.WriteString(tpl.Must("shell_page_main", nil))
}

// End closes what Begin opened: </div></div> (main, wrap), Footer, </body></html>.
func (c *Ctx) End() {
	c.WriteString(tpl.Must("shell_page_close_main", nil))
	c.Footer()
	c.WriteString(tpl.Must("shell_page_end", nil))
}

// SessionExpiry returns the unix time the login session expires, 0 when unknown.
func (c *Ctx) SessionExpiry() int64 {
	if c.Identity.Expiry.IsZero() {
		return 0
	}
	return c.Identity.Expiry.Unix()
}

// SessionID returns the sha1 of the session cookie, "" without a session.
func (c *Ctx) SessionID() string { return sessions.ID(c.R) }

// CSRFToken returns the anti-CSRF token of the eviction forms.
func (c *Ctx) CSRFToken() string { return c.Sessions.CSRFToken(c.R) }

func (c *Ctx) trackSession() { c.Sessions.Track(c.R, c.Identity) }

// SessionRemainingLabel formats the time before the expiry (unix seconds): "6d 23h" / "7h 59m".
func SessionRemainingLabel(expiry int64, now time.Time) string {
	left := max(0, expiry-now.Unix())
	d, h, m := left/86400, left%86400/3600, left%3600/60
	if d > 0 {
		return strconv.FormatInt(d, 10) + "d " + strconv.FormatInt(h, 10) + "h"
	}
	return strconv.FormatInt(h, 10) + "h " + strconv.FormatInt(m, 10) + "m"
}

// GravatarURL returns the Gravatar of the mail (a silhouette when empty).
func GravatarURL(mail string, size int) string {
	sum := md5.Sum([]byte(strings.ToLower(strings.TrimSpace(mail))))
	return "https://www.gravatar.com/avatar/" + hex.EncodeToString(sum[:]) + "?s=" + strconv.Itoa(size) + "&d=mp"
}
