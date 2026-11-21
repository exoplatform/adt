package pages

import (
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/instances"
)

// /debug-deploy dumps the instances of every getter: the descriptors hold secrets (JMX, Matrix, Jitsi, OAuth, CMIS,
// LDAP passwords), which stay out of the dump like they stay out of /rest/local-instances.
func TestCategoriesDumpMasksSecrets(t *testing.T) {
	b := instances.NewBranches()
	b.Add("7.3.x", instances.Instance{
		"INSTANCE_KEY": "plf-7.3.x", "PRODUCT_NAME": "plf",
		"DEPLOYMENT_JMX_READWRITE_PASSWORD": "SECRET_JMX", "DEPLOYMENT_MATRIX_JWT_SECRET": "SECRET_MATRIX",
		"DEPLOYMENT_OPTS": "-Dx.password=SECRET_OPTS", "DB_PASSWORD": "SECRET_DB", "INSTANCE_TOKEN": "SECRET_TOKEN",
	})
	out := debugx.VarToggle(categoriesDump(b))
	for _, secret := range []string{"SECRET_JMX", "SECRET_MATRIX", "SECRET_OPTS", "SECRET_DB", "SECRET_TOKEN"} {
		if strings.Contains(out, secret) {
			t.Errorf("the dump shows %s", secret)
		}
	}
	if !strings.Contains(out, "plf-7.3.x") {
		t.Error("the dump lost the instance itself")
	}
}
