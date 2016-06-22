#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DATABASE_LOADED:-false} && return
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

do_configure_datasource_file() {
  local FILE_TO_PATCH=$1
  local DB_SERVER_PATCH=$2
  local WORKING_FILE_PREFIX=${FILE_TO_PATCH}-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
  configurable_env_var "DB_DRIVER" ""

    # Reconfigure server.xml for Database
  if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp ${DB_SERVER_PATCH} ${WORKING_FILE_PREFIX}.patch
    echo_info "Applying on ${FILE_TO_PATCH} the patch $DB_SERVER_PATCH ..."
    cp ${FILE_TO_PATCH} ${WORKING_FILE_PREFIX}.ori
    patch -l -p0 ${FILE_TO_PATCH} < ${WORKING_FILE_PREFIX}.patch
    cp ${FILE_TO_PATCH} ${WORKING_FILE_PREFIX}.patched

    replace_in_file ${FILE_TO_PATCH} "@DB_JCR_USR@"   "${DEPLOYMENT_DATABASE_USER}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JCR_PWD@"   "${DEPLOYMENT_DATABASE_USER}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JCR_NAME@"  "${DEPLOYMENT_DATABASE_NAME}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JCR_HOST@"  "${DEPLOYMENT_DATABASE_HOST}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JCR_PORT@"  "${DEPLOYMENT_DATABASE_PORT}"
    replace_in_file ${FILE_TO_PATCH} "@DB_IDM_USR@"   "${DEPLOYMENT_DATABASE_USER}"
    replace_in_file ${FILE_TO_PATCH} "@DB_IDM_PWD@"   "${DEPLOYMENT_DATABASE_USER}"
    replace_in_file ${FILE_TO_PATCH} "@DB_IDM_NAME@"  "${DEPLOYMENT_DATABASE_NAME}"
    replace_in_file ${FILE_TO_PATCH} "@DB_IDM_HOST@"  "${DEPLOYMENT_DATABASE_HOST}"
    replace_in_file ${FILE_TO_PATCH} "@DB_IDM_PORT@"  "${DEPLOYMENT_DATABASE_PORT}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JPA_USR@"   "${DEPLOYMENT_DATABASE_USER}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JPA_PWD@"   "${DEPLOYMENT_DATABASE_USER}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JPA_NAME@"  "${DEPLOYMENT_DATABASE_NAME}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JPA_HOST@"  "${DEPLOYMENT_DATABASE_HOST}"
    replace_in_file ${FILE_TO_PATCH} "@DB_JPA_PORT@"  "${DEPLOYMENT_DATABASE_PORT}"

    replace_in_file ${FILE_TO_PATCH} "@DB_DRIVER@"  "${DB_DRIVER}"

    echo_info "Done."
  fi
}

do_get_database_settings() {
  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    # Build a database name without dot, minus ...
    env_var DEPLOYMENT_DATABASE_NAME "${INSTANCE_KEY}"
    env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//./_}"
    env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//-/_}"
    env_var DEPLOYMENT_CONTAINER_NAME "${DEPLOYMENT_DATABASE_NAME}"
    # Build a database user without dot, minus ... (using the branch because limited to 16 characters)
    env_var DEPLOYMENT_DATABASE_USER "${PRODUCT_NAME}_${PRODUCT_BRANCH}"
    env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//./_}"
    env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//-/_}"

    env_var "DEPLOYMENT_DATABASE_HOST" "localhost"
    case "${DEPLOYMENT_DATABASE_TYPE}" in
      MYSQL)
        env_var "DEPLOYMENT_DATABASE_PORT" "3306"

        if [ ! -e ${HOME}/.my.cnf ]; then
        echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
        exit 1
        fi;
      
        env_var "DATABASE_CMD" "mysql ${DEPLOYMENT_DATABASE_NAME}"
      ;;
      DOCKER_MYSQL)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "mysql"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        env_var "DATABASE_CMD" "${DOCKER_CMD} run -i --rm --link ${DEPLOYMENT_CONTAINER_NAME}:db ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION} mysql -h db -u ${DEPLOYMENT_DATABASE_USER} -p${DEPLOYMENT_DATABASE_USER} ${DEPLOYMENT_DATABASE_NAME}"

      ;;
      DOCKER_POSTGRES)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "postgres"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        env_var "DATABASE_CMD" "${DOCKER_CMD} exec -u postgres -i ${DEPLOYMENT_CONTAINER_NAME} psql"
      ;;
      DOCKER_ORACLE)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "exoplatform/oracle"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        # due to oracle limitation on SID
        env_var DEPLOYMENT_DATABASE_NAME "plf"
        env_var DEPLOYMENT_DATABASE_USER "plf" 

        env_var "DATABASE_CMD" "${DOCKER_CMD} exec -i ${DEPLOYMENT_CONTAINER_NAME} bin/sqlplus ${DEPLOYMENT_DATABASE_USER}/${DEPLOYMENT_DATABASE_USER}"
      ;;
      *)
        echo_error "Database type not supported ${DEPLOYMENT_DATABASE_TYPE}"
        exit 1
      ;;
    esac
  fi
}

