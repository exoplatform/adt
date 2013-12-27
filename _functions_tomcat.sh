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

# #############################################################################
# TDB : Use functions that aren't using global vars
# #############################################################################

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
  if [ -e ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ]; then
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig > ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}

    # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for ldap
    find_instance_file LDAP_GATEIN_PATCH "${ETC_DIR}/gatein" "ldap-configuration.properties.patch" "${LDAP_GATEIN_PATCH_PRODUCT_NAME}"

    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for LDAP
    if [ "${LDAP_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp ${LDAP_GATEIN_PATCH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      echo_info "Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $LDAP_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.ori.ldap
      patch -l -p0 ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patch
      cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.patched.ldap

      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DEPLOYMENT_LDAP_URL@" "${DEPLOYMENT_LDAP_URL}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DEPLOYMENT_LDAP_ADMIN_DN@" "${DEPLOYMENT_LDAP_ADMIN_DN}"
      replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DEPLOYMENT_LDAP_ADMIN_PWD@" "${DEPLOYMENT_LDAP_ADMIN_PWD}"
      echo_info "Done."
    fi

  fi
}

do_configure_tomcat_datasources() {
  # Patch to reconfigure server.xml for database
  find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"

  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      if [ ! -f ${DEPLOYMENT_DIR}/lib/mysql-connector*.jar ]; then
        MYSQL_JAR_URL="http://repository.exoplatform.org/public/mysql/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/mysql-connector-java-${DEPLOYMENT_MYSQL_DRIVER_VERSION}.jar"
        if [ ! -e ${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/`basename ${MYSQL_JAR_URL}` ]; then
          if ${ADT_OFFLINE}; then
            echo_error "ADT is offine and the MySQL JDBC Driver isn't available locally"
            exit 1
          else
            mkdir -p ${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/
            echo_info "Downloading MySQL JDBC driver from ${MYSQL_JAR_URL} ..."
            set +e
            curl --fail --show-error --location-trusted ${MYSQL_JAR_URL} > ${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/`basename ${MYSQL_JAR_URL}`
            if [ "$?" -ne "0" ]; then
              echo_error "Cannot download ${MYSQL_JAR_URL}"
              rm -f "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}` # Remove potential corrupted file
              exit 1
            fi
            set -e
            echo_info "Done."
          fi
        fi
        echo_info "Validating MySQL JDBC Driver integrity ..."
        set +e
        jar -tf "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}` > /dev/null
        if [ "$?" -ne "0" ]; then
          echo_error "Sorry, "`basename ${MYSQL_JAR_URL}`" integrity failed. Local copy is deleted."
          rm -f "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}`
          exit 1
        fi
        set -e
        echo_info "MySQL JDBC Driver integrity validated."
        echo_info "Installing MySQL JDBC Driver ..."
        cp -f "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}` ${DEPLOYMENT_DIR}/lib/
        echo_info "Done."
      fi
      if [ -e ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ]; then
        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

        # Ensure the configuration.properties doesn't have some windows end line characters
        # '\015' is Ctrl+V Ctrl+M = ^M
        cp ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig
        tr -d '\015' < ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}.orig > ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH}

        # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
        find_instance_file DB_GATEIN_PATCH "${ETC_DIR}/gatein" "db-configuration.properties.patch" "${DB_GATEIN_PATCH_PRODUCT_NAME}"

        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
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
          replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
          replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
          replace_in_file ${DEPLOYMENT_DIR}/${DEPLOYMENT_GATEIN_CONF_PATH} "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
          echo_info "Done."
        fi

      fi

      # Reconfigure server.xml for MySQL
      if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp ${DB_SERVER_PATCH} ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        echo_info "Applying on server.xml the patch $DB_SERVER_PATCH ..."
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
        patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")

        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        echo_info "Done."
      fi
    ;;
    HSQLDB)
      # Reconfigure server.xml for HSQLDB
      if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp ${DB_SERVER_PATCH} ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        echo_info "Applying on server.xml the patch $DB_SERVER_PATCH ..."
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
        patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")

        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        echo_info "Done."
      fi
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
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

#
# Function that configure the server for ours needs
#
do_configure_tomcat_server() {
  # Ensure the server.xml doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.orig
  tr -d '\015' < ${DEPLOYMENT_DIR}/conf/server.xml.orig > ${DEPLOYMENT_DIR}/conf/server.xml

  # Reconfigure the server to use JMX
  do_configure_tomcat_jmx

  do_configure_tomcat_email
  do_configure_tomcat_jod
  do_configure_tomcat_ldap

  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    # Reconfigure the server to use a database
    do_configure_tomcat_datasources
  fi

  do_configure_tomcat_ports

  do_configure_tomcat_setenv

  # Install optional extension
  if [ -f "${DEPLOYMENT_DIR}/extension.sh" ]; then
    echo_info "Installing PLF extensions ..."
    _extensions=$(echo $DEPLOYMENT_EXTENSIONS | tr "," "\n")
    for _extension in $_extensions; do
      ${DEPLOYMENT_DIR}/extension.sh --install ${_extension}
    done
    echo_info "Done."
  fi
  # Install optional add-ons
  if [ -f "${DEPLOYMENT_DIR}/addon.sh" ]; then
    echo_info "Installing PLF add-ons ..."
    _addons=$(echo $DEPLOYMENT_ADDONS | tr "," "\n")
    for _addon in $_addons; do
      ${DEPLOYMENT_DIR}/addon.sh --install ${_addon} --force
    done
    echo_info "Done."
  fi

  if [ -f ${DEPLOYMENT_DIR}/webapps/crash*.war ]; then
    env_var "DEPLOYMENT_CRASH_ENABLED" true
    # Open firewall port for CRaSH
    do_ufw_open_port ${DEPLOYMENT_CRASH_SSH_PORT} "CRaSH SSH" ${ADT_DEV_MODE}
  fi

}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_TOMCAT_LOADED=true
echo_debug "_functions_tomcat.sh Loaded"