#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_COMPOSE_LOADED:-false} && return
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
# Compose rendering functions
#
# Renders the master docker-compose.yml.j2 + per-instance configs (nginx.conf,
# exo.properties, db configs, ...) into PROJECT_DIR for the current instance.
# #############################################################################

# Render all instance files into the project directory.
do_render_instance() {
  env_var "PROJECT_DIR" "${PROJECTS_DIR}/${INSTANCE_KEY}"
  mkdir -p "${PROJECT_DIR}"

  echo_info "Rendering instance configs into ${PROJECT_DIR} ..."

  # docker-compose.yml
  evaluate_file_content "${ETC_DIR}/compose/docker-compose.yml.j2" \
    "${PROJECT_DIR}/docker-compose.yml"

  # nginx.conf
  evaluate_file_content "${ETC_DIR}/nginx/nginx.conf.j2" \
    "${PROJECT_DIR}/nginx.conf"

  # exo.properties (only for non-meeds / when the product expects it)
  if [ "${PRODUCT_NAME}" != "meeds" ]; then
    evaluate_file_content "${ETC_DIR}/exo/exo.properties.j2" \
      "${PROJECT_DIR}/exo.properties"
  else
    evaluate_file_content "${ETC_DIR}/exo/exo.properties.j2" \
      "${PROJECT_DIR}/exo.properties"
  fi

  # DB configs
  if [ "${DEPLOYMENT_DB_TYPE}" = "mysql" ]; then
    evaluate_file_content "${ETC_DIR}/db/mysql.cnf.j2" \
      "${PROJECT_DIR}/mysql.cnf"
  fi

  # error pages (rendered from j2 to get DEPLOYMENT_EXT_HOST)
  mkdir -p "${PROJECT_DIR}/error_pages"
  evaluate_file_content "${ETC_DIR}/nginx/error_pages/custom_50x.html.j2" \
    "${PROJECT_DIR}/error_pages/custom_50x.html"

  echo_info "Instance configs rendered."
}

# Validate the rendered compose file.
do_validate_instance() {
  compose_config "${PROJECT_DIR}"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_COMPOSE_LOADED=true
echo_debug "_functions_compose.sh Loaded"
