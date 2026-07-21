#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_AI_LOADED:-false} && return
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


do_get_ai_settings() {  
  if [ "${DEPLOYMENT_AI_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_AI_CONTAINER_NAME "${INSTANCE_KEY}_ai_ollama"
}

#
# Drops all ai data used by the instance.
#
do_drop_ai_data() {
  echo_info "Dropping Ai-Ollama data ..."
  if [ "${DEPLOYMENT_AI_ENABLED}" == "true" ] ; then
    echo_info "Drops Ai-Ollama container ${DEPLOYMENT_AI_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_AI_CONTAINER_NAME}
    
    #echo_info "Drops Ai-Ollama docker volume ${DEPLOYMENT_AI_CONTAINER_NAME}_logs ..."
    #delete_docker_volume ${DEPLOYMENT_AI_CONTAINER_NAME}_logs
    #echo_info "Drops AI docker volume ${DEPLOYMENT_AI_CONTAINER_NAME}_reports ..."
    #delete_docker_volume ${DEPLOYMENT_AI_CONTAINER_NAME}_reports
    echo_info "Done."
    echo_info "Ai-Ollama data dropped"
  else
    echo_info "Skip Drops Ai-Ollama container ..."
  fi
}

do_stop_ai() {
  echo_info "Stopping Ai-Ollama ..."
  if [ "${DEPLOYMENT_AI_ENABLED}" == "false" ]; then
    echo_info "Ai-Ollama wasn't specified, skiping its containers shutdown"
    return
  fi
  
  ${DOCKER_CMD} run --rm \
  -v ${DEPLOYMENT_DIR}/ollama:/ollama \
  alpine sh -c "chown -R $(id -u):$(id -g) /ollama"

  ensure_docker_container_stopped ${DEPLOYMENT_AI_CONTAINER_NAME}
  echo_info "Ai-Ollama container ${DEPLOYMENT_AI_CONTAINER_NAME} stopped."
  echo_info "Done."
}

do_start_ai() {
  echo_info "Starting Ai-Ollama..."
  if [ "${DEPLOYMENT_AI_ENABLED}" == "false" ]; then
    echo_info "Ai-Ollama not specified, skiping its containers startup"
    return
  fi
  
  mkdir -p ${DEPLOYMENT_DIR}/ollama

  echo_info "Starting Ai-Ollama container ${DEPLOYMENT_AI_CONTAINER_NAME} based on image ${DEPLOYMENT_AI_IMAGE}:${DEPLOYMENT_AI_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_AI_CONTAINER_NAME}
  export DEPLOYMENT_OPTS="${DEPLOYMENT_OPTS} -Dmeeds.ai.ollama.url=http://localhost:${DEPLOYMENT_AI_PORT} -Dmeeds.ai.mcp.base-url=http://127.0.0.1:8080"
  
  ${DOCKER_CMD} run \
    -d \
    -h "${DEPLOYMENT_AI_CONTAINER_NAME}" \
    -p "${DEPLOYMENT_AI_PORT}:11434" \
    -v "${DEPLOYMENT_DIR}/ollama:/root/.ollama" \
    -e OLLAMA_NUM_PARALLEL=8 \
    -e OLLAMA_HOST=0.0.0.0 \
    --health-cmd='ollama --version && ollama ps || exit 1' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=5 \
    --health-start-period=30s \
    --name ${DEPLOYMENT_AI_CONTAINER_NAME} ${DEPLOYMENT_AI_IMAGE}:${DEPLOYMENT_AI_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_AI_CONTAINER_NAME} container started"

  check_ai_availability
}
  
check_ai_availability() {
  echo_info "Waiting for ai availability on port ${DEPLOYMENT_AI_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -fs "http://127.0.0.1:${DEPLOYMENT_AI_PORT}/api/tags" >/dev/null
    RET=$?

    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Ai-Ollama not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Ai-Ollama ${DEPLOYMENT_AI_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Ai-Ollama ${DEPLOYMENT_AI_CONTAINER_NAME} up and available"
}

#do_reset_ai_data() {
#  do_drop_ai_data
#  do_create_ai
#}

# A raw dataset restore copies ES data as-is, so the RAG index still holds
# vectors from the source dataset, and the DB's "already initialized" flag
# stops the addon from ever reindexing on its own. Drop the index and clear
# the flag so it rebuilds cleanly on next start. Glossary is skipped: it has
# no rebuild path, so wiping it would be permanent data loss.
do_restore_ai_rag_data() {
  echo_info "Checking AI RAG dataset restore prerequisites ..."

  case ${DEPLOYMENT_DB_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_MARIADB)
    ;;
    *)
      echo_warn "AI RAG dataset reset isn't supported for database type \"${DEPLOYMENT_DB_TYPE}\", skipping."
      return 0
    ;;
  esac

  if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
    do_start_database
  fi

  local DATABASE_CMD_HEADLESS=$(echo "${DATABASE_CMD} -N")
  local _uuidSQL='SELECT s.VALUE FROM STG_SETTINGS s JOIN STG_CONTEXTS c ON s.CONTEXT_ID = c.CONTEXT_ID JOIN STG_SCOPES sc ON s.SCOPE_ID = sc.SCOPE_ID WHERE c.TYPE="GLOBAL" AND c.NAME="AI_AGENT" AND sc.TYPE="APPLICATION" AND sc.NAME="AI_AGENT_SETTINGS" AND s.NAME="AI_AGENT_EMBEDDING_MODEL_NAME_ID";'
  local _embeddingModelNameId=$(${DATABASE_CMD_HEADLESS} <<< "${_uuidSQL}")

  if [ -z "${_embeddingModelNameId}" ]; then
    echo_info "Restored dataset has no AI embedding model configured, skipping AI RAG dataset reset."
    if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
      do_stop_database
    fi
    return 0
  fi
  echo_info "Active AI embedding model nameId: ${_embeddingModelNameId}"

  echo_info "Clearing AI user-content indexing bookkeeping for nameId ${_embeddingModelNameId} ..."
  local _aiSql="${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/_restore/airag.sql"
  mkdir -p "$(dirname ${_aiSql})"
  cat >${_aiSql} <<EOF
DELETE s FROM STG_SETTINGS s
JOIN STG_CONTEXTS c ON s.CONTEXT_ID = c.CONTEXT_ID
JOIN STG_SCOPES sc ON s.SCOPE_ID = sc.SCOPE_ID
WHERE c.TYPE='GLOBAL' AND c.NAME='AIAgent'
  AND sc.TYPE='APPLICATION' AND sc.NAME='AIAgentUserContentInit_v1_0'
  AND s.NAME LIKE 'AIAgentUserContentInitialized-%${_embeddingModelNameId}%';
EOF
  ${DATABASE_CMD} < ${_aiSql}
  rm -f ${_aiSql}
  echo_info "Done."

  if [[ ${DEPLOYMENT_DB_TYPE} =~ DOCKER.* ]]; then
    do_stop_database
  fi

  echo_info "Dropping polluted AI user-content RAG index (leaving the glossary index untouched, it has no rebuild path) ..."
  do_start_es
  local _index="ai_user_content_v1_0_${_embeddingModelNameId}"
  local _httpCode=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${DEPLOYMENT_ES_HTTP_PORT}/${_index}")
  if [ "${_httpCode}" == "200" ]; then
    curl -s -X DELETE "http://localhost:${DEPLOYMENT_ES_HTTP_PORT}/${_index}" >/dev/null
    echo_info "Index ${_index} dropped. It will be fully rebuilt from this instance's own content on next startup."
  else
    echo_info "Index ${_index} not found (HTTP ${_httpCode}), nothing to drop."
  fi
  do_stop_es

  echo_info "AI RAG dataset reset done."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_AI_LOADED=true
echo_debug "_function_ai.sh Loaded"