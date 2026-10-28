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

# Add the properties the operator asks for to the exo.properties of the instance (after the ones of the integrations: the last
# definition of a property wins): DEPLOYMENT_PROPERTIES (key=value lines, separated by real or written \n) and the file
# DEPLOYMENT_PROPERTIES_FILE. They are for what the instance needs and ADT does not know, e.g. the properties of the source of a
# restored dataset (exo.wallet.admin.key), or of a customer.
# $1 the exo.properties to complete
do_append_custom_properties() {
  local _target=$1 _file="${DEPLOYMENT_PROPERTIES_FILE:-}" _lines="${DEPLOYMENT_PROPERTIES:-}"
  [ -n "${_lines}" ] || [ -n "${_file}" ] || return 0
  if [ -n "${_file}" ] && [ ! -f "${_file}" ]; then
    echo_error "DEPLOYMENT_PROPERTIES_FILE (${_file}) doesn't exist"
    exit 1
  fi
  {
    echo "# Added by DEPLOYMENT_PROPERTIES and DEPLOYMENT_PROPERTIES_FILE"
    [ -z "${_lines}" ] || printf '%b\n' "${_lines}"
    [ -z "${_file}" ] || cat "${_file}"
  } | grep -v '^[[:space:]]*$' >> "${_target}"
}

# Render the files of the compose project
do_render_compose_files() {
  echo_info "Rendering the compose project in ${DEPLOYMENT_DIR} ..."
  evaluate_file_content "${ETC_DIR}/compose/exo.properties.j2" "${DEPLOYMENT_DIR}/exo.properties"
  do_append_custom_properties "${DEPLOYMENT_DIR}/exo.properties"
  env_var DEPLOYMENT_PROPERTIES_SHA "$(sha256sum "${DEPLOYMENT_DIR}/exo.properties" | cut -d' ' -f1)"
  evaluate_file_content "${ETC_DIR}/compose/docker-compose.yml.j2" "${DEPLOYMENT_COMPOSE_FILE}"
  evaluate_file_content "${ETC_DIR}/compose/nginx.conf.j2" "${DEPLOYMENT_DIR}/nginx.conf"
  # the compose file and the properties hold the passwords of the instance
  chmod 600 "${DEPLOYMENT_COMPOSE_FILE}" "${DEPLOYMENT_DIR}/exo.properties"
  chmod 644 "${DEPLOYMENT_DIR}/nginx.conf"
  do_compose config --quiet
  echo_info "Done."
}

# Pull the images of the instance. The tags of a snapshot move, so the policy is "always" (DEPLOYMENT_PULL_POLICY=missing keeps
# the images that are here). A registry that does not answer is tried again; when it still does not, the deployment goes on if
# every image is already here, otherwise it stops with what to do.
do_compose_pull() {
  if ${ADT_OFFLINE}; then
    echo_warn "Offline mode: the images are not pulled"
    return 0
  fi
  local _policy="${DEPLOYMENT_PULL_POLICY:-always}" _attempt _image _missing=false
  echo_info "Pulling the images (policy ${_policy}) ..."
  for _attempt in 1 2 3; do
    if do_compose pull --quiet --policy "${_policy}"; then
      echo_info "Done."
      return 0
    fi
    echo_warn "The images could not be pulled (attempt ${_attempt}/3)"
    [ "${_attempt}" -lt 3 ] && sleep $(( _attempt * 10 ))
  done
  for _image in $(do_compose config --images); do
    if ! ${DOCKER_CMD} image inspect "${_image}" > /dev/null 2>&1; then
      echo_error "Image ${_image} is not available on this server"
      _missing=true
    fi
  done
  if ${_missing}; then
    echo_error "Pulling failed. Check the network, the registry and, for a private image, 'docker login' of the user of ADT."
    return 1
  fi
  echo_warn "Every image is already on this server: the deployment goes on with them (a snapshot may be outdated)."
}

# Date the application image was built, as the descriptor expects it (YYYYMMDD.HHMMSS, UTC)
# $1 image
do_get_image_build_date() {
  local _created
  _created=$(${DOCKER_CMD} image inspect --format '{{.Created}}' "$1" 2>/dev/null) || return 0
  date -u -d "${_created}" "+%Y%m%d.%H%M%S" 2>/dev/null || true
}

