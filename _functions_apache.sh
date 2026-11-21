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

# Prints "<2.4> <patch>" (for 2.4.66: "2.4 66") from a version text ("Apache/2.4.66 (Ubuntu)", "2.4.66-1ubuntu1", "2.4.37"), or nothing.
apache_version_from_text() {
  if [[ "$1" =~ (^|[^0-9.])([0-9]+\.[0-9]+)\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
  fi
}

# Prints "<2.4> <patch>" of the installed Apache package (dpkg on Debian and Ubuntu, rpm elsewhere): it needs neither the binary in the
# PATH of the user nor the right to run it, which the Jenkins agents may lack.
detect_apache_version_from_package() {
  local _out
  if command -v dpkg-query >/dev/null 2>&1; then
    _out="$(dpkg-query -W -f='${Version}' apache2 2>/dev/null)" && [ -n "${_out}" ] && { apache_version_from_text "${_out}"; return 0; }
  fi
  if command -v rpm >/dev/null 2>&1; then
    _out="$(rpm -q --qf '%{VERSION}' httpd 2>/dev/null)" && [ -n "${_out}" ] && { apache_version_from_text "${_out}"; return 0; }
  fi
  return 0
}

# Prints "<2.4> <patch>" for the Apache that serves the instances, or nothing when it cannot be told: the binary first (apache2,
# apache2ctl, httpd: -v), then the installed package.
# $1 (optional): the commands to ask, instead of the usual ones (tests); the package is not asked then.
detect_apache_version() {
  local _bin _out _found
  for _bin in ${1:-apache2 /usr/sbin/apache2 apache2ctl /usr/sbin/apache2ctl apachectl /usr/sbin/apachectl httpd /usr/sbin/httpd}; do
    command -v "${_bin}" >/dev/null 2>&1 || continue
    _out="$("${_bin}" -v 2>/dev/null)" || continue
    _found="$(apache_version_from_text "${_out##*Apache/}")"
    if [[ "${_out}" == *"Apache/"* ]] && [ -n "${_found}" ]; then
      echo "${_found}"
      return 0
    fi
  done
  [ -n "${1:-}" ] || detect_apache_version_from_package
  return 0
}

# ADT_APACHE_VERSION and ADT_APACHE_VERSION_MINOR (the patch level: 66 for 2.4.66) are rendered in the Apache configuration, and
# the front-end only asks for upgrade=websocket (the live channel of the pages) from 2.4.47. Nothing sets them on the hosts, so
# they are read from the installed Apache when they are empty; what the environment says is never replaced.
set_apache_version_defaults() {
  local _version _minor
  if [ -z "${ADT_APACHE_VERSION:-}" ] || [ -z "${ADT_APACHE_VERSION_MINOR:-}" ]; then
    read -r _version _minor <<< "$(detect_apache_version "$@")"
    if [ -n "${_minor:-}" ]; then
      [ -n "${ADT_APACHE_VERSION:-}" ] || env_var "ADT_APACHE_VERSION" "${_version}"
      [ -n "${ADT_APACHE_VERSION_MINOR:-}" ] || env_var "ADT_APACHE_VERSION_MINOR" "${_minor}"
    fi
  fi
  # Said in the log of the job: the front-end silently went without the live channel when the version was unknown
  if [ -z "${ADT_APACHE_VERSION_MINOR:-}" ]; then
    echo_warn "The version of Apache is unknown (apache2 -v and httpd -v gave nothing, ADT_APACHE_VERSION_MINOR is not set): the live channel (WebSocket) is left out of the front-end configuration. Set ADT_APACHE_VERSION and ADT_APACHE_VERSION_MINOR to enable it."
  elif [ "${ADT_APACHE_VERSION_MINOR##*.}" -ge 47 ] 2>/dev/null; then
    echo_info "Apache ${ADT_APACHE_VERSION:-2.4}.${ADT_APACHE_VERSION_MINOR##*.}: the live channel (WebSocket) is enabled in the front-end configuration."
  else
    echo_info "Apache ${ADT_APACHE_VERSION:-2.4}.${ADT_APACHE_VERSION_MINOR##*.}: older than 2.4.47, the live channel (WebSocket) is left out of the front-end configuration."
  fi
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