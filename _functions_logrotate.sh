#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_LOGROTATE_LOADED:-false} && return
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