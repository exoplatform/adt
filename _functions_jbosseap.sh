#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_JBOSSEAP_LOADED:-false} && return
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

do_configure_jbosseap_jmx() {
  # JMX settings
  echo_info "Creating JMX configuration files ..."
  cp -f ${ETC_DIR}/jmx/jmxremote.access ${DEPLOYMENT_DIR}/standalone/configuration/jmxremote.access
  cp -f ${ETC_DIR}/jmx/jmxremote.password ${DEPLOYMENT_DIR}/standalone/configuration/jmxremote.password
  chmod 400 ${DEPLOYMENT_DIR}/standalone/configuration/jmxremote.password
  echo_info "Done."
  # Open firewall ports
  do_ufw_open_port ${DEPLOYMENT_RMI_REG_PORT} "JMX RMI REG" ${ADT_DEV_MODE}
  do_ufw_open_port ${DEPLOYMENT_RMI_SRV_PORT} "JMX RMI SRV" ${ADT_DEV_MODE}
  DEPLOYMENT_JMX_URL="service:jmx:rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_SRV_PORT}/jndi/rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_REG_PORT}/jmxrmi"
}

do_configure_jbosseap_datasources() {
  # Patch to reconfigure standalone-exo.xml for database
  find_instance_file DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "standalone-exo-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch" "${DB_SERVER_PATCH_PRODUCT_NAME}"

  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      if [ ! -f ${DEPLOYMENT_DIR}/standalone/deployments/mysql-connector*.jar ]; then
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
        cp -f "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}` ${DEPLOYMENT_DIR}/standalone/deployments/
        echo_info "Done."
      fi

      # Reconfigure standalone-exo.xml for MySQL
      if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp ${DB_SERVER_PATCH} ${DEPLOYMENT_DIR}/standalone/configuration/standalone-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        echo_info "Applying on standalone-exo.xml the patch $DB_SERVER_PATCH ..."
        cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.ori-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
        patch -l -p0 ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml < ${DEPLOYMENT_DIR}/standalone/configuration/standalone-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.patched-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")

        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_DRIVER@" `basename ${MYSQL_JAR_URL}`
        echo_info "Done."
      fi
    ;;
    HSQLDB)
      # Reconfigure standalone-exo.xml for HSQLDB
      if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp ${DB_SERVER_PATCH} ${DEPLOYMENT_DIR}/standalone/configuration/standalone-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        echo_info "Applying on standalone-exo.xml the patch $DB_SERVER_PATCH ..."
        cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.ori-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
        patch -l -p0 ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml < ${DEPLOYMENT_DIR}/standalone/configuration/standalone-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.patched-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")

        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
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
# Function that configure the jbossEAP server ports
#
do_configure_jbosseap_ports() {
  # Patch to reconfigure standalone-exo.xml to change ports
  find_instance_file PORTS_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "standalone-exo-ports.xml.patch" "${PORTS_SERVER_PATCH_PRODUCT_NAME}"

  # JBOSS Specific ports
  env_var "DEPLOYMENT_HTTPS_PORT" "${DEPLOYMENT_PORT_PREFIX}10"
  env_var "DEPLOYMENT_REMOTING_PORT" "${DEPLOYMENT_PORT_PREFIX}11"
  env_var "DEPLOYMENT_TXN_RECOVERY_ENV_PORT" "${DEPLOYMENT_PORT_PREFIX}12"
  env_var "DEPLOYMENT_TXN_STATUS_MGR_PORT" "${DEPLOYMENT_PORT_PREFIX}13"
  env_var "DEPLOYMENT_MGT_NATIVE_PORT" "${DEPLOYMENT_PORT_PREFIX}14"
  env_var "DEPLOYMENT_MGT_HTTP_PORT" "${DEPLOYMENT_PORT_PREFIX}15"
  env_var "DEPLOYMENT_MGT_HTTPS_PORT" "${DEPLOYMENT_PORT_PREFIX}16"

  # Reconfigure standalone-exo.xml to change ports
  if [ "${PORTS_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp ${PORTS_SERVER_PATCH} ${DEPLOYMENT_DIR}/standalone/configuration/standalone-ports.xml.patch
    echo_info "Applying on standalone-exo.xml the patch $PORTS_SERVER_PATCH ..."
    cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.ori-ports
    patch -l -p0 ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml < ${DEPLOYMENT_DIR}/standalone/configuration/standalone-ports.xml.patch
    cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.patched-ports

    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@HTTP_PORT@" "${DEPLOYMENT_HTTP_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@AJP_PORT@" "${DEPLOYMENT_AJP_PORT}"
    
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@HTTPS_PORT@" "${DEPLOYMENT_HTTPS_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@REMOTING_PORT@" "${DEPLOYMENT_REMOTING_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@TXN_RECOVERY_ENV_PORT@" "${DEPLOYMENT_TXN_RECOVERY_ENV_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@TXN_STATUS_MGR_PORT@" "${DEPLOYMENT_TXN_STATUS_MGR_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@MGT_NATIVE_PORT@" "${DEPLOYMENT_MGT_NATIVE_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@MGT_HTTP_PORT@" "${DEPLOYMENT_MGT_HTTP_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml "@MGT_HTTPS_PORT@" "${DEPLOYMENT_MGT_HTTPS_PORT}"
    echo_info "Done."
  fi
}

do_configure_jbosseap_standalone() {
  # PLF 4+ only
  if [ -e ${DEPLOYMENT_DIR}/bin/standalone-customize.sample.conf ]; then
    echo_info "Creating standalone configuration ..."
    if [ ! -f "${DEPLOYMENT_DIR}/bin/standalone-customize.conf" ]; then
      echo_info "Installing bin/standalone-customize.conf ..."
      cp ${ETC_DIR}/plf/standalone-customize.conf ${DEPLOYMENT_DIR}/bin/standalone-customize.conf
      echo_info "Done."
    fi
    # Path of the standalone file to use
    find_instance_file STANDALONE_FILE "${ETC_DIR}/plf" "standalone-local.conf" "${STANDALONE_PRODUCT_NAME}"
    if [ "${STANDALONE_FILE}" != "UNSET" ]; then
      echo_info "Installing bin/standalone-local.conf ..."
      evaluate_file_content ${STANDALONE_FILE} ${DEPLOYMENT_DIR}/bin/standalone-local.conf
      echo_info "Done."
    fi
    echo_info "Done."
  fi
}

#
# Function that configure the server for ours needs
#
do_configure_jbosseap_server() {

  # Ensure the standalone-exo.xml doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.orig
  tr -d '\015' < ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml.orig > ${DEPLOYMENT_DIR}/standalone/configuration/standalone-exo.xml

  # Reconfigure the server to use JMX
  #do_configure_jbosseap_jmx

  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    # Reconfigure the server to use a database
    do_configure_jbosseap_datasources
  fi

  # Configure server ports
  do_configure_jbosseap_ports

  # Environment variables configuration
  do_configure_jbosseap_standalone

  # Install optional extension
  if [ -f "${DEPLOYMENT_DIR}/extension.sh" ]; then
    echo_info "Installing PLF extensions ..."
    _extensions=$(echo $DEPLOYMENT_EXTENSIONS | tr "," "\n")
    for _extension in $_extensions; do
      ${DEPLOYMENT_DIR}/extension.sh --install ${_extension}
    done
    echo_info "Done."
  fi

  if [ -f ${DEPLOYMENT_DIR}/standalone/deployments/platform.ear/*crash*.war ]; then
    env_var "DEPLOYMENT_CRASH_ENABLED" true
    # Open firewall port for CRaSH
    do_ufw_open_port ${DEPLOYMENT_CRASH_SSH_PORT} "CRaSH SSH" ${ADT_DEV_MODE}
  fi

}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_JBOSSEAP_LOADED=true
echo_debug "_functions_jbosseap.sh Loaded"