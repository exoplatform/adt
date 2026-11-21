package logview

import (
	"os"
	"path/filepath"
	"testing"
)

func setup(t *testing.T) (data string, p *Policy) {
	t.Helper()
	data = t.TempDir()
	for _, d := range []string{"servers/inst1/logs", "var/log/apache2"} {
		if err := os.MkdirAll(filepath.Join(data, d), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return data, NewPolicy(data)
}

func write(t *testing.T, path string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestPolicyAllowsKnownLogs(t *testing.T) {
	data, p := setup(t)
	a := filepath.Join(data, "servers/inst1/logs/platform.log")
	b := filepath.Join(data, "var/log/apache2/access.log")
	write(t, a)
	write(t, b)
	if !p.Authorized(TypeInstance, a) {
		t.Error("instance log refused")
	}
	if !p.Authorized(TypeApache, b) {
		t.Error("apache log refused")
	}
}

func TestPolicyRefuses(t *testing.T) {
	data, p := setup(t)
	secret := filepath.Join(t.TempDir(), "platform.log") // right name, outside the roots
	write(t, secret)
	other := filepath.Join(data, "servers/inst1/logs/passwd")
	write(t, other)
	apacheInInstance := filepath.Join(data, "var/log/apache2/error.log")
	write(t, apacheInInstance)
	link := filepath.Join(data, "servers/inst1/logs/server.log")
	if err := os.Symlink(secret, link); err != nil {
		t.Fatal(err)
	}
	linkToPasswd := filepath.Join(data, "servers/inst1/logs/catalina.out")
	if err := os.Symlink("/etc/passwd", linkToPasswd); err != nil {
		t.Fatal(err)
	}
	cases := []struct{ name, kind, path string }{
		{"outside the roots", TypeInstance, secret},
		{"name not allowed", TypeInstance, other},
		{"apache file as instance log is outside its roots", TypeInstance, apacheInInstance},
		{"symlink out of the roots", TypeInstance, link},
		{"symlink to /etc/passwd", TypeInstance, linkToPasswd},
		{"dot-dot", TypeInstance, data + "/servers/inst1/../../../etc/passwd"},
		{"relative", TypeInstance, "servers/inst1/logs/platform.log"},
		{"unknown type", "other", filepath.Join(data, "servers/inst1/logs/platform.log")},
		{"missing file", TypeInstance, filepath.Join(data, "servers/inst1/logs/nope/platform.log")},
		{"NUL", TypeInstance, filepath.Join(data, "servers/inst1/logs/platform.log") + "\x00"},
	}
	for _, c := range cases {
		if p.Authorized(c.kind, c.path) {
			t.Errorf("%s: %q was authorized", c.name, c.path)
		}
	}
}

func TestPolicyRefusesSiblingPrefixDirectory(t *testing.T) {
	data, p := setup(t)
	evil := filepath.Join(data, "var/log/apache2-evil")
	if err := os.MkdirAll(evil, 0o755); err != nil {
		t.Fatal(err)
	}
	f := filepath.Join(evil, "access.log")
	write(t, f)
	if p.Authorized(TypeApache, f) {
		t.Error("sibling directory sharing the root prefix was authorized")
	}
}

func TestPolicyRefusesDirectoryAndFIFO(t *testing.T) {
	data, p := setup(t)
	dir := filepath.Join(data, "var/log/apache2/access.log")
	if err := os.Mkdir(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if p.Authorized(TypeApache, dir) {
		t.Error("directory named access.log was authorized")
	}
}
