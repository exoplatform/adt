#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DATASET_LOADED:-false} && return
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

# #############################################################################
# Datasets: the data of an instance in one archive, ${DS_DIR}/${DS_FILENAME}.tar.zst
#
#   exo/             the data of the application (/srv/exo or /srv/meeds: files, jcr values, the HSQLDB when there is one)
#   search/          the data of Elasticsearch
#   backup.sql       the database (mysqldump or pg_dump), absent for HSQLDB
#   codec/           the codec key of the application (codeckey.txt)
#   keycloak/        the data of Keycloak, when it is part of the instance
#   matrix_<key>/    the data of the Matrix server, when it is part of the instance
#
# This is the format the former ADT wrote (and still reads: .tar.bz2 too), so the datasets of the instances it deployed can be
# restored in a compose instance. The data live in docker volumes and the user of ADT is not root: they are read and written by
# throwaway containers (DEPLOYMENT_HELPER_IMAGE) streaming a tar, and the database is reached through its container.
# #############################################################################

# The owners of the files in the volumes: the user of each image
DATASET_UID_APP=999
DATASET_UID_SEARCH=1000
DATASET_UID_KEYCLOAK=1000
DATASET_UID_MATRIX=12000

# The archive to restore: the compressed one first, the one of the former ADT after
do_get_dataset_file() {
  if [ -e "${DS_DIR}/${DS_FILENAME}.tar.zst" ]; then
    echo "${DS_DIR}/${DS_FILENAME}.tar.zst"
  elif [ -e "${DS_DIR}/${DS_FILENAME}.tar.bz2" ]; then
    echo "${DS_DIR}/${DS_FILENAME}.tar.bz2"
  else
    return 1
  fi
}

# The content of an archive, decompressed, on stdout
# $1 archive
do_dataset_cat() {
  case "$1" in
    # from stdin: zstd ignores a symbolic link given as a file
    *.zst) zstd --decompress --stdout < "$1" ;;
    *.bz2) if type -P pbzip2 &>/dev/null; then pbzip2 -dc "$1"; else bzip2 -dc "$1"; fi ;;
    *) echo_error "Unknown archive format: $1"; return 1 ;;
  esac
}

do_check_dataset_tools() {
  if ! type -P zstd &>/dev/null; then
    echo_error "zstd is needed to read and write the datasets."
    exit 1
  fi
}

# The name of the volumes of the instance (docker compose names them after the instance key)
dataset_volume() {
  echo "${INSTANCE_KEY}_$1"
}

# --- The database ------------------------------------------------------------------------------------------------------------

# Run a SQL client in the database container, with the credentials of the instance. The SQL is on stdin.
# $@ options of the client
do_database_client() {
  case "${DEPLOYMENT_DB_TYPE}" in
    MYSQL | MARIADB)
      ${DOCKER_CMD} exec --interactive --env "MYSQL_PWD=${DEPLOYMENT_DATABASE_USER}" "${INSTANCE_KEY}_db" \
        sh -c 'client=$(command -v mariadb || command -v mysql); user=$1; name=$2; shift 2; exec "$client" --user="$user" "$@" "$name"' \
        client "${DEPLOYMENT_DATABASE_USER}" "${DEPLOYMENT_DATABASE_NAME}" "$@"
    ;;
    POSTGRES)
      ${DOCKER_CMD} exec --interactive --env "PGPASSWORD=${DEPLOYMENT_DATABASE_USER}" "${INSTANCE_KEY}_db" \
        psql --username "${DEPLOYMENT_DATABASE_USER}" --dbname "${DEPLOYMENT_DATABASE_NAME}" --quiet "$@"
    ;;
  esac
}

# The SQL dump of the database on stdout
do_database_dump() {
  case "${DEPLOYMENT_DB_TYPE}" in
    MYSQL | MARIADB)
      ${DOCKER_CMD} exec --env "MYSQL_PWD=${DEPLOYMENT_DATABASE_USER}" "${INSTANCE_KEY}_db" \
        sh -c 'dump=$(command -v mariadb-dump || command -v mysqldump); exec "$dump" --user="$1" --routines --triggers --no-tablespaces --single-transaction "$2"' \
        dump "${DEPLOYMENT_DATABASE_USER}" "${DEPLOYMENT_DATABASE_NAME}"
    ;;
    POSTGRES)
      ${DOCKER_CMD} exec --env "PGPASSWORD=${DEPLOYMENT_DATABASE_USER}" "${INSTANCE_KEY}_db" \
        pg_dump --username "${DEPLOYMENT_DATABASE_USER}" --dbname "${DEPLOYMENT_DATABASE_NAME}"
    ;;
  esac
}

