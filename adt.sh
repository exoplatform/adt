#!/bin/bash -eu

# #############################################################################
# Initialize
# #############################################################################                                              
SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="${0%/*}"

#
# LOAD PARAMETERS FROM SERVER AND USER SETTINGS
#

# Load server config from /etc/default/adt
[ -e "/etc/default/adt" ] && source /etc/default/adt

# Load local config from $HOME/.adtrc
[ -e "$HOME/.adtrc" ] && source $HOME/.adtrc

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

# Load shared functions
source "${SCRIPT_DIR}/_functions.sh"

echo "[INFO] # #######################################################################"
echo "[INFO] # $SCRIPT_NAME"
echo "[INFO] # #######################################################################"

# Root dir for config files used by these scripts
export SCRIPT_CONF_DIR=${SCRIPT_DIR}/conf

# Configurable env vars. These variables can be loaded 
# from the env, /etc/default/adt or $HOME/.adtrc
configurable_env_var "ADT_DEBUG" false
configurable_env_var "ADT_DATA" "${SCRIPT_DIR}"
configurable_env_var "ACCEPTANCE_HOST" "acceptance.exoplatform.org"
configurable_env_var "CROWD_ACCEPTANCE_APP_NAME" ""
configurable_env_var "CROWD_ACCEPTANCE_APP_PASSWORD" ""
configurable_env_var "DEPLOYMENT_SETUP_APACHE" false
configurable_env_var "DEPLOYMENT_SETUP_AWSTATS" false
configurable_env_var "DEPLOYMENT_SETUP_UFW" false
configurable_env_var "DEPLOYMENT_DATABASE_TYPE" "HSQLDB"
configurable_env_var "DEPLOYMENT_SHUTDOWN_PORT" "8005"
configurable_env_var "DEPLOYMENT_HTTP_PORT" "8080"
configurable_env_var "DEPLOYMENT_AJP_PORT" "8009"
configurable_env_var "DEPLOYMENT_RMI_REG_PORT" "10001"
configurable_env_var "DEPLOYMENT_RMI_SRV_PORT" "10002"
configurable_env_var "KEEP_DB" false
configurable_env_var "REPOSITORY_SERVER_BASE_URL" "https://repository.exoplatform.org"
configurable_env_var "REPOSITORY_USERNAME" ""
configurable_env_var "REPOSITORY_PASSWORD" ""

# Create ADT_DATA if required
mkdir -p ${ADT_DATA}
# Convert to an absolute path
pushd ${ADT_DATA} > /dev/null
ADT_DATA=`pwd -P`
popd > /dev/null
echo "[INFO] ADT_DATA = ${ADT_DATA}"

env_var "TMP_DIR" "${ADT_DATA}/tmp"
env_var "DL_DIR" "${ADT_DATA}/downloads"
env_var "SRV_DIR" "${ADT_DATA}/servers"
env_var "CONF_DIR" "${ADT_DATA}/conf"
env_var "APACHE_CONF_DIR" "${ADT_DATA}/conf/apache"
env_var "AWSTATS_CONF_DIR" "${ADT_DATA}/conf/awstats"
env_var "ADT_CONF_DIR" "${ADT_DATA}/conf/adt"
env_var "FEATURES_CONF_DIR" "${ADT_DATA}/conf/features"
env_var "ETC_DIR" "${ADT_DATA}/etc"

env_var "CURR_DATE" `date "+%Y%m%d.%H%M%S"`

