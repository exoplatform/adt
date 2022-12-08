#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_TOMCAT_LOADED:-false} && return
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
source "${SCRIPT_DIR}/_functions_ufw.sh"
source "${SCRIPT_DIR}/_functions_plf.sh"

# #############################################################################
# TDB : Use functions that aren't using global vars
# #############################################################################
do_get_tomcat_settings() {
  export DEPLOYMENT_SETTINGS_DIR="${DEPLOYMENT_DIR}/gatein/conf"
}

do_create_jmx_credentials_files() {
  # JMX settings
  echo_info "Creating JMX configuration files ..."
  cp -f ${ETC_DIR}/jmx/jmxremote.access ${DEPLOYMENT_DIR}/conf/jmxremote.access
  cp -f ${ETC_DIR}/jmx/jmxremote.password ${DEPLOYMENT_DIR}/conf/jmxremote.password
  chmod 400 ${DEPLOYMENT_DIR}/conf/jmxremote.password
  echo_info "Done."
  # Open firewall ports
  do_ufw_open_port ${DEPLOYMENT_RMI_REG_PORT} "JMX RMI REG" ${ADT_DEV_MODE}
  do_ufw_open_port ${DEPLOYMENT_RMI_SRV_PORT} "JMX RMI SRV" ${ADT_DEV_MODE}
  DEPLOYMENT_JMX_URL="service:jmx:rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_SRV_PORT}/jndi/rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_REG_PORT}/jmxrmi"
}

