#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_PLF_LOADED:-false} && return
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
source "${SCRIPT_DIR}/_functions_download.sh"

# #############################################################################
# TDB : Use functions that aren't using global vars
# #############################################################################

do_download_mysql_driver() {
  env_var "MYSQL_DL_DIR" "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}"
  mkdir -p ${MYSQL_DL_DIR}
  do_download_maven_artifact "${REPOSITORY_SERVER_BASE_URL}/content/groups/public" "" "" "mysql" "mysql-connector-java" "${DEPLOYMENT_MYSQL_DRIVER_VERSION}" "jar" "" "${MYSQL_DL_DIR}" "mysql-connector-java" ""
}

do_download_postgresql_driver() {
  env_var "PSQL_DL_DIR" "${DL_DIR}/postgresql-jdbc-driver/${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}"
  mkdir -p ${PSQL_DL_DIR}
  do_download_maven_artifact "${REPOSITORY_SERVER_BASE_URL}/content/groups/public" "" "" "org.postgresql" "postgresql" "${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}" "jar" "" "${PSQL_DL_DIR}" "postgresql" ""
} 

do_download_oracle_driver() {
  env_var "ORACLE_DL_DIR" "${DL_DIR}/oracle-jdbc-driver/${DEPLOYMENT_ORACLE_DRIVER_VERSION}"
  mkdir -p ${ORACLE_DL_DIR}
  do_download_maven_artifact "${REPOSITORY_SERVER_BASE_URL}/content/groups/private" "${REPOSITORY_USERNAME}" "${REPOSITORY_PASSWORD}" "ojdbc" "ojdbc" "${DEPLOYMENT_ORACLE_DRIVER_VERSION}" "jar" "" "${ORACLE_DL_DIR}" "ojdbc" ""
}

do_download_sqlserver_driver() {
  env_var "SQLSERVER_DL_DIR" "${DL_DIR}/sqlserver-jdbc-driver/${DEPLOYMENT_SQLSERVER_DRIVER_VERSION}"
  mkdir -p ${SQLSERVER_DL_DIR}
  do_download_maven_artifact "${REPOSITORY_SERVER_BASE_URL}/content/groups/${DEPLOYMENT_SQLSERVER_DRIVER_REPO}" "${REPOSITORY_USERNAME}" "${REPOSITORY_PASSWORD}" "${DEPLOYMENT_SQLSERVER_DRIVER_GROUPID}" "${DEPLOYMENT_SQLSERVER_DRIVER_ARTIFACTID}" "${DEPLOYMENT_SQLSERVER_DRIVER_VERSION}" "jar" "" "${SQLSERVER_DL_DIR}" "sqljdbc" ""
}

do_install_mysql_driver() {
  local _installDir=$1
  
  echo_info "Using standard mysql jdbc driver version ${DEPLOYMENT_MYSQL_DRIVER_VERSION}"

  do_download_mysql_driver
    
  cp ${MYSQL_DL_DIR}/mysql-connector-java-${DEPLOYMENT_MYSQL_DRIVER_VERSION}.jar $1

  # TODO Find a way to determine the driver name from the addon version
  local driver="mysql-connector-java-${DEPLOYMENT_MYSQL_DRIVER_VERSION}.jar"
  env_var "DB_DRIVER" "${MYSQL_DB_DRIVER_OVERRIDE:-$driver}"
}

do_install_postgresql_driver() {
  local _installDir=$1
  
  echo_info "Using standard postgresql jdbc driver version ${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}"

  do_download_postgresql_driver

  cp ${PSQL_DL_DIR}/postgresql-${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}.jar $1

  # TODO Find a way to determine the driver name from the addon version
  env_var "DB_DRIVER" "postgresql-${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}.jar"
}

do_install_oracle_driver() {
  local _installDir=$1
  
  echo_info "Using standard oracle jdbc driver version ${DEPLOYMENT_ORACLE_DRIVER_VERSION}"

  do_download_oracle_driver

  cp ${ORACLE_DL_DIR}/ojdbc-${DEPLOYMENT_ORACLE_DRIVER_VERSION}.jar $1

  # TODO Find a way to determine the driver name from the addon version
  env_var "DB_DRIVER" "ojdbc-${DEPLOYMENT_ORACLE_DRIVER_VERSION}.jar"
  
}

do_install_sqlserver_driver() {
  local _installDir=$1
  
  echo_info "Using standard sqlserver jdbc driver version ${DEPLOYMENT_SQLSERVER_DRIVER_VERSION}"

  do_download_sqlserver_driver

  cp ${SQLSERVER_DL_DIR}/sqljdbc-${DEPLOYMENT_SQLSERVER_DRIVER_VERSION}.jar $1

  # TODO Find a way to determine the driver name from the addon version
  env_var "DB_DRIVER" "sqljdbc-${DEPLOYMENT_SQLSERVER_DRIVER_VERSION}.jar"
}

