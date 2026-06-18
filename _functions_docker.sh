#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DOCKER_LOADED:-false} && return
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

# #############################################################################
# Docker / docker compose wrapper functions
#
# v2 design: each instance is a docker compose project named adt-<INSTANCE_KEY>.
# All state lives in named docker volumes owned by the project.
# The nginx service is dual-homed (isolated project network + external
# reverse_proxy network) and carries Traefik TCP-passthrough labels.
# #############################################################################

# Build the docker compose command prefix for a given project directory.
# Uses the compose v2 plugin (`docker compose`) - not the legacy docker-compose.
# Globals: DOCKER_CMD, COMPOSE_FILE
# $1 : project directory (containing docker-compose.yml)
# echoes the compose command to be eval'd
compose_cmd() {
  local _project_dir=$1
  echo "${DOCKER_CMD} compose -f ${_project_dir}/docker-compose.yml"
}

# compose project name for an instance.
# $1 : INSTANCE_KEY
# echoes "adt-<sanitized key>"
compose_project_name() {
  echo "adt-$(sanitize_name $1)"
}

# Ensure the external frontend network exists. No-op if it already exists.
# Globals: DEPLOYMENT_FRONTEND_NETWORK (default reverse_proxy)
ensure_frontend_network() {
  local _network="${DEPLOYMENT_FRONTEND_NETWORK:-reverse_proxy}"
  local _exists=$(${DOCKER_CMD} network inspect ${_network} 2>/dev/null | jq -r '.[0].Name // empty')
  if [ -z "${_exists}" ]; then
    echo_info "Creating docker network ${_network} ..."
    ${DOCKER_CMD} network create ${_network}
    echo_info "Done."
  else
    echo_debug "Network ${_network} already exists"
  fi
}

# $1 network name or id
delete_docker_network() {
  network=${1}
  local network_name=$(${DOCKER_CMD} network inspect ${network} 2>/dev/null | jq -r '.[0].Name // empty')
  if [ -z "${network_name}" ]; then
    echo_debug "Network ${network} does not exist."
  else
    ${DOCKER_CMD} network rm ${network}
    echo_info "Network ${network} removed"
   fi
}

# Bring a compose project up (detached).
# $1 : project dir
# Optional $2 : extra up args (e.g. "--pull=always")
# Optional $3 : service name (to start only one service)
compose_up() {
  local _project_dir=$1
  local _extra="${2:-}"
  local _service="${3:-}"
  echo_info "Starting compose project in ${_project_dir} ..."
  $(compose_cmd ${_project_dir}) up -d ${_extra} ${_service}
  echo_info "Done."
}

# Stop a compose project (containers kept).
# $1 : project dir
# Optional $2 : service name (to stop only one service)
compose_stop() {
  local _project_dir=$1
  local _service="${2:-}"
  echo_info "Stopping compose project in ${_project_dir} ..."
  $(compose_cmd ${_project_dir}) stop ${_service}
  echo_info "Done."
}

# Start an already-created compose project (no recreate).
# $1 : project dir
compose_start() {
  local _project_dir=$1
  echo_info "Starting compose project in ${_project_dir} ..."
  $(compose_cmd ${_project_dir}) start
  echo_info "Done."
}

# Restart a compose project.
# $1 : project dir
compose_restart() {
  local _project_dir=$1
  echo_info "Restarting compose project in ${_project_dir} ..."
  $(compose_cmd ${_project_dir}) restart
  echo_info "Done."
}

# Take a compose project down.
# $1 : project dir
# $2 : remove volumes (true|false) default false
compose_down() {
  local _project_dir=$1
  local _remove_volumes="${2:-false}"
  local _args="down"
  if [ "${_remove_volumes}" = "true" ]; then
    _args="${_args} -v"
  fi
  if [ ! -f "${_project_dir}/docker-compose.yml" ]; then
    echo_debug "No docker-compose.yml in ${_project_dir}, nothing to take down."
    return 0
  fi
  echo_info "Taking compose project down (${_args}) in ${_project_dir} ..."
  $(compose_cmd ${_project_dir}) ${_args}
  echo_info "Done."
}

# Pull images for a compose project.
# $1 : project dir
compose_pull() {
  local _project_dir=$1
  echo_info "Pulling images for compose project in ${_project_dir} ..."
  $(compose_cmd ${_project_dir}) pull
  echo_info "Done."
}

# Validate a compose file (config).
# $1 : project dir
compose_config() {
  local _project_dir=$1
  $(compose_cmd ${_project_dir}) config -q
}

