package gitx

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// logFormat separates the fields with NUL: git prints names as C strings, so no author name or subject can contain it
// (a "|" in a name used to shift the fields).
const logFormat = "%H%x00%T%x00%an%x00%ae%x00%ad%x00%cn%x00%ce%x00%cd%x00%s"

// Repository is a thin wrapper around the git CLI for one working copy.
type Repository struct{ dir string }

// Commit is one parsed "git log" entry.
type Commit struct {
	ID, Tree                                     string
	AuthorName, AuthorEmail, AuthoredDate        string
	CommitterName, CommitterEmail, CommittedDate string
	Message                                      string
}

// LogOptions are the typed options of Repository.Log.
type LogOptions struct {
	Ref      string // validated revision, "" = HEAD
	Since    string // --after=<Since>
	Date     string // --date=<Date>
	Format   string // --format=format:<Format>
	NoMerges bool
	MaxCount int // -<n> when > 0
}

// Open wraps dir. It requires <dir>/.git/HEAD to exist.
func Open(dir string) (*Repository, error) {
	if dir == "" || hasControl(dir) {
		return nil, invalid("directory", dir)
	}
	if _, err := os.Stat(filepath.Join(dir, ".git", "HEAD")); err != nil {
		return nil, fmt.Errorf("%s is not a valid Git repository", dir)
	}
	return &Repository{dir: dir}, nil
}

// OpenSource opens dataDir/sources/<project>.git.
func OpenSource(dataDir, project string) (*Repository, error) {
	p, err := SourcesPath(dataDir, project)
	if err != nil {
		return nil, err
	}
	return Open(p)
}

// Init runs "git init" in dir and returns the wrapper.
func Init(dir string) (*Repository, error) {
	if _, err := run(dir, "init"); err != nil {
		return nil, err
	}
	return Open(dir)
}

// CloneURL runs "git clone <url> <dir>" and returns the wrapper. Only plain network/file URLs are
// accepted (no leading "-", no "ext::" style transports).
func CloneURL(url, dir string) (*Repository, error) {
	if url == "" || url[0] == '-' || hasControl(url) || strings.Contains(url, "::") || dir == "" || dir[0] == '-' || hasControl(dir) {
		return nil, invalid("clone url", url)
	}
	wd, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	if _, err := run(wd, "-c", "protocol.ext.allow=never", "clone", "--", url, dir); err != nil {
		return nil, err
	}
	return Open(dir)
}

// Dir is the repository directory.
func (r *Repository) Dir() string { return r.dir }

// Git runs "git <args...>" in the repository (no shell: args are an argv). The output is trimmed.
// Callers must validate refs/paths that come from outside (ValidRef, ValidPath).
func (r *Repository) Git(args ...string) (string, error) {
	for _, a := range args {
		if strings.IndexByte(a, 0) >= 0 {
			return "", invalid("argument", a)
		}
	}
	return run(r.dir, args...)
}

// Branches returns the names of "git branch <flags>" with whitespace and "*" removed.
func (r *Repository) Branches(flags ...string) ([]string, error) {
	args := []string{"branch"}
	for _, f := range flags {
		if !validOption(f) {
			return nil, invalid("branch option", f)
		}
		args = append(args, f)
	}
	out, err := r.Git(args...)
	if err != nil {
		return nil, err
	}
	var res []string
	for _, l := range strings.Split(out, "\n") {
		l = strings.Map(func(c rune) rune {
			switch c {
			case ' ', '\t', '\n', '\v', '\f', '\r', '*':
				return -1
			}
			return c
		}, l)
		if l != "" && l != "0" { // array_filter
			res = append(res, l)
		}
	}
	return res, nil
}

// CurrentBranch is getCurrentBranch ("" when no branch is current).
func (r *Repository) CurrentBranch() (string, error) {
	out, err := r.Git("branch")
	if err != nil {
		return "", err
	}
	for _, l := range strings.Split(out, "\n") {
		if strings.HasPrefix(l, "*") {
			if len(l) < 2 {
				return "", nil
			}
			return l[2:], nil
		}
	}
	return "", nil
}

// HasBranch is hasBranch.
func (r *Repository) HasBranch(name string) (bool, error) {
	bs, err := r.Branches()
	if err != nil {
		return false, err
	}
	for _, b := range bs {
		if b == name {
			return true, nil
		}
	}
	return false, nil
}

// Tags is getTags.
func (r *Repository) Tags() ([]string, error) {
	out, err := r.Git("tag")
	if err != nil {
		return nil, err
	}
	var res []string
	for _, l := range strings.Split(out, "\n") {
		if l != "" && l != "0" {
			res = append(res, l)
		}
	}
	return res, nil
}

