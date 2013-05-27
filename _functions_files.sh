#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_FILES_LOADED:-false} && return
set -u

# #############################################################################
# Load shared functions
# #############################################################################
source "./_functions_core.sh"

# #############################################################################
# Files related functions
# #############################################################################

#
# Replace in file $1 the value $2 by $3
#
replace_in_file() {
  mv $1 $1.orig
  sed "s|$2|$3|g" $1.orig > $1
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
  env_var $_varName "UNSET"
  for i in $*
  do
    [ -e "$i" ] && env_var $_varName "$i"
  done
  set -u
}

#
# Replace in file $1 all environment variables (${XXX}) and push the result in $2
#
evaluate_file_content() {
  local _file_in=$1
  local _file_out=$2
  awk '{while(match($0,"[$]{[^}]*}")) {var=substr($0,RSTART+2,RLENGTH -3);gsub("[$]{"var"}",ENVIRON[var])}}1' < $_file_in > $_file_out
  # escape any single quote
  if $LINUX; then
    replace_in_file $_file_out "'" "\\\'"
  else
    replace_in_file $_file_out "\'" "\\\'"
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
      if [ -e $file ]; then
        echo_info "Archiving existing file $file as archived-on-${_start_date}-$file   ..."
        mv $file archived-on-${_start_date}-$file
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