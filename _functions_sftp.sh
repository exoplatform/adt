#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_SFTP_LOADED:-false} && return
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

do_get_sftp_settings() {  
  if [ "${DEPLOYMENT_SFTP_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_SFTP_CONTAINER_NAME "${INSTANCE_KEY}_Sftp"
}

#
# Drops all Sftp data used by the instance.
#
do_drop_sftp_data() {
  echo_info "Dropping Sftp data ..."
  if [ "${DEPLOYMENT_SFTP_ENABLED}" == "true" ]; then
    echo_info "Drops Sftp container ${DEPLOYMENT_SFTP_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_SFTP_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Sftp data dropped"
  else
    echo_info "Skip Drops Sftp container ..."
  fi
}

do_stop_sftp() {
  echo_info "Stopping Sftp ..."
  if [ "${DEPLOYMENT_SFTP_ENABLED}" == "false" ]; then
    echo_info "Sftp wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_SFTP_CONTAINER_NAME}
  echo_info "Sftp container ${DEPLOYMENT_SFTP_CONTAINER_NAME} stopped."
}

do_start_sftp() {
  echo_info "Starting Sftp..."
  if [ "${DEPLOYMENT_SFTP_ENABLED}" == "false" ]; then
    echo_info "Sftp not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Sftp container ${DEPLOYMENT_SFTP_CONTAINER_NAME} based on image ${DEPLOYMENT_SFTP_IMAGE}:${DEPLOYMENT_SFTP_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_SFTP_CONTAINER_NAME}

  ${DOCKER_CMD} run -p ${DEPLOYMENT_SFTP_PORT}:22 -d ${DEPLOYMENT_SFTP_IMAGE}:${DEPLOYMENT_SFTP_IMAGE_VERSION} root:password:::upload
  echo_info "${DEPLOYMENT_SFTP_CONTAINER_NAME} container started"  
  check_sftp_availability
}

check_sftp_availability() {
  echo_info "Waiting for Sftp availability on port ${DEPLOYMENT_SFTP_PORT}"
  local count=0
  local try=600
  local wait_time=60
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e
    nc -z -w ${wait_time} localhost ${DEPLOYMENT_SFTP_PORT} > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Sftp not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Sftp ${DEPLOYMENT_SFTP_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Sftp ${DEPLOYMENT_SFTP_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_SFTP_LOADED=true
echo_debug "_function_sftp.sh Loaded"