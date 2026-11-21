#!/bin/bash
# The Apache templates of the instances must not carry <ProxyMatch> exceptions to the LDAP rule.
#
# A <ProxyMatch> is tested against the URL sent to the backend, wherever the pattern matches in it: "rest" in
# "^.*/(rest|...)/.*$" matches /rest/..;/portal/ (Tomcat strips ";" and resolves "..") and /debug-ws/rest/x (the JDWP
# tunnel), so such an exception skips LDAP for the whole vhost as soon as it is evaluated after the <Proxy *> rule. The ones
# that used to be there were dead (evaluated before <Proxy *>): nothing relied on them. Checked on a real httpd.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
found="$(grep -rnE '<ProxyMatch|^[[:space:]]*ProxyMatch' sites-available includes conf.d 2>/dev/null | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' | grep -v '{#')"
if [ -n "$found" ]; then
  echo "FAIL: <ProxyMatch> in the instance templates (it can skip the LDAP rule):"; echo "$found"; exit 1
fi
echo "no-proxymatch: ok"