do_configure_tomcat_jmx() {
  if [ ! -f ${DEPLOYMENT_DIR}/lib/catalina-jmx-remote*.jar -a ! -f ${DEPLOYMENT_DIR}/lib/tomcat-catalina-jmx-remote*.jar ]; then
    # Install jmx jar
    JMX_JAR_URL="http://archive.apache.org/dist/tomcat/tomcat-${DEPLOYMENT_APPSRV_VERSION:0:1}/v${DEPLOYMENT_APPSRV_VERSION}/bin/extras/catalina-jmx-remote.jar"
    if [ ! -e ${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/`basename ${JMX_JAR_URL}` ]; then
      if ${ADT_OFFLINE}; then
        echo_error "ADT is offine and the JMX remote lib isn't available locally"
        exit 1
      else
        mkdir -p ${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/
        echo_info "Downloading JMX remote lib from ${JMX_JAR_URL} ..."
        set +e
        curl --fail --show-error --location-trusted ${JMX_JAR_URL} > ${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/`basename ${JMX_JAR_URL}`
        if [ "$?" -ne "0" ]; then
          echo_error "Cannot download ${JMX_JAR_URL}"
          rm -f ${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/`basename ${JMX_JAR_URL}` # Remove potential corrupted file
          exit 1
        fi
        set -e
        echo_info "Done."
      fi
    fi
    echo_info "Validating JMX remote lib integrity ..."
    set +e
    jar -tf "${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/"`basename ${JMX_JAR_URL}` > /dev/null
    if [ "$?" -ne "0" ]; then
      echo_error "Sorry, "`basename ${JMX_JAR_URL}`" integrity failed. Local copy is deleted."
      rm -f "${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/"`basename ${JMX_JAR_URL}`
      exit 1
    fi
    set -e
    echo_info "JMX remote lib integrity validated."
    echo_info "Installing JMX remote lib ..."
    cp -f ${DL_DIR}/${DEPLOYMENT_APPSRV_TYPE}/${DEPLOYMENT_APPSRV_VERSION}/`basename ${JMX_JAR_URL}` ${DEPLOYMENT_DIR}/lib/
    echo_info "Done."
  fi
  do_create_jmx_credentials_files
  # Patch to reconfigure server.xml for JMX
  find_instance_file JMX_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-jmx.xml.patch" "${JMX_SERVER_PATCH_PRODUCT_NAME}"

  # Reconfigure server.xml for JMX
  if [ "${JMX_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp ${JMX_SERVER_PATCH} ${DEPLOYMENT_DIR}/conf/server-jmx.xml.patch
    echo_info "Applying on server.xml the patch $JMX_SERVER_PATCH ..."
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-jmx
    patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-jmx.xml.patch
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-jmx

    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@JMX_RMI_REGISTRY_PORT@" "${DEPLOYMENT_RMI_REG_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@JMX_RMI_SERVER_PORT@" "${DEPLOYMENT_RMI_SRV_PORT}"
    echo_info "Done."
  fi
}

do_configure_tomcat_email() {
  if [ -e ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ]; then
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig > ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}

    # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for email
    find_instance_file EMAIL_GATEIN_PATCH "${ETC_DIR}/gatein" "email-configuration.properties.patch" "${EMAIL_GATEIN_PATCH_PRODUCT_NAME}"

    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
    if [ "${EMAIL_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp ${EMAIL_GATEIN_PATCH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      echo_info "Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $EMAIL_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.ori.email
      patch -l -p0 ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patched.email

      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DEPLOYMENT_URL@" "${DEPLOYMENT_URL}"
      echo_info "Done."
    fi

  fi
}

do_configure_tomcat_jod() {
  if [ -e ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ]; then
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig > ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}

    # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for JOD
    find_instance_file JOD_GATEIN_PATCH "${ETC_DIR}/gatein" "jod-configuration.properties.patch" "${JOD_GATEIN_PATCH_PRODUCT_NAME}"

    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for JOD Converter
    if [ "${JOD_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp ${JOD_GATEIN_PATCH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      echo_info "Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $JOD_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.ori.jod
      patch -l -p0 ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patched.jod

      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DEPLOYMENT_JOD_CONVERTER_PORTS@" "${DEPLOYMENT_JOD_CONVERTER_PORTS}"
      echo_info "Done."
    fi

  fi
}

do_configure_tomcat_ldap() {  
  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "true" ] && ! grep -qP "^(1|6)." <<< "${PRODUCT_VERSION}"; then
    echo_info "Start Deploying Directory ${USER_DIRECTORY} conf ..."      
    mkdir -p ${DEPLOYMENT_DIR}/gatein/conf/portal/portal
    cp ${ETC_DIR}/gatein/portal/portal/configuration.xml ${DEPLOYMENT_DIR}/gatein/conf/portal/portal/configuration.xml
    evaluate_file_content ${ETC_DIR}/gatein/portal/portal/idm-configuration.xml.template ${DEPLOYMENT_DIR}/gatein/conf/portal/portal/idm-configuration.xml
    evaluate_file_content ${ETC_DIR}/gatein/portal/portal/picketlink-idm-${USER_DIRECTORY}-config.xml.template ${DEPLOYMENT_DIR}/gatein/conf/portal/portal/picketlink-idm-${USER_DIRECTORY}-config.xml
    echo_info "End Deploying Directory ${USER_DIRECTORY} conf ..."    
  fi
}

do_configure_tomcat_datasources() {

  case ${DEPLOYMENT_DB_TYPE} in
    MYSQL|DOCKER_MYSQL|DOCKER_MARIADB)
      # Patch to reconfigure server.xml for database
      find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-mysql.xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"

      # Deploy the Mysql driver
      if ${DEPLOYMENT_FORCE_JDBC_DRIVER_ADDON}; then 
        local addon="exo-jdbc-driver-mysql:${DEPLOYMENT_MYSQL_ADDON_VERSION}"
        if [ "${PRODUCT_NAME}" = "meeds" ]; then 
          addon="meeds-jdbc-driver-mysql:${DEPLOYMENT_MYSQL_ADDON_VERSION}"
        fi
        echo_info "Using ${addon} addon as jdbc driver"
        env_var "DEPLOYMENT_ADDONS" "${DEPLOYMENT_ADDONS},${addon}"
      else 
        do_install_mysql_driver ${DEPLOYMENT_DIR}/lib/
      fi

      # Patch the configuration files
      if [ -e ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ]; then
        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

        # Ensure the configuration.properties doesn't have some windows end line characters
        # '\015' is Ctrl+V Ctrl+M = ^M
        cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig
        tr -d '\015' < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig > ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}

        # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
        find_instance_file DB_GATEIN_PATCH "${ETC_DIR}/gatein" "db-configuration.properties.patch" "${DB_GATEIN_PATCH_PRODUCT_NAME}"
      fi
    ;;
    DOCKER_POSTGRES)
      # Patch to reconfigure server.xml for database
      find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-postgres.xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"

      if ${DEPLOYMENT_FORCE_JDBC_DRIVER_ADDON}; then
        local addon="exo-jdbc-driver-postgresql:${DEPLOYMENT_POSTGRESQL_ADDON_VERSION}"
        if [ "${PRODUCT_NAME}" = "meeds" ]; then 
          addon="meeds-jdbc-driver-postgresql:${DEPLOYMENT_POSTGRESQL_ADDON_VERSION}"
        fi
        echo_info "Using ${addon} addon as jdbc driver"
        env_var "DEPLOYMENT_ADDONS" "${DEPLOYMENT_ADDONS},${addon}"
      else
        do_install_postgresql_driver ${DEPLOYMENT_DIR}/lib/
      fi
    ;;
    DOCKER_ORACLE)
      # Patch to reconfigure server.xml for database
      find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-oracle.xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"

      if ${DEPLOYMENT_FORCE_JDBC_DRIVER_ADDON}; then
        local addon="exo-jdbc-driver-oracle:${DEPLOYMENT_ORACLE_ADDON_VERSION}"
        echo_info "Using ${addon} addon as jdbc driver"
        env_var "DEPLOYMENT_ADDONS" "${DEPLOYMENT_ADDONS},${addon}"
      else
        do_install_oracle_driver ${DEPLOYMENT_DIR}/lib/
      fi
    ;;
    DOCKER_SQLSERVER)
      # Patch to reconfigure server.xml for database
      find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-sqlserver.xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"

      if ${DEPLOYMENT_FORCE_JDBC_DRIVER_ADDON}; then
        local addon="exo-jdbc-driver-sqlserver:${DEPLOYMENT_SQLSERVER_ADDON_VERSION}"
        echo_info "Using ${addon} addon as jdbc driver"
        env_var "DEPLOYMENT_ADDONS" "${DEPLOYMENT_ADDONS},${addon}"
      else
        do_install_sqlserver_driver ${DEPLOYMENT_DIR}/lib/
      fi
    ;;
    HSQLDB)
      # Patch to reconfigure server.xml for database
      find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-hsqldb.xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac

  do_patch_tomcat_datasources

}

