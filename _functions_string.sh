#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_STRING_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"

# Converts $1 in upper case
toupper() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Converts $1 in lower case
tolower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# $1 : scheme : http, ..
# $2 : host
# $3 : port
# $4 : path
do_build_url() {
  if [ $# -lt 4 ]; then
    echo_error "No enough parameters for function do_build_url !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _scheme="$1";
  shift;
  local _host="$1";
  shift;
  local _port="$1";
  shift;
  local _path="$1";
  shift;

  local _result="${_scheme}://${_host}";
  if [ "$_port" == "80" ]; then
    _result="${_result}${_path}";
  else
    _result="${_result}:${_port}${_path}";
  fi

  echo ${_result}
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_STRING_LOADED=true
echo_debug "_functions_string.sh Loaded"