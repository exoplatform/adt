#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_JITSI_LOADED:-false} && return
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

do_get_jitsi_settings() {  
  if [ "${DEPLOYMENT_JITSI_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_JITSI_CALL_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_call"
  env_var DEPLOYMENT_JITSI_WEB_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_web"
  env_var DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_prosody"
  env_var DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_jicofo"
  env_var DEPLOYMENT_JITSI_JVB_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_jvb"
  env_var DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_jibri"
  env_var DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME "${INSTANCE_KEY}_jitsi_excalidraw_backend"
  env_var DEPLOYMENT_JITSI_NETWORK_NAME "$(tolower "${INSTANCE_KEY}").jitsi"
}

#
# Drops all Jitsi data used by the instance.
#
do_drop_jitsi_data() {
  echo_info "Dropping Jitsi data ..."
  if ${DEPLOYMENT_JITSI_ENABLED}; then
    echo_info "Drops Jitsi docker network ${DEPLOYMENT_JITSI_NETWORK_NAME} ..."
    delete_docker_network ${DEPLOYMENT_JITSI_NETWORK_NAME}
    echo_info "Drops Jitsi call container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME}
    echo_info "Drops Jitsi web container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}
    echo_info "Drops Jitsi prosody container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}
    echo_info "Drops Jitsi jicofo container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}
    echo_info "Drops Jitsi jvb container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}
    echo_info "Drops Jitsi jibri container ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME}
    echo_info "Drops Jitsi excalidraw brackend container ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Jitsi data dropped"
  else
    echo_info "Skip Drops Jitsi container ..."
  fi
}

do_create_jitsi() {
  if ${DEPLOYMENT_JITSI_ENABLED}; then
    echo_info "Creation of the Jitsi Docker network ${DEPLOYMENT_JITSI_NETWORK_NAME} ..."
    create_docker_network ${DEPLOYMENT_JITSI_NETWORK_NAME}
  fi
}

do_stop_jitsi() {
  echo_info "Stopping Jitsi ..."
  if [ "${DEPLOYMENT_JITSI_ENABLED}" == "false" ]; then
    echo_info "Jitsi wasn't specified, skiping its containers shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} stopped."
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} stopped."
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} stopped."
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} stopped."
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} stopped."
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME} stopped."
  ensure_docker_container_stopped ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME}
  echo_info "Jitsi container ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME} stopped."
  echo_info "Done."
}

