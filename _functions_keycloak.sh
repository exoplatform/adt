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
  if [ "${DEPLOYMENT_KEYCLOAK_MODE:-SAML}" = "SAML" ]; then 
    evaluate_file_content ${ETC_DIR}/keycloak/client_saml2_def.json.template ${DEPLOYMENT_DIR}/client_def.json
  else
    evaluate_file_content ${ETC_DIR}/keycloak/client_openid_def.json.template ${DEPLOYMENT_DIR}/client_def.json
  fi
  local _startArgs=""
  if ${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED:-false}; then 
    _startArgs="--proxy-headers=xforwarded --hostname-strict=false"
  fi
  ${DOCKER_CMD} run \
  -d \
  -e KEYCLOAK_ADMIN=root \
  -e KEYCLOAK_ADMIN_PASSWORD=password \
  -e PROXY_ADDRESS_FORWARDING=${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED:-false} \
  -e KC_HTTP_RELATIVE_PATH=/auth \
  -p "${DEPLOYMENT_KEYCLOAK_HTTP_PORT}:8080" \
  -v ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME}:/opt/keycloak/data \
  --health-cmd="timeout 2 /bin/bash -c '</dev/tcp/localhost/8080' || exit 1" \
  --health-interval=30s \
  --health-timeout=30s \
  --health-retries=3 \
  --name ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} ${DEPLOYMENT_KEYCLOAK_IMAGE}:${DEPLOYMENT_KEYCLOAK_IMAGE_VERSION} start-dev ${_startArgs}
  echo_info "${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME} container started"  
  check_keycloak_availability
  local token=$(curl -X POST "http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}/auth/realms/master/protocol/openid-connect/token" \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -d "username=root" \
   -d "password=password" \
   -d 'grant_type=password' \
   -d 'client_id=admin-cli' | jq -r '.access_token')

  local keycloakRootUserId=$(curl -fssL "http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}/auth/admin/realms/master/users" -H 'Content-Type: application/json' -H  "Authorization: Bearer $token" | jq -r '.[]| select(.username == "root") | .id')
  local keycloakCreatedTimestamp=$(curl -fssL "http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}/auth/admin/realms/master/users" -H 'Content-Type: application/json' -H  "Authorization: Bearer $token" | jq -r '.[]| select(.username == "root") | .createdTimestamp')

  curl -s -X PUT --output /dev/null "http://localhost:${DEPLOYMENT_KEYCLOAK_HTTP_PORT}/auth/admin/realms/master/users/${keycloakRootUserId}" \
   -H 'Content-type: application/json' \
   -H "Authorization: Bearer ${token}" \
   -d "{\"id\":\"${keycloakRootUserId}\",\"createdTimestamp\":${keycloakCreatedTimestamp},\"username\":\"root\",\"enabled\":true,\"totp\":false,\"emailVerified\":false,\"disableableCredentialTypes\":[],\"requiredActions\":[],\"notBefore\":0,\"access\":{\"manageGroupMembership\":true,\"view\":true,\"mapRoles\":true,\"impersonate\":true,\"manage\":true},\"attributes\":{},\"email\":\"root@gatein.com\",\"firstName\":\"Root\",\"lastName\":\"Root\"}" \
    && echo_info "Keycloak root user updated"
  
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

# Restore dataset
do_restore_keycloak_dataset() {
  do_drop_keycloak_data
  do_create_keycloak
  local _keycloakData="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/keycloak"
  if [ ! -d ${_keycloakData} ]; then
    echo_warn "Keycloak data (${_keycloakData}) don't exist."
    return 0
  fi
  local mount_point=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME})
  sudo mv -v ${_keycloakData}/* ${mount_point}/ >/dev/null
  sudo chown 1000:1000 -R ${mount_point}
  rm -rf ${_keycloakData}
}

# Dump dataset
do_dump_keycloak_dataset() {
  local _keycloakData="$1/keycloak"
  mkdir -p ${_keycloakData}
  local mount_point=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_KEYCLOAK_CONTAINER_NAME})
  sudo chown 1000:1000 -R ${mount_point}
  sudo cp -fTr "${mount_point}/" ${_keycloakData}/ || touch ${_keycloakData}/__nofile
}


# #############################################################################
# Env var to not load it several times
_FUNCTIONS_KEYCLOAK_LOADED=true
echo_debug "_function_keycloak.sh Loaded"