#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_LDAP_LOADED:-false} && return
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

do_get_ldap_settings() {  
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "false" ] || [ "${USER_DIRECTORY}" != "LDAP" ]; then
    return;
  fi
  env_var DEPLOYMENT_LDAP_CONTAINER_NAME "${INSTANCE_KEY}_ldap"
}

#
# Drops all Ldap data used by the instance.
#
do_drop_ldap_data() {
  echo_info "Dropping ldap data ..."
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "true" ] && [ "${USER_DIRECTORY}" == "LDAP" ]; then
    echo_info "Drops Ldap container ${DEPLOYMENT_LDAP_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_LDAP_CONTAINER_NAME}
    delete_docker_volume ${DEPLOYMENT_LDAP_CONTAINER_NAME}_data
    delete_docker_volume ${DEPLOYMENT_LDAP_CONTAINER_NAME}_conf
    echo_info "Done."
    echo_info "Ldap data dropped"
  else
    echo_info "Skip Drops Ldap container ..."
  fi
}

do_stop_ldap() {
  echo_info "Stopping Ldap ..."
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "false" ] || [ "${USER_DIRECTORY}" != "LDAP" ]; then
    echo_info "Ldap wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_LDAP_CONTAINER_NAME}
  echo_info "Ldap container ${DEPLOYMENT_LDAP_CONTAINER_NAME} stopped."
}

do_create_ldap() {
    ${DOCKER_CMD} volume create --name ${DEPLOYMENT_LDAP_CONTAINER_NAME}_data
    ${DOCKER_CMD} volume create --name ${DEPLOYMENT_LDAP_CONTAINER_NAME}_conf
}

do_start_ldap() {
  echo_info "Starting Ldap..."
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "false" ] || [ "${USER_DIRECTORY}" != "LDAP" ]; then
    echo_info "Ldap not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Ldap container ${DEPLOYMENT_LDAP_CONTAINER_NAME} based on image ${DEPLOYMENT_LDAP_IMAGE}:${DEPLOYMENT_LDAP_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_LDAP_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_LDAP_PORT}:389" \
    -e SLAPD_PASSWORD=exo  \
    -e SLAPD_DOMAIN=exoplatform.com  \
    -v ${HOME}/.eXo/Platform/LDAP/:/etc/ldap.dist/prepopulate  \
    -v ${DEPLOYMENT_LDAP_CONTAINER_NAME}_data:/etc/ldap \
    -v ${DEPLOYMENT_LDAP_CONTAINER_NAME}_conf:/var/lib/ldap \
    --name ${DEPLOYMENT_LDAP_CONTAINER_NAME} ${DEPLOYMENT_LDAP_IMAGE}:${DEPLOYMENT_LDAP_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_LDAP_CONTAINER_NAME} container started"  

  check_ldap_availability
}

check_ldap_availability() {
  echo_info "Waiting for Ldap availability on port ${DEPLOYMENT_LDAP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} ldap://localhost:${DEPLOYMENT_LDAP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Ldap not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Ldap ${DEPLOYMENT_LDAP_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Ldap ${DEPLOYMENT_LDAP_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_LDAP_LOADED=true
echo_debug "_function_ldap.sh Loaded"