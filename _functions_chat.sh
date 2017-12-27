#!/bin/bash -eux

# Don't load it several times
set +u
${_FUNCTIONS_CHAT_LOADED:-false} && return
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

# #############################################################################
# Load shared functions
# #############################################################################
source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"

do_get_chat_settings() {
  if ! ${DEPLOYMENT_CHAT_ENABLED}; then
    return;
  fi

  # Build a database name without dot, minus ...
  env_var DEPLOYMENT_CHAT_MONGODB_NAME "${INSTANCE_KEY}"
  env_var DEPLOYMENT_CHAT_MONGODB_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME//./_}"
  env_var DEPLOYMENT_CHAT_MONGODB_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME//-/_}"

  env_var DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME}_mongo"
  env_var DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME  "${DEPLOYMENT_CHAT_MONGODB_NAME}_chatserver"
}

do_start_chat_server() {
  if ${DEPLOYMENT_CHAT_ENABLED}; then
    if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "DOCKER" ]; then 
      echo_info "Starting chat server database ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} ..."
      delete_docker_container ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}

      ${DOCKER_CMD} run \
        -p "127.0.0.1:${DEPLOYMENT_CHAT_MONGODB_PORT}:27017" -d \
        -v ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}:/data/db \
        --name ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} ${DEPLOYMENT_CHAT_MONGODB_IMAGE}:${DEPLOYMENT_CHAT_MONGODB_VERSION}

    fi

    if ! ${DEPLOYMENT_CHAT_EMBEDDED}; then
      echo_info "Starting chat server standalone..."
      delete_docker_container ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}

      ${DOCKER_CMD} run \
        --link ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}:mongo \
        -p "127.0.0.1:${DEPLOYMENT_CHAT_SERVER_PORT}:8080" -d \
        -e CHAT_PASSPHRASE=${DEPLOYMENT_CHAT_MONGODB_NAME} \
        -e CHAT_MONGO_DB_NAME=${DEPLOYMENT_CHAT_MONGODB_NAME} \
        --name ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME} ${DEPLOYMENT_CHAT_SERVER_IMAGE}:${DEPLOYMENT_CHAT_SERVER_VERSION}

    fi

  fi
}

do_stop_chat_server() {
  if ${DEPLOYMENT_CHAT_ENABLED}; then
    if  ! ${DEPLOYMENT_CHAT_EMBEDDED}; then
      echo_info "Stopping chat server container ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}"
      ensure_docker_container_stopped ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}
    fi
    if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "DOCKER" ]; then 
      echo_info "Stopping chat server database container ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}"
      ensure_docker_container_stopped ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}
    fi
    echo_info "Done."
  fi
}

do_drop_chat_server_containers() {
  if ${DEPLOYMENT_CHAT_ENABLED}; then
    if  ! ${DEPLOYMENT_CHAT_EMBEDDED}; then
      echo_info "Dropping chat server container ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}"
      delete_docker_container ${DEPLOYMENT_CHAT_SERVER_CONTAINER_NAME}
    fi
    if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "DOCKER" ]; then 
      echo_info "Dropping chat server database container ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}"
      delete_docker_container ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}
    fi
    echo_info "Done."
  fi

}

do_drop_chat() {
  if ! ${DEPLOYMENT_CHAT_ENABLED}; then
    echo_info "Chat disabled, skipping chat cleanup..."
    return
  fi

  do_stop_chat_server
  do_drop_chat_server_containers
  do_drop_chat_database

}

do_init_empty_chat_database() {
  if ! ${DEPLOYMENT_CHAT_ENABLED}; then
    echo_info "Chat disabled, skipping chat database creation..."
    return
  fi

  echo_info "Initialize chat database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."

  do_drop_chat_database
  do_create_chat_database
}

do_configure_chat() {
  if ! ${DEPLOYMENT_CHAT_ENABLED}; then
    echo_info "Chat disabled, skipping chat database creation..."
    return
  fi

  if  ! ${DEPLOYMENT_CHAT_EMBEDDED}; then
    echo_info "Copy temporary chat.properties for addon client..."
    cp -v ${ETC_DIR}/chat/chat-standalone.properties ${DEPLOYMENT_SETTINGS_DIR}/chat.properties
    echo_info "Done."
  fi
}

do_create_chat_database() {
  if ! ${DEPLOYMENT_CHAT_ENABLED}; then
    echo_info "Chat disabled, skipping chat database creation..."
    return
  fi

  echo_info "Creating chat database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."
  if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "HOST" ]; then  
    do_create_chat_mongo_database
  else
    echo_info "Creating docker volume ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}"
    create_docker_volume ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}
  fi

  echo_info "Done."  
}

do_drop_chat_database() {
  if ! ${DEPLOYMENT_CHAT_ENABLED}; then
    echo_info "Chat disabled, skipping chat database drop..."
    return
  fi

  echo_info "Drops MongoDB database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."
  if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "HOST" ]; then  
    do_drop_chat_mongo_database
  else
    echo_info "Removing docker volume ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}"
    delete_docker_container ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}
  fi
  echo_info "Done."
}

#
# Creates a MongoDB database for the instance. Don't drop it if it already exists.
#
do_create_chat_mongo_database() {
  if [ ! command -v mongo &>/dev/null ]; then
   echo_error "mongo binary doesn't exist on the system. Please install MongoDB client to be able to manage the MongoDB Server"
   exit 1
  fi;
  # Database are automatically created the first time we access it
  echo_info "Creating chat databse ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} in ${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}:${DEPLOYMENT_CHAT_MONGODB_PORT}..."
  mongo ${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}:${DEPLOYMENT_CHAT_MONGODB_PORT}/${DEPLOYMENT_CHAT_MONGODB_NAME} --quiet --eval "db.getCollectionNames()" > /dev/null
  echo 'show dbs' | mongo ${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}:${DEPLOYMENT_CHAT_MONGODB_PORT} --quiet
  echo_info "Done."
}

#
# Drops the MongoDB database used by the instance.
#
do_drop_chat_mongo_database() {
  set +u
  if [ ! command -v mongo &>/dev/null ]; then
   echo_error "mongo binary doesn't exist on the system. Please install MongoDB client to be able to manage the MongoDB Server"
   exit 1
  fi;

  echo_info "Drop chat databse ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} in ${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}:${DEPLOYMENT_CHAT_MONGODB_PORT}..."
  mongo ${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}:${DEPLOYMENT_CHAT_MONGODB_PORT}/${DEPLOYMENT_CHAT_MONGODB_NAME} --quiet --eval "db.dropDatabase()" > /dev/null
  echo 'show dbs' | mongo ${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}:${DEPLOYMENT_CHAT_MONGODB_PORT} --quiet
  echo_info "Done."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CHAT_LOADED=true
echo_debug "_functions_chat.sh Loaded"
