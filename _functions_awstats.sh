#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_AWSTATS_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"

# Generate AWStats data for a given domain
# $1 : Domain
# $2 : Dev Mode (warning message instead of error)
do_generate_awstats(){
  local _domain=$1
  shift
  local _dev_mode=$1
  shift
  if ! $_dev_mode; then
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