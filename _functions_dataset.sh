#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DATASET_LOADED:-false} && return
set -u

if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"
source "${SCRIPT_DIR}/_functions_database.sh"

# #############################################################################
# Dataset functions
#
# Two mechanisms:
#  1) Within-v2 dump/restore : tar each named docker volume + DB SQL dump into a
#     single tar.gz archive. Restore = untar into fresh volumes + DB SQL restore.
#  2) v1 -> v2 import        : extract a v1 dataset tarball (exo/ data dir, ES,
#     backup.sql, codec) and map it into v2 docker volumes.
# #############################################################################

# Dump the current instance into a dataset archive.
# Output: ${DS_DIR}/${INSTANCE_KEY}-${CURR_DATE}.tar.gz
do_dump_dataset() {
  local _archive="${DS_DIR}/${INSTANCE_KEY}-${CURR_DATE}.tar.gz"
  local _workdir="${TMP_DIR}/dump-${INSTANCE_KEY}-${CURR_DATE}"
  mkdir -p "${_workdir}" "${DS_DIR}"

  echo_info "Dumping dataset for ${INSTANCE_KEY} -> ${_archive} ..."

  # Stop only the app service (keep db running for the dump)
  compose_stop "${PROJECT_DIR}" "${APP_SERVICE_NAME}"

  # Dump the DB (db is still running)
  do_dump_database "${_workdir}/backup.sql"

  # Stop the db too for a consistent volume snapshot
  compose_stop "${PROJECT_DIR}" db

  # Dump each named volume of the project
  local _project="${COMPOSE_PROJECT}"
  local _volumes
  _volumes=$(${DOCKER_CMD} volume ls --filter "name=${_project}_" -q)
  for _vol in ${_volumes}; do
    local _name=${_vol#"${_project}"_}
    dump_docker_volume "${_vol}" "${_workdir}/volumes/${_name}.tar.gz"
  done

  # Bundle everything (gzip for portability)
  tar czf "${_archive}" -C "${_workdir}" .
  echo_info "Dataset dumped to ${_archive}"

  # Restart everything
  compose_start "${PROJECT_DIR}"

  # Cleanup
  rm -rf "${_workdir}"
}

# Restore a dataset archive into the current instance's volumes.
# Uses DEPLOYMENT_DATASET_FILE (set by caller) or ${DS_DIR}/${INSTANCE_KEY}-*.tar.gz (latest).
do_restore_dataset() {
  local _archive="${DEPLOYMENT_DATASET_FILE:-}"
  if [ -z "${_archive}" ]; then
    _archive=$(ls -t "${DS_DIR}"/${INSTANCE_KEY}-*.tar.gz 2>/dev/null | head -1)
  fi
  if [ -z "${_archive}" ] || [ ! -f "${_archive}" ]; then
    echo_error "No dataset archive found for ${INSTANCE_KEY}. Set DEPLOYMENT_DATASET_FILE."
    return 1
  fi

  local _workdir="${TMP_DIR}/restore-${INSTANCE_KEY}-${CURR_DATE}"
  mkdir -p "${_workdir}"
  echo_info "Restoring dataset ${_archive} -> ${INSTANCE_KEY} ..."

  tar xzf "${_archive}" -C "${_workdir}"

  # Start only the db to restore the SQL dump
  compose_up "${PROJECT_DIR}" "" db
  wait_service_healthy "${PROJECT_DIR}" db 120

  if [ -f "${_workdir}/backup.sql" ]; then
    do_restore_database "${_workdir}/backup.sql"
  fi

  # Stop the db before restoring volumes
  compose_stop "${PROJECT_DIR}" db

  # Restore volumes
  if [ -d "${_workdir}/volumes" ]; then
    local _project="${COMPOSE_PROJECT}"
    for _volgz in "${_workdir}"/volumes/*.tar.gz; do
      [ -f "${_volgz}" ] || continue
      local _name
      _name=$(basename "${_volgz}" .tar.gz)
      restore_docker_volume "${_volgz}" "${_project}_${_name}"
    done
  fi

  # Start everything
  compose_start "${PROJECT_DIR}"

  rm -rf "${_workdir}"
  echo_info "Dataset restored."
}

# Import a v1 dataset tarball into v2 volumes.
# v1 tarball layout: exo/ (data dir), search/ (ES), backup.sql, codec/codeckey.txt,
# optional chat.dump, keycloak/, matrix_<key>/.
# DEPLOYMENT_DATASET_FILE must point to the v1 tarball.
do_import_v1_dataset() {
  local _archive="${DEPLOYMENT_DATASET_FILE:-${DEPLOYMENT_V1_DATASET_FILE:-}}"
  if [ -z "${_archive}" ] || [ ! -f "${_archive}" ]; then
    echo_error "v1 dataset tarball not found. Set DEPLOYMENT_DATASET_FILE."
    return 1
  fi

  env_var "PROJECT_DIR" "${PROJECTS_DIR}/${INSTANCE_KEY}"
  do_render_instance

  local _workdir="${TMP_DIR}/import-v1-${INSTANCE_KEY}-${CURR_DATE}"
  mkdir -p "${_workdir}"
  echo_info "Importing v1 dataset ${_archive} -> ${INSTANCE_KEY} ..."

  tar xf "${_archive}" -C "${_workdir}"

  # Start only the db to restore the SQL dump
  compose_up "${PROJECT_DIR}" "" db
  wait_service_healthy "${PROJECT_DIR}" db 120

  if [ -f "${_workdir}/backup.sql" ]; then
    do_restore_database "${_workdir}/backup.sql"
  fi

  # Stop the db before restoring volumes
  compose_stop "${PROJECT_DIR}" db

  # Map v1 paths -> v2 volumes
  local _project="${COMPOSE_PROJECT}"

  # exo data dir -> exo_data volume
  local _data_vol="${_project}_exo_data"
  if [ -d "${_workdir}/exo" ]; then
    create_docker_volume "${_data_vol}"
    echo_info "Copying exo data -> ${_data_vol} ..."
    ${DOCKER_CMD} run --rm -v "${_data_vol}":/target -v "${_workdir}":/src:ro alpine \
      sh -c "cp -a /src/exo/. /target/"
  fi

  # codec -> exo_codec volume
  local _codec_vol="${_project}_exo_codec"
  if [ -d "${_workdir}/codec" ]; then
    create_docker_volume "${_codec_vol}"
    ${DOCKER_CMD} run --rm -v "${_codec_vol}":/target -v "${_workdir}":/src:ro alpine \
      sh -c "cp -a /src/codec/. /target/"
  fi

  # ES data -> es_data volume (chown 1000:1000)
  local _es_vol="${_project}_es_data"
  if [ -d "${_workdir}/search" ]; then
    create_docker_volume "${_es_vol}"
    ${DOCKER_CMD} run --rm -v "${_es_vol}":/target -v "${_workdir}":/src:ro alpine \
      sh -c "cp -a /src/search/. /target/ && chown -R 1000:1000 /target"
  fi

  # Start everything
  compose_start "${PROJECT_DIR}"
  do_create_deployment_descriptor
  rm -rf "${_workdir}"
  echo_info "v1 dataset imported."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DATASET_LOADED=true
echo_debug "_functions_dataset.sh Loaded"