# The result of a query, without headers (MySQL and MariaDB only)
# $1 the query
do_database_query() {
  echo "$1" | do_database_client --skip-column-names
}

# --- Dump --------------------------------------------------------------------------------------------------------------------

# Dump the data of the instance: it is stopped (what is written has to be consistent), the database is the only thing running,
# and everything is started again at the end.
do_dump_dataset() {
  do_check_dataset_tools
  local _out="${DS_DIR}/${DS_FILENAME}.tar.zst"
  mkdir -p "${DS_DIR}"
  if [ "${DS_FILENAME}" = "${PRODUCT_NAME}-${PRODUCT_BRANCH}" ]; then
    echo_warn "Dataset file name is set with default name behaviour, It is strictly recommended to define DS_FILENAME parameter containing only file name prefix (no extension)"
  fi
  if [ -f "${_out}" ]; then
    echo_warn "A dataset ${_out} already exists! You have 10 seconds to cancel this build to save this file. Otherwise, it is going to be removed."
    sleep 10
  fi
  rm -f "${DS_DIR}/${DS_FILENAME}.tar.bz2"

  echo_info "Dumping the data of ${INSTANCE_DESCRIPTION} ..."
  do_compose stop --timeout 60
  local _tmp="${TMP_DIR}/dump-data.${INSTANCE_KEY}"
  rm -rf "${_tmp}"
  mkdir -p "${_tmp}"
  chmod 700 "${_tmp}"

  local _members=(exo search codec)
  local _mounts=(--volume "$(dataset_volume exo_data):/in/exo:ro"
                 --volume "$(dataset_volume search):/in/search:ro"
                 --volume "$(dataset_volume exo_codec):/in/codec:ro")
  if [ "${DEPLOYMENT_DATABASE_ENABLED}" = "true" ]; then
    echo_info "Exporting the database ${DEPLOYMENT_DATABASE_NAME} ..."
    do_compose up --detach --wait db
    do_database_dump > "${_tmp}/backup.sql"
    do_compose stop --timeout 60 db
    _members+=(backup.sql)
    _mounts+=(--volume "${_tmp}/backup.sql:/in/backup.sql:ro")
    echo_info "Done."
  fi
  if ${DEPLOYMENT_KEYCLOAK_ENABLED:-false}; then
    _members+=(keycloak)
    _mounts+=(--volume "$(dataset_volume keycloak_data):/in/keycloak:ro")
  fi
  if ${DEPLOYMENT_MATRIX_ENABLED:-false}; then
    _members+=("matrix_${INSTANCE_KEY}")
    _mounts+=(--volume "$(dataset_volume matrix_data):/in/matrix_${INSTANCE_KEY}:ro")
  fi

  echo_info "Generating the dataset ${_out} ..."
  # the archive is written beside the final name: a failed dump never replaces a good dataset
  ${DOCKER_CMD} run --rm "${_mounts[@]}" "${DEPLOYMENT_HELPER_IMAGE}" tar -C /in -cf - "${_members[@]}" \
    | nice -n 20 zstd --quiet --force -T0 -o "${_out}.part"
  mv -f "${_out}.part" "${_out}"
  rm -rf "${_tmp}"
  echo_info "Dataset ${_out} has been successfuly created!"
  if [ -n "${DS_TARGET_SERVER:-}" ]; then
    echo_info "DS_TARGET_SERVER is specified to ${DS_TARGET_SERVER}. Starting transfer..."
    rsync -Pav -e "ssh -o StrictHostKeyChecking=no" "${_out}" "${DS_TARGET_SERVER}:${DS_DIR}/${DS_FILENAME}.tar.zst"
    echo_info "Transfer done."
  fi
}

# --- Restore -----------------------------------------------------------------------------------------------------------------

