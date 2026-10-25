package confedit_test

import (
	"net/http/httptest"
	"testing"

	"github.com/exoplatform/adt/web/internal/confedit"
	"github.com/exoplatform/adt/web/internal/config"
)

// The edit forms of acceptance12..15 are rendered by the primary front-end, which those servers do not list in
// ACCEPTANCE_SERVERS: their form servers must still accept its posts and send the visitor back to it.
func TestFormServersAcceptThePrimaryFrontEnd(t *testing.T) {
	cfg := config.Config{Servers: []string{"https://acceptance13.exoplatform.org"}}
	post := func(origin string) bool {
		r := httptest.NewRequest("POST", "https://acceptance13.exoplatform.org/editInstance", nil)
		r.Header.Set("Origin", origin)
		return confedit.SameOrigin(r, cfg.FormServers())
	}
	if !post(config.PrimaryFrontEnd) {
		t.Error("post from the primary front-end refused")
	}
	if post("https://evil.example.org") {
		t.Error("post from another site accepted")
	}
	from := config.PrimaryFrontEnd + "/sales"
	if got := confedit.ResolveFrom(from, "acceptance13.exoplatform.org", cfg.FormServers()); got != from {
		t.Errorf("ResolveFrom = %q, want %q", got, from)
	}
	if got := confedit.ResolveFrom(from, "acceptance13.exoplatform.org", cfg.Servers); got != "/" {
		t.Errorf("without the primary front-end ResolveFrom = %q, want /", got)
	}
}

// The GET that follows an edit bounces back from the acceptance server that owns the instance: same-site for the
// browser, so the clearCaches of the page is let in by its Referer.
func TestRefererIn(t *testing.T) {
	servers := config.Config{Servers: []string{"https://acceptance13.exoplatform.org"}}.FormServers()
	get := func(ref string) bool {
		r := httptest.NewRequest("GET", "https://acceptance.exoplatform.org/sales?clearCaches=true", nil)
		if ref != "" {
			r.Header.Set("Referer", ref)
		}
		return confedit.RefererIn(r, servers)
	}
	for _, ref := range []string{"https://acceptance13.exoplatform.org/", config.PrimaryFrontEnd + "/sales"} {
		if !get(ref) {
			t.Errorf("Referer %q refused", ref)
		}
	}
	for _, ref := range []string{"", "https://evil.example.org/", "https://wiki.exoplatform.org/", "javascript:1"} {
		if get(ref) {
			t.Errorf("Referer %q accepted", ref)
		}
	}
}
