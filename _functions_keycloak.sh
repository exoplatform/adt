#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_KEYCLOAK_LOADED:-false} && return
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

do_get_keycloak_settings() {  
  if [ "${DEPLOYMENT_KEYCLOAK_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_KEYCLOAK_CONTAINER_NAME "${INSTANCE_KEY}_Keycloak"
}

#
# Drops all Keycloak data used by the instance.
#
do_drop_keycloak_data() {
  echo_info "Dropping Keycloak data ..."
  if [ "${DEPLOYMENT_KEYCLOAK_ENABLED}" == "true" ]; then
    echo_info "Drops Keycloak container ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}
    delete_docker_volume ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Keycloak data dropped"
  else
    echo_info "Skip Drops Keycloak container ..."
  fi
}

do_create_keycloak() {
  if [ "${DEPLOYMENT_KEYCLOAK_ENABLED}" == "true" ]; then
    echo_info "Creation of the Keycloak Docker volume ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} ..."
    create_docker_volume ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}
  fi  
}

do_stop_keycloak() {
  echo_info "Stopping Keycloak ..."
  if [ "${DEPLOYMENT_KEYCLOAK_ENABLED}" == "false" ]; then
    echo_info "Keycloak wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}
  echo_info "Keycloak container ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} stopped."
}

do_start_keycloak() {
  echo_info "Starting Keycloak..."
  if [ "${DEPLOYMENT_KEYCLOAK_ENABLED}" == "false" ]; then
    echo_info "Keycloak not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Keycloak container ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} based on image ${DEPLOYMENT_KEYCLOAK_IMAGE}:${DEPLOYMENT_KEYCLOAK_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}
  env_var DEP_URL "$(echo ${DEPLOYMENT_URL} | sed -e 's/\(.*\)/\L\1/')"
  evaluate_file_content ${ETC_DIR}/keycloak/client_def.json.template ${DEPLOYMENT_DIR}/client_def.json
  ${DOCKER_CMD} run \
  -d \
  -e KEYCLOAK_USER=root \
  -e KEYCLOAK_PASSWORD=password \
  -e PROXY_ADDRESS_FORWARDING=${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED:-false} \
  -p "${DEPLOYMENT_KEYCLOAK_HTTP_PORT}:8080" \
  -v ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}:/opt/jboss/keycloak/standalone/data \
  --name ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} ${DEPLOYMENT_KEYCLOAK_IMAGE}:${DEPLOYMENT_KEYCLOAK_IMAGE_VERSION} \
  -Djboss.http.port=8080
  echo_info "${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} container started"  
  check_keycloak_availability
  local token=$(curl -X POST "http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}/auth/realms/master/protocol/openid-connect/token" \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -d "username=root" \
   -d "password=password" \
   -d 'grant_type=password' \
   -d 'client_id=admin-cli' | jq -r '.access_token')
  curl -s -X POST --output /dev/null "http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}/auth/admin/realms/master/clients" \
   -H 'Content-type: application/json' \
   -H "Authorization: Bearer ${token}" \
   -d "@${DEPLOYMENT_DIR}/client_def.json" && echo_info "Keycloak client added"
}

check_keycloak_availability() {
  echo_info "Waiting for Keycloak availability on port ${DEPLOYMENT_KEYCLOAK_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Keycloak not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Keycloak ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Keycloak ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_KEYCLOAK_LOADED=true
echo_debug "_function_keycloak.sh Loaded"