# Restore a dataset in the volumes of the instance. The containers exist (docker compose up --no-start) and their volumes are
# empty (the instance was removed with its volumes). The database and the search server are started to receive their data.
do_restore_dataset() {
  do_check_dataset_tools
  local _file
  if ! _file=$(do_get_dataset_file); then
    echo_error "Dataset ${DS_DIR}/${DS_FILENAME}.tar.zst (or .tar.bz2) does not exist! Abort!"
    exit 1
  fi
  echo_info "Loading the dataset ${_file} ..."
  local _members
  _members=$(do_dataset_cat "${_file}" | tar -tf - | cut -d/ -f1 | sort -u)
  local _has_exo=false _has_search=false
  grep -qx 'exo' <<< "${_members}" && _has_exo=true
  grep -qx 'search' <<< "${_members}" && _has_search=true
  if ! ${_has_exo}; then
    echo_error "${_file} is not a dataset: it has no exo directory."
    exit 1
  fi

  # the files: the archive is unpacked in the volumes, then each belongs to the user of its image (the former ADT wrote them
  # with the uid of its own user)
  local _mounts=(--volume "$(dataset_volume exo_data):/out/exo" --volume "$(dataset_volume exo_codec):/out/codec")
  local _chown="chown -R ${DATASET_UID_APP}:${DATASET_UID_APP} /out/exo /out/codec;"
  if ${_has_search}; then
    _mounts+=(--volume "$(dataset_volume search):/out/search")
    _chown+=" chown -R ${DATASET_UID_SEARCH}:${DATASET_UID_SEARCH} /out/search;"
  else
    echo_warn "The dataset has no search data: the index will be built again."
  fi
  local _keycloak=false _matrix=false
  if ${DEPLOYMENT_KEYCLOAK_ENABLED:-false} && grep -qx 'keycloak' <<< "${_members}"; then
    _keycloak=true
    _mounts+=(--volume "$(dataset_volume keycloak_data):/out/keycloak")
    _chown+=" chown -R ${DATASET_UID_KEYCLOAK}:${DATASET_UID_KEYCLOAK} /out/keycloak;"
  fi
  if ${DEPLOYMENT_MATRIX_ENABLED:-false} && grep -qx "matrix_${INSTANCE_KEY}" <<< "${_members}"; then
    _matrix=true
    _mounts+=(--volume "$(dataset_volume matrix_data):/out/matrix_${INSTANCE_KEY}")
    _chown+=" chown -R ${DATASET_UID_MATRIX}:${DATASET_UID_MATRIX} /out/matrix_${INSTANCE_KEY};"
  fi
  do_dataset_cat "${_file}" | nice -n 20 ${DOCKER_CMD} run --rm --interactive "${_mounts[@]}" "${DEPLOYMENT_HELPER_IMAGE}" \
    sh -c "tar -C /out -xpf - --exclude=backup.sql --exclude='chat.*'; ${_chown}"
  echo_info "Files restored"

  # the database
  if [ "${DEPLOYMENT_DATABASE_ENABLED}" = "true" ]; then
    if grep -qx 'backup.sql' <<< "${_members}"; then
      echo_info "Importing the database ${DEPLOYMENT_DATABASE_NAME} ..."
      do_compose up --detach --wait db
      do_dataset_cat "${_file}" | tar -xOf - backup.sql | do_database_client > /dev/null
      echo_info "Importation done"
    else
      echo_error "The dataset has no backup.sql but the instance uses ${DEPLOYMENT_DB_TYPE}."
      exit 1
    fi
  fi

  # what the data of other services say about the instance
  if ${DEPLOYMENT_AI_ENABLED:-false}; then
    do_reset_ai_rag_data
  fi
  if ${DEPLOYMENT_MATRIX_ENABLED:-false} && ! ${_matrix}; then
    echo_warn "No Matrix data in the dataset: the Matrix server of the instance starts empty."
    do_reset_matrix_application_data || echo_warn "Failed to reset the Matrix data of the application"
  fi
  if ${DEPLOYMENT_KEYCLOAK_ENABLED:-false} && ! ${_keycloak}; then
    echo_warn "No Keycloak data in the dataset: Keycloak starts empty and is provisioned again."
  fi
  echo_info "Dataset restored"
}

