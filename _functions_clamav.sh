#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CLAMAV_LOADED:-false} && return
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

source "${SCRIPT_DIR}/_functions_matrix.sh"

do_get_clamav_settings() {  
  if [ "${DEPLOYMENT_CLAMAV_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_CLAMAV_CONTAINER_NAME "${INSTANCE_KEY}_clamav"
  env_var DEPLOYMENT_FILES_DATA_DIR "/gatein/data/files"
}

#
# Drops all clamav data used by the instance.
#
do_drop_clamav_data() {
  echo_info "Dropping Clamav data ..."
  if ${DEPLOYMENT_CLAMAV_ENABLED}; then
    echo_info "Drops Clamav container ${DEPLOYMENT_CLAMAV_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_CLAMAV_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Clamav data dropped"
  else
    echo_info "Skip Drops Clamav container ..."
  fi
}

do_stop_clamav() {
  echo_info "Stopping clamav ..."
  if [ "${DEPLOYMENT_CLAMAV_ENABLED}" == "false" ]; then
    echo_info "Clamav wasn't specified, skiping its containers shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_CLAMAV_CONTAINER_NAME}
  echo_info "Clamav container ${DEPLOYMENT_CLAMAV_CONTAINER_NAME} stopped."
  echo_info "Done."
}

do_start_clamav() {
  echo_info "Starting Clamav..."
  if [ "${DEPLOYMENT_CLAMAV_ENABLED}" == "false" ]; then
    echo_info "Clamav not specified, skiping its containers startup"
    return
  fi
  mkdir -p ${DEPLOYMENT_DIR}/clamav
  #evaluate_file_content ${ETC_DIR}/clamav/clamav-entrypoint.sh.template ${DEPLOYMENT_DIR}/clamav/clamav-entrypoint.sh
  cp -v ${ETC_DIR}/clamav/clamd.conf ${DEPLOYMENT_DIR}/clamav/clamd.conf
  cp -v ${ETC_DIR}/clamav/clamav-entrypoint.sh ${DEPLOYMENT_DIR}/clamav/clamav-entrypoint.sh
  chmod +x ${DEPLOYMENT_DIR}/clamav/clamav-entrypoint.sh
  echo_info "Starting Clamav container ${DEPLOYMENT_CLAMAV_CONTAINER_NAME} based on image ${DEPLOYMENT_CLAMAV_IMAGE}:${DEPLOYMENT_CLAMAV_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_CLAMAV_CONTAINER_NAME}
  export DEPLOYMENT_OPTS="${DEPLOYMENT_OPTS} -Dexo.malwareDetection.connector.clamav.report.path=/report/clamav-report.txt -Dexo.malwareDetection.connector.clamav.isDefault=true"
  ${DOCKER_CMD} run \
    -d \
    -h 'clamav' \
    -p "${DEPLOYMENT_CLAMAV_PORT}:3310" \
    -v ${DEPLOYMENT_CLAMAV_CONTAINER_NAME}_logs:/var/log/clamav  \
    -v ${DEPLOYMENT_CLAMAV_CONTAINER_NAME}_reports:/report  \
    -v ${DEPLOYMENT_DIR}/clamav/clamd.conf:/etc/clamav/clamd.conf:ro \
    -v ${DEPLOYMENT_JCR_PATH_DATA}/values:/scan/jcr/values  \
    -v ${DEPLOYMENT_FILES_DATA_DIR}:/scan/files  \
    -v /srv/docker/volumes/${DEPLOYMENT_MATRIX_CONTAINER_NAME}_data/_data/media_store:/scan/synapse/media:ro  \
    -v ${DEPLOYMENT_DIR}/clamav/clamav-entrypoint.sh:/usr/local/bin/clamav-entrypoint.sh:ro  \
    --health-cmd='nc -z 127.0.0.1 3310' \
    --health-interval=30s \
    --health-timeout=30s \
    --health-retries=5 \
    --health-start-period=30s \
    --name ${DEPLOYMENT_CLAMAV_CONTAINER_NAME} ${DEPLOYMENT_CLAMAV_IMAGE}:${DEPLOYMENT_CLAMAV_IMAGE_VERSION} \
    --entrypoint /usr/local/bin/clamav-entrypoint.sh
  echo_info "${DEPLOYMENT_CLAMAV_CONTAINER_NAME} container started"
  check_clamav_availability
}
  
check_clamav_availability() {
  echo_info "Waiting for clamav availability on port ${DEPLOYMENT_CLAMAV_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    nc -z 127.0.0.1 "${DEPLOYMENT_CLAMAV_PORT}"
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Clamav not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Clamav ${DEPLOYMENT_CLAMAV_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Clamav ${DEPLOYMENT_CLAMAV_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CLAMAV_LOADED=true
echo_debug "_function_clamav.sh Loaded"