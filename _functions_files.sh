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
replace_in_file() {
  mv $1 $1.orig
  ${CMD_SED} "s|$2|$3|g" $1.orig > $1
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
