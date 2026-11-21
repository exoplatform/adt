#!/bin/bash
# The front-end template only asks Apache for upgrade=websocket (the live channel of the pages) from 2.4.47, and decides on
# ADT_APACHE_VERSION_MINOR. Nothing set that variable on the hosts, so the live channel was never switched on: it is read from the
# installed Apache when it is empty, and what the environment says is never replaced.
#
#   tests/apache_version_test.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
bad() { echo "FAIL: $*"; fail=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fake() { # name, the line `-v` prints -> a fake apache binary in $W/bin
  mkdir -p "$W/bin"; printf '#!/bin/sh\necho "%s"\necho "Server built:   Jan  1 2026"\n' "$2" > "$W/bin/$1"; chmod +x "$W/bin/$1"
}
run() { # env assignments..., then the command; stdout of the command
  ( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_apache.sh"; set -u
    PATH="$W/bin:$PATH"; "$@" )
}

# detect_apache_version
fake apache2 "Server version: Apache/2.4.66 (Ubuntu)"
[ "$(run detect_apache_version apache2)" = "2.4 66" ] || bad "Apache/2.4.66 gave [$(run detect_apache_version apache2)]"
fake apache2 "Server version: Apache/2.4.58 (Ubuntu)"
[ "$(run detect_apache_version apache2)" = "2.4 58" ] || bad "Apache/2.4.58"
fake httpd "Server version: Apache/2.4.37 (Red Hat Enterprise Linux)"
[ "$(run detect_apache_version httpd)" = "2.4 37" ] || bad "httpd 2.4.37"
fake weird "something else entirely"
[ -z "$(run detect_apache_version weird)" ] || bad "an unknown output gave a version"
[ -z "$(run detect_apache_version no-such-command)" ] || bad "a missing command gave a version"
printf '#!/bin/sh\nexit 3\n' > "$W/bin/failing"; chmod +x "$W/bin/failing"
[ -z "$(run detect_apache_version failing)" ] || bad "a failing command gave a version"

# set_apache_version_defaults: fills what is empty, never replaces what is set, and does nothing when the version is unknown
fake apache2 "Server version: Apache/2.4.66 (Ubuntu)"
got="$(run bash -c 'true' ; ( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_apache.sh"; set -u; PATH="$W/bin:$PATH"
  unset ADT_APACHE_VERSION ADT_APACHE_VERSION_MINOR; set_apache_version_defaults apache2; echo "[${ADT_APACHE_VERSION:-}][${ADT_APACHE_VERSION_MINOR:-}]" ))"
[ "$got" = "[2.4][66]" ] || bad "unset variables are filled from Apache: $got"
got="$( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_apache.sh"; set -u; PATH="$W/bin:$PATH"
  export ADT_APACHE_VERSION=2.4 ADT_APACHE_VERSION_MINOR=41; set_apache_version_defaults apache2; echo "[${ADT_APACHE_VERSION}][${ADT_APACHE_VERSION_MINOR}]" )"
[ "$got" = "[2.4][41]" ] || bad "what the environment says was replaced: $got"
got="$( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_apache.sh"; set -u; PATH="$W/bin:$PATH"
  export ADT_APACHE_VERSION= ADT_APACHE_VERSION_MINOR=; set_apache_version_defaults apache2; echo "[${ADT_APACHE_VERSION}][${ADT_APACHE_VERSION_MINOR}]" )"
[ "$got" = "[2.4][66]" ] || bad "variables set to the empty string are filled too: $got"
got="$( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_apache.sh"; set -u; PATH="$W/bin:$PATH"
  export ADT_APACHE_VERSION=2.4; unset ADT_APACHE_VERSION_MINOR; set_apache_version_defaults apache2; echo "[${ADT_APACHE_VERSION}][${ADT_APACHE_VERSION_MINOR:-}]" )"
[ "$got" = "[2.4][66]" ] || bad "one set, one missing: $got"
got="$( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_apache.sh"; set -u
  unset ADT_APACHE_VERSION ADT_APACHE_VERSION_MINOR; set_apache_version_defaults no-such-command; echo "[${ADT_APACHE_VERSION:-}][${ADT_APACHE_VERSION_MINOR:-}]" )"
[ "$got" = "[][]" ] || bad "an undetectable Apache must leave the variables empty: $got"

# the result decides the front-end template: Apache 2.4.66 -> the live channel is on (python3 + jinja2 needed, skipped without)
if python3 -c 'import jinja2' 2>/dev/null; then
  has() { python3 - "$ROOT/etc/apache2/includes/frontend.include.j2" "$1" <<'PY'
import sys, jinja2
ctx = {"ADT_WEB_SOCKET": "/run/s.sock"}
if sys.argv[2]: ctx["ADT_APACHE_VERSION_MINOR"] = sys.argv[2]
out = jinja2.Environment(undefined=jinja2.Undefined).from_string(open(sys.argv[1]).read()).render(**ctx)
line = [l for l in out.splitlines() if l.strip().startswith('ProxyPassMatch "^(/events)$"')][0]
print("upgrade=websocket" in line)
PY
  }
  [ "$(has 66)" = True ] || bad "the template does not enable the live channel for 2.4.66"
  [ "$(has '')" = False ] || bad "the template enables the live channel without a version"
fi
[ "$fail" -eq 0 ] && echo "apache version: ok" || { echo "apache version: FAILED"; exit 1; }
