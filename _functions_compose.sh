#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_COMPOSE_LOADED:-false} && return
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
source "${SCRIPT_DIR}/_functions_files.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"

# #############################################################################
# Every instance is a docker compose project, rendered from etc/compose/*.j2 in
# ${SRV_DIR}/${INSTANCE_KEY}/ :
#
#   docker-compose.yml   the services of the instance (secrets inside: mode 600)
#   nginx.conf           the reverse proxy of the instance
#   logs/{app,nginx}     bind mounts (world writable: the containers run as other uids than ADT's user)
#
# The data of the instance (application data, codec key, database, search index)
# live in docker named volumes, so that ADT's user never needs to own or remove
# files created by the containers.
# The project has its own network: the only published port is the one of nginx.
# Containers: <key>_web, <key>_exo, <key>_db, <key>_search; volumes <key>_exo_data, _exo_codec, _db, _search; network <key>.
# #############################################################################

# Docker compose project names only allow [a-z0-9_-]: the key is lowercased and sanitized, and a short checksum of the real key keeps two
# keys that only differ by what the sanitizing removes (case, dots) apart. Everything docker creates (containers, volumes, network) is
# named after the instance key itself, the project is only the grouping of the compose labels.
# $1 instance key
compose_project_name() {
  local _name _sum
  _name=$(tr '[:upper:]' '[:lower:]' <<< "adt-$1")
  _sum=$(printf '%s' "$1" | sha1sum | cut -c1-6)
  echo "${_name//[^a-z0-9_-]/_}-${_sum}"
}

# Paths and commands of the compose project of the instance
do_get_compose_settings() {
  env_var DEPLOYMENT_DIR "${SRV_DIR}/${INSTANCE_KEY}"
  env_var DEPLOYMENT_COMPOSE_PROJECT "$(compose_project_name "${INSTANCE_KEY}")"
  env_var DEPLOYMENT_COMPOSE_FILE "${DEPLOYMENT_DIR}/docker-compose.yml"
  env_var DEPLOYMENT_LOG_DIR "${DEPLOYMENT_DIR}/logs"
  env_var DEPLOYMENT_LOG_PATH "${DEPLOYMENT_LOG_DIR}/app/platform.log"
}

# Run docker compose on the project of the instance
do_compose() {
  ${DOCKER_CMD} compose --project-name "${DEPLOYMENT_COMPOSE_PROJECT}" --file "${DEPLOYMENT_COMPOSE_FILE}" "$@"
}

# Docker hands one subnet of its address pools to every network: with the default
# pools about 30 networks fit on a host, then "docker compose up" fails in a
# confusing way. Check it before creating the network of a new instance.
do_check_docker_network_capacity() {
  # the network of a deployed instance already exists
  if ${DOCKER_CMD} network inspect "${INSTANCE_KEY}" > /dev/null 2>&1; then
    return 0
  fi
  local _max=${DEPLOYMENT_DOCKER_NETWORKS_MAX:-30} _count
  _count=$(${DOCKER_CMD} network ls --filter driver=bridge --quiet | wc -l)
  if [ "${_count}" -ge "${_max}" ]; then
    echo_error "This docker host already has ${_count} bridge networks: the default address pools hold about ${_max}."
    echo_error "Undeploy an instance, or widen the pools in /etc/docker/daemon.json then restart docker, e.g."
    echo_error '  { "default-address-pools": [ { "base": "10.200.0.0/16", "size": 24 } ] }'
    echo_error "(set DEPLOYMENT_DOCKER_NETWORKS_MAX to adapt this check)"
    return 1
  fi
}

# Create the directories bind mounted in the containers. They are world writable
# because the containers run as their own uid (999, 101...), not as the user of ADT.
do_prepare_compose_dirs() {
  mkdir -p "${DEPLOYMENT_DIR}" "${DEPLOYMENT_LOG_DIR}/app" "${DEPLOYMENT_LOG_DIR}/nginx"
  chmod 777 "${DEPLOYMENT_LOG_DIR}/app" "${DEPLOYMENT_LOG_DIR}/nginx"
}

# Render the files of the compose project
do_render_compose_files() {
  echo_info "Rendering the compose project in ${DEPLOYMENT_DIR} ..."
  evaluate_file_content "${ETC_DIR}/compose/docker-compose.yml.j2" "${DEPLOYMENT_COMPOSE_FILE}"
  evaluate_file_content "${ETC_DIR}/compose/nginx.conf.j2" "${DEPLOYMENT_DIR}/nginx.conf"
  # the compose file holds the passwords of the instance
  chmod 600 "${DEPLOYMENT_COMPOSE_FILE}"
  chmod 644 "${DEPLOYMENT_DIR}/nginx.conf"
  do_compose config --quiet
  echo_info "Done."
}

# Pull the images of the instance (moving tags such as a SNAPSHOT are refreshed)
do_compose_pull() {
  if ${ADT_OFFLINE}; then
    echo_warn "Offline mode: the images are not pulled"
    return 0
  fi
  echo_info "Pulling the images ..."
  do_compose pull --quiet
  echo_info "Done."
}

# Date the application image was built, as the descriptor expects it (YYYYMMDD.HHMMSS, UTC)
# $1 image
do_get_image_build_date() {
  local _created
  _created=$(${DOCKER_CMD} image inspect --format '{{.Created}}' "$1" 2>/dev/null) || return 0
  date -u -d "${_created}" "+%Y%m%d.%H%M%S" 2>/dev/null || true
}

# Create/update the containers and wait for the instance to be healthy
do_compose_up() {
  echo_info "Starting the containers of ${INSTANCE_DESCRIPTION} ..."
  do_compose up --detach --remove-orphans --wait --wait-timeout "${DEPLOYMENT_START_TIMEOUT:-1800}"
  echo_info "Done."
}

do_compose_stop() {
  echo_info "Stopping the containers of ${INSTANCE_DESCRIPTION} ..."
  do_compose stop --timeout 60
  echo_info "Done."
}

# Remove the containers and the network (and the data volumes with $1=true)
# $1 remove the volumes (true|false)
do_compose_down() {
  local _volumes=()
  ${1:-false} && _volumes=(--volumes)
  do_compose down --remove-orphans --timeout 60 ${_volumes[@]+"${_volumes[@]}"}
}

# The instance is running when its application container is
# $1 instance key
instance_is_running() {
  [ -n "$(${DOCKER_CMD} ps --quiet --filter "label=adt.instance=$1" --filter "label=adt.role=app" --filter status=running 2>/dev/null)" ]
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_COMPOSE_LOADED=true
echo_debug "_functions_compose.sh Loaded"
