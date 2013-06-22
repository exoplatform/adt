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

# Clone or update a repository $1 from Github's ${GITHUB_ORGA} organisation into ${SRC_DIR}
# $1 : GitHub repository in format organization:repository
# $2 : Directory where to store repositories
clone_or_fetch_git_repo() {
  local _orga=$(echo $1 | cut -d: -f1)
  local _repo=$(echo $1 | cut -d: -f2)
  local _src_dir=$2
  if [ -d ${_src_dir}/${_repo}.git -a ! -d ${_src_dir}/${_repo}.git/.git ]; then
    echo_info "Remove invalid repository ${_repo} from ${_src_dir} ..."
    rm -rf ${_src_dir}/${_repo}.git
    echo_info "Removal done ..."
  fi
  if [ ! -d ${_src_dir}/${_repo}.git ]; then
    echo_info "Cloning repository ${_repo} into ${_src_dir} ..."
    git clone -v git@github.com:/${_orga}/${_repo}.git ${_src_dir}/${_repo}.git
    echo_info "Clone done ..."
  else
    pushd ${_src_dir}/${_repo}.git > /dev/null 2>&1
    set +e
    status=0
    git remote set-url origin git@github.com:${_orga}/${_repo}.git
    echo_info "Updating repository ${_repo} in ${_src_dir} ..."
    git fetch --progress --prune origin
    status=$?
    set -e
    if [ ${status} -ne 0 ]; then
      popd > /dev/null 2>&1
      echo_info "Remove invalid repository ${_repo} from ${_src_dir} ..."
      rm -rf ${_src_dir}/${_repo}.git
      echo_info "Removal done ..."
      echo_info "Cloning repository ${_repo} into ${_src_dir} ..."
      git clone -v git@github.com:/${_orga}/${_repo}.git ${_src_dir}/${_repo}.git
      echo_info "Clone done ..."
      pushd ${_src_dir}/${_repo}.git > /dev/null 2>&1
      git fetch --progress --prune origin
    fi
    echo_info "Update done ..."
    popd > /dev/null 2>&1
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
    # Initialize sources repositories
    for _repo in ${_repositories}
    do
      clone_or_fetch_git_repo "${_repo}" "${_src_dir}"
    done
    _GIT_REPOS_UPDATED=true
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_GIT_LOADED=true
echo_debug "_functions_git.sh Loaded"