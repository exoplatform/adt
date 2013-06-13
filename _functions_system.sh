#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_SYSTEM_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"
source "./_functions_string.sh"

# #################
# System functions
# #################

# Get informations about system
loadSystemInfo() {
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

  OS=`tolower \`uname\``
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
      OS=`tolower ${OS}`
      DistroBasedOn=`tolower ${DistroBasedOn}`
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

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_SYSTEM_LOADED=true
echo_debug "_functions_system.sh Loaded"