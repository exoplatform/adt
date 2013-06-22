#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_AWSTATS_LOADED:-false} && return
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

# Generate AWStats data for a given domain
# $1 : Domain
# $2 : Dev Mode (warning message instead of error)
do_generate_awstats(){
  local _domain=$1
  shift
  local _dev_mode=$1
  shift
  if ! ${_dev_mode}; then
    if [ -e /usr/lib/cgi-bin/awstats.pl ]; then
      echo_info "Generating AWStats data for domain ${_domain} ..."
      sudo /usr/lib/cgi-bin/awstats.pl -config=${_domain} -update
      echo_info "Done."
    else
      echo_error "It is impossible to generate AWStats data for domain ${_domain}. Did you install AWStats ?"
    fi
  else
    echo_warn "Development Mode: No AWStats data generation for domain ${_domain}."
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_AWSTATS_LOADED=true
echo_debug "_functions_awstats.sh Loaded"