package app

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// The push service asks the same revoked.txt that Apache checks: an evicted session or a blocked user gets no push.
func TestPushRevocationUsesRevokedTxt(t *testing.T) {
	dir := t.TempDir()
	a := New(config.Config{DataDir: dir})
	const id = "0123456789abcdef0123456789abcdef01234567"
	if a.Push.Revoked(id, "alice") {
		t.Fatal("nothing is revoked yet")
	}
	if err := os.MkdirAll(filepath.Join(dir, "var", "sessions"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "var", "sessions", "revoked.txt"), []byte(id+"\n"+sessions.UserHash("Mallory")+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if !a.Push.Revoked(id, "alice") || !a.Push.Revoked("other", "mallory") || a.Push.Revoked("other", "alice") {
		t.Error("revoked.txt is not what decides")
	}
}
