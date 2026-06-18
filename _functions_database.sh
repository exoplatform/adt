#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DATABASE_LOADED:-false} && return
set -u

if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"

# #############################################################################
# Database functions
#
# v2: the DB is a compose service (postgres|mysql). This module handles
# dump/restore via `docker compose exec` for the dataset mechanism.
# #############################################################################

# Dump the instance database into a SQL file.
# $1 : output file path (on the host)
do_dump_database() {
  local _output=$1
  mkdir -p "$(dirname ${_output})"
  echo_info "Dumping database ${DEPLOYMENT_DB_NAME} -> ${_output} ..."
  case "${DEPLOYMENT_DB_TYPE}" in
    postgres)
      compose_exec "${PROJECT_DIR}" db pg_dump -U "${DEPLOYMENT_DB_USER}" "${DEPLOYMENT_DB_NAME}" > "${_output}"
      ;;
    mysql)
      compose_exec "${PROJECT_DIR}" db mysqldump -u "${DEPLOYMENT_DB_USER}" -p"${DEPLOYMENT_DB_PASSWORD}" "${DEPLOYMENT_DB_NAME}" > "${_output}"
      ;;
    *)
      echo_error "Unsupported DB type ${DEPLOYMENT_DB_TYPE} for dump"
      return 1
      ;;
  esac
  echo_info "Done."
}

# Restore a SQL dump into the instance database.
# $1 : sql file path (on the host, will be piped into the container)
do_restore_database() {
  local _input=$1
  [ ! -f "${_input}" ] && { echo_error "SQL dump ${_input} not found"; return 1; }
  echo_info "Restoring database ${DEPLOYMENT_DB_NAME} <- ${_input} ..."
  case "${DEPLOYMENT_DB_TYPE}" in
    postgres)
      compose_exec "${PROJECT_DIR}" db psql -U "${DEPLOYMENT_DB_USER}" -d "${DEPLOYMENT_DB_NAME}" < "${_input}"
      ;;
    mysql)
      compose_exec "${PROJECT_DIR}" db mysql -u "${DEPLOYMENT_DB_USER}" -p"${DEPLOYMENT_DB_PASSWORD}" "${DEPLOYMENT_DB_NAME}" < "${_input}"
      ;;
    *)
      echo_error "Unsupported DB type ${DEPLOYMENT_DB_TYPE} for restore"
      return 1
      ;;
  esac
  echo_info "Done."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DATABASE_LOADED=true
echo_debug "_functions_database.sh Loaded"
