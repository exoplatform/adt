#!/bin/bash -eu

# ADT v2 integration tests
#
# Prerequisites:
#   - Docker accessible (user in docker group)
#   - yq, jq in PATH
#   - A self-signed cert for testing (this script generates one)
#
# Usage:
#   ./integration-tests.sh

SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load local config from $HOME/.adtrc
[ -e "$HOME/.adtrc" ] && source "$HOME/.adtrc"

source "${SCRIPT_DIR}/_functions_core.sh"

env_var "ADT_DEV_MODE" true
env_var "ADT_DATA" "/tmp/adt-inttests"
export ADT_DATA

# Test workspace
rm -rf ${ADT_DATA}
mkdir -p ${ADT_DATA}

# Generate a self-signed cert for testing
CERT_DIR="${ADT_DATA}/certs"
mkdir -p ${CERT_DIR}
openssl req -x509 -newkey rsa:2048 -keyout "${CERT_DIR}/key.pem" -out "${CERT_DIR}/cert.pem" \
  -days 1 -nodes -subj "/CN=*.acceptance.exoplatform.org" 2>/dev/null

export DEPLOYMENT_FRONTEND_NETWORK=reverse_proxy
export ADT_SSL_CERTIFICATE_FILE="${CERT_DIR}/cert.pem"
export ADT_SSL_CERTIFICATE_KEY_FILE="${CERT_DIR}/key.pem"
export ADT_SSL_CERTIFICATE_CHAIN_FILE=""
export DEPLOYMENT_START_TIMEOUT=5

# Ensure the network exists
${DOCKER_CMD:-docker} network create ${DEPLOYMENT_FRONTEND_NETWORK} 2>/dev/null || true

PASS=0
FAIL=0

# test_instance <product> <version> [db_type]
test_instance() {
  local _product=$1
  local _version=$2
  local _db=${3:-postgres}
  local _id="itest"

  echo_info ""
  echo_info "# #######################################################################"
  echo_info "# Testing ${_product} ${_version} on ${_db}"
  echo_info "# #######################################################################"

  export PRODUCT_NAME=${_product}
  export PRODUCT_VERSION=${_version}
  export INSTANCE_ID=${_id}
  export DEPLOYMENT_DB_TYPE=${_db}

  echo_info "-- Deploy --"
  if ${SCRIPT_DIR}/adt.sh deploy 2>&1 | grep -q "deployed"; then
    echo_info "PASS: deploy"
    PASS=$((PASS + 1))
  else
    echo_error "FAIL: deploy"
    FAIL=$((FAIL + 1))
    return 1
  fi

  echo_info "-- List --"
  if ${SCRIPT_DIR}/adt.sh list 2>&1 | grep -q "${_product}.*${_version}"; then
    echo_info "PASS: list"
    PASS=$((PASS + 1))
  else
    echo_error "FAIL: list"
    FAIL=$((FAIL + 1))
  fi

  echo_info "-- Stop --"
  if ${SCRIPT_DIR}/adt.sh stop 2>&1 | grep -q "stopped"; then
    echo_info "PASS: stop"
    PASS=$((PASS + 1))
  else
    echo_error "FAIL: stop"
    FAIL=$((FAIL + 1))
  fi

  echo_info "-- Start --"
  if ${SCRIPT_DIR}/adt.sh start 2>&1 | grep -q "started"; then
    echo_info "PASS: start"
    PASS=$((PASS + 1))
  else
    echo_error "FAIL: start"
    FAIL=$((FAIL + 1))
  fi

  echo_info "-- Dump dataset --"
  if ${SCRIPT_DIR}/adt.sh dump-dataset 2>&1 | grep -q "dumped"; then
    echo_info "PASS: dump-dataset"
    PASS=$((PASS + 1))
  else
    echo_error "FAIL: dump-dataset"
    FAIL=$((FAIL + 1))
  fi

  echo_info "-- Undeploy --"
  if ${SCRIPT_DIR}/adt.sh undeploy 2>&1 | grep -q "undeployed"; then
    echo_info "PASS: undeploy"
    PASS=$((PASS + 1))
  else
    echo_error "FAIL: undeploy"
    FAIL=$((FAIL + 1))
  fi
}

echo_info "# ======================================================================="
echo_info "# ADT v2 Integration Tests"
echo_info "# ======================================================================="

# Init (deploys dashboard)
echo_info "-- Init --"
if ${SCRIPT_DIR}/adt.sh init 2>&1 | grep -q "initialized"; then
  echo_info "PASS: init"
  PASS=$((PASS + 1))
else
  echo_error "FAIL: init"
  FAIL=$((FAIL + 1))
fi

# Meeds on PostgreSQL
test_instance meeds 7.2.0-SNAPSHOT postgres

# Meeds on MySQL
test_instance meeds 7.2.0-SNAPSHOT mysql

# eXo Community on PostgreSQL
test_instance plfcom develop postgres

# eXo Enterprise on MySQL (with dummy license)
export EXO_LICENSE_FILE="${CERT_DIR}/cert.pem"  # reuse as dummy license
test_instance plfent 7.2.0 mysql
unset EXO_LICENSE_FILE

# List all
echo_info "-- Final list --"
${SCRIPT_DIR}/adt.sh list

# Cleanup dashboard
echo_info "-- Cleanup --"
${DOCKER_CMD:-docker} compose -f ${ADT_DATA}/projects/dashboard/docker-compose.yml down -v 2>/dev/null || true
${DOCKER_CMD:-docker} network rm ${DEPLOYMENT_FRONTEND_NETWORK} 2>/dev/null || true
rm -rf ${ADT_DATA}

echo_info ""
echo_info "# ======================================================================="
echo_info "# Results: ${PASS} passed, ${FAIL} failed"
echo_info "# ======================================================================="

exit ${FAIL}
