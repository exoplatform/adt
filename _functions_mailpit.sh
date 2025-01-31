#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_MAILPIT_LOADED:-false} && return
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

do_get_mailpit_settings() {  
  if [ "${DEPLOYMENT_MAILPIT_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_MAILPIT_CONTAINER_NAME "${INSTANCE_KEY}_mailpit"
}

#
# Drops all Mailpit data used by the instance.
#
do_drop_mailpit_data() {
  echo_info "Dropping mailpit data ..."
  if [ "${DEPLOYMENT_MAILPIT_ENABLED}" == "true" ]; then
    echo_info "Drops Mailpit container ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_MAILPIT_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Drops Mailpit docker volume ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} ..."
    delete_docker_volume ${DEPLOYMENT_MAILPIT_CONTAINER_NAME}
    echo_info "Mailpit data dropped"
  else
    echo_info "Skip Drops Mailpit container ..."
  fi
}

do_create_mailpit() {
  if [ "${DEPLOYMENT_MAILPIT_ENABLED}" == "true" ]; then
    echo_info "Creation of the Mailpit Docker volume ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} ..."
    create_docker_volume ${DEPLOYMENT_MAILPIT_CONTAINER_NAME}
    echo_info "Mailpit Docker volume ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} created"
  fi
}

do_stop_mailpit() {
  echo_info "Stopping Mailpit ..."
  if [ "${DEPLOYMENT_MAILPIT_ENABLED}" == "false" ]; then
    echo_info "Mailpit wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_MAILPIT_CONTAINER_NAME}
  echo_info "Mailpit container ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} stopped."
}

do_start_mailpit() {
  echo_info "Starting Mailpit..."
  if [ "${DEPLOYMENT_MAILPIT_ENABLED}" == "false" ]; then
    echo_info "Mailpit not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Mailpit container ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} based on image ${DEPLOYMENT_MAILPIT_IMAGE}:${DEPLOYMENT_MAILPIT_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_MAILPIT_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    --network "${DEPLOYMENT_MATRIX_NETWORK_NAME}" \
    -d \
    -p "${DEPLOYMENT_MAILPIT_SMTP_PORT}:1025" \
    -p "${DEPLOYMENT_MAILPIT_HTTP_PORT}:8025" \
    -v ${DEPLOYMENT_MAILPIT_CONTAINER_NAME}:/data \
    -e "MP_MAX_MESSAGES=5000" \
    -e "MP_DATABASE=/data/mailpit.db" \
    --health-cmd="printf 'EHLO healthcheck\n' | nc 127.0.0.1 1025 | grep -qE '^220.*Mailpit ESMTP' || exit 1" \
    --health-interval=30s \
    --health-timeout=30s \
    --health-retries=3 \
    --name ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} ${DEPLOYMENT_MAILPIT_IMAGE}:${DEPLOYMENT_MAILPIT_IMAGE_VERSION} \
    --webroot=/mailpit
  echo_info "${DEPLOYMENT_MAILPIT_CONTAINER_NAME} container started"  
  check_mailpit_availability
}

check_mailpit_availability() {
  echo_info "Waiting for Mailpit availability on port ${DEPLOYMENT_MAILPIT_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_MAILPIT_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Mailpit not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Mailpit ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Mailpit ${DEPLOYMENT_MAILPIT_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_MAILPIT_LOADED=true
echo_debug "_function_mailpit.sh Loaded"