do_start_jitsi() {
  echo_info "Starting Jitsi..."
  if [ "${DEPLOYMENT_JITSI_ENABLED}" == "false" ]; then
    echo_info "Jitsi not specified, skiping its containers startup"
    return
  fi
  # TL;DR: export All envrionment variables included on this template
  jitsi_major_version=$(echo ${DEPLOYMENT_JITSI_IMAGE_VERSION} | grep -oP [0-9] | head -n 1)
  [[ "${jitsi_major_version:-}" =~ ^[78]$ ]] || jitsi_major_version="8" # latest version
  export DEPLOYMENT_URL DEPLOYMENT_JITSI_NETWORK_NAME DEPLOYMENT_JITSI_JVB_PORT jitsi_major_version
  evaluate_file_content ${ETC_DIR}/jitsi/jitsi${jitsi_major_version}x.env.template ${DEPLOYMENT_DIR}/jitsi.env
  echo_info "Starting Jitsi call container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} based on image ${DEPLOYMENT_JITSI_IMAGE}:${DEPLOYMENT_JITSI_CALL_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME}
  create_docker_network ${DEPLOYMENT_JITSI_NETWORK_NAME}
  ${DOCKER_CMD} pull ${DEPLOYMENT_JITSI_IMAGE}:${DEPLOYMENT_JITSI_CALL_IMAGE_VERSION:-latest}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_CALL_HTTP_PORT}:80" \
    --env-file ${DEPLOYMENT_DIR}/jitsi.env \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --name ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} ${DEPLOYMENT_JITSI_IMAGE}:${DEPLOYMENT_JITSI_CALL_IMAGE_VERSION:-latest}
  echo_info "${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} container started"
  check_jitsi_call_availability

  echo_info "Starting Jitsi prosody container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} based on image jitsi/prosody:${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}
  cp -v ${ETC_DIR}/jitsi/algorithm.cfg.lua ${DEPLOYMENT_DIR}/algorithm.cfg.lua
  ${DOCKER_CMD} run \
    -d \
    -v ${DEPLOYMENT_DIR}/algorithm.cfg.lua:/config/config.d/algorithm.cfg.lua:ro \
    --env-file ${DEPLOYMENT_DIR}/jitsi.env \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --network-alias "xmpp.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} jitsi/prosody:${DEPLOYMENT_JITSI_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} container started"

  echo_info "Starting Jitsi Jicofo container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} based on image jitsi/jicofo:${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    --env-file ${DEPLOYMENT_DIR}/jitsi.env \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} jitsi/jicofo:"${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  echo_info "${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} container started"

  echo_info "Starting Jitsi JVB container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} based on image jitsi/jvb:${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_JVB_PORT}:${DEPLOYMENT_JITSI_JVB_PORT}/udp" \
    -p "${DEPLOYMENT_JITSI_JVB_COLIBRI_PORT}:9090" \
    --env-file ${DEPLOYMENT_DIR}/jitsi.env \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --network-alias "jvb.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} jitsi/jvb:"${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  echo_info "${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} container started"

  echo_info "Starting Jitsi Jibri container ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME} based on image jitsi/jibri:${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME}
  cp -v ${ETC_DIR}/jitsi/finalize.sh ${DEPLOYMENT_DIR}/finalize.sh
  chmod +x ${DEPLOYMENT_DIR}/finalize.sh
  evaluate_file_content ${ETC_DIR}/jitsi/jibri/jibri.conf.j2 ${DEPLOYMENT_DIR}/jibri.conf
  ${DOCKER_CMD} run \
    -d \
    -v /dev/shm:/dev/shm \
    -v ${DEPLOYMENT_DIR}/jibri.conf:/etc/jitsi/jibri/jibri.conf:ro \
    -v ${DEPLOYMENT_DIR}/finalize.sh:/tmp/finalize.sh \
    --cap-add SYS_ADMIN \
    --cap-add NET_BIND_SERVICE \
    --device /dev/snd \
    --shm-size=512m \
    --env-file ${DEPLOYMENT_DIR}/jitsi.env \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_JIBRI_CONTAINER_NAME} jitsi/jibri:"${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  echo_info "${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} container started"

  echo_info "Starting Jitsi Web container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} based on image exoplatform/jitsi-web:${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_WEB_HTTP_PORT}:80" \
    -p "${DEPLOYMENT_JITSI_WEB_HTTPS_PORT}:443" \
    --env-file ${DEPLOYMENT_DIR}/jitsi.env \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --network-alias "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} exoplatform/jitsi-web:"${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  echo_info "${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} container started"
  check_jitsi_web_availability
  ${DOCKER_CMD} exec ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} bash -c "echo \"interfaceConfig['DEFAULT_LOGO_URL'] = '${DEPLOYMENT_URL}/jitsicall/images/logo.png';\" >> \"/config/interface_config.js\""
  ${DOCKER_CMD} exec ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} bash -c "echo \"interfaceConfig['JITSI_WATERMARK_LINK'] = '';\" >> \"/config/interface_config.js\""
  ${DOCKER_CMD} exec ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} bash -c "rm -fv /usr/share/jitsi-meet/sounds/recordingOff.mp3 /usr/share/jitsi-meet/sounds/recordingOn.mp3"
  
  echo_info "Starting Jitsi excalidraw backend container ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME} based on image exoplatform/exo-excalidraw-backend:${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_IMAGE_VERSION}"

  delete_docker_container ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_PORT}:80" \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --network-alias "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME} exoplatform/exo-excalidraw-backend:"${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_IMAGE_VERSION}"  
  echo_info "${DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_CONTAINER_NAME} container started"
}

check_jitsi_call_availability() {
  echo_info "Waiting for Jitsi Call availability on port ${DEPLOYMENT_JITSI_CALL_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_JITSI_CALL_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Jitsi Call not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Jitsi Call ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Jitsi Call ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} up and available"
}

check_jitsi_web_availability() {
  echo_info "Waiting for Jitsi Web availability on port ${DEPLOYMENT_JITSI_WEB_HTTPS_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_JITSI_WEB_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Jitsi Web not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Jitsi Web ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Jitsi Web ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_JITSI_LOADED=true
echo_debug "_function_jitsi.sh Loaded"