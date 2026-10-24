package logview

import (
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

// Log types of the "type" parameter of the viewers.
const (
	TypeInstance = "instance" // application server logs
	TypeApache   = "apache"   // Apache access and error logs
)

// ErrNotAuthorized is returned for every refusal (type, name, location, kind of file): the caller never
// tells the visitor which check failed.
var ErrNotAuthorized = errors.New("not authorized to read this file")

// instanceNames and apacheNames are the file names each type may show (isAuthorizedToReadFile).
var (
	instanceNames = []string{"platform.log", "server.log", "catalina.out"}
	apacheNames   = []string{"access.log", "error.log"}
)

// Policy decides which files the viewers may open: a file is allowed when its type accepts its name, and,
// once every symbolic link is resolved, it is a regular file inside one of the roots of its type.
type Policy struct {
	// Roots maps a type to the directories holding its files.
	Roots map[string][]string
}

// NewPolicy is the policy of an ADT_DATA: Apache logs live in var/log/apache2, the application server logs
// under servers/ (one directory per instance; DEPLOYMENT_LOG_PATH is below it) or in var/log.
func NewPolicy(dataDir string) *Policy {
	return &Policy{Roots: map[string][]string{
		TypeInstance: {filepath.Join(dataDir, "servers"), filepath.Join(dataDir, "var", "log")},
		TypeApache:   {filepath.Join(dataDir, "var", "log", "apache2")},
	}}
}

func nameAllowed(kind, base string) bool {
	var names []string
	switch kind {
	case TypeInstance:
		names = instanceNames
	case TypeApache:
		names = apacheNames
	default:
		return false
	}
	for _, n := range names {
		if strings.HasSuffix(base, n) {
			return true
		}
	}
	return false
}

// within reports whether p is strictly below dir (both clean): the separator matters, /data/logs-evil is not
// below /data/logs.
func within(dir, p string) bool {
	if dir == "/" {
		return p != "/" && strings.HasPrefix(p, "/")
	}
	return strings.HasPrefix(p, dir+string(filepath.Separator))
}

// cleanAbs rejects what is not a clean absolute path: relative, "..", "//", "/./", NUL and other control
// characters, backslashes.
func cleanAbs(path string) bool {
	if path == "" || len(path) > 4096 || !filepath.IsAbs(path) || filepath.Clean(path) != path {
		return false
	}
	for i := 0; i < len(path); i++ {
		if path[i] < 0x20 || path[i] == 0x7f || path[i] == '\\' {
			return false
		}
	}
	return true
}

// resolveIn canonicalizes path (symbolic links resolved) and requires it to be strictly below one of roots.
func resolveIn(roots []string, path string) (string, error) {
	if !cleanAbs(path) {
		return "", ErrNotAuthorized
	}
	real, err := filepath.EvalSymlinks(path)
	if err != nil {
		return "", ErrNotAuthorized
	}
	for _, root := range roots {
		r, err := filepath.EvalSymlinks(root)
		if err != nil {
			continue
		}
		if within(r, real) {
			return real, nil
		}
	}
	return "", ErrNotAuthorized
}

// Resolve checks a requested path of a type and returns its canonical form. It does not open anything.
func (p *Policy) Resolve(kind, path string) (string, error) {
	if !cleanAbs(path) || !nameAllowed(kind, filepath.Base(path)) {
		return "", ErrNotAuthorized
	}
	real, err := resolveIn(p.Roots[kind], path)
	if err != nil {
		return "", err
	}
	// The link target must itself be a log of that type, not only the link name
	if !nameAllowed(kind, filepath.Base(real)) {
		return "", ErrNotAuthorized
	}
	return real, nil
}

// Authorized also requires the file to exist and to be a regular file.
func (p *Policy) Authorized(kind, path string) bool {
	f, err := p.Open(kind, path)
	if err != nil {
		return false
	}
	_ = f.Close()
	return true
}

// Open returns the file for reading when the policy allows it, see OpenIn.
func (p *Policy) Open(kind, path string) (*os.File, error) {
	return open(path, func(q string) (string, error) { return p.Resolve(kind, q) })
}

// OpenIn opens a regular file below one of roots, whatever its name (for pages that list a directory).
func OpenIn(roots []string, path string) (*os.File, error) {
	return open(path, func(q string) (string, error) { return resolveIn(roots, q) })
}

// open opens the canonical path without following a link (O_NOFOLLOW) and without blocking on a FIFO, and
// checks the open file again: it must be a regular file, the same one the path resolved to, and still
// located where the policy allows (a path component swapped for a link between the check and the open is
// caught here).
func open(path string, resolve func(string) (string, error)) (*os.File, error) {
	real, err := resolve(path)
	if err != nil {
		return nil, err
	}
	f, err := os.OpenFile(real, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK|syscall.O_CLOEXEC, 0)
	if err != nil {
		return nil, ErrNotAuthorized
	}
	fi, err := f.Stat()
	if err != nil || !fi.Mode().IsRegular() {
		_ = f.Close()
		return nil, ErrNotAuthorized
	}
	if lfi, err := os.Lstat(real); err != nil || !os.SameFile(fi, lfi) {
		_ = f.Close()
		return nil, ErrNotAuthorized
	}
	// Where the descriptor really points (Linux); skipped when /proc is not available
	if cur, err := os.Readlink("/proc/self/fd/" + strconv.Itoa(int(f.Fd()))); err == nil {
		if _, err := resolve(cur); err != nil {
			_ = f.Close()
			return nil, ErrNotAuthorized
		}
	}
	return f, nil
}
