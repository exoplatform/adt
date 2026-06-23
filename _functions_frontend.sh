#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_FRONTEND_LOADED:-false} && return
set -u

if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_files.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"

# #############################################################################
# Frontend / dashboard functions
#
# The dashboard is a PHP app (var/www/) served by a dedicated docker compose
# project (nginx + php-fpm) attached to the reverse_proxy network, registered
# with Traefik as <ACCEPTANCE_HOST> (TCP SNI passthrough). It reads the instance
# deployment descriptors in ADT_CONF_DIR.
# #############################################################################

# Initialize the environment: ensure the frontend network exists, pre-pull base
# images, deploy the dashboard compose project.
do_init() {
  echo_info "Initializing ADT environment ..."

  # Ensure the external reverse_proxy network exists (Traefik is expected to be
  # already running on it, managed by puppet). We only create the network if it
  # is missing so that Traefik doesn't need to restart.
  ensure_frontend_network

  # Deploy the dashboard
  do_deploy_dashboard

  echo_info "ADT environment initialized."
  echo_info "Dashboard: ${ACCEPTANCE_SCHEME}://${ACCEPTANCE_HOST}"
}

# Deploy (or reconfigure) the dashboard compose project.
do_deploy_dashboard() {
  local _dir="${PROJECTS_DIR}/dashboard"
  mkdir -p "${_dir}"

  echo_info "Rendering dashboard compose project ..."

  # Resolve dashboard certs (uses the global ADT_SSL_* for the acceptance host)
  env_var "INSTANCE_DOMAIN" "$(echo ${ACCEPTANCE_HOST} | cut -d'.' -f2,3)"
  configurable_env_var "INSTANCE_SSL_CERTIFICATE_FILE"      "${ADT_SSL_CERTIFICATE_FILE}"
  configurable_env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${ADT_SSL_CERTIFICATE_KEY_FILE}"
  configurable_env_var "INSTANCE_SSL_CERTIFICATE_CHAIN_FILE" "${ADT_SSL_CERTIFICATE_CHAIN_FILE}"
  case "${INSTANCE_DOMAIN}" in
    meeds.io)
      if [ -n "${MEEDSIO_SSL_CERTIFICATE_FILE:-}" ]; then
        env_var "INSTANCE_SSL_CERTIFICATE_FILE"      "${MEEDSIO_SSL_CERTIFICATE_FILE}"
        env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${MEEDSIO_SSL_CERTIFICATE_KEY_FILE}"
        env_var "INSTANCE_SSL_CERTIFICATE_CHAIN_FILE" "${MEEDSIO_SSL_CERTIFICATE_CHAIN_FILE}"
      fi
      ;;
  esac

  env_var "DASHBOARD_EXT_HOST" "${ACCEPTANCE_HOST}"
  env_var "DASHBOARD_PROJECT" "adt-dashboard"
  env_var "ADT_VAR_WWW" "${SCRIPT_DIR}/var/www"

  evaluate_file_content "${ETC_DIR}/dashboard/docker-compose.yml.j2" \
    "${_dir}/docker-compose.yml"
  evaluate_file_content "${ETC_DIR}/dashboard/nginx.conf.j2" \
    "${_dir}/nginx.conf"

  echo_info "Starting dashboard compose project ..."
  $(compose_cmd "${_dir}") up -d --pull=always --force-recreate
  echo_info "Dashboard started."
}

# Start a local PHP built-in server (dev mode, for frontend hacking).
do_load_php_server() {
  echo_info "Starting PHP built-in server on ${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT} ..."
  if ! which php &>/dev/null; then
    echo_error "php is not installed. Install PHP >= 7.4 to use the dev web-server."
    exit 1
  fi
  php -S ${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT} -t "${SCRIPT_DIR}/var/www" "${SCRIPT_DIR}/var/www/router.php"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_FRONTEND_LOADED=true
echo_debug "_functions_frontend.sh Loaded"
