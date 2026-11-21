#!/bin/bash
# replace_in_file puts values taken from the environment (ports, URLs, database names, ...) into @PLACEHOLDER@ of the files of an
# instance with sed. The value is data: with 's|@X@|<value>|g' a value holding the delimiter ends the substitution, and GNU sed's
# 'e' command then runs the rest as shell commands ('x|g;e cmd;s|a|b').
#
#   tests/replace_in_file_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0
bad() { echo "FAIL: $*"; fail=1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
load() { SCRIPT_DIR="$ROOT"; ADT_DEBUG=false; CMD_SED=sed; source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_files.sh"; set -u; }

# the placeholder is replaced by the value, exactly, whatever the value holds
for v in 'http://x/|g;e touch PWNED;s|a|b' 'a&b&&c' 'back\slash' 'two\\slashes' 'pipe|char' $'line1\nline2' '$HOME' '$(touch PWNED)' '`touch PWNED`' "it's" 'a"b' '/path/to/x' 'host:8080' '*' '[x]' '.' ''; do
  ( load
    printf '<a>@VALUE@</a>\n' > f.xml
    replace_in_file f.xml "@VALUE@" "$v"
    got="$(cat f.xml)"; want="<a>${v}</a>"
    [ "$got" = "$want" ] || { echo "FAIL: [$(printf '%q' "$v")] gave [$(printf '%q' "$got")]"; exit 1; } ) || fail=1
done
ls PWNED 2>/dev/null && bad "a value was run by sed"

# every occurrence, and the other lines are untouched
( load; printf 'a @P@ b @P@\nsecond @Q@ line\n' > f.xml; replace_in_file f.xml "@P@" "1|2"
  [ "$(cat f.xml)" = $'a 1|2 b 1|2\nsecond @Q@ line' ] ) || bad "several occurrences"

# the legacy form is unchanged: this is how evaluate_file_content escapes a single quote (sed syntax in the replacement on purpose)
( load; printf "it's\n" > f.txt; replace_in_file f.txt "'" "\\\\\\'"; [ "$(cat f.txt)" = "it\\'s" ] ) || bad "the legacy quote escape changed: $(cat "$W/f.txt")"

# the files of the callers are still the same shape: all of them replace @PLACEHOLDERS@
callers="$(grep -hE '^[[:space:]]*replace_in_file ' "$ROOT"/_functions*.sh | grep -vE 'replace_in_file \$\{_file_out\}' | awk '{print $3}' | tr -d '"' | sort -u)"
nonph="$(printf '%s\n' "$callers" | grep -vE '^@[A-Za-z0-9_]+@$' | grep -v '^$')"
[ -z "$nonph" ] || bad "a caller replaces something that is not a @PLACEHOLDER@ (its value would not be escaped): $nonph"

[ "$fail" -eq 0 ] && echo "replace_in_file: ok" || { echo "replace_in_file: FAILED"; exit 1; }