#
# Function that installs the addons manager
#
do_install_addons_manager() {
  # Install add-ons manager
  if [ -f "${DEPLOYMENT_DIR}/extension.sh" -a ! -d "${DEPLOYMENT_DIR}/addons" ] || [ -f "${DEPLOYMENT_DIR}/addons.sh" ]; then
    ADDONS_MANAGER_ZIP_URL="http://repository.exoplatform.org/public/org/exoplatform/platform/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/addons-manager-${DEPLOYMENT_ADDONS_MANAGER_VERSION}.zip"
    if [ ! -e ${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/`basename ${ADDONS_MANAGER_ZIP_URL}` ]; then
      if ${ADT_OFFLINE}; then
        echo_error "ADT is offine and the Add-ons Manager isn't available locally"
        exit 1
      else
        mkdir -p ${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/
        echo_info "Downloading Add-ons Manager from ${ADDONS_MANAGER_ZIP_URL} ..."
        set +e
        curl --fail --show-error --location-trusted ${ADDONS_MANAGER_ZIP_URL} > ${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/`basename ${ADDONS_MANAGER_ZIP_URL}`
        if [ "$?" -ne "0" ]; then
          echo_error "Cannot download ${ADDONS_MANAGER_ZIP_URL}"
          rm -f "${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/"`basename ${ADDONS_MANAGER_ZIP_URL}` # Remove potential corrupted file
          exit 1
        fi
        set -e
        echo_info "Done."
      fi
    fi
    echo_info "Validating Add-ons Manager integrity ..."
    set +e
    zip -T "${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/"`basename ${ADDONS_MANAGER_ZIP_URL}`
    if [ "$?" -ne "0" ]; then
      echo_error "Sorry, "`basename ${ADDONS_MANAGER_ZIP_URL}`" integrity failed. Local copy is deleted."
      rm -f "${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/"`basename ${ADDONS_MANAGER_ZIP_URL}`
      exit 1
    fi
    set -e
    echo_info "Add-ons Manager integrity validated."
    echo_info "Installing Add-ons Manager ..."
    unzip -o -q "${DL_DIR}/addons-manager/${DEPLOYMENT_ADDONS_MANAGER_VERSION}/"`basename ${ADDONS_MANAGER_ZIP_URL}` -d ${DEPLOYMENT_DIR}
    echo_info "Done."
  fi
}

#
# Function that installs required extensions
#
do_install_extensions() {
  # Install optional extension
  if [ -f "${DEPLOYMENT_DIR}/extension.sh" ]; then
    echo_info "Installing PLF extensions ..."
    _extensions=$(echo $DEPLOYMENT_EXTENSIONS | tr "," "\n")
    for _extension in $_extensions; do
      ${DEPLOYMENT_DIR}/extension.sh --install ${_extension}
    done
    echo_info "Done."
  fi
}

#
# Function that installs required addons
#
do_install_addons() {
  local _addons_manager_script=""

  if [ ! -z "${DEPLOYMENT_ADDONS_CATALOG:-}" ]; then
    echo "The add-on manager catalog url was overriden with : ${DEPLOYMENT_ADDONS_CATALOG}"
    _addons_manager_option_catalog="--catalog=${DEPLOYMENT_ADDONS_CATALOG}"
  fi

  if [ ! -z "${DEPLOYMENT_ADDONS_MANAGER_CONFLICT_MODE:-}" ]; then
    echo "The add-on manager parameter --conflict was overriden with : ${DEPLOYMENT_ADDONS_MANAGER_CONFLICT_MODE}"
    _addons_manager_option_conflict="--conflict=${DEPLOYMENT_ADDONS_MANAGER_CONFLICT_MODE}"
  fi

  if [ "${DEPLOYMENT_ADDONS_MANAGER_NOCOMPAT_MODE}" == "true" ]; then
    echo "The add-on manager parameter --no-compat was enabled for the addon install"
    _addons_manager_option_nocompat="--no-compat"
  fi

  if [ "${DEPLOYMENT_ADDONS_MANAGER_UNSTABLE_MODE}" == "true" ]; then
    echo "The add-on manager parameter --unstable was enabled for the addon install"
    _addons_manager_option_unstable="--unstable"
  fi

  # Install optional add-ons
  if [ -f "${DEPLOYMENT_DIR}/addon" ]; then
    _addons_manager_script=${DEPLOYMENT_DIR}/addon
  fi
  if [ -n "${_addons_manager_script}" -a -f "${_addons_manager_script}" ]; then
    # Let's list them first (this will trigger an update of the installed version of the addons-manager if required)
    ${_addons_manager_script} list ${_addons_manager_option_catalog:-} --snapshots --unstable
    echo_info "Installing PLF add-ons ..."
    # Let's install them from $DEPLOYMENT_ADDONS env var
    _addons=$(echo $DEPLOYMENT_ADDONS | tr "," "\n")
    for _addon in $_addons; do
      ${_addons_manager_script} install ${_addons_manager_option_catalog:-} ${_addon} ${_addons_manager_option_conflict:-} ${_addons_manager_option_nocompat:-} ${_addons_manager_option_unstable:-} --force --batch-mode
    done
    if [ -f "${DEPLOYMENT_DIR}/addons.list" ]; then
      # Let's install them from ${DEPLOYMENT_DIR}/addons.list file
      _addons_list="${DEPLOYMENT_DIR}/addons.list"
      while read -r _addon; do
        # Don't read empty lines
        [[ "$_addon" =~ ^[[:blank:]]+$ ]] && continue
        # Don't read comments
        [[ "$_addon" =~ ^#.*$ ]] && continue
        # Install addon
        ${_addons_manager_script} install ${_addons_manager_option_catalog:-} ${_addon} ${_addons_manager_option_conflict:-} ${_addons_manager_option_nocompat:-} ${_addons_manager_option_unstable:-} --force --batch-mode
      done < "$_addons_list"
    fi
    echo_info "Done."
  fi
}

do_install_patches() {
  local _addons_manager_script=""

  if [ ! -z "${DEPLOYMENT_PATCHES_CATALOG:-}" ]; then
    echo "The add-on manager patches catalog url was set to  : ${DEPLOYMENT_PATCHES_CATALOG}"
    _addons_manager_patches_catalog="--catalog=${DEPLOYMENT_PATCHES_CATALOG}"
  fi

  if [ ! -z "${DEPLOYMENT_ADDONS_MANAGER_PATCHES_CONFLICT_MODE:-}" ]; then
    echo "The add-on manager parameter --conflict was overriden with : ${DEPLOYMENT_ADDONS_MANAGER_PATCHES_CONFLICT_MODE}"
    _addons_manager_patches_option_conflict="--conflict=${DEPLOYMENT_ADDONS_MANAGER_PATCHES_CONFLICT_MODE}"
  fi

  if [ "${DEPLOYMENT_ADDONS_MANAGER_PATCHES_NOCOMPAT_MODE}" == "true" ]; then
    echo "The add-on manager parameter --no-compat was enabled for the patch install"
    _addons_manager_patches_option_nocompat="--no-compat"
  fi

  # Install optional add-ons
  if [ -f "${DEPLOYMENT_DIR}/addon" ]; then
    _addons_manager_script=${DEPLOYMENT_DIR}/addon
  fi
  if [ -n "${_addons_manager_script}" -a -f "${_addons_manager_script}" ]; then
    # Let's list them first (this will trigger an update of the installed version of the addons-manager if required)
    ${_addons_manager_script} list ${_addons_manager_patches_catalog:-}
    echo_info "Installing PLF Patches ..."
    # Let's install them from $DEPLOYMENT_PATCHES env var
    _addons=$(echo $DEPLOYMENT_PATCHES | tr "," "\n")
    for _addon in $_addons; do
      ${_addons_manager_script} install ${_addons_manager_patches_catalog:-} ${_addon} ${_addons_manager_patches_option_conflict:-} ${_addons_manager_patches_option_nocompat:-} --force --batch-mode
    done
    echo_info "Done."
  fi
}

do_remove_addons() {
  local _addons_manager_script=""

  # Uninstall optional add-ons
  if [ -f "${DEPLOYMENT_DIR}/addon" ]; then
    _addons_manager_script=${DEPLOYMENT_DIR}/addon
  fi
  if [ -n "${_addons_manager_script}" -a -f "${_addons_manager_script}" ]; then
    echo_info "Uninstalling PLF Addons ..."
    # Let's install them from $DEPLOYMENT_ADDONS_TOREMOVE env var
    _addons=$(echo $DEPLOYMENT_ADDONS_TOREMOVE | tr "," "\n")
    for _addon in $_addons; do
      ${_addons_manager_script} uninstall ${_addon}
    done
    echo_info "Done."
  fi
}

#
# Function that get plf properties
#
do_get_plf_settings() {
  case "${DEPLOYMENT_APPSRV_TYPE}" in
    "tomcat")
      env_var DEPLOYMENT_DATA_DIR "/gatein/data"
      env_var DEPLOYMENT_CODEC_DIR "/gatein/conf/codec"
    ;;
    "jbosseap")
      env_var DEPLOYMENT_DATA_DIR "/standalone/data/gatein"
      env_var DEPLOYMENT_CODEC_DIR "standalone/configuration/gatein/codec"
    ;;
    *)
      echo_error "Server type ${DEPLOYMENT_APPSRV_TYPE} not supported"
      exit 1
    ;;
  esac
  env_var DEPLOYMENT_ES_PATH_DATA "${DEPLOYMENT_DATA_DIR}/exoplatform-es"
  env_var DEPLOYMENT_JCR_PATH_DATA "${DEPLOYMENT_DATA_DIR}/jcr"

}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_PLF_LOADED=true
echo_debug "_functions_plf.sh Loaded"
