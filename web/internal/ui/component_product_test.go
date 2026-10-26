package ui

import (
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/instances"
)

// Addresses no application opens (JMX, LDAP, SSH) are copy buttons, not dead links.
func TestDeploymentActionsCopyButtons(t *testing.T) {
	d := instances.Instance{
		"DEPLOYMENT_EXT_HOST":       "acc.example.org",
		"DEPLOYMENT_JMX_URL":        "service:jmx:rmi://acc.example.org:10001/jndi/rmi://acc.example.org:10002/jmxrmi",
		"DEPLOYMENT_LDAP_LINK":      "ldap://acc.example.org:10389",
		"DEPLOYMENT_CRASH_ENABLED":  "true",
		"DEPLOYMENT_CRASH_SSH_PORT": "10003",
	}
	out := DeploymentActions(d)
	for _, want := range []string{
		`data-copy-text="service:jmx:rmi://acc.example.org:10001/jndi/rmi://acc.example.org:10002/jmxrmi"`,
		`data-copy-text="ldap://acc.example.org:10389"`,
		`data-copy-text="ssh -p 10003 root@acc.example.org"`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %s in %s", want, out)
		}
	}
	for _, bad := range []string{`href="service:jmx`, `href="ldap:`, `href="ssh:`} {
		if strings.Contains(out, bad) {
			t.Errorf("unexpected link %s in %s", bad, out)
		}
	}
}
