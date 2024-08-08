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
      check_mongodb_intermediate_upgrades
      ${DOCKER_CMD} pull ${DEPLOYMENT_CHAT_MONGODB_IMAGE}:${DEPLOYMENT_CHAT_MONGODB_VERSION}   
      local major_version=$(echo ${DEPLOYMENT_CHAT_MONGODB_VERSION} | grep -oP '^[1-9]+\.[0-9]+')
      local ga_version=$(echo ${DEPLOYMENT_CHAT_MONGODB_VERSION} | grep -oP '^[1-9]+')
      local mongo_cmd="mongo"
      if [ "${ga_version}" -ge "6" ]; then
        mongo_cmd="mongosh"
      fi
      ${DOCKER_CMD} run \
        -p "127.0.0.1:${DEPLOYMENT_CHAT_MONGODB_PORT}:27017" -d \
        -v ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}:/data/db \
        --health-cmd="${mongo_cmd} --eval 'quit(db.runCommand({ ping: 1 }).ok ? 0 : 2)' || exit 1" \
        --health-interval=30s \
        --health-timeout=30s \
        --health-retries=3 \
        --name ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} ${DEPLOYMENT_CHAT_MONGODB_IMAGE}:${DEPLOYMENT_CHAT_MONGODB_VERSION}
        check_mongodb_availability
        # Update feature compatibility version to support further mongodb upgrades
        set +e
        if [ "${ga_version}" -ge "6" ]; then 
          ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} mongosh --quiet --eval "db.adminCommand({setFeatureCompatibilityVersion: \"$major_version\"})" &>/dev/null
        else 
          ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} mongo --quiet --eval "db.adminCommand({setFeatureCompatibilityVersion: \"$major_version\"})" &>/dev/null
        fi
        set -e
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

check_mongodb_availability() {
  echo_info "Waiting for Mongodb availability on port ${DEPLOYMENT_CHAT_MONGODB_PORT}"
  local count=0
  local try=600
  local wait_time=60
  local RET=-1
  local VERSION=${1:-${DEPLOYMENT_CHAT_MONGODB_VERSION}}
  if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "DOCKER" ]; then 
    try=100
    wait_time=10
  fi
  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e
    if [ ${DEPLOYMENT_CHAT_MONGODB_TYPE} == "DOCKER" ]; then 
      local ga_version=$(echo ${VERSION} | grep -oP '^[1-9]+')
      if [ "${ga_version}" -ge "6" ]; then 
        ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} timeout ${wait_time} mongosh --quiet --eval "quit(db.runCommand({ ping: 1 }).ok ? 0 : 2)" &>/dev/null
      else
        ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} timeout ${wait_time} mongo --quiet --eval "quit(db.runCommand({ ping: 1 }).ok ? 0 : 2)" &>/dev/null
      fi
    else 
      nc -z -w ${wait_time} localhost ${DEPLOYMENT_CHAT_MONGODB_PORT} > /dev/null
    fi
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Mongodb not yet available (${count} / ${try})..."
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Mongodb ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Mongodb ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} up and available"
}

check_mongodb_intermediate_upgrades() {
  echo_info "Checking for intermediate mongodb upgrades"
  if [ -z "${DEPLOYMENT_CHAT_INTERMEDIATE_MONGODB_UPGRADE_VERSIONS:-}" ]; then 
    echo_info "No intermediate upgrade is required. Skipped!"
    return 0
  fi
  echo_info "Starting intermediate Upgrades"
  local counter=0 
  local upgrades_length=$(echo ${DEPLOYMENT_CHAT_INTERMEDIATE_MONGODB_UPGRADE_VERSIONS} | wc -w)
  for mongoversion in ${DEPLOYMENT_CHAT_INTERMEDIATE_MONGODB_UPGRADE_VERSIONS}; do 
    counter=$((counter+1))
    echo_info "Upgrade ($counter/$upgrades_length) to $mongoversion"
    ${DOCKER_CMD} pull ${DEPLOYMENT_CHAT_MONGODB_IMAGE}:${mongoversion}
    ${DOCKER_CMD} run \
      -p "127.0.0.1:${DEPLOYMENT_CHAT_MONGODB_PORT}:27017" -d \
      -v ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}:/data/db \
      --name ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} ${DEPLOYMENT_CHAT_MONGODB_IMAGE}:${mongoversion}
      check_mongodb_availability $mongoversion
      # Update feature compatibility version to support further mongodb upgrades
      local major_version=$mongoversion
      local ga_version=$(echo ${mongoversion} | grep -oP '^[1-9]+')
      set +e
      if [ "${ga_version}" -ge "6" ]; then 
        ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} mongosh --quiet --eval "db.adminCommand({setFeatureCompatibilityVersion: \"$major_version\"})" &>/dev/null
      else 
        ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} mongo --quiet --eval "db.adminCommand({setFeatureCompatibilityVersion: \"$major_version\"})" &>/dev/null
      fi
      set -e
      delete_docker_container ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}
      echo_info "$mongoversion upgrade done."
  done 
  echo_info "Mongo intermediate upgrades done."
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
    delete_docker_volume ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}
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


do_restore_chat_mongo_dataset() {
  do_drop_chat_database
  do_start_chat_server
  local _dumpfile="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/chat.dump"
  local _dbnamefile="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/chat.name"
  case ${DEPLOYMENT_CHAT_MONGODB_TYPE} in
    DOCKER)
      if [ ! -e ${_dumpfile} ]; then
        echo_error "Mongo dump file (${_dumpfile}) doesn't exist."
        exit 1
      fi;
      local dbname="chat"
      [ -f "$_dbnamefile" -a -s "$_dbnamefile" ] && dbname=$(cat $_dbnamefile)
      echo_info "Restauring dump file to mongo server..."
      ${DOCKER_CMD} cp ${_dumpfile} ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME}:/tmp/
      ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} mongorestore --nsFrom "${dbname}.*" --nsTo "${DEPLOYMENT_CHAT_MONGODB_NAME}.*" --quiet --archive=/tmp/chat.dump
      echo_info "Done."
      do_stop_chat_server
    ;;
    *)
      echo_error "Dataset restoration isn't supported for chat mongo type \"${DEPLOYMENT_CHAT_MONGODB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  rm -rf ${_dumpfile}
}

do_dump_chat_mongo_dataset() {
  do_start_chat_server
  local _dumpfile="$1/chat.dump"
  local _dbnamefile="$1/chat.name"
  case ${DEPLOYMENT_CHAT_MONGODB_TYPE} in
    DOCKER)
      echo_info "Generating dump file from mongo server..."
      ${DOCKER_CMD} exec ${DEPLOYMENT_CHAT_MONGODB_CONTAINER_NAME} mongodump --archive --db ${DEPLOYMENT_CHAT_MONGODB_NAME} > ${_dumpfile}
      echo ${DEPLOYMENT_CHAT_MONGODB_NAME} > ${_dbnamefile}
      echo_info "Done."
      do_stop_chat_server
    ;;
    *)
      echo_error "Dataset backup isn't supported for chat mongo type \"${DEPLOYMENT_CHAT_MONGODB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}


# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CHAT_LOADED=true
echo_debug "_functions_chat.sh Loaded"
