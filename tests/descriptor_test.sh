#!/bin/bash
# The deployment descriptor (etc/adt/config.j2) and the artifact .info file are written from CI parameters and from what a
# repository returns, and SOURCED by bash at every later list, start, stop and undeploy (possibly by a more privileged operator):
# a value that closes its quotes or holds $(...) or a backtick used to run there, again and again.
#
# The descriptor keeps its values RAW: callers write DEPLOYMENT_OPTS with escapes that bash consumes when the file is sourced
# (\" for the quotes of a cron expression, \$ in a regular expression, bare "..." pairs, ${VAR}), as documented in adt.sh.
# assert_sourceable refuses what executes, and nothing else.
#
#   tests/descriptor_test.sh        (the template part needs python3 with jinja2: skipped without)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
fail=0
bad() { echo "FAIL: $*"; fail=1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2

# the functions under test, loaded the way adt.sh loads them
load() {
  SCRIPT_DIR="$ROOT"; ADT_DEBUG=false
  source "$ROOT/_functions_core.sh"; source "$ROOT/_functions_string.sh"; source "$ROOT/_functions_files.sh"
  echo_error() { :; }
  set -u
}

HOSTILE=( 'x"; touch PWNED; "' '$(touch PWNED)' '`touch PWNED`' 'a" touch PWNED "b' 'a";touch PWNED;"' '${X:-$(touch PWNED)}' '$((1+1))' '$[1+1]' 'a b" c' 'unterminated"' )

# 1. dq_escape (the .info files): written as NAME="<escaped>" and sourced, the value comes back as it was, and nothing runs
for v in "${HOSTILE[@]}" '\' 'a\"b$c`d' '${HOME}' '$HOME' "it's" '*' '~' ' lead and trail ' '#not a comment' '!bang' 'a;b|c&d' '""' '\\\"' $'two\nlines' ''; do
  ( load
    printf 'NAME="%s"\n' "$(dq_escape "$v")" > "$W/f.info"
    got="$(source "$W/f.info"; printf '%s' "$NAME")"
    [ "$got" = "$v" ] || { echo "FAIL: dq_escape round trip: [$(printf '%q' "$v")] came back as [$(printf '%q' "$got")]"; exit 1; } ) || fail=1
done
ls PWNED 2>/dev/null && bad "a value was run by source (dq_escape)"

# 2. assert_sourceable (the deployment descriptor). The values are written RAW and bash reads them as the inside of a double-quoted
#    string: callers rely on it, as documented in adt.sh (DEPLOYMENT_OPTS: \" for the quotes of a cron expression, \$ in a regular expression, ${VAR},
#    bare "..." pairs around a token). Those stay as they are; what executes or breaks out of the string is refused.
accept=(
  'A="plain"' 'A=""' 'A=' 'A=1234' 'A=true' 'A=/data/x/y.z' 'A=image:1.2-3' '# comment' '' 'A_B1="x y z"' 'A=a,b=c@d%e+f'
  # what callers put in DEPLOYMENT_OPTS (escaped quotes of cron expressions, $ before an escaped quote in a regexp ...)
  'A="-Dexo.job.expression=\"0 0,30 0-23 ? 1-12 1-7\" -Dx.y=1"'
  'A="-Dr.regexp=\"^[a-zA-Z0-9@.]*$\" -Dq=\"[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}$\" -Dz=2"'
  'A="-Dwith.escaped=\\\"two backslashes and a quote\\\" -Dn=1"'
  'A="-Donlyoffice.secret="acceptance%@abc123" -Dz=1"'
  'A=""overwrite""'
  'A="with \"quotes\" and \$dollar and \`tick\` and \\ slash"'
  'A="-Du=${DEPLOYMENT_URL}/path $HOME ${X_1} $1 end"'
  # passwords on the unquoted lines of the template (master sourced all of these)
  'A=Passw0rd!' 'A=a#b' 'A=abc~def' 'A=p^q' 'A=a?b' 'A=a*b' 'A={x}' 'A=[x]' 'A=a/b:c@d'
)
reject=(
  'A="x"; touch PWNED' 'A="x" touch PWNED' 'A="a"b"' 'A="$(touch PWNED)"' 'A="`touch PWNED`"' 'A="$((1+1))"' 'A="$[1+1]"'
  'A="${X:-$(touch PWNED)}"' 'A="${X:-y}"' 'A="${!x}"' 'A="${X}${"' 'A="a"b c"' 'A="a" b"' 'A="a";b' 'A="x"y"' 'A="unterminated' 'A="x\"' 'A="x\\\"'
  'A="x" # c' 'A="x"|id' 'A="x">f' 'A="x"&id' 'A="x"(id)' "A=\"x\"'y'" 'A="$"$(id)' 'A="x"$(id)' 'A="x"`id`'
  'A=a;touch PWNED' 'A=a b' 'A=$(id)' 'A=`id`' 'A=a|b' 'A=a&b' 'A=(1 2)' 'A=<x' 'A=>x' 'A=a"b' "A='x'" 'A=$x' 'A=a\b'
  'touch PWNED' '1A="x"' 'A-B="x"' 'export A="x"' ' A="x"' 'A ="x"' 'A= "x"'
)
for l in "${accept[@]}"; do
  printf '%s\n' "$l" > "$W/l.txt"; ( load; assert_sourceable "$W/l.txt" ) || bad "assert_sourceable refused [$l]"
done
for l in "${reject[@]}"; do
  printf '%s\n' "$l" > "$W/l.txt"; ( load; assert_sourceable "$W/l.txt" ) 2>/dev/null && bad "assert_sourceable accepted [$l]"
done
# a value with a newline is two lines for it: refused
printf 'A="two\nlines"\n' > "$W/l.txt"; ( load; assert_sourceable "$W/l.txt" ) 2>/dev/null && bad "assert_sourceable accepted a value with a newline"
# the message names the line and the variable, never the value
printf 'A=ok\nSECRET_PW="x"; touch PWNED\n' > "$W/l.txt"
msg="$( load; echo_error() { echo "$*"; }; assert_sourceable "$W/l.txt" )"
case "$msg" in *"line 2"*"SECRET_PW"*) ;; *) bad "message does not say which line and variable: $msg";; esac
case "$msg" in *"touch PWNED"*) bad "the message shows the value: $msg";; esac