// Commits returns the last n commits.
func (r *Repository) Commits(n int) ([]Commit, error) {
	out, err := r.Git("log", "-n", strconv.Itoa(n), "--date=iso", "--format=format:"+logFormat)
	if err != nil {
		return nil, err
	}
	return parseLogs(out), nil
}

// DifferenceBetweenBranches lists the commits of source that are not in target.
func (r *Repository) DifferenceBetweenBranches(target, source string) ([]Commit, error) {
	if !ValidRef(target) {
		return nil, invalid("ref", target)
	}
	if !ValidRef(source) {
		return nil, invalid("ref", source)
	}
	out, err := r.Git("log", target+".."+source, "--date=iso", "--format=format:"+logFormat)
	if err != nil {
		return nil, err
	}
	return parseLogs(out), nil
}

// parseLogs parses the log output (see logFormat).
func parseLogs(out string) []Commit {
	var cs []Commit
	if out == "" {
		return cs
	}
	for _, l := range strings.Split(out, "\n") {
		f := strings.SplitN(l, "\x00", 9)
		for len(f) < 9 {
			f = append(f, "")
		}
		cs = append(cs, Commit{f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8]})
	}
	return cs
}

// ConfigGet is `git config --get <option>`; ok is false when the option is not set.
func (r *Repository) ConfigGet(option string) (string, bool) {
	if !validConfigKey(option) {
		return "", false
	}
	v, err := r.Git("config", "--get", option)
	if err != nil {
		return "", false
	}
	return v, true
}

// ConfigSet is `git config --local <option> <value>`.
func (r *Repository) ConfigSet(option, value string) error {
	if !validConfigKey(option) {
		return invalid("config option", option)
	}
	_, err := r.Git("config", "--local", option, value)
	return err
}

// ConfigRemove is `git config --local --unset <option>`.
func (r *Repository) ConfigRemove(option string) error {
	if !validConfigKey(option) {
		return invalid("config option", option)
	}
	_, err := r.Git("config", "--local", "--unset", option)
	return err
}

// RemoteOriginURL is `git config --get remote.origin.url` ("" when unset).
func (r *Repository) RemoteOriginURL() string {
	v, _ := r.ConfigGet("remote.origin.url")
	return v
}

// RefExists is `git rev-parse --verify <ref>`.
func (r *Repository) RefExists(ref string) bool {
	if !ValidRef(ref) {
		return false
	}
	_, err := r.Git("rev-parse", "--verify", ref)
	return err == nil
}

// PathExists is `git cat-file -e <ref>:<path>`.
func (r *Repository) PathExists(ref, path string) bool {
	if !ValidRef(ref) || !ValidPath(path) {
		return false
	}
	_, err := r.Git("cat-file", "-e", ref+":"+path)
	return err == nil
}

// Show is `git show <ref>:<path>`.
func (r *Repository) Show(ref, path string) (string, error) {
	if !ValidRef(ref) {
		return "", invalid("ref", ref)
	}
	if !ValidPath(path) {
		return "", invalid("path", path)
	}
	return r.Git("show", ref+":"+path)
}

// Log runs `git log` with typed options.
func (r *Repository) Log(o LogOptions) (string, error) {
	args := []string{"log"}
	if o.Since != "" {
		if hasControl(o.Since) {
			return "", invalid("since", o.Since)
		}
		args = append(args, "--after="+o.Since)
	}
	if o.Date != "" {
		if hasControl(o.Date) {
			return "", invalid("date", o.Date)
		}
		args = append(args, "--date="+o.Date)
	}
	if o.Format != "" {
		args = append(args, "--format=format:"+o.Format)
	}
	if o.NoMerges {
		args = append(args, "--no-merges")
	}
	if o.MaxCount > 0 {
		args = append(args, "-"+strconv.Itoa(o.MaxCount))
	}
	if o.Ref != "" {
		if !ValidRef(o.Ref) {
			return "", invalid("ref", o.Ref)
		}
		args = append(args, o.Ref)
	}
	return r.Git(args...)
}

// CountCommits is the number of lines of `git log from..to --oneline`.
func (r *Repository) CountCommits(from, to string) (int, error) {
	if !ValidRef(from) {
		return 0, invalid("ref", from)
	}
	if !ValidRef(to) {
		return 0, invalid("ref", to)
	}
	out, err := r.Git("log", from+".."+to, "--oneline")
	if err != nil {
		return 0, err
	}
	if out == "" || out == "0" { // empty or "0"
		return 0, nil
	}
	return strings.Count(out, "\n") + 1, nil
}
