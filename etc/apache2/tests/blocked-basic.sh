#!/bin/bash
# A user blocked from /debug-sessions must be refused on the HTTP Basic paths of the front-end too (/downloads, /datasets,
# /stats): they do not use the session, so the block (sha1 of the lower-cased login in revoked.txt) is all that can cut them.
# The RequireNone lines are read from frontend.include.j2 and run on a private httpd with Basic auth on a password file.
#
#   etc/apache2/tests/blocked-basic.sh        (needs httpd or apache2, htpasswd and curl)
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../includes/frontend.include.j2"
HTTPD="$(command -v httpd || command -v apache2 || true)"
[ -n "$HTTPD" ] && command -v htpasswd >/dev/null || { echo "SKIP: no httpd/apache2 or htpasswd"; exit 0; }
MODS="$(dirname "$(find /usr/lib64/httpd /usr/lib/apache2 /usr/lib/httpd -name mod_authz_core.so 2>/dev/null | head -1)")"
[ -d "$MODS" ] || { echo "SKIP: modules directory not found"; exit 0; }

W="$(mktemp -d)"; trap 'kill "$(cat "$W/httpd.pid" 2>/dev/null)" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/www" "$W/logs"; echo downloaded > "$W/www/file.txt"
htpasswd -b -c "$W/users" alice pw >/dev/null 2>&1   # -c only for the first one: it creates the file
htpasswd -b "$W/users" bob pw >/dev/null 2>&1
htpasswd -b "$W/users" Carol pw >/dev/null 2>&1
printf '%s\n' "$(printf 'bob' | sha1sum | cut -d' ' -f1)" "$(printf 'carol' | sha1sum | cut -d' ' -f1)" > "$W/revoked.txt"

# the RequireNone block of the Basic-auth LocationMatch
BLOCK="$(sed -n '/<LocationMatch "\^\/(downloads|datasets|stats)/,/<\/LocationMatch>/p' "$TEMPLATE" | sed -n '/<RequireNone>/,/<\/RequireNone>/p' | sed "s#{{ ADT_DATA }}/var/sessions/revoked.txt#$W/revoked.txt#")"
printf '%s' "$BLOCK" | grep -q 'REMOTE_USER' || { echo "FAIL: no block check in the Basic-auth LocationMatch of the template"; exit 1; }

cat > "$W/httpd.conf" <<CONF
ServerRoot "$W"
ServerName localhost
Listen 127.0.0.1:18143
PidFile "$W/httpd.pid"
ErrorLog "$W/logs/error.log"
LoadModule mpm_event_module $MODS/mod_mpm_event.so
LoadModule unixd_module $MODS/mod_unixd.so
LoadModule authz_core_module $MODS/mod_authz_core.so
LoadModule authn_core_module $MODS/mod_authn_core.so
LoadModule authn_file_module $MODS/mod_authn_file.so
LoadModule authz_user_module $MODS/mod_authz_user.so
LoadModule auth_basic_module $MODS/mod_auth_basic.so
LoadModule dir_module $MODS/mod_dir.so
LoadModule log_config_module $MODS/mod_log_config.so
DocumentRoot "$W/www"
<Directory "$W/www">
    AuthType Basic
    AuthName "x"
    AuthBasicProvider file
    AuthUserFile "$W/users"
    <RequireAll>
        Require valid-user
$BLOCK
    </RequireAll>
</Directory>
CONF
prune_modules "$W/httpd.conf"
"$HTTPD" -f "$W/httpd.conf" -t >/dev/null 2>&1 || { echo "FAIL: the template lines do not parse"; "$HTTPD" -f "$W/httpd.conf" -t; exit 1; }
"$HTTPD" -f "$W/httpd.conf" 2>/dev/null; sleep 1
fail=0
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 3 -u "$1" http://127.0.0.1:18143/file.txt; }
want() { local got; got="$(code "$2")"; [ "$got" = "$3" ] || { echo "FAIL $1: $got, want $3"; fail=1; }; }
want "a user who is not blocked"                         alice:pw 200
want "a blocked user"                                    bob:pw 401
want "a blocked user typing the login in another case"   Carol:pw 401
want "a wrong password stays refused"                    alice:bad 401
[ "$fail" -eq 0 ] && echo "blocked-basic: ok" || { echo "blocked-basic: FAILED"; exit 1; }
