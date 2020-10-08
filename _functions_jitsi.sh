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
  env_var DEPLOYMENT_JITSI_NETWORK_NAME "$(tolower "${INSTANCE_KEY}").jitsi"
}

#
# Drops all Jitsi data used by the instance.
#
do_drop_jitsi_data() {
  echo_info "Dropping Jitsi data ..."
  if ${DEPLOYMENT_JITSI_ENABLED}; then
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
    echo_info "Drops Jitsi docker volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_web ..."
    delete_docker_volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_web
    echo_info "Drops Jitsi docker volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_transcripts ..."
    delete_docker_volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_transcripts
    echo_info "Drops Jitsi docker volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_config ..."
    delete_docker_volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_config
    echo_info "Drops Jitsi docker volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_plugins-custom ..."
    delete_docker_volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_plugins-custom
    echo_info "Drops Jitsi docker volume ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}_jicofo ..."
    delete_docker_volume ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}_jicofo
    echo_info "Drops Jitsi docker volume ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}_config ..."
    delete_docker_volume ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}_config
    echo_info "Drops Jitsi docker network ${DEPLOYMENT_JITSI_NETWORK_NAME} ..."
    delete_docker_network ${DEPLOYMENT_JITSI_NETWORK_NAME}
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
    echo_info "Creation of the Jitsi Docker volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_web ..."
    create_docker_volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_web
    echo_info "Creation of the Jitsi Docker volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_transcripts ..."
    create_docker_volume ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_transcripts
    echo_info "Creation of the Jitsi Docker volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_config ..."
    create_docker_volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_config
    echo_info "Creation of the Jitsi Docker volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_plugins-custom ..."
    create_docker_volume ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_plugins-custom
    echo_info "Creation of the Jitsi Docker volume ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}_jicofo ..."
    create_docker_volume ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}_jicofo
    echo_info "Creation of the Jitsi Docker volume ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}_config ..."
    create_docker_volume ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}_config    
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
  echo_info "Done."
}

