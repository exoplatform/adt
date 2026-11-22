#!/bin/bash
# The instance vhosts show their own page for 401 and 403, not only for 404/500/502/503.
#
# A 401 must keep its WWW-Authenticate header, or the browser never asks for a login: that is why the ErrorDocument is a local
# path (a URL would make Apache redirect). The page itself is served without authentication (/errors/instance/ is excepted from
# the proxy and has no auth rule), otherwise the error page would need a login of its own.
# The ErrorDocument lines are the ones of the rendered include; the pages are the files of web/static/errors/instance.
#
#   etc/apache2/tests/instance-error-pages.sh     (needs httpd or apache2, python3 with jinja2, htpasswd and curl)
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC="$HERE/.."; STATIC="$HERE/../../../web/static"
HTTPD="$(command -v httpd || command -v apache2 || true)"
[ -n "$HTTPD" ] || { echo "SKIP: no httpd/apache2"; exit 0; }
python3 -c 'import jinja2' 2>/dev/null || { echo "SKIP: no python3 jinja2"; exit 0; }
command -v htpasswd >/dev/null || { echo "SKIP: no htpasswd"; exit 0; }
MODS="$(dirname "$(find /usr/lib64/httpd /usr/lib/apache2 /usr/lib/httpd -name mod_authz_core.so 2>/dev/null | head -1)")"
[ -d "$MODS" ] || { echo "SKIP: modules directory not found"; exit 0; }
fail=0

LINES="$(python3 - "$ETC" <<'PY'
import jinja2, re, sys
env = jinja2.Environment(loader=jinja2.FileSystemLoader(sys.argv[1]), undefined=jinja2.Undefined)
out = env.get_template("includes/instance.include.j2").render(DEPLOYMENT_MATRIX_ENABLED="false", DEPLOYMENT_APACHE_SECURITY="private", DEPLOYMENT_DIR="/D",
        DEPLOYMENT_EXT_HOST="h", ADT_DATA="/A", APACHE_CONF_DIR="/c")
print("\n".join(l.strip() for l in out.splitlines() if re.match(r"\s*ErrorDocument ", l)))
PY
)"
for code in 401 403 404 500 502 503; do
  echo "$LINES" | grep -q "^ErrorDocument $code /errors/instance/$code.html$" || { echo "FAIL: no 'ErrorDocument $code /errors/instance/$code.html' in the instance include"; fail=1; }
  [ -f "$STATIC/errors/instance/$code.html" ] || { echo "FAIL: web/static/errors/instance/$code.html is missing"; fail=1; }
  grep -q "data-code=\"$code\"" "$STATIC/errors/instance/$code.html" 2>/dev/null || { echo "FAIL: $code.html does not say $code"; fail=1; }
done
[ "$fail" -eq 0 ] || { echo "instance-error-pages: FAILED"; exit 1; }

W="$(mktemp -d)"; trap 'kill "$(cat "$W/httpd.pid" 2>/dev/null)" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/logs"; htpasswd -bc "$W/users" u p >/dev/null 2>&1
cat > "$W/httpd.conf" <<CONF
ServerRoot "$W"
ServerName localhost
Listen 127.0.0.1:18144
PidFile "$W/httpd.pid"
ErrorLog "$W/logs/error.log"
LoadModule mpm_event_module $MODS/mod_mpm_event.so
LoadModule unixd_module $MODS/mod_unixd.so
LoadModule authz_core_module $MODS/mod_authz_core.so
LoadModule authz_user_module $MODS/mod_authz_user.so
LoadModule authn_core_module $MODS/mod_authn_core.so
LoadModule authn_file_module $MODS/mod_authn_file.so
LoadModule auth_basic_module $MODS/mod_auth_basic.so
LoadModule alias_module $MODS/mod_alias.so
LoadModule mime_module $MODS/mod_mime.so
LoadModule dir_module $MODS/mod_dir.so
LoadModule log_config_module $MODS/mod_log_config.so
TypesConfig /dev/null
AddType text/html .html
DocumentRoot "$STATIC"
<Directory "$STATIC">
    Options FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
$LINES
<Location /private>
    AuthType Basic
    AuthName "eXo Employees only"
    AuthUserFile "$W/users"
    Require valid-user
</Location>
<Location /refused>
    Require all denied
</Location>
CONF
prune_modules "$W/httpd.conf"
"$HTTPD" -f "$W/httpd.conf" -t >/dev/null 2>&1 || { echo "FAIL: the config does not parse"; "$HTTPD" -f "$W/httpd.conf" -t; exit 1; }
"$HTTPD" -f "$W/httpd.conf" 2>/dev/null; sleep 1.5
U=http://127.0.0.1:18144
out="$(curl -s -i --max-time 5 $U/private)"
echo "$out" | head -1 | grep -q " 401 " || { echo "FAIL: /private without credentials is not a 401"; fail=1; }
echo "$out" | grep -qi '^WWW-Authenticate: Basic' || { echo "FAIL: the 401 lost its WWW-Authenticate header (the browser would not ask for a login)"; fail=1; }
echo "$out" | grep -q 'data-code="401"' || { echo "FAIL: the 401 does not carry the instance page"; fail=1; }
out="$(curl -s -i --max-time 5 -u u:p $U/private)"
echo "$out" | head -1 | grep -q " 404 " || echo "$out" | head -1 | grep -q " 200 " || true   # with credentials: not a 401 any more
echo "$out" | head -1 | grep -q " 401 " && { echo "FAIL: valid credentials still get a 401"; fail=1; }
out="$(curl -s -i --max-time 5 $U/refused)"
echo "$out" | head -1 | grep -q " 403 " || { echo "FAIL: /refused is not a 403"; fail=1; }
echo "$out" | grep -q 'data-code="403"' || { echo "FAIL: the 403 does not carry the instance page"; fail=1; }
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $U/errors/instance/401.html)"
[ "$code" = 200 ] || { echo "FAIL: the error pages need no authentication to be read (got $code)"; fail=1; }
[ "$fail" -eq 0 ] && echo "instance-error-pages: ok (401 keeps its login prompt and shows the page, 403 shows its page)" || { echo "instance-error-pages: FAILED"; exit 1; }
