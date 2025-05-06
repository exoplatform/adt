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
  local WORKING_FILE_PREFIX=${FILE_TO_PATCH}-$(tolower "${DEPLOYMENT_DB_TYPE}")
  configurable_env_var "DB_DRIVER" ""

    # Reconfigure server.xml for Database
  if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp ${DB_SERVER_PATCH} ${WORKING_FILE_PREFIX}.patch
    echo_info "Applying on ${FILE_TO_PATCH} the patch $DB_SERVER_PATCH ..."
    cp ${FILE_TO_PATCH} ${WORKING_FILE_PREFIX}.ori
    replace_in_file ${WORKING_FILE_PREFIX}.patch "@DB_IDM_DEFAULT_NAME@" "${DEPLOYMENT_DB_IDM_DEFAULT_NAME}"
    replace_in_file ${WORKING_FILE_PREFIX}.patch "@DB_JCR_DEFAULT_NAME@" "${DEPLOYMENT_DB_JCR_DEFAULT_NAME}"
    replace_in_file ${WORKING_FILE_PREFIX}.patch "@DB_JPA_DEFAULT_NAME@" "${DEPLOYMENT_DB_JPA_DEFAULT_NAME}"
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
    # Build a container name prefix without dot, minus ...
    env_var DEPLOYMENT_DATABASE_NAME "${INSTANCE_KEY}"
    env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//./_}"
    env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//-/_}"
    env_var DEPLOYMENT_CONTAINER_NAME "${DEPLOYMENT_DATABASE_NAME}"
    # Build a database user without dot, minus ... (using the branch because limited to 16 characters)
    if [ -z "${INSTANCE_TOKEN:-}" ]; then
      env_var DEPLOYMENT_DATABASE_USER "${PRODUCT_NAME}_${PRODUCT_BRANCH}"
    else
      env_var DEPLOYMENT_DATABASE_USER "${PRODUCT_NAME}_${INSTANCE_TOKEN:0:8}"
    fi  
    env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//./_}"
    env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//-/_}"

    env_var "DEPLOYMENT_DATABASE_HOST" "localhost"
    case "${DEPLOYMENT_DB_TYPE}" in
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
        configurable_env_var "DEPLOYMENT_DATABASE_VERSION" "${DEPLOYMENT_MYSQL_DEFAULT_VERSION}"
        validate_env_var     "DEPLOYMENT_DATABASE_VERSION"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        env_var "DATABASE_CMD" "${DOCKER_CMD} run -i --rm --link ${DEPLOYMENT_CONTAINER_NAME}:db ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION} mysql -h db -u ${DEPLOYMENT_DATABASE_USER} -p${DEPLOYMENT_DATABASE_USER} ${DEPLOYMENT_DATABASE_NAME}"
      ;;
      DOCKER_MARIADB)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "mariadb"
        validate_env_var     "DEPLOYMENT_DATABASE_VERSION"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        env_var "DATABASE_CMD" "${DOCKER_CMD} run -i --rm --link ${DEPLOYMENT_CONTAINER_NAME}:db ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION} mysql -h db -u ${DEPLOYMENT_DATABASE_USER} -p${DEPLOYMENT_DATABASE_USER} ${DEPLOYMENT_DATABASE_NAME}"
      ;;
      DOCKER_POSTGRES)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "postgres"
        configurable_env_var "DEPLOYMENT_DATABASE_VERSION" "${DEPLOYMENT_POSTGRESQL_DEFAULT_VERSION}"
        validate_env_var     "DEPLOYMENT_DATABASE_VERSION"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        env_var "DATABASE_CMD" "${DOCKER_CMD} run -i --rm --link ${DEPLOYMENT_CONTAINER_NAME}:db --entrypoint psql -e PGPASSWORD=${DEPLOYMENT_DATABASE_USER} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION} -h db --user=${DEPLOYMENT_DATABASE_USER} ${DEPLOYMENT_DATABASE_NAME}"
      ;;
      DOCKER_ORACLE)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "exoplatform/oracle"
        configurable_env_var "DEPLOYMENT_DATABASE_VERSION" "${DEPLOYMENT_ORACLE_DEFAULT_VERSION}"
        validate_env_var     "DEPLOYMENT_DATABASE_VERSION"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

        # due to oracle limitation on SID
        env_var DEPLOYMENT_DATABASE_NAME "plf"
        env_var DEPLOYMENT_DATABASE_USER "plf"

        env_var "DATABASE_CMD" "${DOCKER_CMD} exec -i ${DEPLOYMENT_CONTAINER_NAME} bin/sqlplus ${DEPLOYMENT_DATABASE_USER}/${DEPLOYMENT_DATABASE_USER}"
      ;;
      DOCKER_SQLSERVER)
        configurable_env_var "DEPLOYMENT_DATABASE_IMAGE" "exoplatform/sqlserver"
        configurable_env_var "DEPLOYMENT_DATABASE_VERSION" "${DEPLOYMENT_SQLSERVER_DEFAULT_VERSION}"
        validate_env_var     "DEPLOYMENT_DATABASE_VERSION"
        env_var "DEPLOYMENT_DATABASE_PORT" "${DEPLOYMENT_PORT_PREFIX}20"
        env_var "DEPLOYMENT_DATABASE_REMOTE_DISPLAY_PORT" "${DEPLOYMENT_PORT_PREFIX}21"

        env_var "DATABASE_CMD" "${DOCKER_CMD} logs ${DEPLOYMENT_CONTAINER_NAME}"
      ;;
      *)
        echo_error "Database type not supported ${DEPLOYMENT_DB_TYPE}"
        exit 1
      ;;
    esac
  fi
}

