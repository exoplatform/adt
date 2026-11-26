#!/bin/bash -e


# Load local config from $HOME/.adtrc
[ -e "$HOME/.adtrc" ] && source $HOME/.adtrc

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

# Load shared functions
source "${SCRIPT_DIR}/_functions_core.sh"

env_var "ADT_DEV_MODE" true

function test-adt() {
  env_var "PRODUCT_NAME" $1
  env_var "PRODUCT_VERSION" $2
  env_var "DEPLOYMENT_PORT_PREFIX" $3
  echo_info "# #######################################################################"
  echo_info "#"
  echo_info "# Testing $PRODUCT_NAME $PRODUCT_VERSION"
  echo_info "#"
  echo_info "# #######################################################################"
  echo_info "#"
  echo_info "#"
  ./adt.sh deploy
  ./adt.sh start
  open -g http://localhost:${DEPLOYMENT_PORT_PREFIX}01
  sleep 30
  ./adt.sh stop
}

test-adt meeds  7.3.x-SNAPSHOT 408
test-adt plfcom 7.3.x-SNAPSHOT 400

if [ -n "${REPOSITORY_USERNAME:-}" ] && [ -n "${REPOSITORY_PASSWORD:-}" ]; then
  # Private distribution: needs credentials (REPOSITORY_USERNAME / REPOSITORY_PASSWORD in ~/.adtrc)
  test-adt plfent 7.3.x-SNAPSHOT 402
else
  echo_warn "REPOSITORY_USERNAME / REPOSITORY_PASSWORD not set: plfent is not tested"
fi

./adt.sh list
