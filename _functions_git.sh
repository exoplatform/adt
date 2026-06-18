#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_GIT_LOADED:-false} && return
set -u

if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"

# #############################################################################
# Git functions (for the dashboard feature-branch scanning)
# #############################################################################

# Clone or fetch a list of GitHub repos into bare clones for branch scanning.
# $1 : offline mode (true|false) - when true, only fetch existing clones
# $2 : target directory
# $3 : space separated list of "org:repo" entries
clone_or_fetch_git_repos() {
  local _offline=$1
  local _dir=$2
  local _repos=$3
  mkdir -p "${_dir}"

  for _repo in ${_repos}; do
    local _org=$(echo ${_repo} | cut -d':' -f1)
    local _name=$(echo ${_repo} | cut -d':' -f2)
    local _url="https://github.com/${_org}/${_name}.git"
    local _clone="${_dir}/${_name}.git"

    if [ -d "${_clone}" ]; then
      if ! ${_offline}; then
        echo_info "Fetching ${_org}/${_name} ..."
        git -C "${_clone}" fetch --prune --quiet origin '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' 2>/dev/null || \
          echo_warn "Could not fetch ${_org}/${_name} (network?)"
      fi
    else
      if ${_offline}; then
        echo_warn "Offline mode: skipping clone of ${_org}/${_name}"
      else
        echo_info "Cloning ${_org}/${_name} ..."
        git clone --bare --quiet "${_url}" "${_clone}" || echo_warn "Could not clone ${_org}/${_name}"
      fi
    fi
  done
  echo_info "Git repositories updated in ${_dir}"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_GIT_LOADED=true
echo_debug "_functions_git.sh Loaded"
