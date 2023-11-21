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
  echo_info "Updating repository ${_repo} in ${_src_dir} ..."
  if [ -d ${_src_dir}/${_repo}.git -a ! -d ${_src_dir}/${_repo}.git/.git ]; then
    rm -rf ${_src_dir}/${_repo}.git
  fi
  if [ ! -d ${_src_dir}/${_repo}.git ]; then
    git clone -v git@github.com:${_orga}/${_repo}.git ${_src_dir}/${_repo}.git
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
    set +e
    git -C ${_src_dir}/${_repo}.git remote update --prune >/dev/null
    status=$?
    set -e
    if [ ${status} -ne 0 ]; then
      rm -rf ${_src_dir}/${_repo}.git
      git clone -v git@github.com:${_orga}/${_repo}.git ${_src_dir}/${_repo}.git
      set +e
      git -C ${_src_dir}/${_repo}.git remote update --prune >/dev/null
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
    # Initialize sources repositories
    for _repo in ${_repositories}
    do
      clone_or_fetch_git_repo "${_repo}" "${_src_dir}" &
    done
    wait < <(jobs -p)
    _GIT_REPOS_UPDATED=true
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_GIT_LOADED=true
echo_debug "_functions_git.sh Loaded"
