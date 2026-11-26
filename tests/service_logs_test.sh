#!/bin/bash
# The index of /logs/ lists the logs of Matrix and Keycloak: relative links logs/app/<service> -> ../<service>, created by
# do_link_service_logs. nginx serves logs/app; in its container the directory of each service is mounted next to it, so the
# link is resolved there. The link of a service that is not enabled is removed, and a real directory is never replaced.
#
#   tests/service_logs_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0
bad() { echo "FAIL: $*"; fail=1; }
W="$(mktemp -d)"; trap 'rm -rf "${W:?}"' EXIT
( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false
  source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_string.sh"; source "$ROOT/_functions_compose.sh"
  echo_warn() { echo "WARN: $*"; }
  export DEPLOYMENT_LOG_DIR="$W/logs"
  mkdir -p "$W/logs/app" "$W/logs/matrix" "$W/logs/keycloak"; echo m > "$W/logs/matrix/synapse.log"; echo k > "$W/logs/keycloak/keycloak.log"

  DEPLOYMENT_MATRIX_ENABLED=true DEPLOYMENT_KEYCLOAK_ENABLED=true do_link_service_logs
  [ "$(readlink "$W/logs/app/matrix")" = "../matrix" ] && [ "$(readlink "$W/logs/app/keycloak")" = "../keycloak" ] || bad "links not created"
  # what nginx sees: logs/app and the directories of the services side by side (the container mounts them at /var/log/...)
  [ "$(cat "$W/logs/app/matrix/synapse.log")" = m ] && [ "$(cat "$W/logs/app/keycloak/keycloak.log")" = k ] || bad "links do not resolve"
  [ "$(ls "$W/logs/app" | sort | tr '\n' ' ')" = "keycloak matrix " ] || bad "the index of logs/app does not list the folders"

  # run again: still two links, not links inside the targets
  DEPLOYMENT_MATRIX_ENABLED=true DEPLOYMENT_KEYCLOAK_ENABLED=true do_link_service_logs
  [ ! -e "$W/logs/matrix/matrix" ] && [ ! -e "$W/logs/keycloak/keycloak" ] || bad "a second run created a link inside a target"

  # a service that is disabled loses its link
  DEPLOYMENT_MATRIX_ENABLED=false DEPLOYMENT_KEYCLOAK_ENABLED=true do_link_service_logs
  [ ! -e "$W/logs/app/matrix" ] && [ -L "$W/logs/app/keycloak" ] || bad "the link of a disabled service was kept (or the other one lost)"
  DEPLOYMENT_KEYCLOAK_ENABLED=false do_link_service_logs
  [ -z "$(ls -A "$W/logs/app")" ] || bad "no service enabled: logs/app should be empty"

  # a real directory is left alone, with a warning
  mkdir "$W/logs/app/matrix"; echo own > "$W/logs/app/matrix/f"
  out="$(DEPLOYMENT_MATRIX_ENABLED=true do_link_service_logs 2>&1)"
  [ -d "$W/logs/app/matrix" ] && [ ! -L "$W/logs/app/matrix" ] && [ -f "$W/logs/app/matrix/f" ] || bad "a real directory was replaced"
  case "$out" in *"is not a link"*) ;; *) bad "no warning for a real directory: $out";; esac
) || fail=1
[ "$fail" -eq 0 ] && echo "service logs: ok" || { echo "service logs: FAILED"; exit 1; }
