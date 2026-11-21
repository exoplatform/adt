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

# Prints "<2.4> <patch>" (for 2.4.66: "2.4 66") for the Apache that serves the instances, or nothing when it cannot be told.
# $1 (optional): the command to ask, instead of looking for apache2 / httpd (tests).
detect_apache_version() {
  local _bin _out
  for _bin in ${1:-apache2 /usr/sbin/apache2 httpd /usr/sbin/httpd}; do
    command -v "${_bin}" >/dev/null 2>&1 || continue
    _out="$("${_bin}" -v 2>/dev/null)" || continue
    if [[ "${_out}" =~ Apache/([0-9]+\.[0-9]+)\.([0-9]+) ]]; then
      echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
      return 0
    fi
  done
  return 0
}

# ADT_APACHE_VERSION and ADT_APACHE_VERSION_MINOR (the patch level: 66 for 2.4.66) are rendered in the Apache configuration, and
# the front-end only asks for upgrade=websocket (the live channel of the pages) from 2.4.47. Nothing sets them on the hosts, so
# they are read from the installed Apache when they are empty; what the environment says is never replaced.
set_apache_version_defaults() {
  local _version _minor
  [ -z "${ADT_APACHE_VERSION:-}" ] || [ -z "${ADT_APACHE_VERSION_MINOR:-}" ] || return 0
  read -r _version _minor <<< "$(detect_apache_version "$@")"
  [ -n "${_minor:-}" ] || return 0
  [ -n "${ADT_APACHE_VERSION:-}" ] || env_var "ADT_APACHE_VERSION" "${_version}"
  [ -n "${ADT_APACHE_VERSION_MINOR:-}" ] || env_var "ADT_APACHE_VERSION_MINOR" "${_minor}"
}

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