#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CMIS_LOADED:-false} && return
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

do_get_cmis_settings() {
  if ! ${DEPLOYMENT_CMISSERVER_ENABLED}; then
    return;
  fi
  env_var DEPLOYMENT_CMIS_CONTAINER_NAME "${INSTANCE_KEY}_cmis"
}

#
# Drops all CMIS Server datas used by the instance.
#
do_drop_cmis_data() {
  echo_info "Dropping CMIS Server data ..."
  if ${DEPLOYMENT_CMISSERVER_ENABLED}; then
    echo_info "Drops CMIS Server container ${DEPLOYMENT_CMIS_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_CMIS_CONTAINER_NAME}
    echo_info "Drops CMIS Server docker volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_logs ..."
    delete_docker_volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_logs
    echo_info "Drops CMIS Server docker volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_data ..."
    delete_docker_volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_data
    echo_info "Done."
    echo_info "CMIS Server data dropped"
  else
    echo_info "Skip Drops CMIS Server container ..."
  fi
}

do_create_cmis() {
  if ${DEPLOYMENT_CMISSERVER_ENABLED}; then
    echo_info "Creation of the CMIS Server Docker volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_logs ..."
    create_docker_volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_logs
    echo_info "Creation of the CMIS Server Docker volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_data ..."
    create_docker_volume ${DEPLOYMENT_CMIS_CONTAINER_NAME}_data
  fi
}

do_stop_cmis() {
  echo_info "Stopping CMIS Server ..."
  if ! ${DEPLOYMENT_CMISSERVER_ENABLED}; then
    echo_info "CMIS Server wasn't started, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_CMIS_CONTAINER_NAME}
  echo_info "CMIS Server container ${DEPLOYMENT_CMIS_CONTAINER_NAME} stopped."
}

do_start_cmis() {
  echo_info "Starting CMIS Server..."
  if ! ${DEPLOYMENT_CMISSERVER_ENABLED}; then
    echo_info "CMIS Server wasn't specified, skiping its server container startup"
    return
  fi

  echo_info "Starting CMIS Server container ${DEPLOYMENT_CMIS_CONTAINER_NAME} based on image ${DEPLOYMENT_CMIS_IMAGE}:${DEPLOYMENT_CMIS_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_CMIS_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    -p "127.0.0.1:${DEPLOYMENT_CMIS_HTTP_PORT}:8080" \
    -v ${DEPLOYMENT_CMIS_CONTAINER_NAME}_logs:/opt/tomcat/logs  \
    -v ${DEPLOYMENT_CMIS_CONTAINER_NAME}_data:/data  \
    --name ${DEPLOYMENT_CMIS_CONTAINER_NAME} ${DEPLOYMENT_CMIS_IMAGE}:${DEPLOYMENT_CMIS_IMAGE_VERSION}

  echo_info "${DEPLOYMENT_CMIS_CONTAINER_NAME} container started"

  check_cmis_availability
}

check_cmis_availability() {
  echo_info "Waiting for CMIS Server availability on port ${DEPLOYMENT_CMIS_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  local temp_file="/tmp/${DEPLOYMENT_CMIS_CONTAINER_NAME}_${DEPLOYMENT_CMIS_HTTP_PORT}.txt"

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_CMIS_HTTP_PORT}  > temp_file
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "CMIS server not yet available (${count} / ${try})..."
    else
      curl -f -s --max-time ${wait_time} http://localhost:${DEPLOYMENT_CMIS_HTTP_PORT}/cmis/ > ${temp_file} 
      local status=$(grep "[Y]our server is up and running." ${temp_file}| wc -l)
      if [ "${status}" == "1" ]; then
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
    echo_error "CMIS Server ${DEPLOYMENT_CMIS_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "CMIS Server ${DEPLOYMENT_CMIS_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CMIS_LOADED=true
echo_debug "_functions_cmis.sh Loaded"
