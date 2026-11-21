#!/bin/bash
# upgrade=websocket (the live channel of the pages) is unknown to Apache before 2.4.47 and would make the configuration test fail,
# which takes every virtual host down. The front-end template only writes it when ADT_APACHE_VERSION_MINOR says 47 or more.
#
#   tests/websocket_gate_test.sh        (needs python3 with jinja2: skipped without)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -c 'import jinja2' 2>/dev/null || { echo "SKIP: python3 jinja2 not available"; exit 0; }
fail=0
line() { # ADT_APACHE_VERSION_MINOR value (or UNSET) -> the ProxyPassMatch line of /events
  python3 - "$ROOT/etc/apache2/includes/frontend.include.j2" "$1" <<'PY'
import sys, jinja2
tpl, minor = sys.argv[1], sys.argv[2]
ctx = {"ADT_WEB_SOCKET": "/run/adt-web/adt-web.sock"}
if minor != "UNSET": ctx["ADT_APACHE_VERSION_MINOR"] = minor
out = jinja2.Environment(undefined=jinja2.Undefined, keep_trailing_newline=True).from_string(open(tpl).read()).render(**ctx)
print([l for l in out.splitlines() if l.strip().startswith('ProxyPassMatch "^(/events)$"')][0])
PY
}
check() { # value, want yes|no
  got="$(line "$1")"
  case "$got" in *"upgrade=websocket"*) has=yes;; *) has=no;; esac
  [ "$has" = "$2" ] || { echo "FAIL: ADT_APACHE_VERSION_MINOR=[$1]: upgrade=websocket $has, want $2 ($got)"; fail=1; }
  case "$got" in *"flushpackets=on"*) ;; *) echo "FAIL: [$1]: flushpackets=on lost: $got"; fail=1;; esac
}
for v in 47 48 58 66 100 2.4.47 2.4.66; do check "$v" yes; done
for v in 0 1 41 46 2.4.46 2.4.37 UNSET "" abc; do check "$v" no; done
[ "$fail" -eq 0 ] && echo "websocket gate: ok" || { echo "websocket gate: FAILED"; exit 1; }
