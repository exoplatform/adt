#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DEBUGPROXY_LOADED:-false} && return
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

#
# The JDWP agent has no authentication nor encryption. When the debug mode is enabled,
# it listens on the loopback only and is reachable through the instance vhost
# (https://<host>/debug-ws, protected by the LDAP authentication of the vhost) thanks to a
# small WebSocket <-> TCP adapter (websocat) running in a container on the host network.
#
# Client side : the instructions (dialog of the debug badge) and the helper script (/adt-debug.sh) are served by the
#               front-end, see the remote debug dialog of web/internal/ui. They boil down to :
#                 websocat -E --binary --basic-auth user:password tcp-l:127.0.0.1:5005 wss://<host>/debug-ws
#               then attach the IDE debugger to localhost:5005
#
# DEPLOYMENT_DEBUG_EXPOSE_PORT=true restores the legacy behavior (JDWP on all interfaces, firewall port opened).
#

do_get_debugproxy_settings() {
  env_var DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME "${INSTANCE_KEY}_debugproxy"
}

#
# Tells if the debug adapter is required by the instance
#
is_debugproxy_required() {
  ${DEPLOYMENT_DEBUG_ENABLED:-false} && ! ${DEPLOYMENT_DEBUG_EXPOSE_PORT:-false}
}

#
# Drops the debug adapter container used by the instance.
#
do_drop_debugproxy_data() {
  echo_info "Drops Debug adapter container ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} ..."
  delete_docker_container ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME}
  echo_info "Done."
}

do_stop_debugproxy() {
  echo_info "Stopping Debug adapter ..."
  # No check on the debug mode: the container must be stopped even if the debug mode was just disabled
  ensure_docker_container_stopped ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME}
  echo_info "Debug adapter container ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} stopped."
}

do_start_debugproxy() {
  echo_info "Starting Debug adapter..."
  # Ensure there is no container with the same name (a previous one could be there if the debug mode was switched off)
  delete_docker_container ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME}
  if ! is_debugproxy_required; then
    echo_info "Debug adapter not required, skiping its container startup"
    return
  fi

  if [ -z "${DEPLOYMENT_DEBUG_WS_PORT:-}" ]; then
    # Instance deployed before the debug adapter was introduced
    echo_warn "Debug adapter port unknown (instance deployed with an older ADT) : redeploy the instance to enable the secured remote debug"
    return
  fi

  echo_info "Starting Debug adapter container ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} based on image ${DEPLOYMENT_DEBUGPROXY_IMAGE}:${DEPLOYMENT_DEBUGPROXY_IMAGE_VERSION}"

  # The host network is required to reach the JDWP agent bound on the loopback of the host.
  # Both sides are on 127.0.0.1 : only Apache (with its authentication) can reach the adapter.
  ${DOCKER_CMD} run \
    -d \
    --network host \
    --user 65534:65534 \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --memory 64m \
    --name ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} ${DEPLOYMENT_DEBUGPROXY_IMAGE}:${DEPLOYMENT_DEBUGPROXY_IMAGE_VERSION} \
    -E --binary "ws-l:127.0.0.1:${DEPLOYMENT_DEBUG_WS_PORT}" "tcp:127.0.0.1:${DEPLOYMENT_DEBUG_PORT}"
  echo_info "${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} container started"
  check_debugproxy_availability
}

check_debugproxy_availability() {
  echo_info "Waiting for Debug adapter availability on port ${DEPLOYMENT_DEBUG_WS_PORT}"
  local count=0
  local try=30
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e
    # Only checks that the adapter listens (the JVM may not have opened its JDWP port yet)
    (exec 3<>/dev/tcp/127.0.0.1/${DEPLOYMENT_DEBUG_WS_PORT}) 2>/dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $RET -ne 0 ]; then
    echo_error "Debug adapter ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Debug adapter ${DEPLOYMENT_DEBUGPROXY_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DEBUGPROXY_LOADED=true
echo_debug "_function_debugproxy.sh Loaded"
