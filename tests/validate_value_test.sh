#!/bin/bash
# The identifiers a deployment starts from (PRODUCT_NAME, PRODUCT_VERSION, INSTANCE_ID, the Apache alias and the domain) are
# checked with validate_value where they enter (_functions.sh). They end up in file names, in the Apache and logrotate
# configuration rendered by Jinja (not quoted for them), in sed expressions and on the command line of sudo: a newline in the
# alias adds a directive to a virtual host that Apache reads as root. The patterns are taken from the source, so this tests what runs.
#
#   tests/validate_value_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0

pattern() { grep -m1 -E "^[[:space:]]*validate_value $1 " "$ROOT/_functions.sh" | sed -E "s/^[^']*'([^']+)'.*/\1/"; }
accepts() { # var pattern value -> 0 when validate_value lets it through
  ( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; set -u
    echo_error() { :; }
    V="$3"; export V
    eval "$1=\$V"
    validate_value "$1" "$2" "test" ) >/dev/null 2>&1
}
expect() { # var want(yes|no) value
  local pat; pat="$(pattern "$1")"
  [ -n "$pat" ] || { echo "FAIL: no validate_value $1 in _functions.sh"; fail=1; return; }
  if accepts "$1" "$pat" "$3"; then got=yes; else got=no; fi
  [ "$got" = "$2" ] || { echo "FAIL: $1 [$(printf '%q' "$3")]: $got, want $2"; fail=1; }
}

for v in plf plfent plfentrial meeds exo plfsales plf-7_3 A1; do expect PRODUCT_NAME yes "$v"; done
for v in 'x$(id)' 'a b' 'a;b' 'a"b' 'a`id`' '../x' 'a/b' $'a\nb' $'plf\n' "a'b" '1plf' '-plf' '_plf' "$(printf 'a%.0s' {1..60})"; do expect PRODUCT_NAME no "$v"; done

for v in 7.3.x-SNAPSHOT 6.5.0-RC01 7.2.0-MLT 7.0.0-20260101 7.3.0-M12 develop 7.3.x-feature-foo.bar-SNAPSHOT 1.0+build5; do expect PRODUCT_VERSION yes "$v"; done
for v in '7.3$(touch x)' '7.3;id' '7 3' '7.3"' '7.3`id`' '../../etc' '7/3' $'7.3\n' $'7.3\nX' '.7' '-7' '7.3|id' '7.3&id' '7.3>x' "$(printf '7%.0s' {1..90})"; do expect PRODUCT_VERSION no "$v"; done

for v in 1 mlt qa-2 test.1 a_b team-x; do expect INSTANCE_ID yes "$v"; done
for v in 'x$(touch y)' 'a b' 'a/b' '../a' $'a\nb' 'a;b' 'a"b' '.a' '-a' 'a`b`' "$(printf 'a%.0s' {1..50})"; do expect INSTANCE_ID no "$v"; done

for v in try.exoplatform.com acc-1.exoplatform.org a.b A1 x-y.z.example.org; do expect DEPLOYMENT_APACHE_VHOST_ALIAS yes "$v"; done
for v in $'a.example.org\nErrorLog "|/bin/sh -c x"' $'a.example.org\nRequire all granted' 'a.example.org Require all granted' 'a b.example.org' 'a/b' '../a' 'a;b' 'a.example.org;' '.a.com' '-a.com' 'a.com-' 'a.com.' $'a.com\n' 'a$(id).com' 'a"b.com' '*.com'; do expect DEPLOYMENT_APACHE_VHOST_ALIAS no "$v"; done
for v in exoplatform.org meeds.io example.com; do expect INSTANCE_DOMAIN yes "$v"; done
for v in $'x.org\nrm' 'x y' 'x/y' '../x' 'x;y'; do expect INSTANCE_DOMAIN no "$v"; done

# an empty value is not this function's business (the callers say elsewhere when a variable is required)
for var in PRODUCT_VERSION INSTANCE_ID DEPLOYMENT_APACHE_VHOST_ALIAS INSTANCE_DOMAIN; do expect "$var" yes ""; done

# the stop itself: a refused value exits and says which variable
out="$( SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; source "$ROOT/_functions_core.sh"; set -u; INSTANCE_ID='a b'
        validate_value INSTANCE_ID "$(pattern INSTANCE_ID)" "letters"; echo reached )"
case "$out" in *reached*) echo "FAIL: validate_value did not stop"; fail=1;; esac
case "$out" in *INSTANCE_ID*) ;; *) echo "FAIL: the message does not name the variable: $out"; fail=1;; esac

[ "$fail" -eq 0 ] && echo "validate_value: ok" || { echo "validate_value: FAILED"; exit 1; }