do_patch_tomcat_datasources() {
  # Patch the configuration files
  if [ -e ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ]; then

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig > ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}

    # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
    find_instance_file DB_GATEIN_PATCH "${ETC_DIR}/gatein" "db-configuration.properties.patch" "${DB_GATEIN_PATCH_PRODUCT_NAME}"
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for current database
    if [ "${DB_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp ${DB_GATEIN_PATCH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      echo_info "Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $DB_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.ori.db
      patch -l -p0 ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patched.db

      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JCR_HOST@" "${DEPLOYMENT_DATABASE_HOST}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JCR_PORT@" "${DEPLOYMENT_DATABASE_PORT}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_HOST@" "${DEPLOYMENT_DATABASE_HOST}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_PORT@" "${DEPLOYMENT_DATABASE_PORT}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JPA_USR@" "${DEPLOYMENT_DATABASE_USER}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JPA_PWD@" "${DEPLOYMENT_DATABASE_USER}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JPA_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JPA_HOST@" "${DEPLOYMENT_DATABASE_HOST}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_JPA_PORT@" "${DEPLOYMENT_DATABASE_PORT}"
      echo_info "Done."
    fi
  fi
  
  do_configure_datasource_file ${DEPLOYMENT_DIR}/conf/server.xml ${DB_SERVER_PATCH}
}