#
# Check and Perform Postgres upgrade
#
check_pg_upgrades() {
  [ -z "${DEPLOYMENT_PG_UPGRADE_IMAGE:-}" ] && return 0
  local mount_point=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_CONTAINER_NAME}) || return 0
  [ -z "${mount_point:-}" ] && return 0
  local data_pg_version=$(sudo cat ${mount_point}/PG_VERSION 2>/dev/null| xargs -n 1)
  [ -z "${data_pg_version:-}" ] && return 0
  if (( $(echo "${DEPLOYMENT_DATABASE_VERSION} > ${data_pg_version}" |bc -l) )); then
     echo_info "Postgres Database changes detected. Performing upgrade from ${data_pg_version} to ${DEPLOYMENT_DATABASE_VERSION} version ..."
     local tmpfolder="/tmp/$(date +'%s')pgold"
     sudo mv -v ${mount_point} ${tmpfolder}
     ${DOCKER_CMD} run --rm -e PGPASSWORD=${DEPLOYMENT_DATABASE_USER} -e PGUSER=${DEPLOYMENT_DATABASE_USER} -e POSTGRES_INITDB_ARGS="-U ${DEPLOYMENT_DATABASE_USER}" \
	   -v ${tmpfolder}:/var/lib/postgresql/${data_pg_version}/data \
	   -v ${mount_point}:/var/lib/postgresql/${DEPLOYMENT_DATABASE_VERSION}/data \
	   ${DEPLOYMENT_PG_UPGRADE_IMAGE}:${data_pg_version}-to-${DEPLOYMENT_DATABASE_VERSION}
     # Fix User permission after the upgrade
     echo "host  all  all 0.0.0.0/0 md5" | sudo tee -a ${mount_point}/pg_hba.conf
     # Cleanup
     sudo rm -rf ${tmpfolder}
     echo_info "Upgrade from ${data_pg_version} to ${DEPLOYMENT_DATABASE_VERSION} has been executed successfully!"
  fi
}

