#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CORE_LOADED:-false} && return
set -u

# OS specific support. $var _must_ be set to either true or false.
CYGWIN=false
LINUX=false;
OS400=false
DARWIN=false
case "`uname`" in
  CYGWIN*) CYGWIN=true ;;
  Linux*) LINUX=true ;;
  OS400*) OS400=true ;;
  Darwin*) DARWIN=true ;;
esac

# #################
# Environments functions
# #################

# Checks that the env var with the name provided in param is defined
validate_env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$(eval echo \${$1-UNSET})
  if [ "${PARAM_VALUE}" = "UNSET" ]; then
    echo_error "Environment variable $PARAM_NAME is not set";
    echo_error "Please set it either : "
    echo_error "* in your shell environment (export $PARAM_NAME=xxx)"
    echo_error "* in the system file /etc/default/adt"
    echo_error "* in the user file \$HOME/.adtrc"
    exit 1;
  fi
  set -u
}

# Setup an env var
# The user can override the value in its environment.
# In that case the default value won't be used.
configurable_env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$(eval echo \${$1-UNSET})
  if [ "${PARAM_VALUE}" = "UNSET" ]; then
    PARAM_VALUE=$2
    eval ${PARAM_NAME}=\"${PARAM_VALUE}\"
    export eval ${PARAM_NAME}
  fi
  echo_debug "$PARAM_NAME=$PARAM_VALUE"
  set -u
}

# Setup an env var
# The user cannot override the value
env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$2
  eval ${PARAM_NAME}=\"${PARAM_VALUE}\"
  export eval ${PARAM_NAME}
  echo_debug "$PARAM_NAME=$PARAM_VALUE"
  set -u
}

# Get informations about system
loadSystemInfo() {
  OS=`lowercase \`uname\``
  OSSTR=""
  KERNEL=`uname -r`
  MACH=`uname -m`
  ARCH=""
  DIST=""
  PSEUDONAME=""
  REV=""
  DistroBasedOn=""

  if [ "${OS}" == "windowsnt" ]; then
    OS=windows
  elif [ "${OS}" == "darwin" ]; then
    OS=mac
  else
    OS=`uname`
    if [ "${OS}" = "SunOS" ]; then
      OS=Solaris
      ARCH=`uname -p`
      OSSTR="${OS}${REV}(${ARCH}`uname-v`)"
    elif [ "${OS}" = "AIX" ]; then
      OSSTR="${OS}`oslevel` (`oslevel-r`)"
    elif [ "${OS}" = "Linux" ]; then
      if [ -f /etc/redhat-release ]; then
        DistroBasedOn='RedHat'
        DIST=`cat /etc/redhat-release | sed s/\ release.*//`
        PSEUDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
        REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
      elif [ -f /etc/SuSE-release ]; then
        DistroBasedOn='SuSe'
        PSEUDONAME=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/VERSION.*//`
        REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
      elif [ -f /etc/mandrake-release ]; then
        DistroBasedOn='Mandrake'
        PSEUDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
        REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
      elif [ -f /etc/debian_version ]; then
        DistroBasedOn='Debian'
        DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F= '{ print $2 }'`
        PSEUDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F= '{ print $2 }'`
        REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F= '{ print $2 }'`
      fi
      if [ -f /etc/UnitedLinux-release ]; then
        DIST="${DIST}[`cat/etc/UnitedLinux-release|tr"\n"' '|seds/VERSION.*//`]"
      fi
      OS=`lowercase $OS`
      DistroBasedOn=`lowercase $DistroBasedOn`
      readonly OS
      readonly OSSTR
      readonly KERNEL
      readonly MACH
      readonly DIST
      readonly PSEUDONAME
      readonly REV
      readonly DistroBasedOn
    fi

  fi
  echo_info "========"
  if [ -n "${OS}" ]; then
    echo_info "OS: ${OS}";
  fi
  if [ -n "${OSSTR}" ]; then
    echo_info "OSSTR: ${OSSTR}";
  fi
  if [ -n "${DIST}" ]; then
    echo_info "DIST: ${DIST}"
  fi
  if [ -n "${PSEUDONAME}" ]; then
    echo_info "PSEUDONAME: ${PSEUDONAME}"
  fi
  if [ -n "${REV}" ]; then
    echo_info "REV: ${REV}"
  fi
  if [ -n "${DistroBasedOn}" ]; then
    echo_info "DistroBasedOn: ${DistroBasedOn}"
  fi
  if [ -n "${KERNEL}" ]; then
    echo_info "KERNEL: ${KERNEL}"
  fi
  if [ -n "${MACH}" ]; then
    echo_info "MACH: ${MACH}"
  fi
  if [ -n "${ARCH}" ]; then
    echo_info "ARCH: ${ARCH}"
  fi
  echo_info "========"
}

# #################
# Logging functions
# #################

# Display DEBUG message
echo_debug() {
  set +u
  $ADT_DEBUG && echo -e "\033[1;36m[DEBUG]\033[0m " $@
  set -u
}

# Display DEBUG message without trailing newline character
echo_n_debug() {
  set +u
  $ADT_DEBUG && echo -n -e "\033[1;36m[DEBUG]\033[0m " $@
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