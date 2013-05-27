#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_JBOSSEAP_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"
source "./_functions_ufw.sh"

# #############################################################################
# TDB : Use functions that aren't using global vars
# #############################################################################

#
# Function that configure the server for ours needs
#
do_configure_jbosseap_server() {

  echo_info "###### TO BE DONE ######"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_JBOSSEAP_LOADED=true
echo_debug "_functions_jbosseap.sh Loaded"