#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_UFW_LOADED:-false} && return
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

# Open a port in the firewall
# $1 : Port number
# $2 : Port description
# $3 : Dev Mode (warning message instead of error)
do_ufw_open_port(){
  local _port=$1
  shift
  local _description=$1
  shift
  local _dev_mode=$1
  shift
  # Open firewall ports
  if ! ${_dev_mode}; then
    if [ -e /usr/sbin/ufw ]; then
      echo_info "Opening firewall port ${_description} (${_port}) ..."
      sudo /usr/sbin/ufw allow ${_port}
      echo_info "Done."
    else
      echo_error "/usr/sbin/ufw unavailable. Impossible to open port ${_description} (${_port}). Did you install UFW ?"
    fi
  else
    echo_warn "Development Mode: We don't open firewall port ${_description} (${_port})."
  fi
}

# Close a port in the firewall
# $1 : Port number
# $2 : Port description
# $3 : Dev Mode (warning message instead of error)
do_ufw_close_port(){
  local _port=$1
  shift
  local _description=$1
  shift
  local _dev_mode=$1
  shift
  # Close firewall ports
  if ! ${_dev_mode}; then
    if [ -e /usr/sbin/ufw ]; then
      echo_info "Closing firewall port ${_description} (${_port}) ..."
      sudo /usr/sbin/ufw delete allow ${_port}
      echo_info "Done."
    else
      echo_error "/usr/sbin/ufw unavailable. Impossible to close port ${_description} (${_port}). Did you install UFW ?"
    fi
  else
    echo_warn "Development Mode: We don't close firewall port ${_description} (${_port})."
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_UFW_LOADED=true
echo_debug "_functions_ufw.sh Loaded"