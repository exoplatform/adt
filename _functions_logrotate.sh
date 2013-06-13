#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_LOGROTATE_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"

# Call log rotate with a given configuration file
# $1 : Configuration file path
# $1 : Dev Mode (warning message instead of error)
do_logrotate(){
  local _config_file=$1
  shift
  local _dev_mode=$1
  shift
  if ! ${_dev_mode}; then
    if [ -e /usr/sbin/logrotate ]; then
      echo_info "Rotate logs using configuration ${_config_file} ..."
      sudo /usr/sbin/logrotate -s ${_config_file}.status -f ${_config_file}
      echo_info "Done."
    else
      echo_error "It is impossible to rotate logs using configuration ${_config_file}. Did you install logrotate ?"
    fi
  else
    echo_warn "Development Mode: No rotation of logs using configuration ${_config_file}."
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_LOGROTATE_LOADED=true
echo_debug "_functions_logrorate.sh Loaded"