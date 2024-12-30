#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_MONGO_EXPRESS_LOADED:-false} && return
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

do_get_mongo_express_settings() {  
  if [ "${DEPLOYMENT_MONGO_EXPRESS_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME "${INSTANCE_KEY}_mongo_express"
  env_var DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME "${INSTANCE_KEY}_admin_mongo" # Transition to new image. TODO: Remove it in the future
}

do_stop_mongo_express() {
  echo_info "Stopping Mongo Express ..."
  if [ "${DEPLOYMENT_MONGO_EXPRESS_ENABLED}" == "false" ]; then
    echo_info "Mongo Express wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME}
  ensure_docker_container_stopped ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} # Transition to new image. TODO: Remove it in the future
  echo_info "Mongo Express container ${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME} stopped."
}

do_start_mongo_express() {
  echo_info "Starting Mongo Express..."
  # No need to start Mongo Express when chat service is disabled
  if ! ${DEPLOYMENT_CHAT_ENABLED} && [ "${DEPLOYMENT_MONGO_EXPRESS_ENABLED}" == "true" ]; then
    echo_warn "Chat disabled, skipping Mongo Express creation..."
    return
  fi
  if [ "${DEPLOYMENT_MONGO_EXPRESS_ENABLED}" == "false" ]; then
    echo_info "Mongo Express not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Mongo Express container ${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME} based on image ${DEPLOYMENT_MONGO_EXPRESS_IMAGE}:${DEPLOYMENT_MONGO_EXPRESS_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME}
  delete_docker_container ${DEPLOYMENT_ADMIN_MONGO_CONTAINER_NAME} # Transition to new image. TODO: Remove it in the future
  local mongo_ip_addr=$(${DOCKER_CMD} inspect --format '{{ .NetworkSettings.IPAddress }}' ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME})
  ${DOCKER_CMD} run \
    -d \
    -e ME_CONFIG_BASICAUTH_ENABLED="false" \
    -e ME_CONFIG_BASICAUTH="false" \
    -e ME_CONFIG_OPTIONS_READONLY="${DEPLOYMENT_MONGO_EXPRESS_READONLY:-true}" \
    -e ME_CONFIG_MONGODB_ENABLE_ADMIN="${DEPLOYMENT_MONGO_EXPRESS_ADMIN:-true}" \
    -e ME_CONFIG_MONGODB_SERVER="${mongo_ip_addr}" \
    -e ME_CONFIG_SITE_COOKIESECRET="${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME}_cookies" \
    -e ME_CONFIG_SITE_SESSIONSECRET="${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME}_session" \
    -e ME_CONFIG_SITE_BASEURL="/mongoexpress" \
    -p "${DEPLOYMENT_MONGO_EXPRESS_HTTP_PORT}:8081" \
    -h "mongoexpress" \
    --health-cmd="wget -qO- mongoexpress:8081/mongoexpress/status  &> /dev/null || exit 1" \
    --health-interval=30s \
    --health-timeout=30s \
    --health-retries=3 \
    --name "${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME}" "${DEPLOYMENT_MONGO_EXPRESS_IMAGE}:${DEPLOYMENT_MONGO_EXPRESS_IMAGE_VERSION}"
  echo_info "${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME} container started"
  check_mongo_express_availability
}

check_mongo_express_availability() {
  echo_info "Waiting for Mongo Express availability on port ${DEPLOYMENT_MONGO_EXPRESS_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_MONGO_EXPRESS_HTTP_PORT}/mongoexpress/status  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Mongo Express not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Mongo Express ${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Mongo Express ${DEPLOYMENT_MONGO_EXPRESS_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_MONGO_EXPRESS_LOADED=true
echo_debug "_function_mongo_express.sh Loaded"