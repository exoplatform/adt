#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_APACHE_LOADED:-false} && return
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

# Reload Apache
# $1 : Dev Mode (warning message instead of error)
do_reload_apache(){
  local _dev_mode=$1
  shift
  if ! ${_dev_mode}; then
    if [ -e /usr/sbin/service -a -e /etc/init.d/apache2 ]; then
      echo_info "Reloading Apache server ..."
      sudo /usr/sbin/service apache2 reload
      echo_info "Done."
    else
      echo_error "It is impossible to reload Apache. Did you install Apache2 ?"
    fi
  else
    echo_warn "Development Mode: No Apache server reload."
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_APACHE_LOADED=true
echo_debug "_functions_apache.sh Loaded"