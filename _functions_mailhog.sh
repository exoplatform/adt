#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_MAILHOG_LOADED:-false} && return
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

do_get_mailhog_settings() {  
  if [ "${DEPLOYMENT_MAILHOG_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_MAILHOG_CONTAINER_NAME "${INSTANCE_KEY}_mailhog"
}

#
# Drops all Mailhog data used by the instance.
#
do_drop_mailhog_data() {
  echo_info "Dropping mailhog data ..."
  if [ "${DEPLOYMENT_MAILHOG_ENABLED}" == "true" ]; then
    echo_info "Drops Mailhog container ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_MAILHOG_CONTAINER_NAME}
    delete_docker_volume ${DEPLOYMENT_MAILHOG_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Mailhog data dropped"
  else
    echo_info "Skip Drops Mailhog container ..."
  fi
}

do_create_mailhog() {
  if [ "${DEPLOYMENT_MAILHOG_ENABLED}" == "true" ]; then
    echo_info "Creation of the Mailhog Docker volume ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} ..."
    create_docker_volume ${DEPLOYMENT_MAILHOG_CONTAINER_NAME}
  fi  
}

do_stop_mailhog() {
  echo_info "Stopping Mailhog ..."
  if [ "${DEPLOYMENT_MAILHOG_ENABLED}" == "false" ]; then
    echo_info "Mailhog wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_MAILHOG_CONTAINER_NAME}
  echo_info "Mailhog container ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} stopped."
}

do_start_mailhog() {
  echo_info "Starting Mailhog..."
  if [ "${DEPLOYMENT_MAILHOG_ENABLED}" == "false" ]; then
    echo_info "Mailhog not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Mailhog container ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} based on image ${DEPLOYMENT_MAILHOG_IMAGE}:${DEPLOYMENT_MAILHOG_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_MAILHOG_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    -e "MH_STORAGE=maildir" \
    -p "${DEPLOYMENT_MAILHOG_SMTP_PORT}:1025" \
    -p "${DEPLOYMENT_MAILHOG_HTTP_PORT}:8025" \
    -v ${DEPLOYMENT_MAILHOG_CONTAINER_NAME}:/maildir \
    --name ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} ${DEPLOYMENT_MAILHOG_IMAGE}:${DEPLOYMENT_MAILHOG_IMAGE_VERSION} -storage=maildir -maildir-path=/maildir
  echo_info "${DEPLOYMENT_MAILHOG_CONTAINER_NAME} container started"  

  check_mailhog_availability
}

check_mailhog_availability() {
  echo_info "Waiting for Mailhog availability on port ${DEPLOYMENT_MAILHOG_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_MAILHOG_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Mailhog not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Mailhog ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Mailhog ${DEPLOYMENT_MAILHOG_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_MAILHOG_LOADED=true
echo_debug "_function_mailhog.sh Loaded"