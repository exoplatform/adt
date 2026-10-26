// Package gitx runs git for the dashboard: a repository wrapper and the repository helpers.
//
// Nothing here goes through a shell: every git invocation is
// exec.CommandContext with an argv, a timeout, GIT_TERMINAL_PROMPT=0 and a bounded output. Names that
// reach git (repositories, refs, paths) are validated first (see ValidRepoName, ValidRef, ValidPath).
//
// # API
//
// Repository list and module metadata:
//
//	type Repo struct{ Name, Label string }              // one tracked repository
//	func Repositories() []Repo                         // in display order
//	func RepositoryNames() []string                    // names of the repositories, in display order
//	func RepositoryLabel(name string) (label string, ok bool)
//	func ModuleCiPrefix(item string) string            // "" when the module has no prefix
//	func GitDirectoriesList(dir string) ([]string, error) // entries containing ".git" at index > 0
//	func DirectoryList(dir string) ([]string, error)       // all entries except "." and ".."
//	func BaseBranchToCompareWith(org, repo, branch string) string // always "develop" (translation branches)
//	func FeatureBases(dataDir string) map[string]string  // conf/feature-bases/<key>.base, by FeatureBaseKey
//	func FeatureBase(bases map[string]string, name string) string // "develop" unless set
//	func KnownBaseBranch(dataDir string, projects []string, base string) bool
//
// Names and validation:
//
//	func ValidRepoName(name string) bool   // [A-Za-z0-9][A-Za-z0-9._-]*, no ".."
//	func ValidRef(ref string) bool         // safe git ref/revision: no leading "-", no control, space, :?*[\ ;&|$()`<>"'!{}, no "..", ~N/^N only as a suffix
//	func ValidPath(p string) bool          // relative path inside a tree: no leading "/", no ".." segment, no control chars
//	func SourcesPath(dataDir, project string) (string, error) // dataDir/sources/<project>.git, validated
//
// The repository wrapper. Open fails when <dir>/.git/HEAD is missing:
//
//	type Repository struct{ ... }
//	func Open(dir string) (*Repository, error)
//	func OpenSource(dataDir, project string) (*Repository, error) // Open(SourcesPath(...))
//	func Init(dir string) (*Repository, error)                    // git init
//	func CloneURL(url, dir string) (*Repository, error)           // git clone
//	func (r *Repository) Dir() string
//	func (r *Repository) Git(args ...string) (string, error)      // run "git <args>", output trimmed
//	func (r *Repository) Branches(flags ...string) ([]string, error)     // git branch <flags>
//	func (r *Repository) CurrentBranch() (string, error)
//	func (r *Repository) HasBranch(name string) (bool, error)
//	func (r *Repository) Tags() ([]string, error)
//	func (r *Repository) Commits(n int) ([]Commit, error)                         // the last n commits
//	func (r *Repository) DifferenceBetweenBranches(target, source string) ([]Commit, error)
//	func (r *Repository) ConfigGet(option string) (string, bool)      // `git config --get`; ok=false when unset
//	func (r *Repository) ConfigSet(option, value string) error
//	func (r *Repository) ConfigRemove(option string) error
//	func (r *Repository) RemoteOriginURL() string                     // "" when no remote.origin.url
//	func (r *Repository) RefExists(ref string) bool                   // git rev-parse --verify <ref>
//	func (r *Repository) PathExists(ref, path string) bool            // git cat-file -e <ref>:<path>
//	func (r *Repository) Show(ref, path string) (string, error)       // git show <ref>:<path>
//	func (r *Repository) Log(o LogOptions) (string, error)            // git log with typed options
//	func (r *Repository) CountCommits(from, to string) (int, error)   // lines of `git log from..to --oneline`
//
//	type Commit struct {
//		ID, Tree                          string
//		AuthorName, AuthorEmail, AuthoredDate string
//		CommitterName, CommitterEmail, CommittedDate string
//		Message                           string
//	}
//	type LogOptions struct {
//		Ref       string // validated revision, "" = HEAD
//		Since     string // --after=<Since>
//		Date      string // --date=<Date>
//		Format    string // --format=format:<Format>
//		NoMerges  bool
//		MaxCount  int    // -<n> when > 0
//	}
//
// An error from Git is a *GitError (Args, ExitCode, Stderr); errors.Is(err, ErrInvalid) is true for
// rejected names/arguments, ErrOutputTooLarge for a bounded-output overflow, and context.DeadlineExceeded
// for a timeout. Package knobs: GitExecutable, Timeout, MaxOutput.
//
// Branch listings. Results are refreshed every 5 minutes (cache keys: dataDir + projects); an out-of-date
// listing keeps being served while a background refresh runs, and only the very first computation is waited
// for (Warm does it at startup, cache.InvalidateAll forces a refresh). The slice order is
// the display order (branch names sorted with strcasecmp, projects in input order). A project whose
// repository is missing or fails is skipped.
//
//	type BranchProject struct {
//		Project                               string
//		HTTPURL, HTTPURLBehind, HTTPURLAhead  string
//		BehindCommits, AheadCommits           int
//	}
//	type BranchGroup struct {
//		Name     string // branch name without the "feature/" or "integration/" prefix
//		Projects []BranchProject
//	}
//	func FeatureBranches(dataDir string, projects []string) []BranchGroup
//	func TranslationBranches(dataDir string, projects []string) []BranchGroup
//	func Warm(dataDir string)                                       // computes the listings now
package gitx
