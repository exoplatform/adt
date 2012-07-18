#!/bin/bash -eu

#
# LOAD PARAMETERS FROM SERVER AND USER SETTINGS
#

# Load server config from /etc/default/adt
[ -e "/etc/default/adt" ] && source /etc/default/adt

# Load local config from $HOME/.adtrc
[ -e "$HOME/.adtrc" ] && source $HOME/.adtrc

# Load shared functions
source "$SCRIPT_DIR/_functions.sh"

echo "[INFO] # #######################################################################"
echo "[INFO] # $SCRIPT_NAME"
echo "[INFO] # #######################################################################"

# if the script was started from the base directory, then the
# expansion returns a period
if test "$SCRIPT_DIR" == "." ; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/" ; then
  SCRIPT_DIR="$PWD/$SCRIPT_DIR"
fi

# #############################################################################
# Mandatory env var to define to use the script
# #############################################################################
validate_env_var "ADT_DATA"

# Root dir for config files used by these scripts
export SCRIPT_CONF_DIR=${SCRIPT_DIR}/conf

do_init(){
  # #############################################################################
  # If you define a value for these environment variables they'll be used
  # otherwise they'll use the default value.
  # #############################################################################
  configurable_env_var "CROWD_ACCEPTANCE_APP_NAME"      ""
  configurable_env_var "CROWD_ACCEPTANCE_APP_PASSWORD"  ""
  # Create ADT_DATA if required
  mkdir -p $ADT_DATA

  # Convert to an absolute path
  pushd $ADT_DATA > /dev/null
  ADT_DATA=`pwd -P`
  popd > /dev/null

  echo "[INFO] ADT_DATA = $ADT_DATA"

  # Copy everything in it
  if [[ "$SCRIPT_DIR" != "$ADT_DATA" ]]; then
    cp -rf $SCRIPT_DIR/etc $ADT_DATA
    cp -rf $SCRIPT_DIR/var $ADT_DATA
  fi

  # Create the main vhost from the template
  cp $ADT_DATA/etc/apache2/sites-available/acceptance.exoplatform.org.template $ADT_DATA/etc/apache2/sites-available/acceptance.exoplatform.org
  replace_in_file $ADT_DATA/etc/apache2/sites-available/acceptance.exoplatform.org "@ADT_DATA@" "$ADT_DATA"    
  replace_in_file $ADT_DATA/etc/apache2/sites-available/acceptance.exoplatform.org "@CROWD_ACCEPTANCE_APP_NAME@" "$CROWD_ACCEPTANCE_APP_NAME"    
  replace_in_file $ADT_DATA/etc/apache2/sites-available/acceptance.exoplatform.org "@CROWD_ACCEPTANCE_APP_PASSWORD@" "$CROWD_ACCEPTANCE_APP_PASSWORD"	
	
  env_var "START_DATE"     `date -u "+%Y-%m-%d %H:%M:%S UTC"`
  env_var "SHORT_HOSTNAME" `hostname -s`
  env_var "HOSTNAME"       `hostname`
  env_var "UNAME"          `uname -a`
  env_var "HARDWARE"       `uname -m`
  env_var "NODE_NAME"      `uname -n`
  env_var "PROC_ARCH"      `uname -p`
  env_var "OS_RELEASE"     `uname -r`
  env_var "OS_NAME"        `uname -s`
  env_var "OS_VERSION"     `uname -v`
  env_var "USER"           "$USER"
  env_var "HOME"           "$HOME"
  env_var "SHELL"          "$SHELL"
  env_var "PATH"           "$PATH"
  configurable_env_var "TMP_DIR"         "$ADT_DATA/tmp"
  configurable_env_var "DL_DIR"          "$ADT_DATA/downloads"
  configurable_env_var "SRV_DIR"         "$ADT_DATA/servers"
  configurable_env_var "CONF_DIR"        "$ADT_DATA/conf"
  configurable_env_var "APACHE_CONF_DIR" "$ADT_DATA/conf/apache"
  configurable_env_var "ADT_CONF_DIR"    "$ADT_DATA/conf/adt"
  configurable_env_var "ETC_DIR"         "$ADT_DATA/etc"
}
