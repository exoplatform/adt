#!/bin/bash
# /stats must run awstats.pl and nothing else of cgi-bin, and /stats/ must lead to it. The ScriptAlias and RedirectMatch
# lines are read from frontend.include.j2 and run on a private httpd with a cgi-bin that holds a second script.
#
#   etc/apache2/tests/stats-cgi.sh        (needs httpd or apache2 with mod_cgid or mod_cgi, and curl)
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../includes/frontend.include.j2"
HTTPD="$(command -v httpd || command -v apache2 || true)"
[ -n "$HTTPD" ] || { echo "SKIP: no httpd/apache2"; exit 0; }
MODS="$(dirname "$(find /usr/lib64/httpd /usr/lib/apache2 /usr/lib/httpd -name mod_authz_core.so 2>/dev/null | head -1)")"
[ -d "$MODS" ] || { echo "SKIP: modules directory not found"; exit 0; }
CGI=mod_cgid.so; [ -e "$MODS/$CGI" ] || CGI=mod_cgi.so; [ -e "$MODS/$CGI" ] || { echo "SKIP: no mod_cgi"; exit 0; }
case "$CGI" in mod_cgid.so) CGIMOD="cgid_module";; *) CGIMOD="cgi_module";; esac

W="$(mktemp -d)"; trap 'kill "$(cat "$W/httpd.pid" 2>/dev/null)" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/cgi-bin" "$W/logs"
printf '#!/bin/sh\necho "Content-Type: text/plain"\necho\necho AWSTATS-RAN\n' > "$W/cgi-bin/awstats.pl"
printf '#!/bin/sh\necho "Content-Type: text/plain"\necho\necho OTHER-SCRIPT-RAN\n' > "$W/cgi-bin/other.cgi"
chmod +x "$W/cgi-bin/"*

LINES="$(grep -E '^[[:space:]]*(ScriptAlias /stats|RedirectMatch "\^/?stats)' "$TEMPLATE" | sed "s#/usr/lib/cgi-bin#$W/cgi-bin#g")"
[ -n "$LINES" ] || { echo "FAIL: no ScriptAlias/RedirectMatch for /stats in the template"; exit 1; }
cat > "$W/httpd.conf" <<CONF
ServerRoot "$W"
ServerName localhost
Listen 127.0.0.1:18142
PidFile "$W/httpd.pid"
ErrorLog "$W/logs/error.log"
ScriptSock "$W/cgisock"
LoadModule mpm_event_module $MODS/mod_mpm_event.so
LoadModule unixd_module $MODS/mod_unixd.so
LoadModule authz_core_module $MODS/mod_authz_core.so
LoadModule alias_module $MODS/mod_alias.so
LoadModule $CGIMOD $MODS/$CGI
LoadModule log_config_module $MODS/mod_log_config.so
$LINES
<Directory "$W/cgi-bin">
    Options -Indexes +ExecCGI -MultiViews
    Require all granted
</Directory>
CONF
prune_modules "$W/httpd.conf"
"$HTTPD" -f "$W/httpd.conf" -t >/dev/null 2>&1 || { echo "FAIL: the lines do not parse"; "$HTTPD" -f "$W/httpd.conf" -t; exit 1; }
"$HTTPD" -f "$W/httpd.conf" 2>/dev/null; sleep 2
fail=0
body() { curl -s --max-time 5 "http://127.0.0.1:18142$1"; }
expect() { local got; got="$(body "$2")"; case "$got" in *"$3"*) ;; *) echo "FAIL $1: $2 -> '$got', want '$3'"; fail=1;; esac; }
expect_not() { local got; got="$(body "$2")"; case "$got" in *"$3"*) echo "FAIL $1: $2 ran '$3'"; fail=1;; esac; }
expect "awstats runs"                    /stats/awstats.pl      AWSTATS-RAN
expect "awstats with its query string"   "/stats/awstats.pl?config=acc.example.org" AWSTATS-RAN
expect_not "no other script of cgi-bin"  /stats/other.cgi       OTHER-SCRIPT-RAN
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:18142/stats/other.cgi)"
[ "$code" = 404 ] || { echo "FAIL other.cgi answers $code, want 404"; fail=1; }
loc="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 5 http://127.0.0.1:18142/stats/)"
[ "$loc" = "302 http://127.0.0.1:18142/stats/awstats.pl" ] || { echo "FAIL /stats/ -> $loc"; fail=1; }
[ "$fail" -eq 0 ] && echo "stats-cgi: ok" || { echo "stats-cgi: FAILED"; exit 1; }