#
# Function that configure the tomcat server ports
#
do_configure_tomcat_ports() {
  # Patch to reconfigure server.xml to change ports
  find_instance_file PORTS_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-ports.xml.patch" "${PORTS_SERVER_PATCH_PRODUCT_NAME}"

  # Tomcat Specific ports
  env_var "DEPLOYMENT_SHUTDOWN_PORT" "${DEPLOYMENT_PORT_PREFIX}00"

  # Reconfigure server.xml to change ports
  if [ "${PORTS_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp ${PORTS_SERVER_PATCH} ${DEPLOYMENT_DIR}/conf/server-ports.xml.patch
    echo_info "Applying on server.xml the patch $PORTS_SERVER_PATCH ..."
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-ports
    patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-ports.xml.patch
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-ports

    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@SHUTDOWN_PORT@" "${DEPLOYMENT_SHUTDOWN_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@HTTP_PORT@" "${DEPLOYMENT_HTTP_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@AJP_PORT@" "${DEPLOYMENT_AJP_PORT}"
    echo_info "Done."
  fi
}

do_configure_tomcat_setenv() {
  # setenv.xml
  find_instance_file TOMCAT_SETENV_SCRIPT "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "setenv.sh" "${TOMCAT_SETENV_SCRIPT_PRODUCT_NAME}"

  # Use a specific setenv.sh
  if [ "${TOMCAT_SETENV_SCRIPT}" != "UNSET" ]; then
    echo_info "Installing custom setenv.sh script $TOMCAT_SETENV_SCRIPT ..."
    cp ${TOMCAT_SETENV_SCRIPT} ${DEPLOYMENT_DIR}/bin/setenv.sh
    chmod 755 ${DEPLOYMENT_DIR}/bin/setenv.sh
    echo_info "Done."
  fi

  # PLF 4+ only
  if [ -e ${DEPLOYMENT_DIR}/bin/setenv-customize.sample.sh ]; then
    echo_info "Creating setenv resources ..."
    if [ ! -f "${DEPLOYMENT_DIR}/bin/setenv-customize.sh" ]; then
      echo_info "Installing bin/setenv-customize.sh ..."
      cp ${ETC_DIR}/plf/setenv-customize.sh ${DEPLOYMENT_DIR}/bin/setenv-customize.sh
      echo_info "Done."
    fi
    # Path of the setenv file to use
    find_instance_file SET_ENV_FILE "${ETC_DIR}/plf" "setenv-local.sh" "${SET_ENV_PRODUCT_NAME}"
    if [ "${SET_ENV_FILE}" != "UNSET" ]; then
      echo_info "Installing bin/setenv-local.sh ..."
      evaluate_file_content ${SET_ENV_FILE} ${DEPLOYMENT_DIR}/bin/setenv-local.sh
      echo_info "Done."
    fi
    echo_info "Done."
  fi
}

do_configure_gzip_compression() {
  xmlstarlet ed -L -u "/Server/Service/Connector/@compression" -v "on" ${DEPLOYMENT_DIR}/conf/server.xml || {
    echo_error "Failend to enable GZIP compression on Tomcat Server!"
  }
}

#
# Function that configure the server for ours needs
#
do_configure_tomcat_server() {
  # Ensure the server.xml doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.orig
  tr -d '\015' < ${DEPLOYMENT_DIR}/conf/server.xml.orig > ${DEPLOYMENT_DIR}/conf/server.xml

  # Reconfigure the server to use JMX
  # if DEPLOYMENT_APPSRV_VERSION = 9.0+ skip downloading catalina-jmx-remote.jar (Not supported anymore)
  if [[ "${DEPLOYMENT_APPSRV_VERSION}" =~ ^(9.0) ]]; then
    # Juste display the calculated JMX URL
    do_create_jmx_credentials_files
  else
    do_configure_tomcat_jmx
  fi
  do_configure_tomcat_email
  do_configure_tomcat_jod
  do_configure_tomcat_ldap

  # Install the addons manager
  # Addon manager is needed to install jdbc driver
  do_install_addons_manager

  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    # Reconfigure the server to use a database
    do_configure_tomcat_datasources
  fi

  do_configure_tomcat_ports

  if ${DEPLOYMENT_GZIP_ENABLED:-false}; then 
    do_configure_gzip_compression
  fi

  do_configure_tomcat_setenv

  # Install optional extensions
  do_install_extensions

  # Install optional addons
  do_install_addons

  # Install patches from patch catalog
  do_install_patches

  # Uninstall addons
  do_remove_addons

  if [ -f ${DEPLOYMENT_DIR}/webapps/crash*.war ]; then
    env_var "DEPLOYMENT_CRASH_ENABLED" true
    # Open firewall port for CRaSH
    do_ufw_open_port ${DEPLOYMENT_CRASH_SSH_PORT} "CRaSH SSH" ${ADT_DEV_MODE}
  fi

  if ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED} ; then
    # Open firewall port for Onlyoffice documentserver
    do_ufw_open_port ${DEPLOYMENT_ONLYOFFICE_HTTP_PORT} "OnlyOffice Documentserver HTTP" ${ADT_DEV_MODE}
  fi

  if [ "${DEPLOYMENT_LDAP_ENABLED}" == "true" ] && [ "${USER_DIRECTORY}" == "LDAP" ]; then
    # Open firewall port for LDAPS
    do_ufw_open_port ${DEPLOYMENT_LDAP_PORT} "Ldap Port" ${ADT_DEV_MODE}
  fi

  if [ "${DEPLOYMENT_SFTP_ENABLED}" == "true" ]; then
    do_ufw_open_port ${DEPLOYMENT_SFTP_PORT} "Sftp Port" ${ADT_DEV_MODE}
  fi  
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_TOMCAT_LOADED=true
echo_debug "_functions_tomcat.sh Loaded"