#
# Usage message
#
print_usage() {
  cat << EOF

  usage: $0 <action>

This script manages automated deployment of eXo products for testing purpose.

Action :
  deploy       Deploys (Download+Configure) the server
  start        Starts the server
  stop         Stops the server
  restart      Restarts the server
  undeploy     Undeploys (deletes) the server

  start-all    Starts all deployed servers
  stop-all     Stops all deployed servers
  restart-all  Restarts all deployed servers
  undeploy-all Undeploys (deletes) all deployed servers
  list         Lists all deployed servers

Environment Variables :

  They may be configured in the current shell environment or /etc/default/adt or \$HOME/.adtrc
  
  PRODUCT_NAME                  : The product you want to manage. Possible values are :
    gatein       GateIn Community edition
    exogtn       GateIn eXo edition
    webos        eXo WebOS
    social       eXo Social
    ecms         eXo Content
    ks           eXo Knowledge
    cs           eXo Collaboration
    plf          eXo Platform Standard Edition
    plfcom       eXo Platform Community Edition
    plftrial     eXo Platform Trial Edition
    compint      eXo Company Intranet
    docs         eXo Platform Documentations Website
  PRODUCT_VERSION               : The version of the product. Can be either a release, a snapshot (the latest one) or a timestamped snapshot

  ADT_DATA                      : The path where data have to be stored (default: under the script path - ${SCRIPT_DIR})
  DEPLOYMENT_SETUP_APACHE       : Do you want to setup the apache configuration (default: false)
  DEPLOYMENT_SETUP_AWSTATS      : Do you want to setup the awstats configuration (default: false)
  DEPLOYMENT_SETUP_UFW          : Do you want to setup the ufw firewall configuration (default: false)
  DEPLOYMENT_AJP_PORT           : AJP Port (default: 8009)
  DEPLOYMENT_HTTP_PORT          : HTTP Port (default: 8080)
  DEPLOYMENT_SHUTDOWN_PORT      : SHUTDOWN Port (default: 8005)
  DEPLOYMENT_RMI_REG_PORT       : RMI Registry Port for JMX (default: 10001) 
  DEPLOYMENT_RMI_SRV_PORT       : RMI Server Port for JMX (default: 10002)
  DEPLOYMENT_DATABASE_TYPE      : Which database do you want to use for your deployment ? (default: HSQLDB, values : HSQLDB | MYSQL)
  ACCEPTANCE_HOST               : The hostname (vhost) where is deployed the acceptance server (default: acceptance.exoplatform.org)
  CROWD_ACCEPTANCE_APP_NAME     : The crowd application used to authenticate the front-end (default: none)
  CROWD_ACCEPTANCE_APP_PASSWORD : The crowd application''s password used to authenticate the front-end (default: none)
  KEEP_DB                       : Keep the current database content for MYSQL. By default the deployment process drops the database if it already exists. (default: false)

  REPOSITORY_SERVER_BASE_URL    : The Maven repository URL used to download artifacts (default: https://repository.exoplatform.org)
  REPOSITORY_USERNAME           : The username to logon on \$REPOSITORY_SERVER_BASE_URL if necessary (default: none)
  REPOSITORY_PASSWORD           : The password to logon on \$REPOSITORY_SERVER_BASE_URL if necessary (default: none)

  ADT_DEBUG                     : Display debug details (default: false)
EOF

}


init() {
  validate_env_var "SCRIPT_DIR"
  validate_env_var "ADT_DATA"
  validate_env_var "ETC_DIR"
  validate_env_var "TMP_DIR"
  validate_env_var "DL_DIR"
  validate_env_var "SRV_DIR"
  validate_env_var "CONF_DIR"
  validate_env_var "APACHE_CONF_DIR"
  validate_env_var "ADT_CONF_DIR"
  validate_env_var "FEATURES_CONF_DIR"
  mkdir -p ${ETC_DIR}
  mkdir -p ${TMP_DIR}
  mkdir -p ${DL_DIR}
  mkdir -p ${SRV_DIR}
  mkdir -p ${CONF_DIR}
  mkdir -p ${APACHE_CONF_DIR}/conf.d
  mkdir -p ${APACHE_CONF_DIR}/sites-available
  mkdir -p ${ADT_CONF_DIR}
  mkdir -p ${FEATURES_CONF_DIR}
  chmod 777 ${FEATURES_CONF_DIR} # apache needs to write here
  # Recopy default data
  # Copy everything in it
  if [[ "${SCRIPT_DIR}" != "${ADT_DATA}" ]]; then
    rm -rf ${ETC_DIR}/*
    cp -rf ${SCRIPT_DIR}/* ${ADT_DATA}
  fi
  # Create the main vhost from the template
  if ${DEPLOYMENT_SETUP_APACHE}; then
    validate_env_var "ADT_DATA"
    validate_env_var "ACCEPTANCE_HOST"
    validate_env_var "CROWD_ACCEPTANCE_APP_NAME"
    validate_env_var "CROWD_ACCEPTANCE_APP_PASSWORD"
    evaluate_file_content ${ETC_DIR}/apache2/conf.d/adt.conf.template ${APACHE_CONF_DIR}/conf.d/adt.conf
    evaluate_file_content ${ETC_DIR}/apache2/sites-available/frontend.template ${APACHE_CONF_DIR}/sites-available/acceptance.exoplatform.org
    sudo /usr/sbin/service apache2 reload
  fi
}

# find_patch <VAR> <PATCH_DIR> <BASENAME> <PRODUCT_NAME>
# Finds which patch to apply and store its path in <VAR>
# We'll try to find it in the directory <PATCH_DIR> and we'll select it in this order :
# <PRODUCT_NAME>-${PRODUCT_VERSION}-<BASENAME>.patch
# <PRODUCT_NAME>-${PRODUCT_BRANCH}-<BASENAME>.patch
# <PRODUCT_NAME>-${PRODUCT_MAJOR_BRANCH}-<BASENAME>.patch
# <PRODUCT_NAME>-<BASENAME>.patch  
# <BASENAME>.patch
find_patch() {
  local _variable=$1
  local _patchDir=$2
  local _basename=$3
  local _product=$4
  find_file $_variable  \
 "$_patchDir/$_basename.patch"  \
 "$_patchDir/$_product-$_basename.patch"  \
 "$_patchDir/$_product-${PRODUCT_MAJOR_BRANCH}-$_basename.patch"  \
 "$_patchDir/$_product-${PRODUCT_BRANCH}-$_basename.patch"  \
 "$_patchDir/$_product-${PRODUCT_VERSION}-$_basename.patch"
}

#
# Decode command line parameters
#
initialize_product_settings() {
  validate_env_var "ACTION"

  # validate additional parameters
  case "${ACTION}" in
    deploy)
    # Mandatory env vars. They need to be defined before launching the script
      validate_env_var "PRODUCT_NAME"
      validate_env_var "PRODUCT_VERSION"

      if ${DEPLOYMENT_SETUP_APACHE}; then
        env_var "DEPLOYMENT_EXT_HOST" "${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}"
        env_var "DEPLOYMENT_EXT_PORT" "80"
      else
        env_var "DEPLOYMENT_EXT_HOST" "localhost"
        env_var "DEPLOYMENT_EXT_PORT" "${DEPLOYMENT_HTTP_PORT}"
      fi
      env_var "DEPLOYMENT_URL" "http://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_EXT_PORT}"


      # Defaults values we can override by product/branch/version
      env_var "EXO_PROFILES" "all"
      env_var "DEPLOYMENT_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_NAME" ""
      env_var "DEPLOYMENT_DATABASE_USER" ""
      env_var "DEPLOYMENT_EXTRA_ENV_VARS" ""
      env_var "DEPLOYMENT_EXTRA_JAVA_OPTS" ""
      env_var "DEPLOYMENT_EXO_PROFILES" "-Dexo.profiles=${EXO_PROFILES}"
      env_var "DEPLOYMENT_GATEIN_CONF_PATH" "gatein/conf/configuration.properties"
      env_var "DEPLOYMENT_SERVER_SCRIPT" "bin/gatein.sh"
      env_var "DEPLOYMENT_APPSRV_TYPE" "tomcat" #Server type
      env_var "DEPLOYMENT_APPSRV_VERSION" "6.0.35" #Default version used to download additional resources like JMX lib

      env_var "ARTIFACT_GROUPID" ""
      env_var "ARTIFACT_ARTIFACTID" ""
      env_var "ARTIFACT_TIMESTAMP" ""
      env_var "ARTIFACT_CLASSIFIER" ""
      env_var "ARTIFACT_PACKAGING" "zip"

      env_var "ARTIFACT_REPO_GROUP" "public"

      # They are set by the script
      env_var "ARTIFACT_DATE" ""
      env_var "ARTIFACT_REPO_URL" ""
      env_var "ARTIFACT_DL_URL" ""
      env_var "DEPLOYMENT_DATE" ""
      env_var "DEPLOYMENT_DIR" ""
      env_var "DEPLOYMENT_LOG_URL" ""
      env_var "DEPLOYMENT_LOG_PATH" ""
      env_var "DEPLOYMENT_JMX_URL" ""
      env_var "DEPLOYMENT_PID_FILE" ""

      # Classifier to group together projects in the UI
      env_var PLF_BRANCH "UNKNOWN" # 3.0.x, 3.5.x, 4.0.x

      # More user friendly description
      env_var "PRODUCT_DESCRIPTION" "${PRODUCT_NAME}"

      # To reuse patches between products
      env_var "PORTS_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "JMX_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "MYSQL_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "MYSQL_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"

      # ${PRODUCT_BRANCH} is computed from ${PRODUCT_VERSION} and is equal to the version up to the latest dot
      # and with x added. ex : 3.5.0-M4-SNAPSHOT => 3.5.x, 1.1.6-SNAPSHOT => 1.1.x
      env_var PRODUCT_BRANCH `expr "${PRODUCT_VERSION}" : '\([0-9]*\.[0-9]*\).*'`".x"
      env_var PRODUCT_MAJOR_BRANCH `expr "${PRODUCT_VERSION}" : '\([0-9]*\).*'`".x"

      # Validate product and load artifact details
      case "${PRODUCT_NAME}" in
        gatein)
          env_var PRODUCT_DESCRIPTION "GateIn Community edition"
          case "${PRODUCT_BRANCH}" in
            "3.0.x" | "3.1.x" | "3.2.x" | "3.3.x" | "3.4.x")
              env_var ARTIFACT_GROUPID "org.exoplatform.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.pkg.tc6"
            ;;
            *)
            # 3.5.x and +
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.tomcat7"
              env_var DEPLOYMENT_APPSRV_VERSION "7.0.30"
            ;;
          esac
          env_var ARTIFACT_CLASSIFIER "bundle"
          case "${PRODUCT_BRANCH}" in
            "3.5.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
          esac
        ;;
        exogtn)
          env_var PRODUCT_DESCRIPTION "GateIn eXo edition"
          env_var ARTIFACT_GROUPID "org.exoplatform.portal"
          env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.assembly"
          env_var ARTIFACT_CLASSIFIER "tomcat"
          case "${PRODUCT_BRANCH}" in
            "3.2.x")
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
        ;;
        webos)
          env_var PRODUCT_DESCRIPTION "eXo WebOS"
          env_var ARTIFACT_GROUPID "org.exoplatform.webos"
          env_var ARTIFACT_ARTIFACTID "exo.webos.packaging.assembly"
          env_var ARTIFACT_CLASSIFIER "tomcat"
          case "${PRODUCT_BRANCH}" in
            *)
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
        ;;
        ecms)
          env_var PRODUCT_DESCRIPTION "eXo Content"
          env_var ARTIFACT_GROUPID "org.exoplatform.ecms"
          env_var ARTIFACT_ARTIFACTID "exo-ecms-delivery-wcm-assembly"
          env_var ARTIFACT_CLASSIFIER "tomcat"
          case "${PRODUCT_BRANCH}" in
            "4.0.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
            *)
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
        ;;
        social)
          env_var PRODUCT_DESCRIPTION "eXo Social"
          env_var ARTIFACT_GROUPID "org.exoplatform.social"
          env_var ARTIFACT_ARTIFACTID "exo.social.packaging.pkg"
          env_var ARTIFACT_CLASSIFIER "tomcat"
          env_var DEPLOYMENT_GATEIN_CONF_PATH "gatein/conf/portal/socialdemo/socialdemo.properties"
          case "${PRODUCT_BRANCH}" in
            "4.0.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
            *)
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
        ;;
        ks)
          env_var PRODUCT_DESCRIPTION "eXo Knowledge"
          env_var ARTIFACT_GROUPID "org.exoplatform.ks"
          env_var ARTIFACT_ARTIFACTID "exo.ks.packaging.assembly"
          env_var ARTIFACT_CLASSIFIER "tomcat"
          env_var DEPLOYMENT_GATEIN_CONF_PATH "gatein/conf/portal/ksdemo/ksdemo.properties"
          case "${PRODUCT_BRANCH}" in
            "4.0.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
            *)
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
        ;;
        cs)
          env_var PRODUCT_DESCRIPTION "eXo Collaboration"
          env_var ARTIFACT_GROUPID "org.exoplatform.cs"
          env_var ARTIFACT_ARTIFACTID "exo.cs.packaging.assembly"
          env_var ARTIFACT_CLASSIFIER "tomcat"
          case "${PRODUCT_BRANCH}" in
            "4.0.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
            *)
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
        ;;
        plf)
          env_var PRODUCT_DESCRIPTION "eXo Platform Standard Edition"
          env_var ARTIFACT_GROUPID "org.exoplatform.platform"
          case "${PRODUCT_BRANCH}" in
            "3.0.x")
              env_var ARTIFACT_ARTIFACTID "exo.platform.packaging.assembly"
              env_var ARTIFACT_CLASSIFIER "tomcat"
            ;;
            "3.5.x")
              env_var ARTIFACT_ARTIFACTID "exo.platform.packaging.tomcat"
              env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
            ;;
            *)
            # 4.0.x and +
              env_var ARTIFACT_GROUPID "org.exoplatform.platform.pkg"
              env_var ARTIFACT_ARTIFACTID "platform-tomcat-standalone"
              env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
            ;;
          esac
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        plftrial)
          env_var PRODUCT_DESCRIPTION "eXo Platform Trial Edition"
          env_var ARTIFACT_GROUPID "org.exoplatform.platform"
          env_var ARTIFACT_ARTIFACTID "exo.platform.packaging.trial"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PORTS_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var JMX_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var MYSQL_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var MYSQL_GATEIN_PATCH_PRODUCT_NAME "plf"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        plfcom)
          env_var PRODUCT_DESCRIPTION "eXo Platform Community Edition"
          env_var ARTIFACT_GROUPID "org.exoplatform.platform"
          env_var ARTIFACT_ARTIFACTID "exo.platform.packaging.community"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PORTS_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var JMX_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var MYSQL_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var MYSQL_GATEIN_PATCH_PRODUCT_NAME "plf"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        compint)
          env_var PRODUCT_DESCRIPTION "eXo Company Intranet"
          env_var ARTIFACT_REPO_GROUP "cp"
          env_var ARTIFACT_GROUPID "com.exoplatform.intranet"
          env_var ARTIFACT_ARTIFACTID "exo-intranet-package"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PORTS_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var MYSQL_GATEIN_PATCH_PRODUCT_NAME "plf"
        ;;
        docs)
          env_var ARTIFACT_REPO_GROUP "private"
          env_var PRODUCT_DESCRIPTION "eXo Platform Documentations Website"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.documentation"
          env_var ARTIFACT_ARTIFACTID "platform-documentation-website-packaging"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_DATABASE_ENABLED false
        ;;
        *)
          echo "[ERROR] Invalid product \"${PRODUCT_NAME}\""
          print_usage
          exit 1
        ;;
      esac
      if ${DEPLOYMENT_DATABASE_ENABLED}; then
        # Build a database name without dot, minus ...
        env_var DEPLOYMENT_DATABASE_NAME "${PRODUCT_NAME}_${PRODUCT_VERSION}"
        env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//./_}"
        env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//-/_}"
        # Build a database user without dot, minus ... (using the branch because limited to 16 characters)
        env_var DEPLOYMENT_DATABASE_USER "${PRODUCT_NAME}_${PRODUCT_BRANCH}"
        env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//./_}"
        env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//-/_}"
      fi
      # Patch to reconfigure server.xml to change ports
      find_patch PORTS_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-ports.xml" "${PORTS_SERVER_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure server.xml for JMX
      find_patch JMX_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-jmx.xml" "${JMX_SERVER_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure server.xml for MySQL
      find_patch MYSQL_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-mysql.xml" "${MYSQL_SERVER_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
      find_patch MYSQL_GATEIN_PATCH "${ETC_DIR}/gatein" "configuration.properties" "${MYSQL_GATEIN_PATCH_PRODUCT_NAME}"
    ;;
    start | stop | restart | undeploy)
    # Mandatory env vars. They need to be defined before launching the script
      validate_env_var "PRODUCT_NAME"
      validate_env_var "PRODUCT_VERSION" ;;
    list | start-all | stop-all | restart-all | undeploy-all)
    # Nothing to do
    ;;
    *)
      echo "[ERROR] Invalid action \"${ACTION}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Function that downloads the app server from nexus
#
do_download_server() {
  validate_env_var "DL_DIR"
  validate_env_var "PRODUCT_NAME"
  validate_env_var "PRODUCT_VERSION"
  validate_env_var "ARTIFACT_REPO_GROUP"
  validate_env_var "ARTIFACT_GROUPID"
  validate_env_var "ARTIFACT_ARTIFACTID"
  validate_env_var "ARTIFACT_PACKAGING"
  validate_env_var "ARTIFACT_CLASSIFIER"

  # Downloads the product from Nexus
  do_download_from_nexus  \
 "${REPOSITORY_SERVER_BASE_URL}/${ARTIFACT_REPO_GROUP}" "${REPOSITORY_USERNAME}" "${REPOSITORY_PASSWORD}"  \
 "${ARTIFACT_GROUPID}" "${ARTIFACT_ARTIFACTID}" "${PRODUCT_VERSION}" "${ARTIFACT_PACKAGING}" "${ARTIFACT_CLASSIFIER}"  \
 "${DL_DIR}" "${PRODUCT_NAME}" "PRODUCT"
  do_load_artifact_descriptor "${DL_DIR}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}"
  env_var ARTIFACT_TIMESTAMP ${PRODUCT_ARTIFACT_TIMESTAMP}
  env_var ARTIFACT_DATE ${PRODUCT_ARTIFACT_DATE}
  env_var ARTIFACT_REPO_URL ${PRODUCT_ARTIFACT_URL}
  env_var ARTIFACT_LOCAL_PATH ${PRODUCT_ARTIFACT_LOCAL_PATH}
  env_var ARTIFACT_DL_URL "http://${ACCEPTANCE_HOST}/downloads/${PRODUCT_NAME}-${ARTIFACT_TIMESTAMP}.${ARTIFACT_PACKAGING}"
}

#
# Function that unpacks the app server archive
#
do_unpack_server() {
  rm -rf ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  echo "[INFO] Unpacking server ..."
  mkdir -p ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  set +e
  case ${ARTIFACT_PACKAGING} in
    zip)
      unzip -q ${ARTIFACT_LOCAL_PATH} -d ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo "[WARNING] unpack of the server failed. We will try to download it a second time."
        rm ${ARTIFACT_LOCAL_PATH}
        do_download_server
        unzip -q ${ARTIFACT_LOCAL_PATH} -d ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
        if [ "$?" -ne "0" ]; then
          echo "[ERROR] Unable to unpack the server."
          exit 1
        fi
      fi
    ;;
    tar.gz)
      cd ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
      tar -xzf ${ARTIFACT_LOCAL_PATH}
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo "[WARNING] unpack of the server failed. We will try to download it a second time."
        rm ${ARTIFACT_LOCAL_PATH}
        do_download_server
        tar -xzf ${ARTIFACT_LOCAL_PATH}
        if [ "$?" -ne "0" ]; then
          echo "[ERROR] Unable to unpack the server."
          exit 1
        fi
      fi
      cd -
    ;;
    *)
      echo "[ERROR] Invalid packaging \"${ARTIFACT_PACKAGING}\""
      print_usage
      exit 1
    ;;
  esac
  set -e
  DEPLOYMENT_PID_FILE=${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.pid
  mkdir -p ${SRV_DIR}
  rm -rf ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  cp -rf ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION} ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  # We search the tomcat directory as the parent of a gatein directory
  pushd `find ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION} -maxdepth 4 -mindepth 1 -name webapps -type d`/.. > /dev/null
  DEPLOYMENT_DIR=`pwd -P`
  popd > /dev/null
  DEPLOYMENT_LOG_PATH=${DEPLOYMENT_DIR}/logs/catalina.out
  echo "[INFO] Server unpacked"
}

#
# Creates a database for the instance. Drops it if it already exists.
#
do_create_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      echo "[INFO] Creating MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
      SQL=""
      if (! $KEEP_DB); then
        SQL=$SQL"DROP DATABASE IF EXISTS ${DEPLOYMENT_DATABASE_NAME};"
        echo "[INFO] Existing databases will be dropped !"
      fi
      SQL=$SQL"CREATE DATABASE IF NOT EXISTS ${DEPLOYMENT_DATABASE_NAME} CHARACTER SET latin1 COLLATE latin1_bin;"
      SQL=$SQL"GRANT ALL ON ${DEPLOYMENT_DATABASE_NAME}.* TO '${DEPLOYMENT_DATABASE_USER}'@'localhost' IDENTIFIED BY '${DEPLOYMENT_DATABASE_USER}';"
      SQL=$SQL"FLUSH PRIVILEGES;"
      SQL=$SQL"SHOW DATABASES;"
      mysql -e "$SQL"
      echo "[INFO] Done."
    ;;
    HSQLDB)
      echo "[INFO] Using default HSQLDB database. Nothing to do."
    ;;
    *)
      echo "[ERROR] Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Drops the database used by the instance.
#
do_drop_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      echo "[INFO] Drops MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
      SQL=""
      SQL=$SQL"DROP DATABASE IF EXISTS ${DEPLOYMENT_DATABASE_NAME};"
      SQL=$SQL"SHOW DATABASES;"
      mysql -e "$SQL"
      echo "[INFO] Done."
    ;;
    HSQLDB)
      echo "[INFO] Using default HSQLDB database. Nothing to do."
    ;;
    *)
      echo "[ERROR] Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

do_configure_server_for_jmx() {
  if [ ! -e "${DEPLOYMENT_DIR}/lib/*catalina-jmx-remote*.jar" ]; then
    # Install jmx jar
    JMX_JAR_URL="http://archive.apache.org/dist/tomcat/tomcat-${DEPLOYMENT_APPSRV_VERSION:0:1}/v${DEPLOYMENT_APPSRV_VERSION}/bin/extras/catalina-jmx-remote.jar"
    echo "[INFO] Downloading and installing JMX remote lib from ${JMX_JAR_URL} ..."
    curl ${JMX_JAR_URL} > ${DEPLOYMENT_DIR}/lib/`basename $JMX_JAR_URL`
    if [ ! -e "${DEPLOYMENT_DIR}/lib/"`basename $JMX_JAR_URL` ]; then
      echo "[ERROR] !!! Sorry, cannot download ${JMX_JAR_URL}"
      exit 1
    fi
    echo "[INFO] Done."
  fi
  # JMX settings
  echo "[INFO] Creating JMX configuration files ..."
  cp -f ${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}/conf/jmxremote.access ${DEPLOYMENT_DIR}/conf/jmxremote.access
  cp -f ${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}/conf/jmxremote.password ${DEPLOYMENT_DIR}/conf/jmxremote.password
  chmod 400 ${DEPLOYMENT_DIR}/conf/jmxremote.password
  echo "[INFO] Done."
  echo "[INFO] Opening firewall ports ..."
  # Open firewall ports
  if ${DEPLOYMENT_SETUP_UFW}; then
    sudo /usr/sbin/ufw allow ${DEPLOYMENT_RMI_REG_PORT}
    sudo /usr/sbin/ufw allow ${DEPLOYMENT_RMI_SRV_PORT}
  fi
  echo "[INFO] Done."
  DEPLOYMENT_JMX_URL="service:jmx:rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_SRV_PORT}/jndi/rmi://${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_RMI_REG_PORT}/jmxrmi"

  # Reconfigure server.xml for JMX
  if [ "${JMX_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp $JMX_SERVER_PATCH ${DEPLOYMENT_DIR}/conf/server-jmx.xml.patch
    echo "[INFO] Applying on server.xml the patch $JMX_SERVER_PATCH ..."
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-jmx
    patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-jmx.xml.patch
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-jmx

    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@JMX_RMI_REGISTRY_PORT@" "${DEPLOYMENT_RMI_REG_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@JMX_RMI_SERVER_PORT@" "${DEPLOYMENT_RMI_SRV_PORT}"
    echo "[INFO] Done."
  fi
}

do_configure_server_for_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      MYSQL_JAR_URL="http://repository.exoplatform.org/public/mysql/mysql-connector-java/5.1.16/mysql-connector-java-5.1.16.jar"
      echo "[INFO] Download and install MySQL JDBC driver from ${MYSQL_JAR_URL} ..."
      curl ${MYSQL_JAR_URL} > ${DEPLOYMENT_DIR}/lib/`basename $MYSQL_JAR_URL`
      if [ ! -e "${DEPLOYMENT_DIR}/lib/"`basename $MYSQL_JAR_URL` ]; then
        echo "[ERROR] !!! Sorry, cannot download ${MYSQL_JAR_URL}"
        exit 1
      fi
      echo "[INFO] Done."
      if [ -e ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ]; then
        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

        # Ensure the configuration.properties doesn't have some windows end line characters
        # '\015' is Ctrl+V Ctrl+M = ^M
        cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig
        tr -d '\015' < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig > ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH

        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
        if [ "${MYSQL_GATEIN_PATCH}" != "UNSET" ]; then
          # Prepare the patch
          cp $MYSQL_GATEIN_PATCH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
          echo "[INFO] Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $MYSQL_GATEIN_PATCH ..."
          cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.ori
          patch -l -p0 ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
          cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patched

          replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
          replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
          replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
          replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
          replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
          replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
          echo "[INFO] Done."
        fi

      fi

      # Reconfigure server.xml for MySQL
      if [ "${MYSQL_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp $MYSQL_SERVER_PATCH ${DEPLOYMENT_DIR}/conf/server-mysql.xml.patch
        echo $MYSQL_SERVER_PATCH
        echo "[INFO] Applying on server.xml the patch $MYSQL_SERVER_PATCH ..."
        echo $MYSQL_SERVER_PATCH
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-mysql
        patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-mysql.xml.patch
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-mysql

        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        echo "[INFO] Done."
      fi
    ;;
    HSQLDB)
      echo "[INFO] Using default HSQLDB database. Nothing to do."
    ;;
    *)
      echo "[ERROR] Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Function that configure the server for ours needs
#
do_patch_server() {
  # Ensure the server.xml doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.orig
  tr -d '\015' < ${DEPLOYMENT_DIR}/conf/server.xml.orig > ${DEPLOYMENT_DIR}/conf/server.xml

  # Reconfigure the server to use JMX
  do_configure_server_for_jmx

  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    # Reconfigure the server to use a database
    do_configure_server_for_database
  fi

  # Reconfigure server.xml to change ports
  if [ "${PORTS_SERVER_PATCH}" != "UNSET" ]; then
    # Prepare the patch
    cp $PORTS_SERVER_PATCH ${DEPLOYMENT_DIR}/conf/server-ports.xml.patch
    echo "[INFO] Applying on server.xml the patch $PORTS_SERVER_PATCH ..."
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-ports
    patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-ports.xml.patch
    cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-ports

    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@SHUTDOWN_PORT@" "${DEPLOYMENT_SHUTDOWN_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@HTTP_PORT@" "${DEPLOYMENT_HTTP_PORT}"
    replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@AJP_PORT@" "${DEPLOYMENT_AJP_PORT}"
    echo "[INFO] Done."
  fi
}

do_configure_apache() {
  if ${DEPLOYMENT_SETUP_AWSTATS}; then
    echo "[INFO] Configure and update AWStats ..."
    mkdir -p $AWSTATS_CONF_DIR
    # Regenerates stats for this Vhosts
    evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.template $AWSTATS_CONF_DIR/awstats.${DEPLOYMENT_EXT_HOST}.conf
    sudo /usr/lib/cgi-bin/awstats.pl -config=${DEPLOYMENT_EXT_HOST} -update || true
    # Regenerates stats for root vhosts
    evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.template $AWSTATS_CONF_DIR/awstats.${ACCEPTANCE_HOST}.conf
    sudo /usr/lib/cgi-bin/awstats.pl -config=${ACCEPTANCE_HOST} -update
    echo "[INFO] Done."
  fi
  if ${DEPLOYMENT_SETUP_APACHE}; then
    echo "[INFO] Creating Apache Virtual Host ..."
    mkdir -p ${APACHE_CONF_DIR}
    evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
    DEPLOYMENT_LOG_URL=${DEPLOYMENT_URL}/logs/catalina.out
    echo "[INFO] Done."
    echo "[INFO] Rotate Apache logs ..."
    evaluate_file_content ${ETC_DIR}/logrotate.d/instance.template ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
    sudo logrotate -s ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}.status -f ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
    rm ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
    evaluate_file_content ${ETC_DIR}/logrotate.d/frontend.template ${TMP_DIR}/logrotate-acceptance
    sudo logrotate -s ${TMP_DIR}/logrotate-acceptance.status -f ${TMP_DIR}/logrotate-acceptance
    sudo /usr/sbin/service apache2 reload
    rm ${TMP_DIR}/logrotate-acceptance
    echo "[INFO] Done."
  fi
}

do_create_deployment_descriptor() {
  echo "[INFO] Creating deployment descriptor ..."
  mkdir -p ${ADT_CONF_DIR}
  evaluate_file_content ${ETC_DIR}/adt/config.template ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}

  # Additional settings
  for _var in ${DEPLOYMENT_EXTRA_ENV_VARS}
  do
    echo "${_var}=$(evalecho\${$_var})" >> ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  done
  echo "[INFO] Done."
  #Display the deployment descriptor
  echo "[INFO] ========================= Deployment Descriptor ========================="
  cat ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  echo "[INFO] ========================================================================="
}

do_load_deployment_descriptor() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo "[WARNING] ${PRODUCT_NAME}${PRODUCT_VERSION} isn't deployed !"
    echo "[WARNING] You need to deploy it first."
    exit 1
  else
    source ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  fi
}

#
# Function that deploys (Download+configure) the app server
#
do_deploy() {
  echo "[INFO] Deploying server ${PRODUCT_NAME}${PRODUCT_VERSION} ..."
  do_download_server
  if ${DEPLOYMENT_ENABLED}; then
    if ${DEPLOYMENT_DATABASE_ENABLED}; then
      do_create_database
    fi
    do_unpack_server
    do_patch_server
    if ${DEPLOYMENT_SETUP_APACHE}; then
      do_configure_apache
    fi
  fi
  do_create_deployment_descriptor
  echo "[INFO] Server deployed"
}

#
# Function that starts the app server
#
do_start() {
  # The server is supposed to be already deployed.
  # We load its settings from the configuration
  do_load_deployment_descriptor
  if ${DEPLOYMENT_ENABLED}; then
    echo "[INFO] Starting server ${PRODUCT_NAME}${PRODUCT_VERSION} ..."
    chmod 755 ${DEPLOYMENT_DIR}/bin/*.sh
    mkdir -p ${DEPLOYMENT_DIR}/logs
    export CATALINA_HOME=${DEPLOYMENT_DIR}
    export CATALINA_PID=${DEPLOYMENT_PID_FILE}
    export JAVA_JRMP_OPTS="-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.password.file=${DEPLOYMENT_DIR}/conf/jmxremote.password -Dcom.sun.management.jmxremote.access.file=${DEPLOYMENT_DIR}/conf/jmxremote.access"
    export JAVA_OPTS="$JAVA_JRMP_OPTS$DEPLOYMENT_EXTRA_JAVA_OPTS"
    if [ "${PRODUCT_NAME}" == "plf" ]; then
      case "${PRODUCT_BRANCH}" in
        "3.0.x" | "3.5.x")
          export EXO_PROFILES="${DEPLOYMENT_EXO_PROFILES}"
        ;;
        *)
        # 4.0.x and +
          export EXO_PROFILES="${EXO_PROFILES}"
        ;;
      esac
    else
      export EXO_PROFILES="${DEPLOYMENT_EXO_PROFILES}"
    fi
    ########################################
    # Externalized configuration for PLF 4
    ########################################
    export EXO_TOMCAT_SHUTDOWN_PORT="${DEPLOYMENT_SHUTDOWN_PORT}"
    export EXO_TOMCAT_RMI_REGISTRY_PORT="${DEPLOYMENT_RMI_REG_PORT}"
    export EXO_TOMCAT_RMI_SERVER_PORT="${DEPLOYMENT_RMI_SRV_PORT}"
    export EXO_HTTP_PORT="${DEPLOYMENT_HTTP_PORT}"
    export EXO_AJP_PORT="${DEPLOYMENT_AJP_PORT}"
    export EXO_DS_IDM_DRIVER="com.mysql.jdbc.Driver"
    export EXO_DS_IDM_USERNAME="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_IDM_PASSWORD="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_IDM_URL="jdbc:mysql://localhost:3306/${DEPLOYMENT_DATABASE_NAME}"
    export EXO_DS_PORTAL_DRIVER="com.mysql.jdbc.Driver"
    export EXO_DS_PORTAL_USERNAME="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_PORTAL_PASSWORD="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_PORTAL_URL="jdbc:mysql://localhost:3306/${DEPLOYMENT_DATABASE_NAME}"

    # Additional settings
    for _var in ${DEPLOYMENT_EXTRA_ENV_VARS}
    do
      export ${_var} = $(eval echo \${$_var})
    done
    cd `dirname ${CATALINA_HOME}/${DEPLOYMENT_SERVER_SCRIPT}`

    # We need to backup existing logs if they already exist
    backup_logs "$CATALINA_HOME/logs/" "catalina.out"

    # Startup the server
    ${CATALINA_HOME}/${DEPLOYMENT_SERVER_SCRIPT} start

    # Wait for logs availability
    while [ true ];
    do
      if [ -e "${DEPLOYMENT_DIR}/logs/catalina.out" ]; then
        break
      fi
    done
    # Display logs
    tail -f ${DEPLOYMENT_DIR}/logs/catalina.out &
    local tailPID=$!
    # Check for the end of startup
    set +e
    while [ true ];
    do
      if grep -q "Server startup in" ${DEPLOYMENT_DIR}/logs/catalina.out; then
        kill $tailPID
        wait $tailPID 2 > /dev/null
        break
      fi
    done
    set -e
    cd -
    echo "[INFO] Server started"
    echo "[INFO] URL  : ${DEPLOYMENT_URL}"
    echo "[INFO] Logs : ${DEPLOYMENT_LOG_URL}"
    echo "[INFO] JMX  : ${DEPLOYMENT_JMX_URL}"
  else
    echo "[WARNING] This product (${PRODUCT_NAME}:${PRODUCT_VERSION}) cannot be started"
  fi
}

#
# Function that stops the app server
#
do_stop() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo "[WARNING] ${PRODUCT_NAME}${PRODUCT_VERSION} isn't deployed !"
    echo "[WARNING] The product cannot be stopped"
    exit 0
  else
    # The server is supposed to be already deployed.
    # We load its settings from the configuration
    do_load_deployment_descriptor
    if ${DEPLOYMENT_ENABLED}; then
      if [ -n "${DEPLOYMENT_DIR}" ] && [ -e "${DEPLOYMENT_DIR}" ]; then
        echo "[INFO] Stopping server ${PRODUCT_NAME}${PRODUCT_VERSION} ..."
        export CATALINA_HOME=${DEPLOYMENT_DIR}
        export CATALINA_PID=${DEPLOYMENT_PID_FILE}
        ########################################
        # Externalized configuration for PLF 4
        ########################################
        export EXO_TOMCAT_SHUTDOWN_PORT="${DEPLOYMENT_SHUTDOWN_PORT}"

        # Additional settings
        for _var in ${DEPLOYMENT_EXTRA_ENV_VARS}
        do
          export ${_var} = $(eval echo \${$_var})
        done
        ${CATALINA_HOME}/${DEPLOYMENT_SERVER_SCRIPT} stop 60 -force || true
        echo "[INFO] Server stopped"
      else
        echo "[WARNING] No server directory to stop it"
      fi
    else
      echo "[WARNING] This product (${PRODUCT_NAME}:${PRODUCT_VERSION}) cannot be stopped"
    fi
  fi
}

#
# Function that undeploys (delete) the app server
#
do_undeploy() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo "[WARNING] ${PRODUCT_NAME}${PRODUCT_VERSION} isn't deployed !"
    echo "[WARNING] The product cannot be undeployed"
    exit 0
  else
    # The server is supposed to be already deployed.
    # We load its settings from the configuration
    do_load_deployment_descriptor
    if ${DEPLOYMENT_ENABLED}; then
      # Stop the server
      do_stop
      if ${DEPLOYMENT_DATABASE_ENABLED}; then
        do_drop_database
      fi
      echo "[INFO] Undeploying server ${PRODUCT_NAME}${PRODUCT_VERSION} ..."
      if ${DEPLOYMENT_SETUP_AWSTATS}; then
        # Delete Awstat config
        rm -f $AWSTATS_CONF_DIR/awstats.${DEPLOYMENT_EXT_HOST}.conf
      fi
      if ${DEPLOYMENT_SETUP_APACHE}; then
        # Delete the vhost
        rm -f ${APACHE_CONF_DIR}/${DEPLOYMENT_EXT_HOST}
        # Reload Apache to deactivate the config
        sudo /usr/sbin/service apache2 reload
      fi
      # Delete the server
      rm -rf ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
      # Close firewall ports
      if ${DEPLOYMENT_SETUP_UFW}; then
        # Prod vs Dev (To be improved)
        sudo /usr/sbin/ufw deny ${DEPLOYMENT_RMI_REG_PORT}
        sudo /usr/sbin/ufw deny ${DEPLOYMENT_RMI_SRV_PORT}
      fi
      echo "[INFO] Server undeployed"
    fi
    # Delete the deployment descriptor
    rm ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  fi
}

#
# Function that lists all deployed servers
#
do_list() {
  if [ "$(ls-A${ADT_CONF_DIR})" ]; then
    echo "[INFO] Deployed servers : "
    printf "%-10s %-20s %-10s %-10s %-10s %-10s %-10s %-10s\n" "Product" "Version" "HTTP_P" "AJP_P" "SHUTDOWN_P" "JMX_REG_P" "JMX_SRV_P" "RUNNING"
    printf "%-10s %-20s %-10s %-10s %-10s %-10s %-10s %-10s\n" "==========" "====================" "==========" "==========" "==========" "==========" "==========" "=========="
    for f in ${ADT_CONF_DIR}/*
    do
      source $f
      if [ -f ${DEPLOYMENT_PID_FILE} ]; then
        set +e
        kill -0 `cat ${DEPLOYMENT_PID_FILE}`
        if [ $? -eq 0 ]; then
          STATUS="true"
        else
          STATUS="false"
        fi
        set -e
      else
        STATUS="false"
      fi
      printf "%-10s %-20s %-10s %-10s %-10s %-10s %-10s %-10s\n" ${PRODUCT_NAME} ${PRODUCT_VERSION} ${DEPLOYMENT_HTTP_PORT} ${DEPLOYMENT_AJP_PORT} ${DEPLOYMENT_SHUTDOWN_PORT} ${DEPLOYMENT_RMI_REG_PORT} ${DEPLOYMENT_RMI_SRV_PORT} $STATUS
    done
  else
    echo "[INFO] No server deployed."
  fi
}

#
# Function that starts all deployed servers
#
do_start_all() {
  if [ "$(ls-A${ADT_CONF_DIR})" ]; then
    echo "[INFO] Starting all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      source $f
      do_start
    done
    echo "[INFO] All servers started"
  else
    echo "[INFO] No server deployed."
  fi
}

#
# Function that restarts all deployed servers
#
do_restart_all() {
  if [ "$(ls-A${ADT_CONF_DIR})" ]; then
    echo "[INFO] Restarting all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      source $f
      do_stop
      do_start
    done
    echo "[INFO] All servers restarted"
  else
    echo "[INFO] No server deployed."
  fi
}

#
# Function that stops all deployed servers
#
do_stop_all() {
  if [ "$(ls-A${ADT_CONF_DIR})" ]; then
    echo "[INFO] Stopping all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      source $f
      do_stop
    done
    echo "[INFO] All servers stopped"
  else
    echo "[INFO] No server deployed."
  fi
}

#
# Function that undeploys all deployed servers
#
do_undeploy_all() {
  if [ "$(ls-A${ADT_CONF_DIR})" ]; then
    echo "[INFO] Undeploying all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      source $f
      do_undeploy
    done
    echo "[INFO] All servers undeployed"
  else
    echo "[INFO] No server deployed."
  fi
}

# no action ? provide help
if [ $# -lt 1 ]; then
  echo ""
  echo "[ERROR] No action defined !"
  print_usage
  exit 1;
fi

# If help is asked
if [ $1 == "-h" ]; then
  print_usage
  exit
fi

# Action to do
ACTION=$1
shift

init

case "${ACTION}" in
  init)
  # Nothing specific to do
  ;;
  deploy)
    initialize_product_settings
    do_deploy
  ;;
  start)
    initialize_product_settings
    do_start
  ;;
  stop)
    initialize_product_settings
    do_stop
  ;;
  restart)
    initialize_product_settings
    do_stop
    do_start
  ;;
  undeploy)
    initialize_product_settings
    do_undeploy
  ;;
  list)
    do_list
  ;;
  start-all)
    do_start_all
  ;;
  stop-all)
    do_stop_all
  ;;
  restart-all)
    do_restart_all
  ;;
  undeploy-all)
    do_undeploy_all
  ;;
  *)
    echo "[ERROR] Invalid action \"${ACTION}\""
    print_usage
    exit 1
  ;;
esac

exit 0
