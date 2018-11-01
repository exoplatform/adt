#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_ONLYOFFICE_LOADED:-false} && return
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

do_get_onlyoffice_settings() {
  if ! ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED}; then
    return;
  fi
  env_var DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME "${INSTANCE_KEY}_onlyoffice"
}

#
# Drops all Onlyoffice datas used by the instance.
#
do_drop_onlyoffice_data() {
  echo_info "Dropping onlyoffice data ..."
  if ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED}; then
    echo_info "Drops Onlyoffice container ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}
    echo_info "Drops Onlyoffice docker volume ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} ..."
    delete_docker_volume ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Onlyoffice data dropped"
  else
    echo_info "Skip Drops Onlyoffice container ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} ..."
  fi
}

do_create_onlyoffice() {
  if ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED}; then
    echo_info "Creation of the OnlyOffice Docker volume ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} ..."
    create_docker_volume ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}
    echo_info "OnlyOffice Docker volume ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} created"
  fi
}

do_stop_onlyoffice() {
  echo_info "Stopping OnlyOffice ..."
  if ! ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED}; then
    echo_info "Onlyoffice addon wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}
  echo_info "OnlyOffice container ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} stopped."
}

do_start_onlyoffice() {
  echo_info "Starting OnlyOffice..."
  if ! ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED}; then
    echo_info "Onlyoffice addon not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting OnlyOffice container ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} based on image ${DEPLOYMENT_ONLYOFFICE_IMAGE}:${DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    --add-host plfent-5.0.3.acceptance.exoplatform.org:192.168.2.21 \
    -p "127.0.0.1:${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}:80" \
    -v ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}:/var/log/onlyoffice  \
    --name ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} ${DEPLOYMENT_ONLYOFFICE_IMAGE}:${DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION}

  echo_info "${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} container started"

  check_onlyoffice_availability
}

check_onlyoffice_availability() {
  echo_info "Waiting for Onlyoffice DocumentServer availability on port ${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  local temp_file="/tmp/${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}_${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}.txt"

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "OnlyOffice documentserver not yet available (${count} / ${try})..."
    else
      curl -f -s --max-time ${wait_time} http://localhost:${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}/healthcheck > ${temp_file} 
      local status=$(grep "true" ${temp_file})
      if [ "${status}" == "true" ]; then
        RET=0   
      fi
    fi

    if [ $RET -ne 0 ]; then
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Onlyoffice DocumentServer ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Onlyoffice DocumentServer ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_ONLYOFFICE_LOADED=true
echo_debug "_functions_onlyoffice.sh Loaded"
