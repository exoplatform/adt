package app

import (
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/config"
)

// script-src lists CDN scripts by exact URL so that an injected <script src> cannot use a host that serves anything. A URL
// without a query string also matches the same path with ANY query string, so a script that takes its code from the query
// (googletagmanager.com/gtag/js?id=<container>, a container runs any JavaScript) must not be listed. Nothing loads it.
func TestScriptSrcHasNoParameterisedScript(t *testing.T) {
	policy := New(config.Config{}).policy()
	var script string
	for _, d := range strings.Split(policy, ";") {
		if d = strings.TrimSpace(d); strings.HasPrefix(d, "script-src ") {
			script = d
		}
	}
	if script == "" {
		t.Fatalf("no script-src in %q", policy)
	}
	tokens := strings.Fields(script)[1:]
	for _, tok := range tokens {
		switch tok {
		case "*", "https:", "http:", "data:", "'unsafe-inline'", "'unsafe-eval'":
			t.Errorf("script-src allows %q: %s", tok, script)
		}
		if strings.Contains(tok, "googletagmanager.com") || strings.HasPrefix(tok, "*.") {
			t.Errorf("script-src allows %q: %s", tok, script)
		}
	}
	for _, want := range []string{"'self'", "https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js", "https://www.google-analytics.com/analytics.js"} {
		if !strings.Contains(script, want) {
			t.Errorf("script-src lost %q: %s", want, script)
		}
	}
}
