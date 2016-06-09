#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_ALIASES_LOADED:-false} && return
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
source "${SCRIPT_DIR}/_functions_system.sh"

#Activate aliases usage in scripts
shopt -s expand_aliases

# Various command aliases
echo_debug "Linux environnement detected : ${LINUX}"
if ${LINUX}; then
  alias display_time='/usr/bin/time -f "[INFO] Return code : %x\n[INFO] Time report (sec) : \t%e real,\t%U user,\t%S system"'
else
  alias display_time='/usr/bin/time'
fi

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_ALIASES_LOADED=true
echo_debug "_functions_aliases.sh Loaded"