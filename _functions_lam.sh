#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_LAM_LOADED:-false} && return
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

do_get_lam_settings() {  
  if [ "${DEPLOYMENT_LAM_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_LAM_CONTAINER_NAME "${INSTANCE_KEY}_lam"
}

#
# Drops all LDAP Account Manager data used by the instance.
#
do_drop_lam_data() {
  echo_info "Dropping LDAP Account Manager data ..."
  if [ "${DEPLOYMENT_LAM_ENABLED}" == "true" ]; then
    echo_info "Drops LDAP Account Manager container ${DEPLOYMENT_LAM_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_LAM_CONTAINER_NAME}
    echo_info "Done."
    echo_info "LDAP Account Manager data dropped"
  else
    echo_info "Skip Drops LDAP Account Manager container ..."
  fi
}

do_stop_lam() {
  echo_info "Stopping LDAP Account Manager ..."
  if [ "${DEPLOYMENT_LAM_ENABLED}" == "false" ]; then
    echo_info "LDAP Account Manager wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_LAM_CONTAINER_NAME}
  echo_info "LDAP Account Manager container ${DEPLOYMENT_LAM_CONTAINER_NAME} stopped."
}

do_start_lam() {
  echo_info "Starting LAM..."
  # No need to start LDAP Account Manager when LDAP integation is disabled
  if ! ${DEPLOYMENT_LDAP_ENABLED} && [ "${DEPLOYMENT_LAM_ENABLED}" == "true" ]; then
    echo_warn "LDAP disabled, skipping LDAP Account Manager creation..."
    return
  fi
  if [ "${DEPLOYMENT_LAM_ENABLED}" == "false" ]; then
    echo_info "LDAP Account Manager not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting LDAP Account Manager container ${DEPLOYMENT_LAM_CONTAINER_NAME} based on image ${DEPLOYMENT_LAM_IMAGE}:${DEPLOYMENT_LAM_IMAGE_VERSION}"

  # Refresh the image (the stable tag moves with PHP security fixes), fall back on the local one when offline
  ${DOCKER_CMD} pull ${DEPLOYMENT_LAM_IMAGE}:${DEPLOYMENT_LAM_IMAGE_VERSION} 2>/dev/null || true

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_LAM_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -e LAM_SKIP_PRECONFIGURE=false \
    -e LDAP_SERVER="${DEPLOYMENT_LDAP_LINK}" \
    -e LDAP_BASE="${USER_DIRECTORY_BASE_DN}" \
    -e LDAP_USER="${USER_DIRECTORY_ADMIN_DN}" \
    -e LAM_PASSWORD="${USER_DIRECTORY_ADMIN_PASSWORD}" \
    -e LDAP_USERS_DN="ou=People,o=portal,o=gatein,${USER_DIRECTORY_BASE_DN}" \
    -e LDAP_GROUPS_DN="ou=groups,${USER_DIRECTORY_BASE_DN}" \
    -v ${ETC_DIR}/php/php-certfr-2026-ale-014.ini:/etc/php/8.4/apache2/conf.d/zz-certfr-2026-ale-014.ini:ro \
    -p "127.0.0.1:${DEPLOYMENT_LAM_HTTP_PORT}:80" \
    --name ${DEPLOYMENT_LAM_CONTAINER_NAME} ${DEPLOYMENT_LAM_IMAGE}:${DEPLOYMENT_LAM_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_LAM_CONTAINER_NAME} container started"  
  check_lam_availability
}

check_lam_availability() {
  echo_info "Waiting for LDAP Account Manager availability on port ${DEPLOYMENT_LAM_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_LAM_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "LDAP Account Manager not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "LDAP Account Manager ${DEPLOYMENT_LAM_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "LDAP Account Manager ${DEPLOYMENT_LAM_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_LAM_LOADED=true
echo_debug "_function_lam.sh Loaded"