# 3. what bash makes of the accepted values is what it made on master (the template is unchanged): the constructs callers use
#    keep their meaning when the descriptor is sourced
check_value() { # label, line of the descriptor, expected value of A
  printf '%s\n' "$2" > "$W/v.txt"
  got="$( load; assert_sourceable "$W/v.txt" && ( source "$W/v.txt"; printf '%s' "$A" ) )"
  [ "$got" = "$3" ] || bad "$1: sourced as [$got], want [$3]"
}
check_value "cron expression"             'A="-Dx.expression=\"0 0/60 * * * *\" -Dy=1"'                  '-Dx.expression="0 0/60 * * * *" -Dy=1'
check_value "regexp with \$ before a quote" 'A="-Dr=\"^[a-zA-Z0-9@.]*$\" -Dz=2"'                         '-Dr="^[a-zA-Z0-9@.]*$" -Dz=2'
check_value "bare quote pair around a token" 'A="-Ds="acceptance%@abc" -Dz=1"'                           '-Ds=acceptance%@abc -Dz=1'
check_value "quoted word (conflict mode)" 'A=""overwrite""'                                              'overwrite'
check_value "escaped dollar and quote"    'A="cost \$5 and \"x\" and back\\slash"'                   'cost $5 and "x" and back\slash'
check_value "unquoted password"           'A=Passw0rd!#~^?*'                                             'Passw0rd!#~^?*'
printf 'B=7\nA="-Du=${B}/p $B end"\n' > "$W/v.txt"
got="$( load; assert_sourceable "$W/v.txt" && ( source "$W/v.txt"; printf '%s' "$A" ) )"; [ "$got" = "-Du=7/p 7 end" ] || bad "a variable reference of the descriptor: [$got]"
ls PWNED 2>/dev/null && bad "something was run"

