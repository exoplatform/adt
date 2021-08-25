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
    if [ "${ACTION}" = "undeploy" ] || [ "${DEPLOYMENT_MODE}" = "NO_DATA" ]; then
      ${DOCKER_CMD} kill ${container} # No need to wait for container shutdown :-)
    else
      ${DOCKER_CMD} stop ${container}
    fi
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

# $1 volume name
create_docker_volume() {
  volume=${1}

  ${DOCKER_CMD} volume create --name ${volume}
}

# $1 network name or id
delete_docker_network() {
  network=${1}
  
  local network_name=$(${DOCKER_CMD} network inspect ${network} 2>/dev/null | jq -r '.[0].Name')
  
  if [ "${network_name}" == "null" ] 
  then 
    echo_info "Network ${network} does not exist."
  else
    ${DOCKER_CMD} network rm ${network}
    if [ $? -ne 0 ]
    then
      echo_error "Error removing network ${network}"
      exit 1
    fi
    echo_info "Network ${network} removed"
   fi
}

# $1 network name
create_docker_network() {
  network=${1}

  ${DOCKER_CMD} network create ${network}
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DOCKER_LOADED=true
echo_debug "_functions_docker.sh Loaded"