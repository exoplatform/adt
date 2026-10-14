#!/bin/bash -eu

# #############################################################################
# Remote debug bridge for an ADT instance
#
# The JDWP port of an instance is not exposed : it is reachable through the
# instance vhost (https://<instance-host>/debug-ws) which is protected by the
# LDAP authentication. This script opens a local port (default 5005) bridged to
# it. Attach your IDE remote debugger to localhost:5005.
# #############################################################################
SCRIPT_NAME="${0##*/}"
WEBSOCAT_VERSION="v1.14.1"

usage() {
  cat <<EOF
usage: ${SCRIPT_NAME} [-u <user>] [-p <local port>] <instance host | instance url>

Opens a local debug port bridged to the remote debug (JDWP) of an ADT instance.

Options
  -u <user>    LDAP user (default: \$ADT_DEBUG_USER, then \$USER)
  -p <port>    Local port to listen on, 127.0.0.1 only (default: 5005)
  -h           This help

Environment
  ADT_DEBUG_USER      LDAP user
  ADT_DEBUG_PASSWORD  LDAP password (asked interactively if not set)

Examples
  ${SCRIPT_NAME} myfeature-1.acceptance.exoplatform.org
  ${SCRIPT_NAME} -u jdoe -p 5006 https://myfeature-1.acceptance.exoplatform.org

Then attach your IDE remote debugger to localhost:<local port>.
The remote debug must be enabled on the instance (DEPLOYMENT_DEBUG_ENABLED=true).
EOF
}

echo_info()  { echo "[${SCRIPT_NAME}] $*"; }
echo_error() { echo "[${SCRIPT_NAME}] ERROR: $*" >&2; }

install_hint() {
  echo_error "websocat is required and wasn't found in your PATH."
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64|Linux-amd64) _arch="x86_64" ;;
    Linux-aarch64|Linux-arm64) _arch="aarch64" ;;
    Darwin-*)
      echo "Install it with : brew install websocat" >&2
      return ;;
    MINGW*|MSYS*|CYGWIN*)
      cat >&2 <<EOF
Install it (Git Bash, no admin needed) with :
  mkdir -p ~/bin
  curl -sSL -o ~/bin/websocat.exe https://github.com/vi/websocat/releases/download/${WEBSOCAT_VERSION}/websocat.x86_64-pc-windows-gnu.exe
then reopen Git Bash (so that ~/bin is in the PATH).
EOF
      return ;;
    *) _arch="" ;;
  esac
  if [ -n "${_arch}" ]; then
    cat >&2 <<EOF
Install it (no root needed) with :
  mkdir -p ~/.local/bin
  curl -sSL -o ~/.local/bin/websocat https://github.com/vi/websocat/releases/download/${WEBSOCAT_VERSION}/websocat.${_arch}-unknown-linux-musl
  chmod +x ~/.local/bin/websocat
EOF
  else
    echo "Download it from https://github.com/vi/websocat/releases" >&2
  fi
}

LOCAL_PORT=5005
USER_NAME="${ADT_DEBUG_USER:-${USER:-}}"

while getopts ":u:p:h" opt; do
  case "${opt}" in
    u) USER_NAME="${OPTARG}" ;;
    p) LOCAL_PORT="${OPTARG}" ;;
    h) usage; exit 0 ;;
    :) echo_error "Option -${OPTARG} requires an argument"; usage >&2; exit 1 ;;
    *) echo_error "Unknown option -${OPTARG}"; usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -ne 1 ]; then
  usage >&2
  exit 1
fi
TARGET="$1"

if ! [[ "${LOCAL_PORT}" =~ ^[0-9]+$ ]] || [ "${LOCAL_PORT}" -lt 1 ] || [ "${LOCAL_PORT}" -gt 65535 ]; then
  echo_error "Invalid local port: ${LOCAL_PORT}"
  exit 1
fi
if [ -z "${USER_NAME}" ]; then
  echo_error "No user : use -u or ADT_DEBUG_USER"
  exit 1
fi

if ! command -v websocat >/dev/null 2>&1; then
  install_hint
  exit 1
fi

# Build the WebSocket URL from a host name or an instance URL
case "${TARGET}" in
  https://*) WS_URL="wss://${TARGET#https://}" ;;
  http://*)  WS_URL="ws://${TARGET#http://}" ;;
  wss://*|ws://*) WS_URL="${TARGET}" ;;
  *) WS_URL="wss://${TARGET}" ;;
esac
WS_URL="${WS_URL%/}"
case "${WS_URL}" in
  */debug-ws) ;;
  *) WS_URL="${WS_URL}/debug-ws" ;;
esac
HTTP_URL="${WS_URL/#ws/http}"

if [ -z "${ADT_DEBUG_PASSWORD:-}" ]; then
  if [ ! -t 0 ]; then
    echo_error "No terminal to ask the password : set ADT_DEBUG_PASSWORD"
    exit 1
  fi
  read -r -s -p "LDAP password for ${USER_NAME}: " ADT_DEBUG_PASSWORD
  echo
fi

# Quick check of the access to give a clear message before starting the bridge
if command -v curl >/dev/null 2>&1; then
  # The credentials are given on stdin (not visible in the process list)
  _escaped="$(printf '%s:%s' "${USER_NAME}" "${ADT_DEBUG_PASSWORD}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  set +e
  _code="$(printf 'user = "%s"\n' "${_escaped}" | curl -s -K - -o /dev/null -m 3 -w '%{http_code}' \
    -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "${HTTP_URL}")"
  set -e
  case "${_code}" in
    101) ;;
    401) echo_error "Authentication failed (wrong user or password, or you are not allowed to access this instance)."; exit 1 ;;
    404) echo_error "${WS_URL} not found : is the remote debug enabled (DEPLOYMENT_DEBUG_ENABLED=true) and the instance deployed with a recent ADT ?"; exit 1 ;;
    502|503|504) echo_error "The instance debug adapter isn't reachable (HTTP ${_code}) : is the instance started with the remote debug enabled ?"; exit 1 ;;
    000) echo_error "Unable to reach ${HTTP_URL} (network, DNS or TLS error)."; exit 1 ;;
    *) echo_error "Unexpected answer from ${HTTP_URL} (HTTP ${_code})."; exit 1 ;;
  esac
fi

echo_info "Bridging 127.0.0.1:${LOCAL_PORT} <-> ${WS_URL} as ${USER_NAME}"
echo_info "Attach your IDE remote debugger to localhost:${LOCAL_PORT}. Press Ctrl+C to stop."
# Note : websocat only accepts the credentials as an argument, they are visible to the local users in the process list.
exec websocat -E --binary \
  --basic-auth "${USER_NAME}:${ADT_DEBUG_PASSWORD}" \
  "tcp-l:127.0.0.1:${LOCAL_PORT}" "${WS_URL}"
