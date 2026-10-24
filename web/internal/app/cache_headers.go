package app

import (
	"path"
	"strings"
)

// dynamicCacheControl is the Cache-Control of dynamic pages: they are never cached.
const dynamicCacheControl = "no-cache, no-store, must-revalidate, max-age=0, proxy-revalidate, no-transform"

// staticCacheControl is the cache policy of a static file
// (a year for icons, a week for images, two hours for CSS/JS/HTML/text, none for the service worker and the
// manifest so a new version is picked up without a hard refresh, and none for anything else).
func staticCacheControl(p string) string {
	switch path.Base(p) {
	case "sw.js", "manifest.json":
		return "no-cache, must-revalidate"
	}
	switch strings.ToLower(path.Ext(p)) {
	case ".ico", ".pdf":
		return "public, max-age=29030400"
	case ".gif", ".jpg", ".jpeg", ".png":
		return "public, max-age=604800, proxy-revalidate"
	case ".xml", ".txt", ".html", ".js", ".css":
		return "private, max-age=7200, proxy-revalidate, must-revalidate"
	}
	return "max-age=0"
}

// staticContentType overrides the type Go would guess for the few files whose type matters: the web app manifest
// must be application/manifest+json (an Apache AddType does not apply behind the proxy).
func staticContentType(p string) string {
	if path.Base(p) == "manifest.json" {
		return "application/manifest+json"
	}
	return ""
}
