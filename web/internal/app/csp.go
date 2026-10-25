package app

import (
	"crypto/sha256"
	"encoding/base64"
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

// Content-Security-Policy of the pages (ADT_WEB_CSP: "enforce", the default, "report-only" or "off").
//
// The pages carry no inline script and no inline event handler (the scripts are /js/*.js, the few values they
// need are data-* attributes or a JSON block), so scripts are allowed from this origin and the CDNs only: a
// script injected into a page by a value that was not escaped would not run. Styles keep 'unsafe-inline' (the
// pages use style attributes and <style> blocks). connect-src lists the CDNs too, which the developer tools ask for
// the source maps of their files. Forms may post to this server and to the other acceptance
// servers, where the edit forms of their instances live.
const (
	cspEnforce    = "enforce"
	cspReportOnly = "report-only"
)

// policy is the policy text; scriptHashes allows the inline scripts of a static page by their hash.
func (a *App) policy(scriptHashes ...string) string {
	// The CDN scripts by exact URL, not by host: jsdelivr serves any package or GitHub repository, and a tag manager
	// serves whatever its owner configured, so a host-wide rule would make any injected <script src> work. The
	// pages also carry the integrity hash of the CDN files they load. A new version of a library is a new line here
	// (the CI checks that every script URL of the templates is listed).
	script := []string{"'self'",
		"https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js",
		"https://cdn.jsdelivr.net/npm/chart.js@4.6.1/dist/chart.umd.min.js",
		"https://www.google-analytics.com/analytics.js",
		"https://www.googletagmanager.com/gtag/js"}
	script = append(script, scriptHashes...)
	form := []string{"'self'"}
	seen := map[string]bool{}
	for _, s := range a.Cfg.FormServers() {
		if u, err := url.Parse(s); err == nil && u.Host != "" && !seen[u.Scheme+"://"+u.Host] {
			seen[u.Scheme+"://"+u.Host] = true
			form = append(form, u.Scheme+"://"+u.Host)
		}
	}
	return strings.Join([]string{
		"default-src 'self'",
		"script-src " + strings.Join(script, " "),
		"style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com",
		"font-src 'self' https://cdnjs.cloudflare.com data:",
		"img-src 'self' data: https:",
		"connect-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://img.shields.io https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com https://*.doubleclick.net",
		"object-src 'none'",
		"base-uri 'self'",
		"frame-ancestors 'self'",
		"form-action " + strings.Join(form, " "),
	}, "; ")
}

// cspHeader is the header name and value to send, or "" when the policy is off.
func (a *App) cspHeader(scriptHashes ...string) (name, value string) {
	switch a.Cfg.CSP {
	case "off":
		return "", ""
	case cspReportOnly:
		return "Content-Security-Policy-Report-Only", a.policy(scriptHashes...)
	}
	return "Content-Security-Policy", a.policy(scriptHashes...)
}

var inlineScript = regexp.MustCompile(`(?s)<script>(.*?)</script>`)

// StaticPageCSP sets the policy of a static HTML page that has inline scripts of its own (the 403 and 404 pages are
// self-contained on purpose): those scripts, and only those, are allowed, by hash. Call it before writing the page.
func (a *App) StaticPageCSP(w http.ResponseWriter, page []byte) {
	var hashes []string
	for _, m := range inlineScript.FindAllSubmatch(page, -1) {
		sum := sha256.Sum256(m[1])
		hashes = append(hashes, "'sha256-"+base64.StdEncoding.EncodeToString(sum[:])+"'")
	}
	if name, value := a.cspHeader(hashes...); name != "" {
		w.Header().Set(name, value)
	}
}

// cspWriter adds the policy to the responses that are HTML (known from the Content-Type, or sniffed on the first
// write): JSON, logs, downloads, scripts and styles do not need it, and the service worker must not get one.
type cspWriter struct {
	http.ResponseWriter
	a    *App
	done bool
}

func (c *cspWriter) apply(first []byte) {
	if c.done {
		return
	}
	c.done = true
	h := c.ResponseWriter.Header()
	if h.Get("X-Content-Type-Options") == "" {
		h.Set("X-Content-Type-Options", "nosniff")
	}
	if h.Get("Content-Security-Policy") != "" || h.Get("Content-Security-Policy-Report-Only") != "" {
		return
	}
	ct := h.Get("Content-Type")
	if ct == "" && first != nil {
		ct = http.DetectContentType(first)
	}
	if !strings.HasPrefix(ct, "text/html") {
		return
	}
	if name, value := c.a.cspHeader(); name != "" {
		h.Set(name, value)
	}
	if h.Get("X-Frame-Options") == "" {
		h.Set("X-Frame-Options", "SAMEORIGIN") // browsers that do not know frame-ancestors
	}
}

func (c *cspWriter) WriteHeader(code int) {
	c.apply(nil)
	c.ResponseWriter.WriteHeader(code)
}

func (c *cspWriter) Write(p []byte) (int, error) {
	c.apply(p)
	return c.ResponseWriter.Write(p)
}

func (c *cspWriter) Flush() {
	c.apply(nil)
	if f, ok := c.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Unwrap lets http.ResponseController reach the real writer.
func (c *cspWriter) Unwrap() http.ResponseWriter { return c.ResponseWriter }
