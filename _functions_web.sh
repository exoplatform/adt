#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_WEB_LOADED:-false} && return
set -u

# The dashboard is adt-web (web/, Go): one static binary built from this checkout and run as a service behind
# Apache. These functions build it, install its environment file and restart the service.
#
#   do_build_web          build ${ADT_WEB_BIN} from web/ (skipped when the sources did not change)
#   do_deploy_web         build, render ${ADT_WEB_ENV_FILE}, restart ${ADT_WEB_SERVICE} when needed, check it answers
#   do_load_web_server    development: build, then run adt-web in the foreground (development mode, no Apache)

# docker, or sudo docker when the user is not allowed to talk to the daemon
_web_docker() {
  if docker info >/dev/null 2>&1; then
    docker "$@"
  else
    sudo /usr/bin/docker "$@"
  fi
}

# sha256 of everything the binary is built from (Go sources, go.mod and the embedded static files)
web_sources_hash() {
  (cd "${SCRIPT_DIR}/web" && find . -type f -print0 | sort -z | xargs -0 sha256sum) | sha256sum | cut -d' ' -f1
}

# The golang image web/ is built with when no suitable Go is installed (go 1.26 in web/go.mod)
ADT_WEB_GO_IMAGE_DEFAULT="golang:1.26.10-alpine@sha256:27f2d3b83cfc5803c8078f8e730af0f7c431bf067afaec8f60a36fb763187cba"

# Build ${ADT_WEB_BIN}. A local Go (>= the version of go.mod) is used when there is one, otherwise the build runs in a
# golang container, so the hosts need no Go toolchain. The binary is replaced atomically: a running service keeps the
# old one until it is restarted.
do_build_web() {
  validate_env_var "ADT_WEB_BIN"
  local _want _tmp _go_version
  _want=$(web_sources_hash)
  if [ -x "${ADT_WEB_BIN}" ] && [ "$(cat "${ADT_WEB_BIN}.sha" 2>/dev/null)" = "${_want}" ]; then
    echo_info "adt-web is up to date (${ADT_WEB_BIN})"
    return 0
  fi
  mkdir -p "$(dirname "${ADT_WEB_BIN}")"
  _tmp="${ADT_WEB_BIN}.new.$$"
  _go_version=$(awk '/^go /{print $2; exit}' "${SCRIPT_DIR}/web/go.mod")
  echo_info "Building adt-web (go ${_go_version}) ..."
  if command -v go >/dev/null 2>&1 && go version | grep -qE "go(${_go_version}|1\.(2[7-9]|[3-9][0-9]))"; then
    (cd "${SCRIPT_DIR}/web" && CGO_ENABLED=0 go build -buildvcs=false -trimpath -ldflags='-s -w' -o "${_tmp}" ./cmd/adt-web)
  else
    # Pinned by digest: the build does not depend on what a floating tag points to the day a host first pulls it (docker
    # run never refreshes an image it already has). Bump it with the Go patch releases. GOTOOLCHAIN=local: Go never
    # downloads another toolchain while building.
    configurable_env_var "ADT_WEB_GO_IMAGE" "${ADT_WEB_GO_IMAGE_DEFAULT}"
    _web_docker run --rm --user "$(id -u):$(id -g)" \
      -e CGO_ENABLED=0 -e GOTOOLCHAIN=local -e GOCACHE=/tmp/gocache -e GOPATH=/tmp/go -e GOFLAGS=-buildvcs=false \
      -v "${SCRIPT_DIR}/web:/src:ro" -v "$(dirname "${_tmp}"):/out" -w /src \
      "${ADT_WEB_GO_IMAGE}" go build -trimpath -ldflags='-s -w' -o "/out/$(basename "${_tmp}")" ./cmd/adt-web
  fi
  mv -f "${_tmp}" "${ADT_WEB_BIN}"
  echo "${_want}" > "${ADT_WEB_BIN}.sha"
  echo_info "adt-web built: ${ADT_WEB_BIN}"
}

# Build adt-web, render its environment file from the ADT variables and restart the service when the binary or the
# environment changed. Fails when the service does not answer on its socket afterwards.
do_deploy_web() {
  validate_env_var "ADT_WEB_ENV_FILE"
  validate_env_var "ADT_WEB_SERVICE"
  validate_env_var "ADT_WEB_SOCKET"
  do_build_web
  local _env_tmp _state_file _state
  mkdir -p "$(dirname "${ADT_WEB_ENV_FILE}")"
  _env_tmp="${ADT_WEB_ENV_FILE}.new.$$"
  evaluate_file_content "${ETC_DIR}/adt-web/adt-web.env.j2" "${_env_tmp}"
  mv -f "${_env_tmp}" "${ADT_WEB_ENV_FILE}"
  # restart when what the running service was started with (binary + environment) is not what is installed now
  _state_file="${ADT_WEB_BIN}.started"
  _state="$(cat "${ADT_WEB_BIN}.sha") $(sha256sum "${ADT_WEB_ENV_FILE}" | cut -d' ' -f1)"
  if [ "$(cat "${_state_file}" 2>/dev/null)" != "${_state}" ] || ! [ -S "${ADT_WEB_SOCKET}" ]; then
    echo_info "Restarting ${ADT_WEB_SERVICE} ..."
    if ! sudo /usr/sbin/service "${ADT_WEB_SERVICE}" restart; then
      echo_error "Unable to restart the ${ADT_WEB_SERVICE} service (is the unit installed and /usr/sbin/service ${ADT_WEB_SERVICE} restart allowed in sudoers?)"
      exit 1
    fi
    echo "${_state}" > "${_state_file}"
  else
    echo_info "${ADT_WEB_SERVICE} is up to date"
  fi
  local _i
  for _i in $(seq 1 30); do
    if curl -fsS --max-time 2 --unix-socket "${ADT_WEB_SOCKET}" http://localhost/healthz >/dev/null 2>&1; then
      echo_info "${ADT_WEB_SERVICE} answers on ${ADT_WEB_SOCKET}"
      return 0
    fi
    sleep 1
  done
  echo_error "${ADT_WEB_SERVICE} does not answer on ${ADT_WEB_SOCKET} (see: journalctl -u ${ADT_WEB_SERVICE})"
  exit 1
}

# Development: build adt-web and run it in the foreground, without Apache, with a fake identity (ADT_DEV_MODE)
do_load_web_server() {
  do_build_web
  echo_info "Starting adt-web on http://${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT} (development mode)"
  # ADT_STATIC_DIR and ADT_WEB_SRC make the static files and the HTML templates read from the sources on each
  # request, so they can be edited without rebuilding
  ADT_DEV_MODE=true ADT_DATA="${ADT_DATA}" ACCEPTANCE_SERVERS="${ACCEPTANCE_SERVERS}" \
    ADT_LISTEN="${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT}" ADT_STATIC_DIR="${SCRIPT_DIR}/web/static" \
    ADT_WEB_SRC="${SCRIPT_DIR}/web" exec "${ADT_WEB_BIN}"
}

_FUNCTIONS_WEB_LOADED=true
