#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_ADMIN_MONGO_LOADED:-false} && return
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

do_get_admin_mongo_settings() {  
  if [ "${DEPLOYMENT_ADMIN_MONGO_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME "${INSTANCE_KEY}_admin_mongo"
}

do_stop_admin_mongo() {
  echo_info "Stopping Admin Mongo ..."
  if [ "${DEPLOYMENT_ADMIN_MONGO_ENABLED}" == "false" ]; then
    echo_info "Admin Mongo wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME}
  echo_info "Admin Mongo container ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} stopped."
}

do_start_admin_mongo() {
  echo_info "Starting Admin Mongo..."
  if [ "${DEPLOYMENT_ADMIN_MONGO_ENABLED}" == "false" ]; then
    echo_info "Admin Mongo not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Admin Mongo container ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} based on image ${DEPLOYMENT_ADMIN_MONGO_IMAGE}:${DEPLOYMENT_ADMIN_MONGO_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME}
  local mongo_ip_addr=$(${DOCKER_CMD} inspect --format '{{ .NetworkSettings.IPAddress }}' ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME})
  ${DOCKER_CMD} run \
    -d \
    -e HOST="0.0.0.0" \
    -e PORT="1234" \
    -e CONTEXT="adminmongo" \
    -e MONITORING="false" \
    -e CONN_NAME="Acceptance" \
    -e DB_HOST="${mongo_ip_addr}" \
    -e DB_PORT="27017" \
    -e DB_NAME="${DEPLOYMENT_CHAT_MONGODB_NAME}" \
    -p "${DEPLOYMENT_ADMIN_MONGO_HTTP_PORT}:1234" \
    --name ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} ${DEPLOYMENT_ADMIN_MONGO_IMAGE}:${DEPLOYMENT_ADMIN_MONGO_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} container started"  
  check_admin_mongo_availability
}

check_admin_mongo_availability() {
  echo_info "Waiting for Admin Mongo availability on port ${DEPLOYMENT_ADMIN_MONGO_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_ADMIN_MONGO_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Admin Mongo not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Admin Mongo ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Admin Mongo ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_ADMIN_MONGO_LOADED=true
echo_debug "_function_admin_mongo.sh Loaded"