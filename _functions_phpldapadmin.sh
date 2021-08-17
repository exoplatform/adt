#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_PHPLDAPADMIN_LOADED:-false} && return
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

do_get_phpldapadmin_settings() {  
  if [ "${DEPLOYMENT_PHPLDAPADMIN_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME "${INSTANCE_KEY}_phpldapadmin"
}

do_stop_phpldapadmin() {
  echo_info "Stopping phpLDAPAdmin ..."
  if [ "${DEPLOYMENT_PHPLDAPADMIN_ENABLED}" == "false" ]; then
    echo_info "phpLDAPAdmin wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME}
  echo_info "phpLDAPAdmin container ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME} stopped."
}

do_start_phpldapadmin() {
  echo_info "Starting PHPLDAPADMIN..."
  # No need to start phpLDAPAdmin when LDAP integation is disabled
  if ! ${DEPLOYMENT_LDAP_ENABLED} && [ "${DEPLOYMENT_PHPLDAPADMIN_ENABLED}" == "true" ]; then
    echo_warn "LDAP disabled, skipping phpLDAPAdmin creation..."
    return
  fi
  if [ "${DEPLOYMENT_PHPLDAPADMIN_ENABLED}" == "false" ]; then
    echo_info "phpLDAPAdmin not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting phpLDAPAdmin container ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME} based on image ${DEPLOYMENT_PHPLDAPADMIN_IMAGE}:${DEPLOYMENT_PHPLDAPADMIN_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -e LDAP_URL="${DEPLOYMENT_LDAP_LINK}" \
    -e LDAP_BASE="${USER_DIRECTORY_BASE_DN}" \
    -e LDAP_ADMIN="${USER_DIRECTORY_ADMIN_DN}" \
    -p "${DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT}:80" \
    --name ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME} ${DEPLOYMENT_PHPLDAPADMIN_IMAGE}:${DEPLOYMENT_PHPLDAPADMIN_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME} container started"  
  check_phpldapadmin_availability
}

check_phpldapadmin_availability() {
  echo_info "Waiting for phpLDAPAdmin availability on port ${DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "phpLDAPAdmin not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "phpLDAPAdmin ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "phpLDAPAdmin ${DEPLOYMENT_PHPLDAPADMIN_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_PHPLDAPADMIN_LOADED=true
echo_debug "_function_phpldapadmin.sh Loaded"