#!/bin/bash
# /.well-known/matrix/ serves the two discovery documents (client, server) and nothing else of the Matrix directory, in
# every mode of an instance. The directory also holds homeserver.yaml (registration, macaroon, form and JWT secrets),
# initialize.sh (the admin password) and the federation signing key.
#
# The rules come from BOTH templates, rendered as they are deployed: the Alias and <Directory> of the shared include, and the
# <LocationMatch> of the vhost. Apache merges <Location> sections AFTER <Directory> and <Files>: a "Require all granted" in the
# <LocationMatch> overrides the <Directory> rule for every file under the path (public instances with https were serving
# homeserver.yaml, initialize.sh and the signing key although the <Directory> denied them).
#
#   etc/apache2/tests/matrix-wellknown.sh      (needs httpd or apache2, python3 with jinja2, and curl)
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC="$HERE/.."
HTTPD="$(command -v httpd || command -v apache2 || true)"
[ -n "$HTTPD" ] || { echo "SKIP: no httpd/apache2"; exit 0; }
python3 -c 'import jinja2' 2>/dev/null || { echo "SKIP: no python3 jinja2"; exit 0; }
MODS="$(dirname "$(find /usr/lib64/httpd /usr/lib/apache2 /usr/lib/httpd -name mod_authz_core.so 2>/dev/null | head -1)")"
[ -d "$MODS" ] || { echo "SKIP: modules directory not found"; exit 0; }

W="$(mktemp -d)"; trap 'kill "$(cat "$W/httpd.pid" 2>/dev/null)" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/logs" "$W/matrix"
echo '{"m.homeserver":{"base_url":"https://x"}}' > "$W/matrix/client"
echo '{"m.server":"x:443"}' > "$W/matrix/server"
for f in homeserver.yaml initialize.sh matrix.host.signing.key; do echo "SECRET-$f" > "$W/matrix/$f"; done

# The rendered rules of one mode: the Alias + Directory of the include, and the LocationMatch of the vhost if it has one
render() { # security ssl
  python3 - "$ETC" "$W" "$1" "$2" <<'PY'
import jinja2, re, sys
etc, w, security, ssl = sys.argv[1:5]
env = jinja2.Environment(loader=jinja2.FileSystemLoader(etc), undefined=jinja2.Undefined)
v = dict(DEPLOYMENT_MATRIX_ENABLED="true", DEPLOYMENT_APACHE_SECURITY=security, DEPLOYMENT_APACHE_HTTPS_ENABLED=ssl,
         DEPLOYMENT_APACHE_HTTPSONLY_ENABLED="false", DEPLOYMENT_DIR=w, DEPLOYMENT_EXT_HOST="h", DEPLOYMENT_APACHE_VHOST_ALIAS="h",
         APACHE_CONF_DIR="/c")
inc = env.get_template("includes/instance.include.j2").render(**v)
vh = env.get_template("sites-available/instance.j2").render(**v)
a = re.search(r'^\s*Alias /\.well-known/matrix/.*?</Directory>', inc, re.S | re.M)
lm = re.search(r'<LocationMatch "\^/\.well-known/matrix.*?</LocationMatch>', vh, re.S)
print(a.group(0) if a else "")
print(lm.group(0) if lm else "")
PY
}

run_mode() { # name security ssl
  local rules; rules="$(render "$2" "$3")"
  case "$rules" in *"Alias /.well-known/matrix/"*) ;; *) echo "FAIL $1: no Alias for /.well-known/matrix/ in the include"; return 1;; esac
  cat > "$W/httpd.conf" <<CONF
ServerRoot "$W"
ServerName localhost
Listen 127.0.0.1:18143
PidFile "$W/httpd.pid"
ErrorLog "$W/logs/error.log"
LoadModule mpm_event_module $MODS/mod_mpm_event.so
LoadModule unixd_module $MODS/mod_unixd.so
LoadModule authz_core_module $MODS/mod_authz_core.so
LoadModule alias_module $MODS/mod_alias.so
LoadModule headers_module $MODS/mod_headers.so
LoadModule log_config_module $MODS/mod_log_config.so
$rules
CONF
  prune_modules "$W/httpd.conf"
  "$HTTPD" -f "$W/httpd.conf" -t >/dev/null 2>&1 || { echo "FAIL $1: the rules do not parse"; "$HTTPD" -f "$W/httpd.conf" -t; return 1; }
  "$HTTPD" -f "$W/httpd.conf" 2>/dev/null; sleep 1.5
  local rc=0 code f
  for f in client server; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:18143/.well-known/matrix/$f")"
    [ "$code" = 200 ] || { echo "FAIL $1: $f answers $code, want 200"; rc=1; }
  done
  for f in "" homeserver.yaml initialize.sh matrix.host.signing.key; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:18143/.well-known/matrix/$f")"
    case "$code" in 403|404) ;; *) echo "FAIL $1: /.well-known/matrix/$f answers $code, want 403"; rc=1;; esac
  done
  kill "$(cat "$W/httpd.pid")" 2>/dev/null; sleep 1
  return $rc
}

fail=0
run_mode "public with https (has the LocationMatch)" public true || fail=1
run_mode "private with https"                          private true || fail=1
run_mode "public without https"                        public false || fail=1
[ "$fail" -eq 0 ] && echo "matrix-wellknown: ok (only client and server are served, in every mode)" || { echo "matrix-wellknown: FAILED"; exit 1; }
