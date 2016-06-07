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

# Stop a container if is running
# $1 container name or id
ensure_docker_container_stopped() {
  local container=$1
  
  set +e
  local running="$(${DOCKER_CMD} inspect --format {{.State.Running}} ${container} 2>/dev/null)"
  set -e
  
  if [ "${running}" == "true" ]; then
    ${DOCKER_CMD} stop ${container}
  fi
}

# delete a container
# $1 container name or id
# $2 force (delete it even if it's an active container)
delete_docker_container() {
  local container=$1
  
  ensure_docker_container_stopped ${container}
  
  set +e
  ${DOCKER_CMD} rm -v ${container} 2>/dev/null
  set -e
}

# $1 volume name or id
delete_docker_volume() {
  volume=${1}
  
  local volume_name=$(${DOCKER_CMD} volume inspect ${volume} 2>/dev/null | jq -r '.[0].Name')
  
  if [ "${volume_name}" == "null" ] 
  then 
    echo_info "Volume ${volume} does not exist."
  else
    ${DOCKER_CMD} volume rm ${volume}
    if [ $? -ne 0 ]
    then
      echo_error "Error removing volume ${volume}"
      exit 1
    fi
    echo_info "Volume ${volume} removed"
   fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DOCKER_LOADED=true
echo_debug "_functions_docker.sh Loaded"