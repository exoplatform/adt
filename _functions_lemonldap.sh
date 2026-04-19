#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_LEMONLDAP_LOADED:-false} && return
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

do_get_lemonldap_settings() {  
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_LEMONLDAP_CONTAINER_NAME "${INSTANCE_KEY}_LemonLDAP"
}

#
# Drops all LemonLDAP-NG data used by the instance.
#
do_drop_lemonldap_data() {
  echo_info "Dropping LemonLDAP-NG data ..."
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "true" ]; then
    echo_info "Drops LemonLDAP-NG container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
    delete_docker_volume ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
    echo_info "Done."
    echo_info "LemonLDAP-NG data dropped"
  else
    echo_info "Skip Drops LemonLDAP-NG container ..."
  fi
}

do_create_lemonldap() {
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "true" ]; then
    echo_info "Creation of the LemonLDAP-NG Docker volume ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} ..."
    create_docker_volume ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
  fi
}

do_stop_lemonldap() {
  echo_info "Stopping LemonLDAP-NG ..."
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "false" ]; then
    echo_info "LemonLDAP-NG wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
  echo_info "LemonLDAP-NG container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} stopped."
}

do_start_lemonldap() {
  echo_info "Starting LemonLDAP-NG..."
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "false" ]; then
    echo_info "LemonLDAP-NG not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting LemonLDAP-NG container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} based on image ${DEPLOYMENT_LEMONLDAP_IMAGE}:${DEPLOYMENT_LEMONLDAP_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
  env_var DEP_URL "$(echo ${DEPLOYMENT_URL} | sed -e 's/\(.*\)/\L\1/')"

  if [ "${DEPLOYMENT_LEMONLDAP_MODE:-SAML}" = "SAML" ]; then
    evaluate_file_content ${ETC_DIR}/lemonldap/application_saml2_def.json.template ${DEPLOYMENT_DIR}/lemonldap_app_def.json
  else
    evaluate_file_content ${ETC_DIR}/lemonldap/application_openid_def.json.template ${DEPLOYMENT_DIR}/lemonldap_app_def.json
  fi

  ${DOCKER_CMD} run \
  -d \
  -e SSOWAT_DOMAIN=localhost \
  -e SSOWAT_PORTAL_HOSTNAME=auth.localhost \
  -e LEMONLDAP_ADMIN_USER=admin \
  -e LEMONLDAP_ADMIN_PASSWORD=admin123 \
  -p "${DEPLOYMENT_LEMONLDAP_HTTP_PORT}:80" \
  -v ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}:/var/lib/lemonldap-ng \
  --health-cmd="curl -fs http://localhost/manager.html || exit 1" \
  --health-interval=30s \
  --health-timeout=30s \
  --health-retries=3 \
  --name ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} ${DEPLOYMENT_LEMONLDAP_IMAGE}:${DEPLOYMENT_LEMONLDAP_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} container started"
  check_lemonldap_availability
  do_provision_lemonldap_admin
  do_provision_lemonldap_application
}

check_lemonldap_availability() {
  echo_info "Waiting for LemonLDAP-NG availability on port ${DEPLOYMENT_LEMONLDAP_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_LEMONLDAP_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "LemonLDAP-NG not yet available (${count} / ${try})..."
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "LemonLDAP-NG ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "LemonLDAP-NG ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} up and available"
}

