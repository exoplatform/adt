#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_GIT_LOADED:-false} && return
set -u

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

# #############################################################################
# Load shared functions
# #############################################################################
source "${SCRIPT_DIR}/_functions_core.sh"

# The repositories (their names) whose remote branches moved during the last clone_or_fetch_git_repos of this run, separated by spaces:
# what the dashboards are told, so that only these are recomputed. Empty when nothing moved (or nothing was fetched).
GIT_REPOS_CHANGED=""

# A fingerprint of the remote branches of the clone $1 (name and commit of each): it changes when a fetch moved, added or removed one
git_refs_fingerprint() {
  git -C "$1" for-each-ref --format='%(refname) %(objectname)' refs/remotes 2>/dev/null | sha1sum | cut -d' ' -f1
}

# Says that the repository $1 changed: the jobs of clone_or_fetch_git_repos run in parallel, each in a subshell, hence a file
git_mark_repo_changed() {
  [ -n "${_GIT_CHANGED_FILE:-}" ] && echo "$1" >> "${_GIT_CHANGED_FILE}"
  return 0
}

# Clone or update a repository $1 from Github's ${GITHUB_ORGA} organisation into ${SRC_DIR}
# $1 : GitHub repository in format organization:repository
# $2 : Directory where to store repositories
clone_or_fetch_git_repo() {
  local _orga=$(echo $1 | cut -d: -f1)
  local _repo=$(echo $1 | cut -d: -f2)
  local _src_dir=$2
  echo_info "Updating repository ${_repo} in ${_src_dir} ..."
  if [ -d ${_src_dir}/${_repo}.git -a ! -d ${_src_dir}/${_repo}.git/.git ]; then
    rm -rf ${_src_dir}/${_repo}.git
  fi
  if [ ! -d ${_src_dir}/${_repo}.git ]; then
    git clone -v git@github.com:${_orga}/${_repo}.git ${_src_dir}/${_repo}.git
    git_mark_repo_changed "${_repo}"
    # Add remote named blessed for exoplatform organization if exists
    if git ls-remote --exit-code git@github.com:exoplatform/${_repo}.git &>/dev/null; then 
      git -C ${_src_dir}/${_repo}.git remote add blessed git@github.com:exoplatform/${_repo}.git  
    fi  
  else
    set +e
    status=0
    git -C ${_src_dir}/${_repo}.git remote set-url origin git@github.com:${_orga}/${_repo}.git
    if git ls-remote --exit-code git@github.com:exoplatform/${_repo}.git &>/dev/null; then 
      if git -C ${_src_dir}/${_repo}.git remote | grep -q blessed; then
        git -C ${_src_dir}/${_repo}.git remote set-url blessed git@github.com:exoplatform/${_repo}.git 
      else 
        git -C ${_src_dir}/${_repo}.git remote add blessed git@github.com:exoplatform/${_repo}.git
      fi
    fi
    local _before _after
    _before="$(git_refs_fingerprint "${_src_dir}/${_repo}.git")"
    set +e
    git -C ${_src_dir}/${_repo}.git remote update --prune >/dev/null
    status=$?
    set -e
    if [ ${status} -ne 0 ]; then
      rm -rf ${_src_dir}/${_repo}.git
      git clone -v git@github.com:${_orga}/${_repo}.git ${_src_dir}/${_repo}.git
      set +e
      git -C ${_src_dir}/${_repo}.git remote update --prune >/dev/null
      _before="" # a new clone: everything is new
    fi
    _after="$(git_refs_fingerprint "${_src_dir}/${_repo}.git")"
    if [ "${_before}" != "${_after}" ]; then
      git_mark_repo_changed "${_repo}"
    fi
  fi
}

# Update all git repositories used by PHP frontend
# $1 : offline ?
# $2 : Directory where to store repositories
# $3 and following : Github repositories in format organization:repository
clone_or_fetch_git_repos() {
  local _offline=$1
  shift
  local _src_dir=$1
  shift
  local _repositories="$@"
  if  ! ${_offline} && ! ${_GIT_REPOS_UPDATED:-false}; then
    _GIT_CHANGED_FILE="$(mktemp)"
    # Initialize sources repositories
    for _repo in ${_repositories}
    do
      clone_or_fetch_git_repo "${_repo}" "${_src_dir}" &
    done
    wait < <(jobs -p)
    # The repositories whose branches moved, once each (the jobs ran in parallel, in subshells: they wrote them in a file)
    GIT_REPOS_CHANGED="$(sort -u "${_GIT_CHANGED_FILE}" | tr '\n' ' ')"
    rm -f "${_GIT_CHANGED_FILE}"
    _GIT_CHANGED_FILE=""
    _GIT_REPOS_UPDATED=true
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_GIT_LOADED=true
echo_debug "_functions_git.sh Loaded"
