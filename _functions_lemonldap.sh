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
  env_var DEPLOYMENT_LEMONLDAP_CONTAINER_NAME "${INSTANCE_KEY}_lemonldap"
}

#
# Drops all LemonLdap data used by the instance.
#
do_drop_lemonldap_data() {
  echo_info "Dropping lemonldap data ..."
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "true" ]; then
    echo_info "Drops Lemonldap container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Lemonldap data dropped"
  else
    echo_info "Skip Drops Lemonldap container ..."
  fi
}

do_stop_lemonldap() {
  echo_info "Stopping Lemonldap ..."
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "false" ]; then
    echo_info "Lemonldap wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}
  echo_info "Lemonldap container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} stopped."
}

do_start_lemonldap() {
  echo_info "Starting Ldap..."
  if [ "${DEPLOYMENT_LEMONLDAP_ENABLED}" == "false" ]; then
    echo_info "Lemonldap not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Lemonldap container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} based on image ${DEPLOYMENT_LEMONLDAP_IMAGE}:${DEPLOYMENT_LEMONLDAP_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}

  echo_info "Start command: ${DOCKER_CMD} run -d -e SSODOMAIN=\"${DEPLOYMENT_EXT_HOST}\" -e MANAGER_HOSTNAME=\"manager.${DEPLOYMENT_EXT_HOST}\" -e HANDLER_HOSTNAME=\"handler.${DEPLOYMENT_EXT_HOST}\" -e LOGLEVEL=\"debug\" -e FASTCGI_LISTEN_PORT=\"\" --name ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} ${DEPLOYMENT_LEMONLDAP_IMAGE}:${DEPLOYMENT_LEMONLDAP_IMAGE_VERSION}"

  ${DOCKER_CMD} run \
    -d \
    -e SSODOMAIN="${DEPLOYMENT_EXT_HOST}"  \
    -e PORTAL_HOSTNAME="auth.${DEPLOYMENT_EXT_HOST}"  \
    -e MANAGER_HOSTNAME="manager.${DEPLOYMENT_EXT_HOST}"  \
    -e HANDLER_HOSTNAME="handler.${DEPLOYMENT_EXT_HOST}"  \
    -e TEST1_HOSTNAME="exo.${DEPLOYMENT_EXT_HOST}"  \
    -e LOGLEVEL="debug"  \
    -e FASTCGI_LISTEN_PORT=""  \
    --name ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} ${DEPLOYMENT_LEMONLDAP_IMAGE}:${DEPLOYMENT_LEMONLDAP_IMAGE_VERSION}

   echo_info "${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} container started"

  evaluate_file_content ${ETC_DIR}/lemonldap/conf/config.json.template ${DEPLOYMENT_DIR}/temp/configlemon.json

# Import lemon ldap configuration
cat ${DEPLOYMENT_DIR}/temp/configlemon.json | ${DOCKER_CMD} exec -t ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} /usr/share/lemonldap-ng/bin/lemonldap-ng-cli restore -

# restart lemon to be sure the configuration is uptodate
${DOCKER_CMD} restart --no-deps ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME}

  echo_info "${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} container started"  

  check_lemonldap_availability
}

check_lemonldap_availability() {
  echo_info "Waiting for Lemonldap availability on port ${DEPLOYMENT_LEMONLDAP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  #while [ $count -lt $try -a $RET -ne 0 ]; do
  #  count=$(( $count + 1 ))
 #   set +e
#
  #  curl -s -q --max-time ${wait_time} ldap://localhost:${DEPLOYMENT_LDAP_PORT}  > /dev/null
  #  RET=$?
  #  if [ $RET -ne 0 ]; then
  #    [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Lemonldap not yet available (${count} / ${try})..."    
  #    echo -n "."
  #    sleep $wait_time
  #  fi
  #  set -e
  #done
  #if [ $count -eq $try ]; then
  #  echo_error "Ldap ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
  #  exit 1
  #fi
  echo_info "LemonLdap ${DEPLOYMENT_LEMONLDAP_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_LEMONLDAP_LOADED=true
echo_debug "_function_lemonldap.sh Loaded"
