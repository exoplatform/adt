package main

import (
	"os"
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/config"
)

// adt-web trusts identity headers: outside the development mode it must never open a TCP port.
func TestListenRefusesTCPOutsideDevMode(t *testing.T) {
	l, _, err := listen(config.Config{Listen: "127.0.0.1:0"})
	if err == nil {
		_ = l.Close()
		t.Fatal("TCP listener opened outside ADT_DEV_MODE")
	}
	if !strings.Contains(err.Error(), "refusing") {
		t.Errorf("unexpected error %v", err)
	}
}

func TestListenTCPInDevMode(t *testing.T) {
	l, _, err := listen(config.Config{DevMode: true, Listen: "127.0.0.1:0"})
	if err != nil {
		t.Fatal(err)
	}
	_ = l.Close()
}

func TestListenSocketRefusesToRemoveAFile(t *testing.T) {
	p := t.TempDir() + "/adt.sock"
	if err := writeFile(p); err != nil {
		t.Fatal(err)
	}
	if _, _, err := listen(config.Config{Socket: p}); err == nil {
		t.Error("regular file replaced by the socket")
	}
}

func writeFile(p string) error { return os.WriteFile(p, []byte("x"), 0o600) }
