#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CORE_LOADED:-false} && return
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

# #################
# Environments functions
# #################

# The values of the env vars come from CI parameters and from developers (INSTANCE_ID, PRODUCT_VERSION, ...) and the defaults
# embed them: they are assigned with printf -v and read with an indirect expansion, never through eval. With
# eval NAME="value" the value, already expanded by the caller, was expanded a second time: INSTANCE_ID='x$(cmd)' or a
# double quote in a value ran commands as the deploy user.

# Stops unless the argument is the name of a variable
_check_env_var_name() {
  if [[ ! "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo_error "'$1' is not an environment variable name"
    exit 1
  fi
}

# Checks that the env var with the name provided in param is defined
validate_env_var() {
  set +u
  PARAM_NAME=$1
  _check_env_var_name "${PARAM_NAME}"
  if [ -z "${!PARAM_NAME+x}" ]; then
    echo_error "Environment variable $PARAM_NAME is not set";
    echo_error "Please set it either : "
    echo_error "- in your shell environment (export $PARAM_NAME=xxx)"
    echo_error "- in the system file /etc/default/adt"
    echo_error "- in the user file \$HOME/.adtrc"
    exit 1;
  fi
  set -u
}

# Stops unless the variable is empty (the callers say elsewhere when it is required) or its value matches the pattern.
# The identifiers of a deployment (product, version, instance id, host names) end up in file names, in the Apache
# and logrotate configuration (rendered by Jinja, not quoted for them), in sed expressions and on the command line of sudo:
# they are checked where they enter, with a pattern as narrow as what is legitimate.
validate_value() {
  local _name=$1 _pattern=$2 _what=$3
  set +u
  local _value=${!_name}
  set -u
  [ -z "${_value}" ] && return 0
  if [[ ! "${_value}" =~ ${_pattern} ]]; then
    echo_error "${_name} is not valid: ${_what}"
    exit 1
  fi
}

# Setup an env var
# The user can override the value in its environment.
# In that case the default value won't be used.
configurable_env_var() {
  set +u
  PARAM_NAME=$1
  _check_env_var_name "${PARAM_NAME}"
  if [ -z "${!PARAM_NAME+x}" ]; then
    PARAM_VALUE=$2
    printf -v "${PARAM_NAME}" '%s' "${PARAM_VALUE}"
    export "${PARAM_NAME}"
  else
    PARAM_VALUE=${!PARAM_NAME}
  fi
  echo_debug "$PARAM_NAME=$PARAM_VALUE"
  set -u
}

# Setup an env var
# The user cannot override the value
env_var() {
  set +u
  PARAM_NAME=$1
  _check_env_var_name "${PARAM_NAME}"
  PARAM_VALUE=$2
  printf -v "${PARAM_NAME}" '%s' "${PARAM_VALUE}"
  export "${PARAM_NAME}"
  echo_debug "$PARAM_NAME=$PARAM_VALUE"
  set -u
}

# #################
# Logging functions
# #################

# Display DEBUG message
echo_debug() {
  set +u
  ${ADT_DEBUG} && echo -e "\033[1;36m[DEBUG]\033[0m " $@
  set -u
}

# Display DEBUG message without trailing newline character
echo_n_debug() {
  set +u
  ${ADT_DEBUG} && echo -n -e "\033[1;36m[DEBUG]\033[0m " $@
  set -u
}

# Display INFO message
echo_info() {
  echo -e "\033[1;32m[INFO]\033[0m " $@
}

# Display INFO message without trailing newline character
echo_n_info() {
  echo -n -e "\033[1;32m[INFO]\033[0m " $@
}

# Display WARN message
echo_warn() {
  echo -e "\033[1;33m[WARN]\033[0m " $@
}

# Display WARN message without trailing newline character
echo_n_warn() {
  echo -n -e "\033[1;33m[WARN]\033[0m " $@
}

# Display ERROR message
echo_error() {
  echo -e "\033[1;31m[ERROR]\033[0m" $@
}

# Display ERROR message without trailing newline character
echo_n_error() {
  echo -n -e "\033[1;31m[ERROR]\033[0m" $@
}

# Configurable env vars. These variables can be loaded
# from the env, /etc/default/adt or $HOME/.adtrc
configurable_env_var "ADT_DEBUG" false

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CORE_LOADED=true
echo_debug "_functions_core.sh Loaded"