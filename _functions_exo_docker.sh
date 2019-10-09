#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_EXO_DOCKER_LOADED:-false} && return
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

do_get_exo_docker_settings() {
  if ! ${DEPLOY_EXO_DOCKER}; then
    return;
  fi
  env_var DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME "${INSTANCE_KEY}_exo"
}

#
# Drops all exo docker data used by the instance.
#
do_drop_exo_docker_data() {
  echo_info "Dropping exo docker data ..."
  if ${DEPLOY_EXO_DOCKER}; then
    echo_info "Drops Exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs ..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data ..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_lib ..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_lib
    echo_info "Drops Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_db ..."
    delete_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_db
    echo_info "Done."
    echo_info "exo docker data dropped"
  else
    echo_info "Skip Drops exo docker container ..."
  fi
}

do_create_exo_docker() {
  if ${DEPLOY_EXO_DOCKER}; then
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_logs
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_data
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_lib ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_lib
    echo_info "Creation of the Exo docker volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_db ..."
    create_docker_volume ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}_db
  fi
}

do_stop_exo_docker() {
  echo_info "Stopping Exo docker ..."
  if ! ${DEPLOY_EXO_DOCKER}; then
    echo_info "Exo wasn't deployed in docker, skiping exo docker shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}
  echo_info "Exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} stopped."
}

do_start_exo_docker() {
  echo_info "Starting Exo docker..."
  if ! ${DEPLOYMENT_EXO_DOCKER_ENABLED}; then
    echo_info "Exo wasn't deployed in docker, skiping exo docker startup"
    return
  fi

  
  echo_info "Starting exo docker container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME} based on image ${DEPLOYMENT_EXO_DOCKER_IMAGE}:${DEPLOYMENT_EXO_DOCKER_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_EXO_DOCKER_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    -p "${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}:80" \
    -v ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}_logs:/var/log/onlyoffice  \
    -v ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}_data:/var/www/onlyoffice/Data  \
    -v ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}_lib:/var/lib/onlyoffice  \
    -v ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}_db:/var/lib/postgresql  \
    -v ${HOME}/.eXo/Platform/local.json:/etc/onlyoffice/documentserver/local.json  \
    --name ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} ${DEPLOYMENT_ONLYOFFICE_IMAGE}:${DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION}

  echo_info "${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} container started"

  check_onlyoffice_availability
}

check_onlyoffice_availability() {
  echo_info "Waiting for Onlyoffice DocumentServer availability on port ${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  local temp_file="/tmp/${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME}_${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}.txt"

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "OnlyOffice documentserver not yet available (${count} / ${try})..."
    else
      curl -f -s --max-time ${wait_time} http://localhost:${DEPLOYMENT_ONLYOFFICE_HTTP_PORT}/healthcheck > ${temp_file} 
      local status=$(grep "true" ${temp_file})
      if [ "${status}" == "true" ]; then
        RET=0   
      fi
    fi

    if [ $RET -ne 0 ]; then
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Onlyoffice DocumentServer ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Onlyoffice DocumentServer ${DEPLOYMENT_ONLYOFFICE_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_EXO_DOCKER_LOADED=true
echo_debug "_functions_onlyoffice.sh Loaded"