#
# Creates a database for the instance. Don't drop it if it already exists.
#
do_create_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      echo_info "Creating MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
      if [ ! -e ${HOME}/.my.cnf ]; then
       echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
       exit 1
      fi;
      SQL=""
      SQL=${SQL}"CREATE DATABASE IF NOT EXISTS ${DEPLOYMENT_DATABASE_NAME};"
      SQL=${SQL}"GRANT ALL ON ${DEPLOYMENT_DATABASE_NAME}.* TO '${DEPLOYMENT_DATABASE_USER}'@'localhost' IDENTIFIED BY '${DEPLOYMENT_DATABASE_USER}';"
        SQL=${SQL}"FLUSH PRIVILEGES;"
      SQL=${SQL}"SHOW DATABASES;"
      mysql -e "$SQL"
      echo_info "Done."
    ;;
    HSQLDB)
      echo_info "Using default HSQLDB database. Nothing to do to create the Database."
    ;;
    DOCKER_MYSQL | DOCKER_POSTGRES)
      echo_info "Using a docker database ${DEPLOYMENT_DATABASE_IMAGE}"
      ${DOCKER_CMD} volume create --name ${DEPLOYMENT_CONTAINER_NAME}
      do_start_database
    ;;
    DOCKER_ORACLE)
      echo_info "Oracle image is not yet supporting volume"
      do_start_database
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Drops the database used by the instance.
#
do_drop_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      echo_info "Drops MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
      if [ ! -e ${HOME}/.my.cnf ]; then
       echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
       exit 1
      fi;
      SQL=""
      SQL=${SQL}"DROP DATABASE IF EXISTS ${DEPLOYMENT_DATABASE_NAME};"
      SQL=${SQL}"SHOW DATABASES;"
      mysql -e "$SQL"
      echo_info "Done."
    ;;
    HSQLDB)
      echo_info "Drops HSQLDB database ..."
      rm -rf ${DEPLOYMENT_DIR}/gatein/data/hsqldb
      echo_info "Done."
    ;;
    DOCKER_*)
      echo_info "Drops docker volumes ..."
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}
      delete_docker_volume ${DEPLOYMENT_CONTAINER_NAME}
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Creates a MongoDB database for the instance. Don't drop it if it already exists.
#
do_create_chat_mongo_database() {
  echo_info "Creating MongoDB database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."
  if [ ! command -v mongo &>/dev/null ]; then
   echo_error "mongo binary doesn't exist on the system. Please install MongoDB client to be able to manage the MongoDB Server"
   exit 1
  fi;
  # Database are automatically created the first time we access it
  mongo ${DEPLOYMENT_CHAT_MONGODB_NAME} --quiet --eval "db.getCollectionNames()" > /dev/null
  echo 'show dbs' | mongo --quiet
  echo_info "Done."
}

#
# Drops the MongoDB database used by the instance.
#
do_drop_chat_mongo_database() {
  echo_info "Drops MongoDB database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."
  if [ ! command -v mongo &>/dev/null ]; then
   echo_error "mongo binary doesn't exist on the system. Please install MongoDB client to be able to manage the MongoDB Server"
   exit 1
  fi;
  mongo ${DEPLOYMENT_CHAT_MONGODB_NAME} --quiet --eval "db.dropDatabase()" > /dev/null
  echo 'show dbs' | mongo --quiet
  echo_info "Done."
}

#
# Stop the database if it's a docker deployment, else do nothing
#
do_stop_database() {
  echo_info "Stopping database instance..."
  case ${DEPLOYMENT_DATABASE_TYPE} in
    DOCKER_*)
      echo_info "Stopping docker container ${DEPLOYMENT_CONTAINER_NAME}"
      ensure_docker_container_stopped ${DEPLOYMENT_CONTAINER_NAME}
    ;;
    *)
      echo_info "Database is not using docker, nothing to do"
    ;;
  esac
  echo_info "Done."
}

