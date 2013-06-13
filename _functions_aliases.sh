#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_ALIASES_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"

#Activate aliases usage in scripts
shopt -s expand_aliases

# Various command aliases
if ${LINUX}; then
  alias display_time='/usr/bin/time -f "[INFO] Return code : %x\n[INFO] Time report (sec) : \t%e real,\t%U user,\t%S system"'
else
  alias display_time='/usr/bin/time'
fi

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_ALIASES_LOADED=true
echo_debug "_functions_aliases.sh Loaded"