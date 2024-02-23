#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_IFRAMELY_LOADED:-false} && return
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

do_get_iframely_settings() {
  if [ "${DEPLOYMENT_IFRAMELY_ENABLED}" == "false" ] ; then
    return;
  fi
  env_var DEPLOYMENT_IFRAMELY_CONTAINER_NAME "${INSTANCE_KEY}_iframely"
}

#
# Drops all iframely data used by the instance.
#
do_drop_iframely_data() {
  echo_info "Dropping iframely data ..."
  if [ "${DEPLOYMENT_IFRAMELY_ENABLED}" == "true" ] ; then
    echo_info "Drops Iframely container ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Iframely data dropped"
  else
    echo_info "Skip Drops Iframely container ..."
  fi
}

do_stop_iframely() {
  echo_info "Stopping Iframely ..."
  if [ "${DEPLOYMENT_IFRAMELY_ENABLED}" == "false" ] ; then
    echo_info "Iframely wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME}
  echo_info "Iframely container ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} stopped."
}

#do_create_iframely() {
#    ${DOCKER_CMD} volume create --name ${DEPLOYMENT_LDAP_CONTAINER_NAME}_data
#    ${DOCKER_CMD} volume create --name ${DEPLOYMENT_LDAP_CONTAINER_NAME}_conf
#}

do_start_iframely() {
  echo_info "Starting Iframely..."
  if [ "${DEPLOYMENT_IFRAMELY_ENABLED}" == "false" ]; then
    echo_info "Iframely not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Iframely container ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} based on image ${DEPLOYMENT_IFRAMELY_IMAGE}:${DEPLOYMENT_IFRAMELY_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME}
  export DEPLOYMENT_OPTS="${DEPLOYMENT_OPTS} -Dio.meeds.iframely.url=${DEPLOYMENT_URL}/oembed"
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_IFRAMELY_PORT}:8061" \
    -h 'iframely' \
    --health-cmd='wget -qO- http://iframely:8061 &> /dev/null || exit 1' \
    --health-interval=30s \
    --health-timeout=30s \
    --health-retries=3 \
    --name ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} ${DEPLOYMENT_IFRAMELY_IMAGE}:${DEPLOYMENT_IFRAMELY_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} container started"

  check_iframely_availability
}

check_iframely_availability() {
  echo_info "Waiting for Iframely availability on port ${DEPLOYMENT_IFRAMELY_PORT}"
  local count=0
  local try=600
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    wget -qO- http://localhost:${DEPLOYMENT_IFRAMELY_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "iframely not yet available (${count} / ${try})..."
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Ldap ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Ldap ${DEPLOYMENT_IFRAMELY_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_IFRAMELY_LOADED=true
echo_debug "_function_iframley.sh Loaded"