# AI: the user content index is rebuilt from the content of the instance, so what the dataset holds of it is dropped (MySQL and
# MariaDB only, like the former ADT)
do_reset_ai_rag_data() {
  case "${DEPLOYMENT_DB_TYPE}" in
    MYSQL | MARIADB) ;;
    *)
      echo_warn "AI RAG dataset reset isn't supported for database type \"${DEPLOYMENT_DB_TYPE}\", skipping."
      return 0
    ;;
  esac
  local _model
  _model=$(do_database_query 'SELECT s.VALUE FROM STG_SETTINGS s JOIN STG_CONTEXTS c ON s.CONTEXT_ID = c.CONTEXT_ID JOIN STG_SCOPES sc ON s.SCOPE_ID = sc.SCOPE_ID WHERE c.TYPE="GLOBAL" AND c.NAME="AI_AGENT" AND sc.TYPE="APPLICATION" AND sc.NAME="AI_AGENT_SETTINGS" AND s.NAME="AI_AGENT_EMBEDDING_MODEL_NAME_ID";')
  if [ -z "${_model}" ]; then
    echo_info "Restored dataset has no AI embedding model configured, skipping AI RAG dataset reset."
    return 0
  fi
  echo_info "Clearing AI user-content indexing bookkeeping for nameId ${_model} ..."
  do_database_client <<E
DELETE s FROM STG_SETTINGS s
JOIN STG_CONTEXTS c ON s.CONTEXT_ID = c.CONTEXT_ID
JOIN STG_SCOPES sc ON s.SCOPE_ID = sc.SCOPE_ID
WHERE c.TYPE='GLOBAL' AND c.NAME='AIAgent'
  AND sc.TYPE='APPLICATION' AND sc.NAME='AIAgentUserContentInit_v1_0'
  AND s.NAME LIKE 'AIAgentUserContentInitialized-%${_model}%';
E
  echo_info "Dropping polluted AI user-content RAG index (the glossary index is left untouched, it has no rebuild path) ..."
  do_compose up --detach --wait search
  local _index="ai_user_content_v1_0_${_model}" _code
  _code=$(${DOCKER_CMD} exec "${INSTANCE_KEY}_search" curl -s -o /dev/null -w '%{http_code}' "http://localhost:9200/${_index}")
  if [ "${_code}" = "200" ]; then
    ${DOCKER_CMD} exec "${INSTANCE_KEY}_search" curl -s -X DELETE "http://localhost:9200/${_index}" > /dev/null
    echo_info "Index ${_index} dropped. It will be fully rebuilt from this instance's own content on next startup."
  else
    echo_info "Index ${_index} not found (HTTP ${_code}), nothing to drop."
  fi
  do_compose stop --timeout 60 search
}

# Matrix: a dataset without the data of its server makes the application forget what it created on it (MySQL and MariaDB only,
# like the former ADT)
do_reset_matrix_application_data() {
  case "${DEPLOYMENT_DB_TYPE}" in
    MYSQL | MARIADB) ;;
    *)
      echo_warn "Matrix application data reset isn't supported for database type \"${DEPLOYMENT_DB_TYPE}\""
      return 1
    ;;
  esac
  local _scope
  _scope=$(do_database_query 'SELECT SCOPE_ID FROM STG_SCOPES WHERE NAME = "MatrixRoomAndAccountsDataInitializer";')
  if [ -z "${_scope}" ] || [[ ! "${_scope}" =~ ^[0-9]+$ ]]; then
    echo_info "The dataset never initialized Matrix, nothing to reset."
    return 0
  fi
  echo_info "Reset Matrix initialization of the application on ${DEPLOYMENT_DATABASE_NAME} ..."
  do_database_client <<E
DELETE FROM STG_SETTINGS WHERE SCOPE_ID = ${_scope};
DELETE FROM STG_SCOPES WHERE SCOPE_ID = ${_scope};
DELETE FROM MATRIX_ROOM;
DELETE FROM SOC_IDENTITY_PROPERTIES where name = "matrixId";
E
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DATASET_LOADED=true
echo_debug "_functions_dataset.sh Loaded"
