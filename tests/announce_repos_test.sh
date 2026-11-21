#!/bin/bash
# After the repositories were fetched, the dashboards are told which ones moved (and only those), so that they recompute
# the branches of these only. Nothing moved: nothing is sent. A failure to tell never fails the run.
#
#   tests/announce_repos_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0
bad() { echo "FAIL: $*"; fail=1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
load() { SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_git.sh"; source "$ROOT/_functions_web.sh"; set -u; }

# a stand-in for curl that records its arguments
mkdir bin
cat > bin/curl <<'STUB'
#!/bin/bash
printf '%s\n' "$@" > "$STUB_OUT"
exit "${STUB_EXIT:-0}"
STUB
chmod +x bin/curl
export STUB_OUT="$W/curl.args"
# a real unix socket (the function only looks that it is one)
python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$W/web.sock"

# the fingerprint changes when a remote branch moves, is added or removed, and not otherwise
git init -q -b main origin && git -C origin -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
git clone -q origin clone
( load
  a="$(git_refs_fingerprint clone)"; b="$(git_refs_fingerprint clone)"
  [ "$a" = "$b" ] || exit 1
  git -C origin -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
  git -C clone remote update --prune >/dev/null 2>&1
  c="$(git_refs_fingerprint clone)"; [ "$a" != "$c" ] || exit 2
  git -C origin branch feature/x
  git -C clone remote update --prune >/dev/null 2>&1
  d="$(git_refs_fingerprint clone)"; [ "$c" != "$d" ] || exit 3
  git -C origin branch -D feature/x >/dev/null
  git -C clone remote update --prune >/dev/null 2>&1
  e="$(git_refs_fingerprint clone)"; [ "$d" != "$e" ] || exit 4 ) || bad "fingerprint (step $?)"

# repositories marked from parallel jobs are collected once each
( load
  _GIT_CHANGED_FILE="$W/changed"; : > "$_GIT_CHANGED_FILE"
  ( git_mark_repo_changed addons-a ) & ( git_mark_repo_changed addons-b ) & ( git_mark_repo_changed addons-a ) & wait
  [ "$(sort -u "$_GIT_CHANGED_FILE" | tr '\n' ' ')" = "addons-a addons-b " ] ) || bad "marks from parallel jobs"

# the announcement: one repos= per repository, over the socket
( load; PATH="$W/bin:$PATH"; ADT_WEB_SOCKET="$W/web.sock"; ADT_WEB_SERVICE=adt-web
  GIT_REPOS_CHANGED="addons-a addons-b "
  do_announce_repositories_updated >/dev/null
  args="$(tr '\n' ' ' < "$STUB_OUT")"
  case "$args" in *"--unix-socket $W/web.sock"*"repos=addons-a"*"repos=addons-b"*"http://localhost/internal/refresh"*) ;; *) echo "args: $args"; exit 1;; esac ) || bad "announcement arguments"

# nothing moved: nothing is sent
rm -f "$STUB_OUT"
( load; PATH="$W/bin:$PATH"; ADT_WEB_SOCKET="$W/web.sock"; GIT_REPOS_CHANGED=" "; do_announce_repositories_updated >/dev/null )
[ ! -e "$STUB_OUT" ] || bad "something was sent although nothing moved"

# no socket (development mode): nothing is sent, no failure
( load; PATH="$W/bin:$PATH"; ADT_WEB_SOCKET="$W/none.sock"; GIT_REPOS_CHANGED="addons-a"; do_announce_repositories_updated >/dev/null ) || bad "failed without a socket"
[ ! -e "$STUB_OUT" ] || bad "something was sent without a socket"

# a failing call never fails the run
( load; PATH="$W/bin:$PATH"; STUB_EXIT=22; export STUB_EXIT; ADT_WEB_SOCKET="$W/web.sock"; ADT_WEB_SERVICE=adt-web
  GIT_REPOS_CHANGED="addons-a"; do_announce_repositories_updated >/dev/null 2>&1 ) || bad "a failed notification failed the run"

[ "$fail" -eq 0 ] && echo "announce repositories: ok" || { echo "announce repositories: FAILED"; exit 1; }