do_start_database() {
  if ! ${DEPLOYMENT_DATABASE_ENABLED}; then
    echo_debug "Database disabled, nothing to start"
    return
  fi 
  
  echo_info "Starting database instance..."
  case ${DEPLOYMENT_DATABASE_TYPE} in
    DOCKER_MYSQL)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}
      
      ${DOCKER_CMD} run \
        -p ${DEPLOYMENT_DATABASE_PORT}:3306 -d \
        -v ${DEPLOYMENT_CONTAINER_NAME}:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=${DEPLOYMENT_DATABASE_NAME}@root \
        -e MYSQL_DATABASE=${DEPLOYMENT_DATABASE_NAME} \
        -e MYSQL_USER=${DEPLOYMENT_DATABASE_USER} \
        -e MYSQL_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER_POSTGRES)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}
    
      ${DOCKER_CMD} run \
        -p ${DEPLOYMENT_DATABASE_PORT}:5432 -d \
        -v ${DEPLOYMENT_CONTAINER_NAME}:/var/lib/postgresql/data \
        -e POSTGRES_DB=${DEPLOYMENT_DATABASE_NAME} \
        -e POSTGRES_USER=${DEPLOYMENT_DATABASE_USER} \
        -e POSTGRES_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER_ORACLE)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}

      ${DOCKER_CMD} run \
        -p ${DEPLOYMENT_DATABASE_PORT}:1521 \
        -d \
        -e ORACLE_SID=${DEPLOYMENT_DATABASE_NAME} \
        -e ORACLE_DATABASE=${DEPLOYMENT_DATABASE_NAME} \
        -e ORACLE_USER=${DEPLOYMENT_DATABASE_USER} \
        -e ORACLE_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        -e ORACLE_DBA_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER*)
      echo_error "Docker database of type ${DEPLOYMENT_DATABASE_TYPE} not yet supported"
      exit 1
    ;;
    *)
      echo_info "Database is not using docker, nothing to start"
    ;;
  esac
  check_database_availability

  echo_info "Done."
}

do_restore_database_dataset() {
  _tmpdir=`mktemp -d -t db-export.XXXXXXXXXX` || exit 1

  do_drop_database
  do_create_database

  case ${DEPLOYMENT_DATABASE_TYPE} in
    DOCKER_*)
      # add the tmp directory as a volume
      CMD=$(echo "${DATABASE_CMD}" | sed "s|${DOCKER_CMD} run|${DOCKER_CMD} run  -v ${_tmpdir}:/tmpdir -w /tmpdir|g")
    ;;
    *)
      CMD="${DATABASE_CMD}"
    ;;
  esac

  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL|DOCKER_MYSQL)
      echo_info "Using temporary directory ${_tmpdir}"
      _restorescript="${_tmpdir}/__restoreAllData.sql"
      echo_info "Uncompressing ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2 into ${_tmpdir} ..."
      display_time ${NICE_CMD} tar ${TAR_BZIP2_COMPRESS_PRG} --directory ${_tmpdir} -xf ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2
      echo_info "Done"
      if [ ! -e ${_restorescript} ]; then
       echo_error "SQL file (${_restorescript}) doesn't exist."
       exit 1
      fi;
      
      check_database_availability
      
      echo_info "Importing database ${DEPLOYMENT_DATABASE_NAME} content ..."
      pushd ${_tmpdir} > /dev/null 2>&1
      pv -p -t -e -a -r -b ${_restorescript} | ${CMD}
      popd > /dev/null 2>&1
      echo_info "Done"
      echo_info "Drop if it exists the JCR_CONFIG table from ${DEPLOYMENT_DATABASE_NAME} ..."
      echo "DROP TABLE IF EXISTS JCR_CONFIG;" | ${CMD}
      echo_info "Done"
    ;;
    *)
      echo_error "Dataset restoration isn't supported for database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  rm -rf ${_tmpdir}
}

#
#
#
check_database_availability() {
  local CHECK_CMD=""
  local valid_result=0
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_POSTGRES)
      CHECK_CMD="select 1"
    ;;
    DOCKER_ORACLE)
      CHECK_CMD="select 1 from dual"
      valid_result=1
    ;;
    *)
      echo_error "Database availability check not supported for ${DEPLOYMENT_DATABASE_TYPE}"
      exit 1
    ;;
  esac

  echo_info "Waiting for database availability"

  local count=0
  local try=600
  local wait_time=1
  local RET=-1
  while [ $count -lt $try -a $RET -ne $valid_result ]; do
    count=$(( $count + 1 ))
    set +e
    case ${DEPLOYMENT_DATABASE_TYPE} in
      MYSQL|DOCKER_MYSQL|DOCKER_POSTGRES)
        echo "$CHECK_CMD" | ${DATABASE_CMD} &> /dev/null
        RET=$?
      ;;
      DOCKER_ORACLE)
        echo "$CHECK_CMD" | ${DATABASE_CMD} | grep -q ERROR &> /dev/null
        RET=$?
      ;;
    esac
    if [ $RET -ne $valid_result ]; then
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then 
    echo_error "Database not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DATABASE_LOADED=true
echo_debug "_functions_database.sh Loaded"