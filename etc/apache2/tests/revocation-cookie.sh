#!/bin/bash
# Regression test of the session revocation rule of frontend.include.j2: a variant of an evicted session cookie must
# not get past it. The rule lines are read from the template itself and run on a private httpd (core modules only,
# no mod_session): the question is only which Cookie headers the rule lets through.
#
#   etc/apache2/tests/revocation-cookie.sh        (needs httpd or apache2, and curl)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../includes/frontend.include.j2"
HTTPD="$(command -v httpd || command -v apache2 || true)"
[ -n "$HTTPD" ] || { echo "SKIP: no httpd/apache2"; exit 0; }
MODS="$(dirname "$(find /usr/lib64/httpd /usr/lib/apache2 /usr/lib/httpd -name mod_authz_core.so 2>/dev/null | head -1)")"
[ -d "$MODS" ] || { echo "SKIP: modules directory not found"; exit 0; }

W="$(mktemp -d)"; trap 'kill "$(cat "$W/httpd.pid" 2>/dev/null)" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/www" "$W/logs"; echo ok > "$W/www/index.html"
PORT=18141
SESS='ABCdef123_-+/='
printf '%s\n' "$(printf '%s' "$SESS" | sha1sum | cut -d' ' -f1)" > "$W/revoked.txt"

# the Require lines of the first <RequireAll> that mention the cookie, with the template variable filled in
RULES="$(sed -n '/<RequireAll>/,/<\/RequireAll>/p' "$TEMPLATE" | grep -E 'Require +expr +"(!\(%\{req:Cookie\}|-z %\{req:Cookie2\}|%\{req:Cookie\} !~)' | sed "s#{{ ADT_DATA }}/var/sessions/revoked.txt#$W/revoked.txt#")"
# both places that check revocation (all employees, and the stricter admin rule) must carry the same three lines
[ "$(printf '%s\n' "$RULES" | wc -l)" -eq 6 ] && [ "$(printf '%s\n' "$RULES" | head -3)" = "$(printf '%s\n' "$RULES" | tail -3)" ] \
  || { echo "FAIL: expected the same 3 cookie rules in each of the 2 RequireAll blocks, found: $RULES"; exit 1; }
RULES="$(printf '%s\n' "$RULES" | head -3)"

run() { # name, rules
  cat > "$W/httpd.conf" <<CONF
ServerRoot "$W"
ServerName localhost
Listen 127.0.0.1:$PORT
PidFile "$W/httpd.pid"
ErrorLog "$W/logs/error.log"
LoadModule mpm_event_module $MODS/mod_mpm_event.so
LoadModule unixd_module $MODS/mod_unixd.so
LoadModule authz_core_module $MODS/mod_authz_core.so
LoadModule dir_module $MODS/mod_dir.so
LoadModule log_config_module $MODS/mod_log_config.so
DocumentRoot "$W/www"
<Directory "$W/www">
  <RequireAll>
    Require all granted
$2
  </RequireAll>
</Directory>
CONF
  "$HTTPD" -f "$W/httpd.conf" -t >/dev/null 2>&1 || { echo "FAIL: $1 rule does not parse"; "$HTTPD" -f "$W/httpd.conf" -t; exit 1; }
  "$HTTPD" -f "$W/httpd.conf" 2>/dev/null; sleep 1
}
stop() { kill "$(cat "$W/httpd.pid")" 2>/dev/null; sleep 1; }
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$@" "http://127.0.0.1:$PORT/"; }
fail=0
expect() { # want label curl-args...
  local want="$1" label="$2"; shift 2; local got; got="$(code "$@")"
  if [ "$got" != "$want" ]; then echo "FAIL [$MODE] $label: got $got, want $want"; fail=1; fi
}
cases() {
  expect 403 "evicted cookie, canonical"                       -H "Cookie: adt_session=$SESS"
  expect 403 "evicted, after another cookie"                   -H "Cookie: a=b; adt_session=$SESS"
  expect 200 "valid session"                                   -H "Cookie: adt_session=OtherSession123"
  expect 200 "valid, among other cookies"                      -H "Cookie: a=b; theme=dark; adt_session=OtherSession123; z=1"
  expect 200 "no session cookie"                               -H "Cookie: a=b"
  expect 200 "no cookie"
}
variants() { want="$1"
  expect "$want" "evicted, two spaces before the name"         -H "Cookie: a=b;  adt_session=$SESS"
  expect "$want" "evicted, tab before the name"                -H $'Cookie: a=b;\tadt_session='"$SESS"
  expect "$want" "evicted, separated by comma"                 -H "Cookie: a=b, adt_session=$SESS"
  expect "$want" "evicted, followed by a comma"                -H "Cookie: adt_session=$SESS, x=1"
  expect "$want" "evicted, only in a Cookie2 header"           -H "Cookie2: adt_session=$SESS"
}

# 1. the rule of the template: every variant is refused, the real sessions are not
MODE=template; run template "$RULES"; cases; variants 403
expect 200 "valid session, another cookie holding a comma"     -H "Cookie: prefs=a,b; adt_session=OtherSession123"
stop
# 2. the first rule alone (what the template had before): the test must be able to see the bypass
MODE=old-rule; run old "$(printf '%s\n' "$RULES" | head -1)"; cases; variants 200; stop
if [ "$fail" -ne 0 ]; then echo "revocation-cookie: FAILED"; exit 1; fi
echo "revocation-cookie: ok (every cookie variant of an evicted session is refused; the old rule let them through)"
