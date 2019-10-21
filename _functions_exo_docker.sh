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
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_codec..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_codec
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
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_codec ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_codec
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data    
  fi
}

do_configure_exo_docker_ldap(){
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "true" ]; then
    echo_info "Start Deploying Directory ${USER_DIRECTORY} conf ..."      
    mkdir -p ${DEPLOYMENT_DIR}/gatein/conf/portal/portal
    env_var LDAP_HOST "ldap"
    env_var DEPLOYMENT_LDAP_PORT "389"
    cp ${ETC_DIR}/gatein/portal/portal/configuration.xml ${DEPLOYMENT_DIR}/gatein/conf/portal/portal/configuration.xml
    evaluate_file_content ${ETC_DIR}/gatein/portal/portal/idm-configuration.xml.template ${DEPLOYMENT_DIR}/gatein/conf/portal/portal/idm-configuration.xml
    evaluate_file_content ${ETC_DIR}/gatein/portal/portal/picketlink-idm-${USER_DIRECTORY}-config.xml.template ${DEPLOYMENT_DIR}/gatein/conf/portal/portal/picketlink-idm-${USER_DIRECTORY}-config.xml
    echo_info "End Deploying Directory ${USER_DIRECTORY} conf ..."  
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
  local DOCKER_ARGS=""
  local DATABASE_TYPE=""
  DEPLOYMENT_LOG_PATH="${DEPLOYMENT_DIR}/logs/exo"
  if [ -e "${DEPLOYMENT_LOG_PATH}/platform.log" ]; then
      rm -rf ${DEPLOYMENT_LOG_PATH}/platform.log
  fi
  echo_info "Starting Exo docker..."
  if ! ${DEPLOY_EXO_DOCKER}; then
    echo_info "Exo wasn't deployed in docker, skiping exo docker startup"
    return
  fi
  mkdir -p ${DEPLOYMENT_DIR}/logs/exo
  echo_info "Starting exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} based on image ${DEPLOYMENT_EXO_DOCKER_IMAGE}:${DEPLOYMENT_EXO_DOCKER_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}  
  
  case "${DEPLOYMENT_DATABASE_TYPE}" in      
      DOCKER_MYSQL)
        DATABASE_TYPE="mysql"
      ;;      
      DOCKER_POSTGRES)
        DATABASE_TYPE="pgsql"
      ;;
      *)
        echo_error "${DEPLOYMENT_DATABASE_TYPE} not supported in eXoDocker"
        exit 1
      ;;
   esac
  
  DOCKER_ARGS="${DOCKER_ARGS} run -d"
  DOCKER_ARGS="${DOCKER_ARGS} -p ${DEPLOYMENT_HTTP_PORT}:8080"
  DOCKER_ARGS="${DOCKER_ARGS} -p ${DEPLOYMENT_AJP_PORT}:8443"
  DOCKER_ARGS="${DOCKER_ARGS} -p ${DEPLOYMENT_RMI_REG_PORT}:10001" 
  DOCKER_ARGS="${DOCKER_ARGS} -p ${DEPLOYMENT_RMI_SRV_PORT}:10002" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_REGISTRATION=false" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_ADDONS_LIST=${DEPLOYMENT_ADDONS}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_ADDONS_REMOVE_LIST=${DEPLOYMENT_ADDONS_TOREMOVE}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_ADDONS_CATALOG_URL=${DEPLOYMENT_ADDONS_CATALOG}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_PATCHES_CATALOG_URL=${DEPLOYMENT_PATCHES_CATALOG}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_PATCHES_LIST=${DEPLOYMENT_PATCHES}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_JVM_SIZE_MAX=${DEPLOYMENT_JVM_SIZE_MAX}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_JVM_SIZE_MIN=${DEPLOYMENT_JVM_SIZE_MIN}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_PROXY_VHOST=${DEPLOYMENT_APACHE_VHOST_ALIAS}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_DATA_DIR=/srv/exo" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_DB_TYPE=${DATABASE_TYPE}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_DB_NAME=${DEPLOYMENT_DATABASE_NAME}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_DB_USER=${DEPLOYMENT_DATABASE_USER}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_DB_PASSWORD=${DEPLOYMENT_DATABASE_USER}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MONGO_HOST=${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MONGO_PORT=${DEPLOYMENT_CHAT_MONGODB_PORT}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MONGO_DB_NAME=${DEPLOYMENT_CHAT_MONGODB_NAME}" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_ES_EMBEDDED=${DEPLOYMENT_ES_EMBEDDED}"   
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MAIL_FROM=noreply+acceptance@exoplatform.com" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MAIL_SMTP_HOST=localhost" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MAIL_SMTP_PORT=25" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_MAIL_SMTP_STARTTLS=false" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_JMX_ENABLED=true" 
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_JMX_RMI_REGISTRY_PORT=10001"
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_JMX_RMI_SERVER_PORT=10002"
  DOCKER_ARGS="${DOCKER_ARGS} -e EXO_JMX_RMI_SERVER_HOSTNAME=${DEPLOYMENT_EXT_HOST}" 
  DOCKER_ARGS="${DOCKER_ARGS} -v ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data:/srv/exo:rw"
  DOCKER_ARGS="${DOCKER_ARGS} -v ${DEPLOYMENT_DIR}/logs/exo:/var/log/exo:rw"
  if [ -e "${DEPLOYMENT_DIR}/exo.properties" ]; then
   DOCKER_ARGS="${DOCKER_ARGS} -v ${DEPLOYMENT_DIR}/exo.properties:/etc/exo/exo.properties"
  fi  
  DOCKER_ARGS="${DOCKER_ARGS} -v ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_codec:/etc/exo/codec/:rw"
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "true" ]; then
   DOCKER_ARGS="${DOCKER_ARGS} -v ${DEPLOYMENT_DIR}/gatein/conf/portal:/etc/exo/portal"
   DOCKER_ARGS="${DOCKER_ARGS} --link ${DEPLOYMENT_LDAP_CONTAINER_NAME}:ldap"
  fi
  DOCKER_ARGS="${DOCKER_ARGS} --link ${DEPLOYMENT_CONTAINER_NAME}:db" 
  if [ ! -z "${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}" ]; then
   DOCKER_ARGS="${DOCKER_ARGS} --link ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}:mongo"
  fi
  if ! ${DEPLOYMENT_ES_EMBEDDED}; then 
   DOCKER_ARGS="${DOCKER_ARGS} --link ${DEPLOYMENT_ES_CONTAINER_NAME}:search"
  fi
  DOCKER_ARGS="${DOCKER_ARGS} --name ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} ${DEPLOYMENT_EXO_DOCKER_IMAGE}:${DEPLOYMENT_EXO_DOCKER_IMAGE_VERSION}"

  ${DOCKER_CMD} ${DOCKER_ARGS}

