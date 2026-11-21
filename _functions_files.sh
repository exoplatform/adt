#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_FILES_LOADED:-false} && return
set -u

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

# #############################################################################
# Load shared functions
# #############################################################################
source "${SCRIPT_DIR}/_functions_core.sh"

# #############################################################################
# Files related functions
# #############################################################################

#
# Replace in file $1 the value $2 by $3
#
# When $2 is a placeholder (@NAME@), $3 is a value taken from the environment (a port, a URL, a database name, ...): it is
# data, so what means something in the replacement of a sed expression is escaped: the delimiter |, & (the matched text),
# the backslash and the newline. Unescaped, 'x|g;e cmd;s|a|b' ends the substitution and GNU sed's e command runs cmd.
# Any other $2 is the legacy form (the escape of single quotes in evaluate_file_content), whose $3 is sed syntax on purpose.
#
replace_in_file() {
  local _to=$3
  if [[ "$2" =~ ^@[A-Za-z0-9_]+@$ ]]; then
    _to=${_to//\\/\\\\}
    _to=${_to//|/\\|}
    _to=${_to//&/\\&}
    _to=${_to//$'\n'/\\$'\n'}
  fi
  mv $1 $1.orig
  ${CMD_SED} "s|$2|${_to}|g" $1.orig > $1
  rm $1.orig
}

#
# find_file <VAR> <PATH1> ..  <PATHx>
# test all paths and the path of the latest one existing in parameters is set as VAR
#
find_file() {
  set +u
  local _varName=$1
  shift;
  # default value set to UNSET
  env_var ${_varName} "UNSET"
  for i in $*
  do
    [ -e "$i" ] && env_var ${_varName} "$i"
  done
  set -u
}

#
# Render a Jinja2 template with the environment variables as context
# Usage: j2 [options] <template>  (the result is written on stdout)
# Uses, by order of preference :
#  - jinjanate (jinjanator, the maintained fork of j2cli) : pipx install jinjanator
#  - j2 (legacy j2cli, doesn't work with recent python versions)
#  - the j2cli docker image
#
j2() {
  # "command" bypasses this function and runs the binary (avoids an infinite recursion)
  if type -P jinjanate &>/dev/null; then
    command jinjanate --quiet "$@"
    return
  fi
  if type -P j2 &>/dev/null; then
    command j2 "$@"
    return
  fi
  local _template="${!#}"
  local _options=("${@:1:$#-1}")
  local _dir
  _dir="$(cd "$(dirname "${_template}")" && pwd)"
  local _envfile
  _envfile=$(mktemp)
  # --env-file doesn't support multi-lines values, keep only NAME=value lines
  # and don't override the container environment with the host specific ones (PATH, HOME, ...)
  env | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | grep -vE '^(PATH|HOME|HOSTNAME|PWD|OLDPWD|SHLVL|_|TERM)=' > "${_envfile}" || true
  local _rc=0
  ${DOCKER_CMD} run --rm --env-file "${_envfile}" -v "${_dir}":"${_dir}":ro \
    ${DEPLOYMENT_J2CLI_IMAGE}:${DEPLOYMENT_J2CLI_VERSION} \
    ${_options[@]+"${_options[@]}"} "${_dir}/$(basename "${_template}")" || _rc=$?
  rm -f "${_envfile}"
  return ${_rc}
}

#
# Export every shell variable referenced in the {{ }} / {% %} tags of the Jinja2 template $1
# (j2 only sees the exported variables, this avoids to maintain a list of export before each call)
#
export_template_vars() {
  local _name
  for _name in $(grep -oE '\{\{[^}]*\}\}|\{%[^%]*%\}' "$1" | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | sort -u); do
    # -v is true for any set variable (global or local of the callers), even when it is not exported yet
    if [[ -v "${_name}" ]]; then
      export "${_name}"
    fi
  done
}

#
# A file that bash will "source" later (the deployment descriptor of an instance, read at every list, start, stop and
# undeploy, possibly by a more privileged operator) must not be able to run anything.
#
# The values are written raw, NAME="<value>", and bash reads them as the inside of a double-quoted string: callers rely on
# that, as documented for DEPLOYMENT_OPTS in adt.sh (it holds \"0 0/60 * * * *\" for the quotes of a cron expression, \$ in a regular expression, ${VAR} references,
# bare "..." pairs around a token). That language is kept as it is. What is refused is what executes or breaks out of the string:
# a command substitution $( ) or $[ ], a backtick, ${...} other than ${NAME}, a quote that leaves the string with something other
# than plain word characters outside it (a space, ; & | < > ( ) end the assignment and start a command), an unbalanced quote.
#
# _dq_value_is_safe takes what follows NAME=" up to the end of the line, closing quote included.
#
_dq_value_is_safe() {
  local _s=$1 _i=0 _n _c _next _inquote=1
  local _braced='^\$\{[A-Za-z_][A-Za-z0-9_]*\}'
  local _word='[]A-Za-z0-9._/:@%+,=~^*?!#{}[-]'
  _n=${#_s}
  while [ "${_i}" -lt "${_n}" ]; do
    _c=${_s:${_i}:1}
    case "${_c}" in
      '\')
        # a backslash makes the next character data, inside the quotes and outside
        [ $((_i + 1)) -lt "${_n}" ] || return 1
        _i=$((_i + 2)); continue ;;
      '"') _inquote=$((1 - _inquote)) ;;
      '`') return 1 ;;
      '$')
        _next=${_s:$((_i + 1)):1}
        case "${_next}" in
          '(' | '[') return 1 ;;
          '{')
            [[ "${_s:${_i}}" =~ ${_braced} ]] || return 1
            _i=$((_i + ${#BASH_REMATCH[0]})); continue ;;
          "'") [ "${_inquote}" -eq 1 ] || return 1 ;;
        esac ;;
      *)
        if [ "${_inquote}" -eq 0 ] && [[ ! "${_c}" =~ ${_word} ]]; then
          return 1
        fi ;;
    esac
    _i=$((_i + 1))
  done
  [ "${_inquote}" -eq 0 ]
}

#
# Returns 1 unless every line of the file is empty, a comment, NAME="value" (see above) or NAME=value with a value made of
# characters that mean nothing to bash outside quotes. The message names the line and the variable, never the value (it may be
# a password).
#
assert_sourceable() {
  local _file=$1 _line _n=0
  local _quoted='^[A-Za-z_][A-Za-z0-9_]*="(.*)$'
  local _plain='^[A-Za-z_][A-Za-z0-9_]*=[]A-Za-z0-9._/:@%+,=~^*?!#{}[-]*$'
  while IFS= read -r _line || [ -n "${_line}" ]; do
    _n=$((_n + 1))
    [ -z "${_line}" ] && continue
    [[ "${_line}" == \#* ]] && continue
    if [[ "${_line}" =~ ${_quoted} ]]; then
      _dq_value_is_safe "${BASH_REMATCH[1]}" && continue
    elif [[ "${_line}" =~ ${_plain} ]]; then
      continue
    fi
    echo_error "${_file}, line ${_n} (${_line%%=*}): the value cannot be sourced safely by bash (command substitution, backtick, unbalanced or breaking quotes, shell syntax), refusing the file"
    return 1
  done < "${_file}"
  return 0
}

#
# Render the template $1 and push the result in $2
#  - *.j2 files are rendered with Jinja2 (conditions, loops, filters ...) : use them for any new template
#  - DEPRECATED: any other file only gets its environment variables (${XXX}) replaced
#    using perl (or awk as a fallback), without any condition support. Migrate them to *.j2
#
evaluate_file_content() {
  local _file_in=$1
  local _file_out=$2
  if [ ${_file_in##*.} = "j2" ]; then 
    export_template_vars "${_file_in}"
    j2 --undefined "${_file_in}" > "${_file_out}"
  else 
    echo_warn "DEPRECATED: ${_file_in} is evaluated with the legacy \${XXX} substitution (perl/awk), please migrate it to a Jinja2 (.j2) template"
    if which perl &>/dev/null; then 
      perl -pe 's/\$\{([^}]+)\}/$ENV{$1} || ""/ge' < ${_file_in} > ${_file_out}
    else 
      awk '{while(match($0,"[$]{[^}]*}")) {var=substr($0,RSTART+2,RLENGTH -3);gsub("[$]{"var"}",ENVIRON[var])}}1' < ${_file_in} > ${_file_out}
    fi
    # escape any single quote
    if ${LINUX}; then
      replace_in_file ${_file_out} "'" "\\\'"
    else
      replace_in_file ${_file_out} "\'" "\\\'"
    fi
  fi
}

# Backup the file passed as parameter
backup_file() {
  if [ -d $1 ]; then
    # We need to backup existing file if they already exist
    cd $1
    local _start_date=`date -u "+%Y%m%d-%H%M%S-UTC"`
    for file in $2
    do
      if [ -e ${file} ]; then
        echo_info "Archiving existing file $file as archived-on-${_start_date}-$file   ..."
        mv ${file} archived-on-${_start_date}-${file}
        echo_info "Done."
      fi
    done
    cd -
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_FILES_LOADED=true
echo_debug "_functions_files.sh Loaded"