do_start_jitsi() {
  echo_info "Starting Jitsi..."
  if [ "${DEPLOYMENT_JITSI_ENABLED}" == "false" ]; then
    echo_info "Jitsi not specified, skiping its containers startup"
    return
  fi
  echo_info "Starting Jitsi call container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} based on image ${DEPLOYMENT_JITSI_IMAGE}:${DEPLOYMENT_JITSI_IMAGE_VERSION}"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_CALL_HTTP_PORT}:80" \
    -e "EXO_JWT_SECRET=MAPPudDBpSAqUwM0FY2r86gNAd6be5tN1xqwdFDOb4Us1DT4Tx" \
    -e "PUBLIC_URL= ${DEPLOYMENT_URL}" \
    -e "JWT_APP_SECRET=nQzPudDBpSAqUwM0FY2r86gNAd6be5tN1xqwdFDOb4Us1DT4Tx" \
    -e "JWT_APP_ID=exo-jitsi" \
    --name ${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} ${DEPLOYMENT_JITSI_IMAGE}:${DEPLOYMENT_JITSI_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_JITSI_CALL_CONTAINER_NAME} container started"
  check_jitsi_call_availability

  echo_info "Starting Jitsi call container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} based on image jitsi/prosody:latest"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -v ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_config:/config:Z  \
    -v ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME}_plugins-custom:/prosody-plugins-custom:Z \
    -e "AUTH_TYPE=jwt" \
    -e "ENABLE_AUTH=1" \
    -e "XMPP_DOMAIN=${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_AUTH_DOMAIN=auth.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_GUEST_DOMAIN=guest.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_MUC_DOMAIN=muc.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_INTERNAL_MUC_DOMAIN=internal-muc.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_RECORDER_DOMAIN=recorder.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "JICOFO_COMPONENT_SECRET=2024eb12115fccc435ac8382e347d5d9" \
    -e "JICOFO_AUTH_USER=focus" \
    -e "JICOFO_AUTH_PASSWORD=c4f0b969570298d5d77a8545f23dc8ce" \
    -e "JVB_AUTH_USER=jvb" \
    -e "JVB_AUTH_PASSWORD=a2f17f0b494489773ec879bd12ef6a12" \
    -e "JIGASI_XMPP_USER=jigasi" \
    -e "JIGASI_XMPP_PASSWORD=bf19cdebc0f1e9f444cc3a4eb4f3612c" \
    -e "JIBRI_XMPP_USER=jibri" \
    -e "JIBRI_XMPP_PASSWORD=9e40f754c897f55d83e6d51ba544be5e" \
    -e "JIBRI_RECORDER_USER=recorder" \
    -e "JIBRI_RECORDER_PASSWORD=682869f8ad2910a94e99f631bf597726" \
    -e "JWT_APP_ID=exo-jitsi" \
    -e "JWT_APP_SECRET=nQzPudDBpSAqUwM0FY2r86gNAd6be5tN1xqwdFDOb4Us1DT4Tx" \
    -e "TZ=UTC" \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --network-alias "xmpp.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} jitsi/prosody:latest
  echo_info "${DEPLOYMENT_JITSI_PROSODY_CONTAINER_NAME} container started"

  echo_info "Starting Jitsi call container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} based on image jitsi/jicofo:latest"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -v ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME}_jicofo:/config:Z  \
    -e "AUTH_TYPE=jwt" \
    -e "ENABLE_AUTH=1" \
    -e "XMPP_DOMAIN=${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_AUTH_DOMAIN=auth.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_MUC_DOMAIN=muc.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_INTERNAL_MUC_DOMAIN=internal-muc.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_SERVER=xmpp.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "JICOFO_COMPONENT_SECRET=2024eb12115fccc435ac8382e347d5d9" \
    -e "JICOFO_AUTH_USER=focus" \
    -e "JICOFO_AUTH_PASSWORD=c4f0b969570298d5d77a8545f23dc8ce" \
    -e "JVB_BREWERY_MUC=jvbbrewery" \
    -e "JIGASI_BREWERY_MUC=jigasibrewery" \
    -e "JIBRI_BREWERY_MUC=jibribrewery" \
    -e "JIBRI_PENDING_TIMEOUT=90" \
    -e "TZ=UTC" \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} jitsi/jicofo:latest
  echo_info "${DEPLOYMENT_JITSI_JICOFO_CONTAINER_NAME} container started"

  echo_info "Starting Jitsi call container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} based on image jitsi/jvb:latest"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_JVB_TCP_PORT}:4443" \
    -p "${DEPLOYMENT_JITSI_JVB_UDP_PORT}:10000/udp" \
    -v ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME}_config:/config:Z  \
    -e "XMPP_AUTH_DOMAIN=auth.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_INTERNAL_MUC_DOMAIN=internal-muc.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_SERVER=xmpp.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "JVB_AUTH_USER=jvb" \
    -e "JVB_AUTH_PASSWORD=a2f17f0b494489773ec879bd12ef6a12" \
    -e "JVB_BREWERY_MUC=jvbbrewery" \
    -e "JVB_PORT=${DEPLOYMENT_JITSI_JVB_UDP_PORT}" \
    -e "JVB_TCP_HARVESTER_DISABLED=true" \
    -e "JVB_TCP_PORT=${DEPLOYMENT_JITSI_JVB_TCP_PORT}" \
    -e "JVB_STUN_SERVERS=meet-jit-si-turnrelay.jitsi.net:443" \
    -e "TZ=UTC" \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} jitsi/jvb:latest
  echo_info "${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} container started"
  check_jitsi_jvb_availability

  echo_info "Starting Jitsi call container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} based on image jitsi/web:latest"
  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_JITSI_WEB_HTTP_PORT}:80" \
    -v ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_web:/config:Z  \
    -v ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME}_transcripts:/usr/share/jitsi-meet/transcripts:Z \
    -e "ENABLE_AUTH=1" \
    -e "DISABLE_HTTPS=1" \
    -e "JICOFO_AUTH_USER=focus" \
    -e "PUBLIC_URL= ${DEPLOYMENT_URL}/jitsi" \
    -e "XMPP_DOMAIN=${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_AUTH_DOMAIN=auth.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_BOSH_URL_BASE=http://xmpp.${DEPLOYMENT_JITSI_NETWORK_NAME}:5280" \
    -e "XMPP_GUEST_DOMAIN=guest.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_MUC_DOMAIN=muc.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "XMPP_RECORDER_DOMAIN=recorder.${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    -e "TZ=UTC" \
    -e "JIBRI_BREWERY_MUC=jibribrewery" \
    -e "JIBRI_PENDING_TIMEOUT=90" \
    -e "JIBRI_XMPP_USER=jibri" \
    -e "JIBRI_XMPP_PASSWORD=9e40f754c897f55d83e6d51ba544be5e" \
    -e "JIBRI_RECORDER_USER=recorder" \
    -e "JIBRI_RECORDER_PASSWORD=682869f8ad2910a94e99f631bf597726" \
    --network "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --network-alias "${DEPLOYMENT_JITSI_NETWORK_NAME}" \
    --restart unless-stopped \
    --name ${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} jitsi/web:latest
  echo_info "${DEPLOYMENT_JITSI_WEB_CONTAINER_NAME} container started"
  check_jitsi_web_availability
  
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
  echo_info "Waiting for Jitsi Web availability on port ${DEPLOYMENT_JITSI_WEB_HTTP_PORT}"
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

check_jitsi_jvb_availability() {
  echo_info "Waiting for Jitsi Jvb availability on port ${DEPLOYMENT_JITSI_JVB_TCP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_JITSI_JVB_TCP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Jitsi Jvb not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Jitsi Jvb ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Jitsi Jvb ${DEPLOYMENT_JITSI_JVB_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_JITSI_LOADED=true
echo_debug "_function_jitsi.sh Loaded"