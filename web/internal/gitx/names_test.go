package gitx

import "testing"

func TestValidRef(t *testing.T) {
	ok := []string{"develop", "feature/foo-bar", "origin/develop", "HEAD~3", "origin/develop^2", "release/7.3.x", "1.2.3"}
	bad := []string{"", "-rf", "--upload-pack=x", "/abs", ".hidden", "a..b", "a//b", "a/", "a.", "a.lock",
		"a b", "a;b", "a|b", "a$(x)", "a`x`", "a:b", "a?b", "a*b", "a[b", "a\\b", "a{b}", "a\nb", "a\x00b", "a~b", "a^b^c-", "a\x7fb"}
	for _, r := range ok {
		if !ValidRef(r) {
			t.Errorf("ValidRef(%q) = false, want true", r)
		}
	}
	for _, r := range bad {
		if ValidRef(r) {
			t.Errorf("ValidRef(%q) = true, want false", r)
		}
	}
	long := make([]byte, 1025)
	for i := range long {
		long[i] = 'a'
	}
	if ValidRef(string(long)) {
		t.Error("over-long ref accepted")
	}
}

func TestValidPath(t *testing.T) {
	for _, p := range []string{"pom.xml", "a/b/c.txt", "dir/.hidden", "a/..b/c"} {
		if !ValidPath(p) {
			t.Errorf("ValidPath(%q) = false, want true", p)
		}
	}
	for _, p := range []string{"", "/etc/passwd", "../x", "a/../b", "a/..", "a\nb", "a\x00b"} {
		if ValidPath(p) {
			t.Errorf("ValidPath(%q) = true, want false", p)
		}
	}
}

func TestCloneURLRejectsOptionsAndExtTransports(t *testing.T) {
	for _, u := range []string{"", "--upload-pack=touch /tmp/pwn", "-oProxyCommand=x", "ext::sh -c id", "https://h/r\n.git"} {
		if _, err := CloneURL(u, t.TempDir()+"/d"); err == nil {
			t.Errorf("CloneURL(%q) accepted", u)
		}
	}
	if _, err := CloneURL("https://example.org/r.git", "-evil"); err == nil {
		t.Error("CloneURL accepted a dir starting with -")
	}
}

func TestGitRejectsNUL(t *testing.T) {
	r := &Repository{dir: t.TempDir()}
	if _, err := r.Git("log", "a\x00b"); err == nil {
		t.Error("NUL argument accepted")
	}
}
