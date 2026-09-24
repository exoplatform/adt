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

# logrotate run through sudo ignores config files not owned by root or
# writable by group/others (exit status 1 since logrotate 3.22 / Ubuntu 26.04)
# $1 : Configuration file path
secure_logrotate_config(){
  local _config_file=$1
  local _root_copy=${_config_file}.root
  chmod 400 ${_config_file}
  if [ ${EUID} -eq 0 ]; then
    return 0
  fi
  # /bin/cp is allowed by sudoers: copy becomes root owned with mode 400
  if sudo -n /bin/cp -f ${_config_file} ${_root_copy}; then
    mv -f ${_root_copy} ${_config_file}
  else
    echo_warn "Cannot install ${_config_file} as root, logrotate may ignore it."
  fi
}

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
      secure_logrotate_config ${_config_file}
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