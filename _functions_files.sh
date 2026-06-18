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

# Replace in file $1 the value $2 by $3
replace_in_file() {
  mv $1 $1.orig
  ${CMD_SED} "s|$2|$3|g" $1.orig > $1
  rm $1.orig
}

# find_file <VAR> <PATH1> ..  <PATHx>
# test all paths and the path of the latest one existing in parameters is set as VAR
find_file() {
  set +u
  local _varName=$1
  shift;
  # default value set to UNSET
  env_var ${_varName} "UNSET"
  for i in "$@"
  do
    [ -e "$i" ] && env_var ${_varName} "$i"
  done
  set -u
}

# Render a Jinja2 template file $1 into the output file $2 using the current
# environment as variables. Uses the local `j2` binary when available, else
# falls back to the exoplatform/j2cli docker image (no host python needed).
j2() {
  local _template=$1
  local _output=$2
  if which j2 &>/dev/null; then
    j2 --undefined ${_template} > ${_output}
  else
    local _envfile=$(mktemp)
    env > ${_envfile}
    ${DOCKER_CMD:-docker} run --env-file ${_envfile} --rm \
      -v "${_template}":"${_template}" \
      ${DEPLOYMENT_J2CLI_IMAGE}:${DEPLOYMENT_J2CLI_VERSION} \
      ${_template} > ${_output}
    rm ${_envfile}
  fi
}

# Render a template file $1 into the output file $2.
# .j2 files are rendered with Jinja2 (j2 function above).
# Other files are copied as-is.
evaluate_file_content() {
  local _file_in=$1
  local _file_out=$2
  mkdir -p "$(dirname ${_file_out})"
  if [ "${_file_in##*.}" = "j2" ]; then
    j2 ${_file_in} ${_file_out}
  else
    cp ${_file_in} ${_file_out}
  fi
}

# Backup the file passed as parameter
backup_file() {
  if [ -d $1 ]; then
    cd $1
    local _start_date=$(date -u "+%Y%m%d-%H%M%S-UTC")
    for file in $2
    do
      if [ -e ${file} ]; then
        echo_info "Archiving existing file $file as archived-on-${_start_date}-$file   ..."
        mv ${file} archived-on-${_start_date}-${file}
        echo_info "Done."
      fi
    done
    cd - > /dev/null
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_FILES_LOADED=true
echo_debug "_functions_files.sh Loaded"