#
# Creates a database for the instance. Don't drop it if it already exists.
#
do_create_database() {
  case ${DEPLOYMENT_DB_TYPE} in
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
    DOCKER_MYSQL | DOCKER_POSTGRES | DOCKER_MARIADB)
      echo_info "Using a docker database ${DEPLOYMENT_DATABASE_IMAGE}"
      ${DOCKER_CMD} volume create --name ${DEPLOYMENT_CONTAINER_NAME}
      # do_start_database
    ;;
    DOCKER_ORACLE)
      echo_info "Oracle image is not yet supporting volume"
      # do_start_database
    ;;
    DOCKER_SQLSERVER)
      echo_info "SQL Server image is not yet supporting volume"
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Drops the database used by the instance.
#
do_drop_database() {
  case ${DEPLOYMENT_DB_TYPE} in
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
      echo_error "Invalid database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Stop the database if it's a docker deployment, else do nothing
#
do_stop_database() {
  echo_info "Stopping database instance..."
  case ${DEPLOYMENT_DB_TYPE} in
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
  case ${DEPLOYMENT_DB_TYPE} in
    DOCKER_MYSQL | DOCKER_MARIADB)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}

      ${DOCKER_CMD} run \
        -p "127.0.0.1:${DEPLOYMENT_DATABASE_PORT}:3306" -d \
        -v ${DEPLOYMENT_CONTAINER_NAME}:/var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=${DEPLOYMENT_DATABASE_NAME}@root \
        -e MYSQL_DATABASE=${DEPLOYMENT_DATABASE_NAME} \
        -e MYSQL_USER=${DEPLOYMENT_DATABASE_USER} \
        -e MYSQL_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --health-cmd="mysqladmin -h 'localhost' -u ${DEPLOYMENT_DATABASE_USER} -p${DEPLOYMENT_DATABASE_USER} ping --silent" \
        --health-interval=30s \
        --health-timeout=30s \
        --health-retries=3 \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER_POSTGRES)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}
      check_pg_upgrades
      ${DOCKER_CMD} run \
        -p "127.0.0.1:${DEPLOYMENT_DATABASE_PORT}:5432" -d \
        -v ${DEPLOYMENT_CONTAINER_NAME}:/var/lib/postgresql/data \
        -e POSTGRES_DB=${DEPLOYMENT_DATABASE_NAME} \
        -e POSTGRES_USER=${DEPLOYMENT_DATABASE_USER} \
        -e POSTGRES_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --health-cmd="sh -c 'pg_isready -U ${DEPLOYMENT_DATABASE_USER} -d ${DEPLOYMENT_DATABASE_NAME}'" \
        --health-interval=30s \
        --health-timeout=30s \
        --health-retries=3 \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER_ORACLE)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}

      ${DOCKER_CMD} run \
        -p "127.0.0.1:${DEPLOYMENT_DATABASE_PORT}:1521" \
        -d \
        -e ORACLE_SID=${DEPLOYMENT_DATABASE_NAME} \
        -e ORACLE_DATABASE=${DEPLOYMENT_DATABASE_NAME} \
        -e ORACLE_USER=${DEPLOYMENT_DATABASE_USER} \
        -e ORACLE_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        -e ORACLE_DBA_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER_SQLSERVER)
      echo_info "Starting database container ${DEPLOYMENT_CONTAINER_NAME} based on image ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}"
      delete_docker_container ${DEPLOYMENT_CONTAINER_NAME}

      ${DOCKER_CMD} run \
        --privileged \
        --init \
        -p "127.0.0.1:${DEPLOYMENT_DATABASE_PORT}:1433" \
        -p ${DEPLOYMENT_DATABASE_REMOTE_DISPLAY_PORT}:3389 \
        -d \
        -e SQLSERVER_DATABASE=${DEPLOYMENT_DATABASE_NAME} \
        -e SQLSERVER_USER=${DEPLOYMENT_DATABASE_USER} \
        -e SQLSERVER_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        -e SA_PASSWORD=${DEPLOYMENT_DATABASE_USER} \
        --name ${DEPLOYMENT_CONTAINER_NAME} ${DEPLOYMENT_DATABASE_IMAGE}:${DEPLOYMENT_DATABASE_VERSION}
    ;;
    DOCKER*)
      echo_error "Docker database of type ${DEPLOYMENT_DB_TYPE} not yet supported"
      exit 1
    ;;
    *)
      echo_info "Database is not using docker, nothing to start"
    ;;
  esac
  check_database_availability

  echo_info "Done."
}

do_dump_database_dataset() {
  local _backupfile="$1/backup.sql"
  case ${DEPLOYMENT_DB_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_MARIADB)
      if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
        do_start_database
      fi
      echo_info "Exporting database ${DEPLOYMENT_DATABASE_NAME} content ..."
      local DATABASE_CMD_DUMP=$(echo "${DATABASE_CMD} --routines --triggers --no-tablespaces" | sed 's/mysql -h db -u/mysqldump -h db -u/')
      ${DATABASE_CMD_DUMP} > ${_backupfile}
      echo_info "Exportation done"
      if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
        do_stop_database
      fi
    ;;
    DOCKER_POSTGRES)
      do_start_database
      echo_info "Exporting database ${DEPLOYMENT_DATABASE_NAME} content ..."
      local DATABASE_CMD_DUMP=$(echo "${DATABASE_CMD}" | sed 's/psql/pg_dump/g')
      ${DATABASE_CMD_DUMP} > ${_backupfile}
      echo_info "Exportation done"
    ;;
    *)
      echo_error "Dataset backup isn't supported for database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

