#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_SYSTEM_LOADED:-false} && return
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
source "${SCRIPT_DIR}/_functions_string.sh"

# #################
# System functions
# #################

# Get informations about system
loadSystemInfo() {
  # OS specific support. $var _must_ be set to either true or false.
  CYGWIN=false
  LINUX=false;
  OS400=false
  DARWIN=false
  case "$(uname)" in
    CYGWIN*) CYGWIN=true ;;
    Linux*) LINUX=true ;;
    OS400*) OS400=true ;;
    Darwin*) DARWIN=true ;;
  esac

  OS=$(tolower "$(uname)")
  KERNEL=$(uname -r)
  MACH=$(uname -m)

  if [ "${OS}" == "windowsnt" ]; then
    OS=windows
  elif [ "${OS}" == "darwin" ]; then
    OS=mac
  else
    OS=$(uname)
    OS=$(tolower "${OS}")
  fi
  echo_debug "OS=${OS} KERNEL=${KERNEL} MACH=${MACH}"
}

# init system informations as soon this lib is loaded
loadSystemInfo

if [ "${OS}" == "mac" ]; then
    # to point to the OS X original binary
    export CMD_SED="/usr/bin/sed"
    export CMD_LS="/bin/ls"
else
    export CMD_SED="sed"
    export CMD_LS="ls"
fi

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_SYSTEM_LOADED=true
echo_debug "_functions_system.sh Loaded"