# 4. the real descriptor template, rendered with Jinja2 (the CI has it; skipped without)
if python3 -c 'import jinja2' 2>/dev/null; then
  render() { # args: NAME=value ... (every other variable is left undefined, as j2 --undefined does)
    python3 - "$ROOT/etc/adt/config.j2" "$@" <<'PY'
import sys, jinja2
tpl = open(sys.argv[1]).read()
ctx = dict(a.split("=", 1) for a in sys.argv[2:])
sys.stdout.write(jinja2.Environment(undefined=jinja2.Undefined, keep_trailing_newline=True).from_string(tpl).render(**ctx))
PY
  }
  QUOTED="$(grep -oE '^[A-Z0-9_]+="\{\{ [A-Za-z0-9_]+ \}\}"$' "$ROOT/etc/adt/config.j2" | sed -E 's/^([A-Z0-9_]+)="\{\{ ([A-Za-z0-9_]+) \}\}"$/\1 \2/')"
  UNQUOTED="$(grep -oE '^[A-Z0-9_]+=\{\{ [A-Za-z0-9_]+ \}\}$' "$ROOT/etc/adt/config.j2" | sed -E 's/^([A-Z0-9_]+)=\{\{ ([A-Za-z0-9_]+) \}\}$/\1 \2/')"
  [ "$(printf '%s\n' "$QUOTED" | wc -l)" -gt 100 ] || bad "fewer than 100 quoted lines in config.j2"
  # every line that holds a value is either quoted or plain-unquoted
  [ "$(grep -c '{{' "$ROOT/etc/adt/config.j2")" -eq "$(( $(printf '%s\n' "$QUOTED" | wc -l) + $(printf '%s\n' "$UNQUOTED" | wc -l) ))" ] \
    || bad "config.j2 has a line that is neither quoted nor plain"
  SAFE_UNQUOTED=(); while read -r n v; do [ -n "$n" ] && SAFE_UNQUOTED+=("$v=true"); done <<< "$UNQUOTED"
  # a hostile value in ANY quoted line makes the descriptor refused (nothing is sourced here: nothing can run)
  for h in "${HOSTILE[@]}"; do
    while read -r n v; do
      [ -n "$n" ] || continue
      render "${SAFE_UNQUOTED[@]}" "$v=$h" > "$W/descriptor"
      ( load; assert_sourceable "$W/descriptor" ) 2>/dev/null && { bad "the descriptor with [$h] in $n was accepted"; break 2; }
    done < <(printf '%s\n' "$QUOTED" | awk 'NR%13==1')
  done
  # the values callers use are accepted and keep their meaning once sourced
  args=("${SAFE_UNQUOTED[@]}" 'DEPLOYMENT_OPTS=-Dx.cron=\"0 0/60 * * * *\" -Dr=\"^[a-z]*$\" -Ds="tok%@en" -Dok=true' 'DEPLOYMENT_LABELS=qa,demo' 'ARTIFACT_DL_URL=https://repo.example.org/a/b.zip?x=1&y=2')
  render "${args[@]}" > "$W/descriptor"
  ( load; assert_sourceable "$W/descriptor" ) || bad "a descriptor with the usual values is refused"
  got="$( bash -c 'source "$1"; printf "%s" "$DEPLOYMENT_OPTS"' _ "$W/descriptor" )"
  [ "$got" = '-Dx.cron="0 0/60 * * * *" -Dr="^[a-z]*$" -Ds=tok%@en -Dok=true' ] || bad "DEPLOYMENT_OPTS sourced as [$got]"
  grep -q '^ARTIFACT_DL_URL="https://repo.example.org/a/b.zip?x=1&y=2"$' "$W/descriptor" || bad "an ordinary URL was altered"
  # the template is byte for byte the one of master: the descriptors of the instances do not change
  if git -C "$ROOT" cat-file -e master:etc/adt/config.j2 2>/dev/null; then
    git -C "$ROOT" show master:etc/adt/config.j2 | cmp -s - "$ROOT/etc/adt/config.j2" || bad "etc/adt/config.j2 differs from master: the escapes callers use would change meaning"
  fi
  # a value on an unquoted line that means something to bash is refused
  for n_v in $(printf '%s\n' "$UNQUOTED" | awk '{print $2}' | head -40); do
    args=("${SAFE_UNQUOTED[@]}" "$n_v=a;touch PWNED"); render "${args[@]}" > "$W/descriptor"
    ( load; assert_sourceable "$W/descriptor" ) 2>/dev/null && { bad "an unquoted line with ';' was accepted ($n_v)"; break; }
  done
else
  echo "SKIP: python3 jinja2 not available, the template part is not tested"
fi

# 4. the .info file of an artifact: the writer of _functions_download.sh, run with hostile fields, sourced like
#    do_load_artifact_descriptor does
block="$(sed -n '/# NAME="value" with the value escaped/,/} > "${_artifactInfo}"/p' "$ROOT/_functions_download.sh")"
[ -n "$block" ] || bad "the .info writer was not found in _functions_download.sh"
for h in "${HOSTILE[@]}"; do
  ( load
    _prefix=DL; _artifactVersion="$h"; _artifactGroupId="$h"; _artifactArtifactId="$h"; _artifactTimestamp="$h"; _artifactDate="$h"
    _artifactClassifier="$h"; _artifactPackaging="$h"; _artifactUrl="$h"; _artifactFile="$h"; _artifactInfo="$W/a.info"
    eval "$block"
    got="$(source "$W/a.info"; printf '%s|%s|%s' "$DL_VERSION" "$DL_ARTIFACT_URL" "$DL_ARTIFACT_LOCAL_PATH")"
    [ "$got" = "$h|$h|$h" ] || { echo "FAIL: .info with [$h] read back as [$got]"; exit 1; } ) || fail=1
done
ls PWNED 2>/dev/null && bad "sourcing an .info file ran a value"

# 5. the timestamp a repository returns is checked before it is used (file names, sed, URL, the .info above)
ts_pattern="$(grep -m1 -E '\$_artifactTimestamp" =~ \^' "$ROOT/_functions_download.sh" | sed -E 's/.*=~ (\^[^ ]+\$) \]\].*/\1/')"
[ -n "$ts_pattern" ] || bad "the timestamp check was not found in _functions_download.sh"
for v in 7.3.x-20260121.101500-12 7.3.x-SNAPSHOT 7.3.0 7.3.0-M12 6.5.x-20260101.000000-1; do [[ "$v" =~ $ts_pattern ]] || bad "timestamp [$v] refused"; done
for v in '../../../../home/u/.adtrc' '1$(id)' 'a b' 'a"b' 'a`b`' $'1\n2' '1;2' '.hidden' '-x' '/etc/passwd' 'a/b' ''; do [[ "$v" =~ $ts_pattern ]] && bad "timestamp [$(printf '%q' "$v")] accepted"; done

[ "$fail" -eq 0 ] && echo "descriptor: ok" || { echo "descriptor: FAILED"; exit 1; }
