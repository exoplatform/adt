// Package static embeds the CSS, images, service worker, manifest and static error pages.
package static

import "embed"

//go:embed all:*
var FS embed.FS