do_restore_database_dataset() {
  do_drop_database
  do_create_database
  local _backupfile="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/backup.sql"
  case ${DEPLOYMENT_DB_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_MARIADB)
      if [ ! -e ${_backupfile} ]; then
       echo_error "SQL file (${_backupfile}) doesn't exist."
       exit 1
      fi;
      if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
        do_start_database
      fi
      echo_info "Importing database ${DEPLOYMENT_DATABASE_NAME} content ..."
      pv -p -t -e -a -r -b ${_backupfile} | ${DATABASE_CMD}
      echo_info "Importation done"
      if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
        do_stop_database
      fi
    ;;
    DOCKER_POSTGRES)
      do_start_database
      echo_info "Importing database ${DEPLOYMENT_DATABASE_NAME} content ..."
      pv -p -t -e -a -r -b ${_backupfile} | ${DATABASE_CMD} >/dev/null
      echo_info "Importation done"
    ;;
    *)
      echo_error "Dataset restoration isn't supported for database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  rm -rf ${_backupfile}
}

do_reset_matrix_plf_database() {
   
  local _matrixsql="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/exomatrix.sql"

  case ${DEPLOYMENT_DB_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_MARIADB)
      if [ ! -e ${_matrixsql} ]; then
       echo_error "SQL file (${_matrixsql}) doesn't exist."
       exit 1
      fi;
      if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
        do_start_database
      fi
      local DATABASE_CMD_HEADLESS=$(echo "${DATABASE_CMD} -N")
      local _scopeIdSQL='SELECT SCOPE_ID FROM STG_SCOPES WHERE NAME = "MatrixRoomAndAccountsDataInitializer";'
      local _scopeId=$(${DATABASE_CMD_HEADLESS} <<< "${_scopeIdSQL}")
      if [ -z "${scopeId}" ] || [[ ! $scopeId =~ ^[0-9]+$ ]]; then
        echo_error "Unable to get the scopeId from the database"
        exit 1
      fi
      cat >${_matrixsql} <<EOF
DELETE FROM STG_SETTINGS WHERE SCOPE_ID = ${scopeId};
DELETE FROM STG_SCOPES WHERE SCOPE_ID = ${scopeId};
DELETE FROM MATRIX_ROOM;
DELETE FROM SOC_IDENTITY_PROPERTIES where name = "matrixId";
EOF
      echo_info "Reset Matrix plf database initialization on ${DEPLOYMENT_DATABASE_NAME} database ..."
      pv -p -t -e -a -r -b ${_matrixsql} | ${DATABASE_CMD}
      echo_info "Reset done"
      if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
        do_stop_database
      fi
    ;;
    # To be implemented for postgres database
    *)
      echo_error "Matrix Plf Dataset reset isn't supported for database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  rm -rf ${_matrixsql}
}

#
#
#
check_database_availability() {
  local CHECK_CMD=""
  local valid_result=0
  case ${DEPLOYMENT_DB_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_POSTGRES|DOCKER_MARIADB)
      CHECK_CMD="select 1"
    ;;
    DOCKER_ORACLE)
      CHECK_CMD="select 1 as AVAILABLE from dual;"
    ;;
    DOCKER_SQLSERVER)
      echo "Using docker container logs to check availability"
    ;;
    *)
      echo_error "Database availability check not supported for ${DEPLOYMENT_DB_TYPE}"
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
    case ${DEPLOYMENT_DB_TYPE} in
      MYSQL|DOCKER_MYSQL|DOCKER_POSTGRES|DOCKER_MARIADB)
        echo "$CHECK_CMD" | ${DATABASE_CMD} &> /dev/null
        RET=$?
      ;;
      DOCKER_ORACLE)
        echo "$CHECK_CMD" | ${DATABASE_CMD} | grep -q AVAILABLE &> /dev/null
        RET=$?
      ;;
      DOCKER_SQLSERVER)
        ${DATABASE_CMD} | grep -q "Database started"
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
