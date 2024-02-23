#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_FRONTAIL_LOADED:-false} && return
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

do_get_frontail_settings() {  
  if [ "${DEPLOYMENT_FRONTAIL_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_FRONTAIL_CONTAINER_NAME "${INSTANCE_KEY}_frontail"
}

#
# Drops all Frontail data used by the instance.
#
do_drop_frontail_data() {
  if [ "${DEPLOYMENT_FRONTAIL_ENABLED}" == "true" ]; then
    echo_info "Drops Frontail container ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME}
    echo_info "Done."
  else
    echo_info "Skip Drops Frontail container ..."
  fi
}

do_stop_frontail() {
  echo_info "Stopping Frontail ..."
  if [ "${DEPLOYMENT_FRONTAIL_ENABLED}" == "false" ]; then
    echo_info "Frontail wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME}
  echo_info "Frontail container ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} stopped."
}

do_start_frontail() {
  echo_info "Starting Frontail..."
  if [ "${DEPLOYMENT_FRONTAIL_ENABLED}" == "false" ]; then
    echo_info "Frontail not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Frontail container ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} based on image ${DEPLOYMENT_FRONTAIL_IMAGE}:${DEPLOYMENT_FRONTAIL_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_FRONTAIL_HTTP_PORT}:9001" \
    -v "$(dirname ${DEPLOYMENT_LOG_PATH}):/logs" \
    -h 'frontail' \
    --health-cmd="timeout 2 /bin/bash -c '</dev/tcp/frontail/9001' || exit 1" \
    --health-interval=30s \
    --health-timeout=30s \
    --health-retries=3 \
    --name ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} ${DEPLOYMENT_FRONTAIL_IMAGE}:${DEPLOYMENT_FRONTAIL_IMAGE_VERSION} --disable-usage-stats --url-path /livelogs /logs/${DEPLOYMENT_SERVER_LOG_FILE}
  echo_info "${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} container started"  
  check_frontail_availability
}

check_frontail_availability() {
  echo_info "Waiting for Frontail availability on port ${DEPLOYMENT_FRONTAIL_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_FRONTAIL_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Frontail not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Frontail ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Frontail ${DEPLOYMENT_FRONTAIL_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_FRONTAIL_LOADED=true
echo_debug "_function_frontail.sh Loaded"