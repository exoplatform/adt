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
  do_download_maven_artifact "${REPOSITORY_SERVER_BASE_URL}/content/groups/private" "${REPOSITORY_USERNAME}" "${REPOSITORY_PASSWORD}" "com.microsoft" "sqljdbc" "${DEPLOYMENT_SQLSERVER_DRIVER_VERSION}" "jar" "" "${SQLSERVER_DL_DIR}" "sqljdbc" ""
}

do_install_postgresql_driver() {
  local _installDir=$1
  
  do_download_postgresql_driver

  cp ${PSQL_DL_DIR}/postgresql-${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}.jar $1

  # TODO Find a way to determine the driver name from the addon version
  env_var "DB_DRIVER" "postgresql-${DEPLOYMENT_POSTGRESQL_DRIVER_VERSION}.jar"
}

do_install_oracle_driver() {
  local _installDir=$1
  
  do_download_oracle_driver

  cp ${ORACLE_DL_DIR}/ojdbc-${DEPLOYMENT_ORACLE_DRIVER_VERSION}.jar $1

  # TODO Find a way to determine the driver name from the addon version
  env_var "DB_DRIVER" "ojdbc-${DEPLOYMENT_ORACLE_DRIVER_VERSION}.jar"
  
}

do_install_sqlserver_driver() {
  local _installDir=$1
  
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
  # Install optional add-ons
  if [ -f "${DEPLOYMENT_DIR}/addon" ]; then
    _addons_manager_script=${DEPLOYMENT_DIR}/addon
  fi
  if [ -n "${_addons_manager_script}" -a -f "${_addons_manager_script}" ]; then
    # Let's list them first (this will trigger an update of the installed version of the addons-manager if required)
    ${_addons_manager_script} list --snapshots --unstable
    echo_info "Installing PLF add-ons ..."
    # Let's install them from $DEPLOYMENT_ADDONS env var
    _addons=$(echo $DEPLOYMENT_ADDONS | tr "," "\n")
    for _addon in $_addons; do
      ${_addons_manager_script} install ${_addon} --force --batch-mode
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
        ${_addons_manager_script} install ${_addon} --force --batch-mode
      done < "$_addons_list"
    fi
    echo_info "Done."
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_PLF_LOADED=true
echo_debug "_functions_plf.sh Loaded"