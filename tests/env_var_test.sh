#!/bin/bash
# env_var / configurable_env_var / validate_env_var (_functions_core.sh) must never run what is in a value.
#
# The values come from CI parameters and developers (INSTANCE_ID, PRODUCT_VERSION, ...), and the defaults embed them.
# They used to be assigned with eval NAME="value": the value, already expanded by the caller, was expanded a second time,
# so INSTANCE_ID='x$(cmd)' or a double quote in a value ran commands as the deploy user.
#
#   tests/env_var_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0
check() { # label, got, want
  if [ "$2" != "$3" ]; then echo "FAIL: $1: got [$2], want [$3]"; fail=1; fi
}

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2

# run a snippet in a fresh shell that loaded the functions (ADT_DEBUG off, as in production)
run() {
  bash -c '
    SCRIPT_DIR='"$ROOT"'
    ADT_DEBUG=false
    source "'"$ROOT"'/_functions_core.sh"
    set -u
    '"$1"'
  ' 2>&1
}

# 1. a command substitution in a value is a string, not a command
out="$(run 'INSTANCE_ID='"'"'x$(touch PWNED_SUBST)'"'"'; env_var INSTANCE_KEY "plf-7.3-${INSTANCE_ID}"; printf "%s" "$INSTANCE_KEY"')"
check "command substitution in a value" "$out" 'plf-7.3-x$(touch PWNED_SUBST)'
# 2. neither is a quote that closes the string, a backtick, a semicolon or a newline
out="$(run 'BAD='"'"'a"; touch PWNED_QUOTE; "b`touch PWNED_TICK`'"'"'; configurable_env_var FOO "pre-${BAD}"; printf "%s" "$FOO"')"
check "quote, semicolon and backtick" "$out" 'pre-a"; touch PWNED_QUOTE; "b`touch PWNED_TICK`'
out="$(run 'V=$'"'"'line1\nline2 $HOME \\n'"'"'; env_var MULTI "$V"; printf "%s" "$MULTI"')"
check "newline, \$HOME and backslash kept as they are" "$out" $'line1\nline2 $HOME \\n'
ls PWNED_* 2>/dev/null && { echo "FAIL: a command of a value was run: $(ls PWNED_*)"; fail=1; }

# 3. what the callers rely on
out="$(run 'unset FOO; configurable_env_var FOO "default"; printf "%s" "$FOO"')"
check "configurable_env_var sets the default" "$out" "default"
out="$(run 'FOO=mine; configurable_env_var FOO "default"; printf "%s" "$FOO"')"
check "configurable_env_var keeps the value of the user" "$out" "mine"
out="$(run 'FOO=; configurable_env_var FOO "default"; printf "[%s]" "$FOO"')"
check "a variable set to the empty string counts as set" "$out" "[]"
out="$(run 'FOO=mine; env_var FOO "forced"; printf "%s" "$FOO"')"
check "env_var overrides" "$out" "forced"
out="$(run 'unset FOO; env_var FOO "v"; bash -c '"'"'printf "%s" "$FOO"'"'"'')"
check "the variable is exported" "$out" "v"
out="$(run 'configurable_env_var BAR "a b  c"; printf "%s" "$BAR"')"
check "spaces are kept" "$out" "a b  c"

# 4. validate_env_var
out="$(run 'unset NOPE; validate_env_var NOPE; echo reached')"
case "$out" in *"reached"*) echo "FAIL: validate_env_var did not stop on an unset variable"; fail=1;; esac
case "$out" in *"NOPE is not set"*) ;; *) echo "FAIL: no message for an unset variable: $out"; fail=1;; esac
out="$(run 'SET=1; validate_env_var SET; echo reached')"
check "validate_env_var accepts a set variable" "$out" "reached"

# 5. the name is a variable name, nothing else
for bad in 'A;touch PWNED_NAME' 'A B' 'A$(touch PWNED_NAME)' '1A' 'A-B' '' 'A[0]'; do
  # the name travels as data (BADNAME), not through the shell of the test
  out="$(BADNAME="$bad" run 'env_var "$BADNAME" x; echo reached')"
  case "$out" in *reached*) echo "FAIL: the name [$bad] was accepted"; fail=1;; esac
done
ls PWNED_NAME 2>/dev/null && { echo "FAIL: a name was run"; fail=1; }

[ "$fail" -eq 0 ] && echo "env_var: ok" || { echo "env_var: FAILED"; exit 1; }
