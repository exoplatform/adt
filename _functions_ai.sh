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
# #############################################################################
# Env var to not load it several times
_FUNCTIONS_AI_LOADED=true
echo_debug "_function_ai.sh Loaded"