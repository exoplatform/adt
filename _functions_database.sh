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
    DOCKER_MYSQL)
      echo_info "Using a docker database ${DEPLOYMENT_DATABASE_IMAGE}"
      ${DOCKER_CMD} volume create --name ${DEPLOYMENT_DATABASE_NAME}
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
    DOCKER_MYSQL)
      echo_info "Drops docker volumes ..."
      delete_docker_container ${DEPLOYMENT_DATABASE_NAME}
      delete_docker_volume ${DEPLOYMENT_DATABASE_NAME}
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
      echo_info "Stopping docker container ${DEPLOYMENT_DATABASE_NAME}"
      ensure_docker_container_stopped ${DEPLOYMENT_DATABASE_NAME}
    ;;
    *)
      echo_info "Database is not using docker, doing nothing"
    ;;
  esac
  echo_info "Done."
}

do_start_database() {
  echo_info "Starting database instance..."
  case ${DEPLOYMENT_DATABASE_TYPE} in
    DOCKER_MYSQL)
      echo_info "Starting database container ${DEPLOYMENT_DATABASE_NAME} based on image mysql:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_DATABASE_NAME}
      
      ${DOCKER_CMD} run \
        -p ${DEPLOYMENT_DATABASE_PORT}:3306 -d \
        -v ${DEPLOYMENT_DATABASE_NAME}:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=${DEPLOYMENT_DATABASE_NAME}@root \
        -e MYSQL_DATABASE=${DEPLOYMENT_DATABASE_NAME} \
        -e MYSQL_USER=${DEPLOYMENT_DATABASE_USER} \
        -e MYSQL_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --name ${DEPLOYMENT_DATABASE_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER*)
      echo_error "Docker database of type ${DEPLOYMENT_DATABASE_TYPE} not yet supported"
      exit 1
    ;;
    *)
      echo_info "Database is not using docker, nothing to start"
    ;;
  esac
  echo_info "Done."
}

do_restore_database_dataset() {
  _tmpdir=`mktemp -d -t db-export.XXXXXXXXXX` || exit 1

  do_drop_database
  do_create_database

  get_database_cmd

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

get_database_cmd() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      if [ ! -e ${HOME}/.my.cnf ]; then
       echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
       exit 1
      fi;
    
      env_var "DATABASE_CMD" "mysql ${DEPLOYMENT_DATABASE_NAME}"
    ;;
    DOCKER_MYSQL)
      env_var "DATABASE_CMD" "${DOCKER_CMD} run -i --rm --link ${DEPLOYMENT_DATABASE_NAME}:mysql ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION} mysql -h mysql -u ${DEPLOYMENT_DATABASE_USER} -p${DEPLOYMENT_DATABASE_USER} ${DEPLOYMENT_DATABASE_NAME}"
      sleep 3
    ;;
    *)
      echo_error "Database connection command not supported for ${DEPLOYMENT_DATABASE_TYPE}"
      exit 1
    ;;
  esac
}

#
#
#
check_database_availability() {
  local CHECK_CMD=""
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL|DOCKER_MYSQL)
      CHECK_CMD="select 1"
    ;;
    *)
      echo_error "Database availability check not supported for ${DEPLOYMENT_DATABASE_TYPE}"
      exit 1
    ;;
  esac
  
  local count=0
  local try=10
  local wait_time=1
  local RET=1
  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e
    echo "$CHCMD" | ${DATABASE_CMD} &> /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      echo_debug "${CHECK_CMD} failed (${RET})"
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