# Get the status of a compose project as JSON (one object per service).
# $1 : project dir
compose_ps_json() {
  local _project_dir=$1
  $(compose_cmd ${_project_dir}) ps --format json 2>/dev/null
}

# Execute a command in a service of a compose project.
# $1 : project dir
# $2 : service name
# $3.. : command
compose_exec() {
  local _project_dir=$1
  local _service=$2
  shift 2
  $(compose_cmd ${_project_dir}) exec -T ${_service} "$@"
}

# Run a one-shot container attached to a compose project's network.
# $1 : project dir
# $2.. : extra `docker compose run` args (must include the service/cmd)
compose_run() {
  local _project_dir=$1
  shift
  $(compose_cmd ${_project_dir}) run --rm "$@"
}

# $1 volume name or id
delete_docker_volume() {
  volume=${1}
  local volume_name=$(${DOCKER_CMD} volume inspect ${volume} 2>/dev/null | jq -r '.[0].Name // empty')
  if [ -z "${volume_name}" ]; then
    echo_debug "Volume ${volume} does not exist."
  else
    ${DOCKER_CMD} volume rm ${volume}
    echo_info "Volume ${volume} removed"
   fi
}

# $1 volume name
create_docker_volume() {
  volume=${1}
  ${DOCKER_CMD} volume create --name ${volume} > /dev/null
}

# Check whether a volume exists.
# $1 volume name
# echoes "true" or "false"
volume_exists() {
  local _volume=$1
  local _name=$(${DOCKER_CMD} volume inspect ${_volume} 2>/dev/null | jq -r '.[0].Name // empty')
  if [ -n "${_name}" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# Dump a named docker volume to a tar.gz file using a throwaway alpine container.
# $1 : volume name
# $2 : output tar.gz path (on the host)
dump_docker_volume() {
  local _volume=$1
  local _output=$2
  mkdir -p "$(dirname ${_output})"
  echo_info "Dumping volume ${_volume} -> ${_output} ..."
  ${DOCKER_CMD} run --rm -v ${_volume}:/source:ro -v "$(dirname ${_output})":/backup alpine \
    tar czf "/backup/$(basename "${_output}")" -C /source .
  echo_info "Done."
}

# Restore a tar.gz file into a named docker volume using a throwaway alpine container.
# The volume is created if it doesn't exist.
# $1 : tar.gz path (on the host)
# $2 : volume name
restore_docker_volume() {
  local _archive=$1
  local _volume=$2
  [ ! -f "${_archive}" ] && { echo_error "Archive ${_archive} not found"; return 1; }
  [ "$(volume_exists ${_volume})" = "false" ] && create_docker_volume ${_volume}
  echo_info "Restoring ${_archive} -> volume ${_volume} ..."
  ${DOCKER_CMD} run --rm -v ${_volume}:/target -v "$(dirname ${_archive})":/backup:ro alpine \
    tar xzf "/backup/$(basename "${_archive}")" -C /target
  echo_info "Done."
}

# Wait for a compose service to become healthy (docker healthcheck).
# $1 : project dir
# $2 : service name
# $3 : timeout in seconds (default 600)
wait_service_healthy() {
  local _project_dir=$1
  local _service=$2
  local _timeout=${3:-600}
  local _elapsed=0
  # Container name = <compose_project>-<service> (we set container_name explicitly)
  # Derive the project name from the compose file's `name:` field
  local _project
  _project=$(yq -r '.name' "${_project_dir}/docker-compose.yml" 2>/dev/null || basename "${_project_dir}")
  local _container="${_project}-${_service}"
  echo_n_info "Waiting for ${_service} to become healthy ..."
  while [ ${_elapsed} -lt ${_timeout} ]; do
    local _health
    _health=$(${DOCKER_CMD} inspect --format '{{.State.Health.Status}}' "${_container}" 2>/dev/null || echo "")
    case "${_health}" in
      healthy)
        echo " OK"
        return 0
        ;;
      unhealthy)
        echo " UNHEALTHY"
        echo_error "Service ${_service} is unhealthy"
        return 1
        ;;
    esac
    printf "."
    sleep 5
    _elapsed=$((_elapsed + 5))
  done
  echo " TIMEOUT"
  echo_error "Service ${_service} did not become healthy within ${_timeout}s"
  return 1
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DOCKER_LOADED=true
echo_debug "_functions_docker.sh Loaded"