# The exo.properties of the instance (what the integrations of its services tell the application, secrets included) goes in the
# application container, owned by the application user (uid 999 in the images) and readable by it only. A bind mount would have to
# be readable by any uid, and the user of ADT is not root to give it away.
do_install_app_properties() {
  grep -q '^[^#].*=' "${DEPLOYMENT_DIR}/exo.properties" || return 0
  local _app
  _app=$(tr '[:upper:]' '[:lower:]' <<< "${DEPLOYMENT_ENV_PREFIX}")
  tar --owner=999 --group=999 --numeric-owner --mode=0400 --directory "${DEPLOYMENT_DIR}" --create --file - exo.properties \
    | ${DOCKER_CMD} cp - "${INSTANCE_KEY}_exo:/etc/${_app}/"
}

# Print the log of the application container while the instance starts (the installation of the add-ons and the startup of the
# server), so that it is in the output of the job that deploys or starts it. DEPLOYMENT_FOLLOW_LOGS=false keeps it quiet.
do_follow_app_logs() {
  ${DEPLOYMENT_FOLLOW_LOGS:-true} || return 0
  (
    local _name="${INSTANCE_KEY}_exo" _i
    # the container is started by the docker compose up that runs at the same time
    for _i in $(seq 1 900); do
      [ "$(${DOCKER_CMD} inspect --format '{{.State.Running}}' "${_name}" 2>/dev/null)" = "true" ] && break
      sleep 1
    done
    exec ${DOCKER_CMD} logs --follow "${_name}" 2>&1
  ) &
  env_var DEPLOYMENT_FOLLOW_LOGS_PID "$!"
}

do_stop_following_app_logs() {
  [ -n "${DEPLOYMENT_FOLLOW_LOGS_PID:-}" ] || return 0
  # the last lines of the startup are still on their way
  sleep 2
  kill "${DEPLOYMENT_FOLLOW_LOGS_PID}" 2>/dev/null || true
  wait "${DEPLOYMENT_FOLLOW_LOGS_PID}" 2>/dev/null || true
  env_var DEPLOYMENT_FOLLOW_LOGS_PID ""
}

# Create/update the containers, give the application its properties, and wait for the instance to be healthy
do_compose_up() {
  echo_info "Starting the containers of ${INSTANCE_DESCRIPTION} ..."
  do_compose up --no-start --remove-orphans
  do_install_app_properties
  do_follow_app_logs
  if ! do_compose up --detach --remove-orphans --wait --wait-timeout "${DEPLOYMENT_START_TIMEOUT:-1800}"; then
    do_stop_following_app_logs
    echo_error "${INSTANCE_DESCRIPTION} did not start. State of its containers:"
    do_compose ps --all --format '  {{.Service}}: {{.State}} {{.Health}}' || true
    return 1
  fi
  do_stop_following_app_logs
  # nginx.conf is a bind mounted file: compose does not notice when it changed
  ${DOCKER_CMD} exec "${INSTANCE_KEY}_web" nginx -s reload > /dev/null 2>&1 || true
  echo_info "Done."
}

# The license of the enterprise edition: a read-only file mounted where the application looks for it. Without it the instance
# starts without a license.
do_get_license_settings() {
  env_var DEPLOYMENT_LICENSE_MOUNT ""
  [ "${PRODUCT_NAME}" = "plfent" ] || return 0
  local _default="${CONF_DIR}/license.xml"
  configurable_env_var "DEPLOYMENT_LICENSE_FILE" "${_default}"
  if [ -f "${DEPLOYMENT_LICENSE_FILE}" ]; then
    env_var DEPLOYMENT_LICENSE_MOUNT "${DEPLOYMENT_LICENSE_FILE}"
    if [ "$(( 8#$(stat -c %a "${DEPLOYMENT_LICENSE_FILE}") & 4 ))" -eq 0 ]; then
      echo_warn "The license ${DEPLOYMENT_LICENSE_FILE} is not readable by others: the application runs as another user (chmod 644)"
    fi
  elif [ "${DEPLOYMENT_LICENSE_FILE}" != "${_default}" ]; then
    echo_error "DEPLOYMENT_LICENSE_FILE (${DEPLOYMENT_LICENSE_FILE}) doesn't exist"
    exit 1
  else
    echo_warn "No license for ${INSTANCE_KEY}: put it in ${_default} or set DEPLOYMENT_LICENSE_FILE"
  fi
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
