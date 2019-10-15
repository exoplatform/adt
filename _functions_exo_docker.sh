#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_EXO_DOCKER_LOADED:-false} && return
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

do_get_exo_docker_settings() {
  if ! ${DEPLOY_EXO_DOCKER}; then
    return;
  fi
  env_var DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME "${INSTANCE_KEY}_exo"
}

#
# Drops all exo docker data used by the instance.
#
do_drop_exo_docker_data() {
  echo_info "Dropping exo docker data ..."
  if ${DEPLOY_EXO_DOCKER}; then
    echo_info "Drops Exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs ..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data ..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data
    echo_info "Done."
    echo_info "exo docker data dropped"
  else
    echo_info "Skip Drops exo docker container ..."
  fi
}

do_create_exo_docker() {
  if ${DEPLOY_EXO_DOCKER}; then
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data    
  fi
}

do_stop_exo_docker() {
  echo_info "Stopping Exo docker ..."
  if ! ${DEPLOY_EXO_DOCKER}; then
    echo_info "Exo wasn't deployed in docker, skiping exo docker shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}
  echo_info "Exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} stopped."
}

do_start_exo_docker() {
  echo_info "Starting Exo docker..."
  if ! ${DEPLOYMENT_EXO_DOCKER_ENABLED}; then
    echo_info "Exo wasn't deployed in docker, skiping exo docker startup"
    return
  fi

  
  echo_info "Starting exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} based on image ${DEPLOYMENT_EXO_DOCKER_IMAGE}:${DEPLOYMENT_EXO_DOCKER_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}

${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_HTTP_PORT}:8080" \
    -p "${DEPLOYMENT_AJP_PORT}:8443" \
    -p "10001:10001"
    -p "10002:10002"
    -e EXO_REGISTRATION="${DEPLOYMENT_SKIP_REGISTER}" \ #check how to negate
    -e EXO_ADDONS_LIST="${DEPLOYMENT_ADDONS}" \
    -e EXO_ADDONS_REMOVE_LIST="${DEPLOYMENT_ADDONS_TOREMOVE}" \
    -e EXO_ADDONS_CATALOG_URL="${DEPLOYMENT_ADDONS_CATALOG}" \
    -e EXO_PATCHES_CATALOG_URL="${DEPLOYMENT_PATCHES_CATALOG}" \
    -e EXO_PATCHES_LIST="${DEPLOYMENT_PATCHES}" \
    -e EXO_JVM_SIZE_MAX="${DEPLOYMENT_JVM_SIZE_MAX}" \
    -e EXO_JVM_SIZE_MIN="${DEPLOYMENT_JVM_SIZE_MIN}" \  
    -e EXO_PROXY_VHOST="${DEPLOYMENT_APACHE_VHOST_ALIAS}" \
    -e EXO_DATA_DIR="${DEPLOYMENT_DATA_DIR}" \
    -e EXO_JODCONVERTER_PORTS="${DEPLOYMENT_JOD_CONVERTER_PORTS}" \
    -e EXO_DB_TYPE="${DEPLOYMENT_DATABASE_TYPE}" \
    -e EXO_DB_NAME="${DEPLOYMENT_DATABASE_NAME}" \
    -e EXO_DB_USER="${DEPLOYMENT_DATABASE_USER}" \
    -e EXO_DB_PASSWORD="${DEPLOYMENT_DATABASE_USER}" \
    -e EXO_DB_HOST="${DEPLOYMENT_DATABASE_HOST}" \
    -e EXO_DB_PORT="${DEPLOYMENT_DATABASE_PORT}" \
    -e EXO_MONGO_HOST="${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}" \
    -e EXO_MONGO_PORT="${DEPLOYMENT_CHAT_MONGODB_PORT}" \
    -e EXO_MONGO_DB_NAME="${DEPLOYMENT_CHAT_MONGODB_NAME}" \
    -e EXO_ES_EMBEDDED="${DEPLOYMENT_ES_EMBEDDED}" \	
    -e EXO_ES_HOST="${DEPLOYMENT_ES_CONTAINER_NAME}" \
    -e EXO_ES_PORT="${DEPLOYMENT_ES_HTTP_PORT}" \
    -e EXO_MAIL_FROM="${EXO_EMAIL_FROM}" \
    -e EXO_MAIL_SMTP_HOST="${EXO_EMAIL_SMTP_HOST}" \
    -e EXO_MAIL_SMTP_PORT="${EXO_EMAIL_SMTP_PORT}" \
    -e EXO_MAIL_SMTP_STARTTLS="${EXO_EMAIL_SMTP_STARTTLS_ENABLE}" \
    -e EXO_JMX_ENABLED: "true" \
    -e EXO_JMX_RMI_REGISTRY_PORT: 10001 \
    -e EXO_JMX_RMI_SERVER_PORT: 10002 \
    -e EXO_JMX_RMI_SERVER_HOSTNAME: "${DEPLOYMENT_EXT_HOST}" \
    -v ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data:/srv/exo:rw \
    -v ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs:/var/log/exo:rw \
    -v "${DEPLOYMENT_DIR}/${DEPLOYMENT_CODEC_DIR}":/opt/exo/gatein/conf/codec:rw \
    --link "${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}" \
    --link "${DEPLOYMENT_CONTAINER_NAME}" \
    --link "${DEPLOYMENT_ES_CONTAINER_NAME}" \
    --name ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} ${DEPLOYMENT_EXO_DOCKER_IMAGE}:${DEPLOYMENT_EXO_DOCKER_IMAGE_VERSION}

  echo_info "${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} container started"

  check_exo_docker_availability
}

check_exo_docker_availability() {  
  END_STARTUP_MSG="Server startup in"
  DEPLOYMENT_LOG_PATH="${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs/exo/platform.log"
  while [ true ];
  do
    if [ -e "${DEPLOYMENT_LOG_PATH}" ]; then
      break
    fi
    sleep 1
  done
  # Display logs
  tail -f "${DEPLOYMENT_LOG_PATH}" &
  local _tailPID=$!
  # Check for the end of startup
  set +e
  while [ true ];
  do
    if grep -q "${END_STARTUP_MSG}" "${DEPLOYMENT_LOG_PATH}"; then
      kill ${_tailPID}
      wait ${_tailPID} 2> /dev/null
      break
    fi
    sleep 1
  done
  set -e
  cd -
  echo_info "Server started"
  echo_info "URL  : ${DEPLOYMENT_URL}"
  echo_info "Logs : ${DEPLOYMENT_LOG_URL}"
  echo_info "JMX  : ${DEPLOYMENT_JMX_URL}"  
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_EXO_DOCKER_LOADED=true
echo_debug "_functions_onlyoffice.sh Loaded"
