#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_UFW_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"

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
  if ! $_dev_mode; then
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
  if ! $_dev_mode; then
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