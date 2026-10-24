package main

import (
	"fmt"
	"net"
	"os"
	"os/user"
	"strconv"
	"syscall"

	"github.com/exoplatform/adt/web/internal/config"
)

// listen opens the TCP listener (development) or the unix socket Apache proxies to (production).
//
// The socket is created already restricted (umask 0117, so no window where another user could connect), then
// handed to ADT_SOCKET_GROUP when set. A stale socket from a previous run is replaced, but nothing else is ever
// removed: if the configured path exists and is not a socket, startup fails instead of deleting it.
func listen(cfg config.Config) (net.Listener, string, error) {
	if cfg.Socket == "" {
		// adt-web trusts the identity headers: on a TCP port any local process could forge them. Only the development
		// mode (which fakes the identity anyway) may listen there.
		if !cfg.DevMode {
			return nil, "", fmt.Errorf("ADT_SOCKET is not set: refusing to listen on TCP %s outside ADT_DEV_MODE", cfg.Listen)
		}
		l, err := net.Listen("tcp", cfg.Listen)
		return l, "tcp " + cfg.Listen, err
	}
	if fi, err := os.Lstat(cfg.Socket); err == nil {
		if fi.Mode()&os.ModeSocket == 0 {
			return nil, "", fmt.Errorf("%s exists and is not a socket, refusing to remove it", cfg.Socket)
		}
		if err := os.Remove(cfg.Socket); err != nil {
			return nil, "", err
		}
	}
	old := syscall.Umask(0o117)
	l, err := net.Listen("unix", cfg.Socket)
	syscall.Umask(old)
	if err != nil {
		return nil, "", err
	}
	if err := os.Chmod(cfg.Socket, 0o660); err != nil {
		_ = l.Close()
		return nil, "", err
	}
	if cfg.SocketGroup != "" {
		gid, err := groupID(cfg.SocketGroup)
		if err == nil {
			err = os.Chown(cfg.Socket, -1, gid)
		}
		if err != nil {
			// An unreachable socket is worse than no start: fail loudly.
			_ = l.Close()
			return nil, "", fmt.Errorf("socket group %q: %w", cfg.SocketGroup, err)
		}
	}
	return l, "unix " + cfg.Socket, nil
}

// groupID resolves a group name (or a numeric gid) to its gid.
func groupID(name string) (int, error) {
	if g, err := user.LookupGroup(name); err == nil {
		return strconv.Atoi(g.Gid)
	}
	return strconv.Atoi(name)
}
