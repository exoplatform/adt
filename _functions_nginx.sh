#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_NGINX_LOADED:-false} && return
set -u

if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_files.sh"

# #############################################################################
# Nginx / TLS functions
#
# Selects the effective TLS certificate files for the current instance and
# validates their presence. The nginx.conf itself is rendered by
# _functions_compose.sh; this module handles cert resolution.
# #############################################################################

# Resolve the effective INSTANCE_SSL_* cert files based on INSTANCE_DOMAIN.
# Mirrors v1 logic:
#  - INSTANCE_DOMAIN auto-detected from ACCEPTANCE_HOST when not set
#  - meeds.io domain -> MEEDSIO_SSL_* override
#  - otherwise       -> ADT_SSL_* (global default)
# Per-instance INSTANCE_SSL_* (set explicitly) always win.
resolve_instance_certs() {
  # Auto-detect domain from ACCEPTANCE_HOST (second+third labels, e.g. exoplatform.org)
  if [ -z "${INSTANCE_DOMAIN:-}" ]; then
    env_var "INSTANCE_DOMAIN" "$(echo ${ACCEPTANCE_HOST} | cut -d'.' -f2,3)"
  fi

  # Default to global ADT_SSL_*
  configurable_env_var "INSTANCE_SSL_CERTIFICATE_FILE"      "${ADT_SSL_CERTIFICATE_FILE}"
  configurable_env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${ADT_SSL_CERTIFICATE_KEY_FILE}"
  configurable_env_var "INSTANCE_SSL_CERTIFICATE_CHAIN_FILE" "${ADT_SSL_CERTIFICATE_CHAIN_FILE}"

  # meeds.io domain override
  case "${INSTANCE_DOMAIN}" in
    meeds.io)
      if [ -n "${MEEDSIO_SSL_CERTIFICATE_FILE:-}" ]; then
        env_var "INSTANCE_SSL_CERTIFICATE_FILE"      "${MEEDSIO_SSL_CERTIFICATE_FILE}"
        env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${MEEDSIO_SSL_CERTIFICATE_KEY_FILE}"
        env_var "INSTANCE_SSL_CERTIFICATE_CHAIN_FILE" "${MEEDSIO_SSL_CERTIFICATE_CHAIN_FILE}"
      fi
      ;;
  esac
}

# Validate that the effective cert files exist (when TLS is expected).
validate_instance_certs() {
  if [ -z "${INSTANCE_SSL_CERTIFICATE_FILE:-}" ] || [ -z "${INSTANCE_SSL_CERTIFICATE_KEY_FILE:-}" ]; then
    echo_error "No TLS certificate configured for ${DEPLOYMENT_EXT_HOST}."
    echo_error "Set ADT_SSL_CERTIFICATE_FILE/_KEY_FILE (and optionally _CHAIN_FILE) in /etc/default/adt or \$HOME/.adtrc"
    echo_error "or MEEDSIO_SSL_* for *.meeds.io instances."
    exit 1
  fi
  if [ ! -f "${INSTANCE_SSL_CERTIFICATE_FILE}" ] || [ ! -f "${INSTANCE_SSL_CERTIFICATE_KEY_FILE}" ]; then
    echo_error "TLS certificate file or key file is missing:"
    echo_error "  cert: ${INSTANCE_SSL_CERTIFICATE_FILE}"
    echo_error "  key:  ${INSTANCE_SSL_CERTIFICATE_KEY_FILE}"
    exit 1
  fi
  if [ -n "${INSTANCE_SSL_CERTIFICATE_CHAIN_FILE:-}" ] && [ ! -f "${INSTANCE_SSL_CERTIFICATE_CHAIN_FILE}" ]; then
    echo_error "TLS chain file is missing: ${INSTANCE_SSL_CERTIFICATE_CHAIN_FILE}"
    exit 1
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_NGINX_LOADED=true
echo_debug "_functions_nginx.sh Loaded"
