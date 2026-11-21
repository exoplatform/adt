package ui

import (
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/instances"
)

// A link target taken from a descriptor is never a script URL, whatever the case, whitespace or control characters
// browsers ignore inside the scheme. Real targets (http, https, sftp, relative) are left alone.
func TestHrefTarget(t *testing.T) {
	for _, bad := range []string{
		"javascript:alert(1)", "JaVaScRiPt:alert(1)", "  javascript:alert(1)", "java\tscript:alert(1)", "java\nscript:alert(1)",
		"\x01javascript:alert(1)", "data:text/html,<script>x</script>", "vbscript:msgbox(1)", "javascript:%0aalert(1)",
	} {
		if got := hrefTarget(bad); got != "#" {
			t.Errorf("hrefTarget(%q) = %q, want #", bad, got)
		}
	}
	for _, ok := range []string{"http://h/x?a=1&b=2", "https://h", "sftp://h:22", "/logs/x", "ldap://h:389", "service:jmx:rmi://h:1/jndi", ""} {
		if got := hrefTarget(ok); got != ok {
			t.Errorf("hrefTarget(%q) = %q, want it unchanged", ok, got)
		}
	}
	if got := href(`javascript:alert("x")`); got != "#" {
		t.Errorf("href = %q", got)
	}
	if got := href(`http://h/?a="b"&c=<d>`); got != `http://h/?a=&quot;b&quot;&c=&lt;d&gt;` {
		t.Errorf("href keeps escaping the way safe() does: %q", got)
	}
}

// The cards of a hostile descriptor carry no javascript: link and no markup breaking out of an attribute.
func TestCardActionsWithHostileDescriptor(t *testing.T) {
	evil := `javascript:alert(1)`
	d := instances.Instance{
		"DEPLOYMENT_EXT_HOST": "acc.example.org", "DEPLOYMENT_LOG_APPSRV_URL": evil, "DEPLOYMENT_LOG_APACHE_URL": evil,
		"DEPLOYMENT_AWSTATS_URL": evil, "DEPLOYMENT_SFTP_LINK": evil, "DEPLOYMENT_SFTP_ENABLED": "true",
	}
	out := DeploymentActions(d)
	if strings.Contains(strings.ToLower(out), "javascript:") {
		t.Fatalf("a script URL reaches a link:\n%s", out)
	}
}