# Restore dataset
do_restore_lemonldap_dataset() {
  do_drop_lemonldap_data
  do_create_lemonldap
  local _lemonldapData="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/lemonldap"
  if [ ! -d ${_lemonldapData} ]; then
    echo_warn "LemonLDAP-NG data (${_lemonldapData}) don't exist."
    return 0
  fi
  local mount_point=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME})
  sudo mv -v ${_lemonldapData}/* ${mount_point}/ >/dev/null
  sudo chown 1000:1000 -R ${mount_point}
  rm -rf ${_lemonldapData}
}

# Dump dataset
do_dump_lemonldap_dataset() {
  local _lemonldapData="$1/lemonldap"
  mkdir -p ${_lemonldapData}
  local mount_point=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME})
  sudo chown 1000:1000 -R ${mount_point}
  sudo cp -fTr "${mount_point}/" ${_lemonldapData}/ || touch ${_lemonldapData}/__nofile
}

# Provision LemonLDAP-NG admin user (change default admin password)
do_provision_lemonldap_admin() {
  local LLNG_BASE_URL="http://localhost:${DEPLOYMENT_LEMONLDAP_HTTP_PORT}"
  echo_info "Provisioning LemonLDAP-NG admin account..."
  local llngcookies_file=$(mktemp)
  # Obtain a session token using the default bootstrap credentials
  local _session=$(curl -s -c $llngcookies_file -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "user=admin&password=admin123" \
    "${LLNG_BASE_URL}/manager/api/v1/session" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ -z "${_session}" ]; then
    echo_warn "Could not obtain LemonLDAP-NG session — admin provisioning skipped."
    return 0
  fi

  echo_info "LemonLDAP-NG session obtained: ${_session}"

  # Set a permanent root/password admin account via the REST manager API
  local _resp=$(curl -s -o /dev/null -w "%{http_code}" \
    -b $llngcookies_file \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"password\"}" \
    "${LLNG_BASE_URL}/manager/api/v1/users/root/password")

  if [ "${_resp}" -eq 200 ] || [ "${_resp}" -eq 201 ]; then
    echo_info "LemonLDAP-NG root password set successfully."
  else
    echo_warn "LemonLDAP-NG root password setup returned HTTP ${_resp} — continuing."
  fi
  rm -f $llngcookies_file
}

# Provision LemonLDAP-NG application (SAML2 SP or OpenID Connect RP)
do_provision_lemonldap_application() {
  local LLNG_BASE_URL="http://localhost:${DEPLOYMENT_LEMONLDAP_HTTP_PORT}"
  echo_info "Provisioning LemonLDAP-NG application (mode: ${DEPLOYMENT_LEMONLDAP_MODE:-SAML})..."
  local llngcookies_file=$(mktemp)
  # Obtain manager session
  local _session=$(curl -s -c $llngcookies_file -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "user=admin&password=admin123" \
    "${LLNG_BASE_URL}/manager/api/v1/session" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ -z "${_session}" ]; then
    echo_warn "Could not obtain LemonLDAP-NG session — application provisioning skipped."
    return 0
  fi

  if [ "${DEPLOYMENT_LEMONLDAP_MODE:-SAML}" = "SAML" ]; then
    # Register SAML2 Service Provider
    local _resp=$(curl -s -o /dev/null -w "%{http_code}" \
      -b $llngcookies_file \
      -X POST \
      -H "Content-Type: application/json" \
      -d "@${DEPLOYMENT_DIR}/lemonldap_app_def.json" \
      "${LLNG_BASE_URL}/manager/api/v1/saml/serviceProviders")
    echo_info "LemonLDAP-NG SAML2 SP registration returned HTTP ${_resp}"
  else
    # Register OpenID Connect Relying Party
    local _resp=$(curl -s -o /dev/null -w "%{http_code}" \
      -b $llngcookies_file \
      -X POST \
      -H "Content-Type: application/json" \
      -d "@${DEPLOYMENT_DIR}/lemonldap_app_def.json" \
      "${LLNG_BASE_URL}/manager/api/v1/oidc/relayingParties")
    echo_info "LemonLDAP-NG OpenID Connect RP registration returned HTTP ${_resp}"
  fi

  # Apply configuration
  curl -s -o /dev/null -w "%{http_code}" \
    -b $llngcookies_file \
    -X POST \
    "${LLNG_BASE_URL}/manager/api/v1/configuration/apply" || true
  echo_info "LemonLDAP-NG configuration applied."
  rm -f $llngcookies_file
}


# #############################################################################
# Env var to not load it several times
_FUNCTIONS_LEMONLDAP_LOADED=true
echo_debug "_function_lemonldap.sh Loaded"
