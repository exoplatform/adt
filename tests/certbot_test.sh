#!/bin/bash
# sudo certbot must receive the values of the CI parameters as DATA: one argument each, never words of a command line.
#
# The EAB account (DEPLOYMENT_CERTBOT_EAB_KID, _HMAC_KEY) and the domain were put unquoted in the command line of
# 'sudo certbot': 'x --deploy-hook cmd' became extra arguments, and certbot runs the hook as root after the issuance. The domain
# also names the folder removed by 'sudo rm -rf' when an instance is undeployed ('..' would remove every certificate).
# sudo is replaced by a function that prints the arguments it gets.
#
#   tests/certbot_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0
bad() { echo "FAIL: $*"; fail=1; }

# runs a function of _functions_certbot.sh with sudo stubbed; stdout = the arguments of every sudo call, one per line
run() { # function, VAR=value...
  local fn=$1; shift
  ( cd "$(mktemp -d)"
    export "$@"
    SCRIPT_DIR="$ROOT"; ADT_DEBUG=false
    source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_string.sh"; source "$ROOT/_functions_certbot.sh"
    echo_info() { :; }; echo_warn() { echo "WARN: $*"; }; echo_error() { echo "ERROR: $*"; }
    evaluate_file_content() { :; }; do_reload_apache() { :; }
    # no certificate exists yet ('sudo test -f' fails), so the action is certonly; other sudo calls print their arguments
    sudo() { if [ "$1" = test ]; then return 1; fi; printf 'SUDO'; printf ' [%s]' "$@"; echo; }
    set -u
    "$fn"; echo "STATUS=$?" ) 2>&1
}
runq() { run "$@" | grep -v "^STATUS="; }   # the output without the exit status line
BASE=( DEPLOYMENT_URL=https://try.example.org DEPLOYMENT_CERTBOT_CONFIG_FOLDER=/etc/letsencrypt DEPLOYMENT_CERTBOT_WEBROOT_PATH=/srv/wwwcertbot
       DEPLOYMENT_CERTBOT_ACME_SERVER=https://acme.example.org/dir DEPLOYMENT_EXT_HOST=h.example.org APACHE_CONF_DIR=/x ETC_DIR=/y ADT_DEV_MODE=false )

# 1. what a normal issuance looks like: every value is one argument
want='SUDO [certbot] [--config-dir=/etc/letsencrypt] [--text] [--agree-tos] [--non-interactive] [certonly] [--rsa-key-size=4096] [--authenticator=webroot] [--webroot-path=/srv/wwwcertbot] [--cert-name=try.example.org] [--domains=try.example.org] [--server=https://acme.example.org/dir] [--email=certificates@exoplatform.com] [--eab-kid=kid-123_ABC] [--eab-hmac-key=aGVsbG8_d29ybGQ=]'
got="$(runq do_generate_certbot_certificate "${BASE[@]}" DEPLOYMENT_CERTBOT_EAB_KID=kid-123_ABC DEPLOYMENT_CERTBOT_EAB_HMAC_KEY=aGVsbG8_d29ybGQ=)"
[ "$got" = "$want" ] || bad "a normal issuance: got [$got]"
# the = form: no option of the call is followed by a separate value (a value starting with '-' could then be taken for an option)
for opt in --config-dir --rsa-key-size --authenticator --webroot-path --cert-name --domains --server --email --eab-kid --eab-hmac-key -a -d; do
  case "$got" in *"[$opt] ["*) bad "option $opt is given its value as a separate argument: $got";; esac
done
got="$(runq do_generate_certbot_certificate "${BASE[@]}")"
case "$got" in *"--eab-kid"*) bad "EAB options without an EAB account: $got";; esac
case "$got" in "SUDO [certbot]"*"[--domains=try.example.org]"*) ;; *) bad "no issuance without an EAB account: $got";; esac

# 2. the values of the EAB account cannot add arguments or run anything
for kid in 'x --deploy-hook touch_PWNED' 'x;touch PWNED' 'a b' 'x$(touch PWNED)' 'x`touch PWNED`' $'x\ny' 'x"y' "x'y" '--deploy-hook=rm' ''; do
  [ -z "$kid" ] && continue
  got="$(runq do_generate_certbot_certificate "${BASE[@]}" "DEPLOYMENT_CERTBOT_EAB_KID=$kid" DEPLOYMENT_CERTBOT_EAB_HMAC_KEY=abc)"
  case "$got" in *"SUDO [certbot]"*) bad "certbot was run with the EAB key id [$(printf '%q' "$kid")]: $got";; esac
  case "$got" in *"EAB_KID is not valid"*) ;; *) bad "no message for the EAB key id [$(printf '%q' "$kid")]: $got";; esac
done
for hmac in 'x --deploy-hook touch_PWNED' 'a b' 'x;y' $'x\ny' 'x`y`'; do
  got="$(runq do_generate_certbot_certificate "${BASE[@]}" DEPLOYMENT_CERTBOT_EAB_KID=kid "DEPLOYMENT_CERTBOT_EAB_HMAC_KEY=$hmac")"
  case "$got" in *"SUDO [certbot]"*) bad "certbot was run with the HMAC key [$(printf '%q' "$hmac")]: $got";; esac
done

# 3. the domain: a host name, or nothing is run (issuing and undeploying)
for url in 'http://../x' 'http://a b.example.org' 'https://-x.org' 'http://a..b.org' 'https://x.org.' 'https://a;touch PWNED.org' 'http://a$(id).org'; do
  # issuing: refused, sudo is not run
  got="$(run do_generate_certbot_certificate "${BASE[@]/DEPLOYMENT_URL=*/DEPLOYMENT_URL=$url}")"
  case "$got" in *"SUDO"*|*"STATUS="*) bad "issuing ran for the domain of [$url]: $got";; esac
  case "$got" in *"not a valid domain name"*) ;; *) bad "issuing: no message for [$url]: $got";; esac
  # undeploying: nothing is removed (no sudo), but it does not stop (status 0) and says why
  got="$(run do_unregister_certbot_certificate "${BASE[@]/DEPLOYMENT_URL=*/DEPLOYMENT_URL=$url}")"
  case "$got" in *"SUDO"*) bad "undeploy ran sudo for the domain of [$url]: $got";; esac
  case "$got" in *"WARN:"*"not a valid domain name"*"STATUS=0"*) ;; *) bad "undeploy must warn and go on for [$url]: $got";; esac
done
got="$(runq do_unregister_certbot_certificate "${BASE[@]}")"
case "$got" in *"SUDO [certbot] [delete] [--cert-name=try.example.org]"*) ;; *) bad "unregister of a valid domain: $got";; esac
ls PWNED 2>/dev/null && bad "something was run"

[ "$fail" -eq 0 ] && echo "certbot: ok" || { echo "certbot: FAILED"; exit 1; }