echo_info "${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} container started"

check_exo_docker_availability
}

check_exo_docker_availability() {  
  END_STARTUP_MSG="Server startup in"
  DEPLOYMENT_LOG_PATH="${DEPLOYMENT_DIR}/logs/exo"
  local count=0
  local try=600
  local wait_time=1
  while [ $count -lt $try ];  
  do
  count=$(( $count + 1 ))
    if [ -e "${DEPLOYMENT_LOG_PATH}/platform.log" ]; then
      break
    fi
    echo -n "."
    sleep 1
  done

  if [ $count -eq $try ]; then
    echo_error "Exo ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} container's logs were not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi

  # Display logs
  tail -f "${DEPLOYMENT_LOG_PATH}/platform.log" &
  local _tailPID=$!
  # Check for the end of startup
  set +e
  while [ true ];
  do
    if grep -q "${END_STARTUP_MSG}" "${DEPLOYMENT_LOG_PATH}/platform.log"; then
      kill ${_tailPID}
      wait ${_tailPID} 2> /dev/null
      break
    fi
    sleep 1
  done
  set -e
  cd -
  DEPLOYMENT_JMX_URL="service:jmx:rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_SRV_PORT}/jndi/rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_REG_PORT}/jmxrmi"
  echo_info "Server started"
  echo_info "URL  : ${DEPLOYMENT_URL}"
  echo_info "Logs : ${DEPLOYMENT_LOG_URL}"
  echo_info "JMX  : ${DEPLOYMENT_JMX_URL}"  
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_EXO_DOCKER_LOADED=true
echo_debug "_functions_onlyoffice.sh Loaded"
