#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_NGINX_LOADED:-false} && return
set -u

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"

# Reload nginx in the Docker container
# $1 : Dev Mode (warning message instead of error)
# $2 : Container name (default: exo-nginx)
do_reload_nginx(){
  local _dev_mode=$1
  local _container=${2:-exo-nginx}
  shift
  if ! ${_dev_mode}; then
    if docker ps --format '{{.Names}}' | grep -q "^${_container}$"; then
      echo_info "Validating nginx configuration ..."
      if docker exec ${_container} nginx -t; then
        echo_info "Reloading nginx server ..."
        docker exec ${_container} nginx -s reload
        echo_info "Done."
      else
        echo_error "nginx configuration test failed! Not reloading."
      fi
    else
      echo_error "Container ${_container} is not running. Cannot reload nginx."
    fi
  else
    echo_warn "Development Mode: No nginx server reload."
  fi
}

_FUNCTIONS_NGINX_LOADED=true
echo_debug "_functions_nginx.sh Loaded"
