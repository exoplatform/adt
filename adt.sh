#!/bin/bash -eu

# #############################################################################
# Initialize
# #############################################################################                                              
SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
configurable_env_var "DEPLOYMENT_PORT_PREFIX" "800"
configurable_env_var "DEPLOYMENT_SHUTDOWN_PORT" "${DEPLOYMENT_PORT_PREFIX}0"
configurable_env_var "DEPLOYMENT_HTTP_PORT" "${DEPLOYMENT_PORT_PREFIX}1"
configurable_env_var "DEPLOYMENT_AJP_PORT" "${DEPLOYMENT_PORT_PREFIX}2"
configurable_env_var "DEPLOYMENT_RMI_REG_PORT" "${DEPLOYMENT_PORT_PREFIX}3"
configurable_env_var "DEPLOYMENT_RMI_SRV_PORT" "${DEPLOYMENT_PORT_PREFIX}4"
configurable_env_var "DEPLOYMENT_JOD_CONVERTER_PORTS" "${DEPLOYMENT_PORT_PREFIX}5,${DEPLOYMENT_PORT_PREFIX}6,${DEPLOYMENT_PORT_PREFIX}7,${DEPLOYMENT_PORT_PREFIX}8,${DEPLOYMENT_PORT_PREFIX}9"
configurable_env_var "DEPLOYMENT_LDAP_URL" ""
configurable_env_var "DEPLOYMENT_LDAP_ADMIN_DN" ""
configurable_env_var "DEPLOYMENT_LDAP_ADMIN_PWD" ""
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
env_var "DS_DIR" "${ADT_DATA}/datasets"
env_var "SRV_DIR" "${ADT_DATA}/servers"
env_var "SRC_DIR" "${ADT_DATA}/sources"
env_var "CONF_DIR" "${ADT_DATA}/conf"
env_var "APACHE_CONF_DIR" "${ADT_DATA}/conf/apache"
env_var "AWSTATS_CONF_DIR" "${ADT_DATA}/conf/awstats"
env_var "ADT_CONF_DIR" "${ADT_DATA}/conf/adt"
env_var "FEATURES_CONF_DIR" "${ADT_DATA}/conf/features"
env_var "ETC_DIR" "${ADT_DATA}/etc"

env_var "CURR_DATE" `date "+%Y%m%d.%H%M%S"`
env_var "REPOS_LIST" "exodev:commons exodev:calendar exodev:forum exodev:wiki exodev:social exodev:ecms exodev:integration exodev:platform exoplatform:platform-tomcat-standalone exoplatform:platform-public-distributions"
configurable_env_var "GIT_REPOS_UPDATED" false

#
# Usage message
#
print_usage() {
  cat << EOF

  usage: $0 <action>

This script manages automated deployment of eXo products for testing purpose.

Action :
  deploy           Deploys (Download+Configure) the server
  download-dataset Downloads the dataset required by the server
  start            Starts the server
  stop             Stops the server
  restart          Restarts the server
  clean-restart    Restarts the server after having deleted all existing data
  undeploy         Undeploys (deletes) the server

  start-all        Starts all deployed servers
  stop-all         Stops all deployed servers
  restart-all      Restarts all deployed servers
  undeploy-all     Undeploys (deletes) all deployed servers
  list             Lists all deployed servers

  init             Initializes the environment
  update-repos     Update Git repositories used by the web front-end
  web-server       Starts a local PHP web server to test the front-end (requires PHP >= 5.4)

Environment Variables :

  They may be configured in the current shell environment or /etc/default/adt or \$HOME/.adtrc
  
  PRODUCT_NAME                   : The product you want to manage. Possible values are :
    gatein         GateIn Community edition
    exogtn         GateIn eXo edition
    plf            eXo Platform Standard Edition
    plfcom         eXo Platform Community Edition
    plfent         eXo Platform Express/Enterprise Edition
    plftrial       eXo Platform Trial Edition
    compint        eXo Company Intranet
    docs           eXo Platform Documentations Website
  PRODUCT_VERSION                : The version of the product. Can be either a release, a snapshot (the latest one) or a timestamped snapshot

  ADT_DATA                       : The path where data have to be stored (default: under the script path - ${SCRIPT_DIR})
  DEPLOYMENT_SETUP_APACHE        : Do you want to setup the apache configuration (default: false)
  DEPLOYMENT_SETUP_AWSTATS       : Do you want to setup the awstats configuration (default: false)
  DEPLOYMENT_SETUP_UFW           : Do you want to setup the ufw firewall configuration (default: false)
  DEPLOYMENT_PORT_PREFIX         : Default prefix for all ports
  DEPLOYMENT_AJP_PORT            : AJP Port (default: \${DEPLOYMENT_PORT_PREFIX}2)
  DEPLOYMENT_HTTP_PORT           : HTTP Port (default: \${DEPLOYMENT_PORT_PREFIX}1)
  DEPLOYMENT_SHUTDOWN_PORT       : SHUTDOWN Port (default: \${DEPLOYMENT_PORT_PREFIX}0)
  DEPLOYMENT_RMI_REG_PORT        : RMI Registry Port for JMX (default: \${DEPLOYMENT_PORT_PREFIX}3)
  DEPLOYMENT_RMI_SRV_PORT        : RMI Server Port for JMX (default: \${DEPLOYMENT_PORT_PREFIX}4)
  DEPLOYMENT_JOD_CONVERTER_PORTS : JOD Converter ports used to launch OpenOffice instances (default : \${DEPLOYMENT_PORT_PREFIX}5,\${DEPLOYMENT_PORT_PREFIX}6,\${DEPLOYMENT_PORT_PREFIX}7,\${DEPLOYMENT_PORT_PREFIX}8,\${DEPLOYMENT_PORT_PREFIX}9)

  DEPLOYMENT_DATABASE_TYPE       : Which database do you want to use for your deployment ? (default: HSQLDB, values : HSQLDB | MYSQL)
  KEEP_DB                        : Keep the current database content for MYSQL. By default the deployment process drops the database if it already exists. (default: false)

  ACCEPTANCE_HOST                : The hostname (vhost) where is deployed the acceptance server (default: acceptance.exoplatform.org)
  CROWD_ACCEPTANCE_APP_NAME      : The crowd application used to authenticate the front-end (default: none)
  CROWD_ACCEPTANCE_APP_PASSWORD  : The crowd application''s password used to authenticate the front-end (default: none)

  DEPLOYMENT_LDAP_URL            : LDAP URL to use if the server is using one (default: none)
  DEPLOYMENT_LDAP_ADMIN_DN       : LDAP DN to use to logon into the LDAP server
  DEPLOYMENT_LDAP_ADMIN_PWD      : LDAP password to use to logon into the LDAP server

  REPOSITORY_SERVER_BASE_URL     : The Maven repository URL used to download artifacts (default: https://repository.exoplatform.org)
  REPOSITORY_USERNAME            : The username to logon on \$REPOSITORY_SERVER_BASE_URL if necessary (default: none)
  REPOSITORY_PASSWORD            : The password to logon on \$REPOSITORY_SERVER_BASE_URL if necessary (default: none)

  ADT_DEBUG                      : Display debug details (default: false)
EOF

}


# Clone or update a repository $1 from Github's ${GITHUB_ORGA} organisation into ${SRC_DIR}
updateRepo() {
  local _orga=$(echo $1 | cut -d: -f1)
  local _repo=$(echo $1 | cut -d: -f2)
  if [ ! -d ${SRC_DIR}/${_repo}.git ]; then
    echo "[INFO] Cloning repository ${_repo} into ${SRC_DIR} ..."
    git clone git://github.com/${_orga}/${_repo}.git ${SRC_DIR}/${_repo}.git
    echo "[INFO] Clone done ..."
  else
    echo "[INFO] Updating repository ${_repo} in ${SRC_DIR} ..."
    cd ${SRC_DIR}/${_repo}.git
    git fetch --prune
    git clean -f -d -x
    cd -
    echo "[INFO] Update done ..."
  fi
}

# Update all git repositories used by PHP frontend
updateRepos() {
  if ! ${GIT_REPOS_UPDATED}; then
    # Initialize sources repositories used by PHP
    for _repo in $REPOS_LIST
    do
      updateRepo ${_repo}
    done
    env_var "GIT_REPOS_UPDATED" true
  fi
}

init() {
  loadSystemInfo
  validate_env_var "SCRIPT_DIR"
  validate_env_var "ADT_DATA"
  validate_env_var "ETC_DIR"
  validate_env_var "TMP_DIR"
  validate_env_var "DL_DIR"
  validate_env_var "DS_DIR"
  validate_env_var "SRV_DIR"
  validate_env_var "CONF_DIR"
  validate_env_var "APACHE_CONF_DIR"
  validate_env_var "ADT_CONF_DIR"
  validate_env_var "FEATURES_CONF_DIR"
  mkdir -p ${ETC_DIR}
  mkdir -p ${TMP_DIR}
  mkdir -p ${DL_DIR}
  mkdir -p ${DS_DIR}
  mkdir -p ${SRV_DIR}
  mkdir -p ${SRC_DIR}
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
    deploy | download-dataset)
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
      env_var "EXO_PROFILES" "-Dexo.profiles=all"
      env_var "DEPLOYMENT_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_NAME" ""
      env_var "DEPLOYMENT_DATABASE_USER" ""
      env_var "DEPLOYMENT_EXTRA_ENV_VARS" ""
      env_var "DEPLOYMENT_EXTRA_JAVA_OPTS" ""
      env_var "DEPLOYMENT_GATEIN_CONF_PATH" "gatein/conf/configuration.properties"
      env_var "DEPLOYMENT_SERVER_SCRIPT" "bin/gatein.sh"
      env_var "DEPLOYMENT_SERVER_LOGS_FILE" "catalina.out"
      env_var "DEPLOYMENT_APPSRV_TYPE" "tomcat" #Server type
      env_var "DEPLOYMENT_APPSRV_VERSION" "6.0.35" #Default version used to download additional resources like JMX lib
      env_var "DEPLOYMENT_MYSQL_DRIVER_VERSION" "5.1.23" #Default version used to download additional mysql driver

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

      # Datasets remote location
      env_var "DATASET_DATA_VALUES_ARCHIVE"    ""
      env_var "DATASET_DATA_INDEX_ARCHIVE"     ""
      env_var "DATASET_DB_ARCHIVE"             ""

      # To reuse patches between products
      env_var "PORTS_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "JMX_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "DB_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "DB_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "EMAIL_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "JOD_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "LDAP_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"

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
            "3.6.x")
              env_var PLF_BRANCH "4.1.x"
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
              env_var EXO_PROFILES "all"
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
          env_var DB_SERVER_PATCH_PRODUCT_NAME "plf"
          env_var DB_GATEIN_PATCH_PRODUCT_NAME "plf"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        plfcom)
          env_var PRODUCT_DESCRIPTION "eXo Platform Community Edition"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          case "${PRODUCT_BRANCH}" in
            "3.5.x")
              env_var ARTIFACT_GROUPID "org.exoplatform.platform"
              env_var ARTIFACT_ARTIFACTID "exo.platform.packaging.community"
              env_var PORTS_SERVER_PATCH_PRODUCT_NAME "plf"
              env_var JMX_SERVER_PATCH_PRODUCT_NAME "plf"
              env_var DB_SERVER_PATCH_PRODUCT_NAME "plf"
              env_var DB_GATEIN_PATCH_PRODUCT_NAME "plf"
            ;;
            *)
            # 4.0.x and +
              env_var ARTIFACT_GROUPID "org.exoplatform.platform.distributions"
              env_var ARTIFACT_ARTIFACTID "plf-community-tomcat-standalone"
              env_var DEPLOYMENT_APPSRV_VERSION "7.0.37"
              env_var PLF_BRANCH "${PRODUCT_BRANCH}"
              env_var EXO_PROFILES "all"
            ;;
          esac
        ;;
        plfent)
          env_var PRODUCT_DESCRIPTION "eXo Platform Express/Enterprise Edition"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_APPSRV_VERSION "7.0.37"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          env_var EXO_PROFILES "all"
        ;;
        compint)
          env_var PRODUCT_DESCRIPTION "eXo Company Intranet"
          env_var ARTIFACT_REPO_GROUP "cp"
          env_var ARTIFACT_GROUPID "com.exoplatform.intranet"
          env_var ARTIFACT_ARTIFACTID "exo-intranet-package"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var EXO_PROFILES "default"
          # Datasets remote location
          env_var "DATASET_DATA_VALUES_ARCHIVE"    "bckintranet@storage.exoplatform.org:/home/bckintranet/intranet-data-values-latest.tar.bz2"
          env_var "DATASET_DATA_INDEX_ARCHIVE"     "bckintranet@storage.exoplatform.org:/home/bckintranet/intranet-data-index-latest.tar.bz2"
          env_var "DATASET_DB_ARCHIVE"             "bckintranet@storage.exoplatform.org:/home/bckintranet/intranet-db-latest.tar.bz2"
        ;;
        docs)
          env_var ARTIFACT_REPO_GROUP "private"
          env_var PRODUCT_DESCRIPTION "eXo Platform Documentations Website"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.documentation"
          env_var ARTIFACT_ARTIFACTID "platform-documentation-website-packaging"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_DATABASE_ENABLED false
          case "${PRODUCT_BRANCH}" in
            "4.0.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
            *)
              env_var PLF_BRANCH "3.5.x"
            ;;
          esac
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
      find_patch DB_SERVER_PATCH "${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}${DEPLOYMENT_APPSRV_VERSION:0:1}" "server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml" "${DB_SERVER_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
      find_patch DB_GATEIN_PATCH "${ETC_DIR}/gatein" "db-configuration.properties" "${DB_GATEIN_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for email
      find_patch EMAIL_GATEIN_PATCH "${ETC_DIR}/gatein" "email-configuration.properties" "${EMAIL_GATEIN_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for email
      find_patch JOD_GATEIN_PATCH "${ETC_DIR}/gatein" "jod-configuration.properties" "${JOD_GATEIN_PATCH_PRODUCT_NAME}"
      # Patch to reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for ldap
      find_patch LDAP_GATEIN_PATCH "${ETC_DIR}/gatein" "ldap-configuration.properties" "${LDAP_GATEIN_PATCH_PRODUCT_NAME}"
    ;;
    start | stop | restart | clean-restart | undeploy )
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

do_download_dataset() {
  validate_env_var "DS_DIR"
  validate_env_var "PRODUCT_NAME"
  validate_env_var "PRODUCT_BRANCH"
  validate_env_var "PRODUCT_DESCRIPTION"
  echo "[INFO] Updating local dataset for ${PRODUCT_DESCRIPTION} ${PRODUCT_BRANCH} from the storage server ..."
  if [ ! -z "${DATASET_DATA_VALUES_ARCHIVE}" ] && [ ! -z "${DATASET_DATA_INDEX_ARCHIVE}" ] && [ ! -z "${DATASET_DB_ARCHIVE}" ]; then
    mkdir -p ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}
    display_time rsync -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DB_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2
    display_time rsync -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DATA_INDEX_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/index.tar.bz2
    display_time rsync -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DATA_VALUES_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/values.tar.bz2
  else
    echo "[ERROR] Datasets not configured"
    exit 1;
  fi
  echo "[INFO] Done"
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
  rm -rf ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  # We search the tomcat directory as the parent of a gatein directory
  pushd `find ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION} -maxdepth 4 -mindepth 1 -name webapps -type d`/.. > /dev/null
  DEPLOYMENT_DIR=`pwd -P`
  popd > /dev/null
  DEPLOYMENT_LOG_PATH=${DEPLOYMENT_DIR}/logs/${DEPLOYMENT_SERVER_LOGS_FILE}
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
  if [ ! -f ${DEPLOYMENT_DIR}/lib/catalina-jmx-remote.jar -a ! -f ${DEPLOYMENT_DIR}/lib/tomcat-catalina-jmx-remote-*.jar ]; then
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
  cp -f ${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}/jmxremote.access ${DEPLOYMENT_DIR}/conf/jmxremote.access
  cp -f ${ETC_DIR}/${DEPLOYMENT_APPSRV_TYPE}/jmxremote.password ${DEPLOYMENT_DIR}/conf/jmxremote.password
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

do_configure_email() {
  if [ -e ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ]; then
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig > ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH

    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
    if [ "${EMAIL_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp $EMAIL_GATEIN_PATCH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
      echo "[INFO] Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $EMAIL_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.ori.email
      patch -l -p0 ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
      cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patched.email

      replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DEPLOYMENT_URL@" "${DEPLOYMENT_URL}"
      echo "[INFO] Done."
    fi

  fi
}

do_configure_jod() {
  if [ -e ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ]; then
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig > ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH

    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for JOD Converter
    if [ "${JOD_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp $JOD_GATEIN_PATCH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
      echo "[INFO] Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $JOD_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.ori.jod
      patch -l -p0 ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
      cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patched.jod

      replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DEPLOYMENT_JOD_CONVERTER_PORTS@" "${DEPLOYMENT_JOD_CONVERTER_PORTS}"
      echo "[INFO] Done."
    fi

  fi
}

do_configure_ldap() {
  if [ -e ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ]; then
    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

    # Ensure the configuration.properties doesn't have some windows end line characters
    # '\015' is Ctrl+V Ctrl+M = ^M
    cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig
    tr -d '\015' < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig > ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH

    # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for LDAP
    if [ "${LDAP_GATEIN_PATCH}" != "UNSET" ]; then
      # Prepare the patch
      cp $LDAP_GATEIN_PATCH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
      echo "[INFO] Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $LDAP_GATEIN_PATCH ..."
      cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.ori.ldap
      patch -l -p0 ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
      cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patched.ldap

      replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DEPLOYMENT_LDAP_URL@" "${DEPLOYMENT_LDAP_URL}"
      replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DEPLOYMENT_LDAP_ADMIN_DN@" "${DEPLOYMENT_LDAP_ADMIN_DN}"
      replace_in_file ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH "@DEPLOYMENT_LDAP_ADMIN_PWD@" "${DEPLOYMENT_LDAP_ADMIN_PWD}"
      echo "[INFO] Done."
    fi

  fi
}

do_configure_server_for_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      if [ ! -f ${DEPLOYMENT_DIR}/lib/mysql-connector-*.jar ]; then
        MYSQL_JAR_URL="http://repository.exoplatform.org/public/mysql/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/mysql-connector-java-${DEPLOYMENT_MYSQL_DRIVER_VERSION}.jar"
        echo "[INFO] Download and install MySQL JDBC driver from ${MYSQL_JAR_URL} ..."
        curl ${MYSQL_JAR_URL} > ${DEPLOYMENT_DIR}/lib/`basename $MYSQL_JAR_URL`
        if [ ! -e "${DEPLOYMENT_DIR}/lib/"`basename $MYSQL_JAR_URL` ]; then
          echo "[ERROR] !!! Sorry, cannot download ${MYSQL_JAR_URL}"
          exit 1
        fi
        echo "[INFO] Done."
      fi
      if [ -e ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ]; then
        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH

        # Ensure the configuration.properties doesn't have some windows end line characters
        # '\015' is Ctrl+V Ctrl+M = ^M
        cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig
        tr -d '\015' < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.orig > ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH

        # Reconfigure $DEPLOYMENT_GATEIN_CONF_PATH for MySQL
        if [ "${DB_GATEIN_PATCH}" != "UNSET" ]; then
          # Prepare the patch
          cp $DB_GATEIN_PATCH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
          echo "[INFO] Applying on $DEPLOYMENT_GATEIN_CONF_PATH the patch $DB_GATEIN_PATCH ..."
          cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.ori.db
          patch -l -p0 ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH < ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patch
          cp ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH ${DEPLOYMENT_DIR}/$DEPLOYMENT_GATEIN_CONF_PATH.patched.db

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
      if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp $DB_SERVER_PATCH ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        echo $DB_SERVER_PATCH
        echo "[INFO] Applying on server.xml the patch $DB_SERVER_PATCH ..."
        echo $DB_SERVER_PATCH
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
        patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")

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
      # Reconfigure server.xml for MySQL
      if [ "${DB_SERVER_PATCH}" != "UNSET" ]; then
        # Prepare the patch
        cp $DB_SERVER_PATCH ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        echo $DB_SERVER_PATCH
        echo "[INFO] Applying on server.xml the patch $DB_SERVER_PATCH ..."
        echo $DB_SERVER_PATCH
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.ori-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")
        patch -l -p0 ${DEPLOYMENT_DIR}/conf/server.xml < ${DEPLOYMENT_DIR}/conf/server-$(tolower "${DEPLOYMENT_DATABASE_TYPE}").xml.patch
        cp ${DEPLOYMENT_DIR}/conf/server.xml ${DEPLOYMENT_DIR}/conf/server.xml.patched-$(tolower "${DEPLOYMENT_DATABASE_TYPE}")

        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
        replace_in_file ${DEPLOYMENT_DIR}/conf/server.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
        echo "[INFO] Done."
      fi
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

  do_configure_email
  do_configure_jod
  do_configure_ldap

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
    export DOMAIN=${DEPLOYMENT_EXT_HOST}
    evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.template $AWSTATS_CONF_DIR/awstats.${DEPLOYMENT_EXT_HOST}.conf
    sudo /usr/lib/cgi-bin/awstats.pl -config=${DEPLOYMENT_EXT_HOST} -update || true
    # Regenerates stats for root vhosts
    export DOMAIN=${ACCEPTANCE_HOST}
    evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.template $AWSTATS_CONF_DIR/awstats.${ACCEPTANCE_HOST}.conf
    sudo /usr/lib/cgi-bin/awstats.pl -config=${ACCEPTANCE_HOST} -update
    unset DOMAIN
    echo "[INFO] Done."
  fi
  if ${DEPLOYMENT_SETUP_APACHE}; then
    echo "[INFO] Creating Apache Virtual Host ..."
    mkdir -p ${APACHE_CONF_DIR}
    evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
    DEPLOYMENT_LOG_URL=${DEPLOYMENT_URL}/logs/${DEPLOYMENT_SERVER_LOGS_FILE}
    echo "[INFO] Done."
    echo "[INFO] Rotate Apache logs ..."
    evaluate_file_content ${ETC_DIR}/logrotate.d/instance.template ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
    sudo logrotate -s ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}.status -f ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
    rm ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
    evaluate_file_content ${ETC_DIR}/logrotate.d/frontend.template ${TMP_DIR}/logrotate-acceptance
    sudo logrotate -s ${TMP_DIR}/logrotate-acceptance.status -f ${TMP_DIR}/logrotate-acceptance
    if [ "${DIST}" == "Ubuntu" ]; then
      sudo /usr/sbin/service apache2 reload
    fi
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
    echo "${_var}=$(eval echo\${$_var})" >> ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  done
  echo "[INFO] Done."
  #Display the deployment descriptor
  echo "[INFO] ========================= Deployment Descriptor ========================="
  cat ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  echo "[INFO] ========================================================================="
}

do_load_deployment_descriptor() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo "[WARNING] ${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
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
  echo "[INFO] Deploying server ${PRODUCT_NAME} ${PRODUCT_VERSION} ..."
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
    echo "[INFO] Starting server ${PRODUCT_NAME} ${PRODUCT_VERSION} ..."
    chmod 755 ${DEPLOYMENT_DIR}/bin/*.sh
    mkdir -p ${DEPLOYMENT_DIR}/logs
    export CATALINA_HOME=${DEPLOYMENT_DIR}
    export CATALINA_PID=${DEPLOYMENT_PID_FILE}
    export JAVA_JRMP_OPTS="-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.password.file=${DEPLOYMENT_DIR}/conf/jmxremote.password -Dcom.sun.management.jmxremote.access.file=${DEPLOYMENT_DIR}/conf/jmxremote.access"
    export JAVA_OPTS="$DEPLOYMENT_EXTRA_JAVA_OPTS"
    export CATALINA_OPTS="$JAVA_JRMP_OPTS"
    export EXO_PROFILES="${EXO_PROFILES}"
    export EXO_LOGS_DISPLAY_CONSOLE=true
    export EXO_LOGS_CONSOLE_COLORIZED=true
    ########################################
    # Externalized configuration for PLF 4
    ########################################
    export EXO_TOMCAT_SHUTDOWN_PORT=${DEPLOYMENT_SHUTDOWN_PORT}
    export EXO_TOMCAT_RMI_REGISTRY_PORT=${DEPLOYMENT_RMI_REG_PORT}
    export EXO_TOMCAT_RMI_SERVER_PORT=${DEPLOYMENT_RMI_SRV_PORT}
    export EXO_HTTP_PORT=${DEPLOYMENT_HTTP_PORT}
    export EXO_AJP_PORT=${DEPLOYMENT_AJP_PORT}
    export EXO_DS_IDM_DRIVER="com.mysql.jdbc.Driver"
    export EXO_DS_IDM_USERNAME="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_IDM_PASSWORD="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_IDM_URL="jdbc:mysql://localhost:3306/${DEPLOYMENT_DATABASE_NAME}?autoReconnect=true"
    export EXO_DS_PORTAL_DRIVER="com.mysql.jdbc.Driver"
    export EXO_DS_PORTAL_USERNAME="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_PORTAL_PASSWORD="${DEPLOYMENT_DATABASE_USER}"
    export EXO_DS_PORTAL_URL="jdbc:mysql://localhost:3306/${DEPLOYMENT_DATABASE_NAME}?autoReconnect=true"
    export EXO_DEV=true

    # Additional settings
    for _var in ${DEPLOYMENT_EXTRA_ENV_VARS}
    do
      export ${_var} = $(eval echo \${$_var})
    done

    #Display the deployment descriptor
    echo "[INFO] ========================= Deployment Descriptor ========================="
    cat ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
    echo "[INFO] ================== Externalized configuration for PLF 4 ================="
    echo EXO_TOMCAT_SHUTDOWN_PORT=${EXO_TOMCAT_SHUTDOWN_PORT}
    echo EXO_TOMCAT_RMI_REGISTRY_PORT=${EXO_TOMCAT_RMI_REGISTRY_PORT}
    echo EXO_TOMCAT_RMI_SERVER_PORT=${EXO_TOMCAT_RMI_SERVER_PORT}
    echo EXO_HTTP_PORT=${EXO_HTTP_PORT}
    echo EXO_AJP_PORT=${EXO_AJP_PORT}
    echo EXO_DS_IDM_DRIVER=${EXO_DS_IDM_DRIVER}
    echo EXO_DS_IDM_USERNAME=${EXO_DS_IDM_USERNAME}
    echo EXO_DS_IDM_PASSWORD=${EXO_DS_IDM_PASSWORD}
    echo EXO_DS_IDM_URL=${EXO_DS_IDM_URL}
    echo EXO_DS_PORTAL_DRIVER=${EXO_DS_PORTAL_DRIVER}
    echo EXO_DS_PORTAL_USERNAME=${EXO_DS_PORTAL_USERNAME}
    echo EXO_DS_PORTAL_PASSWORD=${EXO_DS_PORTAL_PASSWORD}
    echo EXO_DS_PORTAL_URL=${EXO_DS_PORTAL_URL}		
    echo "[INFO] ========================================================================="

    cd `dirname ${CATALINA_HOME}/${DEPLOYMENT_SERVER_SCRIPT}`

    # We need to backup existing logs if they already exist
    backup_logs "$CATALINA_HOME/logs/" "${DEPLOYMENT_SERVER_LOGS_FILE}"

    # Startup the server
    ${CATALINA_HOME}/${DEPLOYMENT_SERVER_SCRIPT} start

    # Wait for logs availability
    while [ true ];
    do
      if [ -e "${DEPLOYMENT_DIR}/logs/${DEPLOYMENT_SERVER_LOGS_FILE}" ]; then
        break
      fi
    done
    # Display logs
    tail -f ${DEPLOYMENT_DIR}/logs/${DEPLOYMENT_SERVER_LOGS_FILE} &
    local _tailPID=$!
    # Check for the end of startup
    set +e
    while [ true ];
    do
      if grep -q "Server startup in" ${DEPLOYMENT_DIR}/logs/${DEPLOYMENT_SERVER_LOGS_FILE}; then
        kill ${_tailPID}
        wait ${_tailPID} 2> /dev/null
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
    echo "[WARNING] ${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
    echo "[WARNING] The product cannot be stopped"
    exit 0
  else
    # The server is supposed to be already deployed.
    # We load its settings from the configuration
    do_load_deployment_descriptor
    if ${DEPLOYMENT_ENABLED}; then
      if [ -n "${DEPLOYMENT_DIR}" ] && [ -e "${DEPLOYMENT_DIR}" ]; then
        echo "[INFO] Stopping server ${PRODUCT_NAME} ${PRODUCT_VERSION} ..."
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
    echo "[WARNING] ${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
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
      echo "[INFO] Undeploying server ${PRODUCT_NAME} ${PRODUCT_VERSION} ..."
      if ${DEPLOYMENT_SETUP_AWSTATS}; then
        # Delete Awstat config
        rm -f $AWSTATS_CONF_DIR/awstats.${DEPLOYMENT_EXT_HOST}.conf
      fi
      if ${DEPLOYMENT_SETUP_APACHE}; then
        # Delete the vhost
        rm -f ${APACHE_CONF_DIR}/${DEPLOYMENT_EXT_HOST}
        # Reload Apache to deactivate the config
        if [ "${DIST}" == "Ubuntu" ]; then
          sudo /usr/sbin/service apache2 reload
        fi
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
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
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

#
# Function that loads a php server to test Acceptance FrontEnd
# requires PHP >= 5.4
#
do_load_php_server() {
  updateRepos
  export ADT_DATA=${ADT_DATA}
  echo "[INFO] The Web server will be started on http://localhost:8080/"
  php -S localhost:8080 -t ${SCRIPT_DIR}/var/www
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
    updateRepos
    # Create the main vhost from the template
    if ${DEPLOYMENT_SETUP_APACHE}; then
      validate_env_var "ADT_DATA"
      validate_env_var "ACCEPTANCE_HOST"
      validate_env_var "CROWD_ACCEPTANCE_APP_NAME"
      validate_env_var "CROWD_ACCEPTANCE_APP_PASSWORD"
      evaluate_file_content ${ETC_DIR}/apache2/conf.d/adt.conf.template ${APACHE_CONF_DIR}/conf.d/adt.conf
      evaluate_file_content ${ETC_DIR}/apache2/sites-available/frontend.template ${APACHE_CONF_DIR}/sites-available/acceptance.exoplatform.org
      if [ "${DIST}" == "Ubuntu" ]; then
        sudo /usr/sbin/service apache2 reload
      fi
    fi
  ;;
  deploy)
    initialize_product_settings
    do_deploy
  ;;
  download-dataset)
    initialize_product_settings
    do_download_dataset
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
  clean-restart)
    initialize_product_settings
    do_stop
    case ${DEPLOYMENT_DATABASE_TYPE} in
      MYSQL)
        echo "[INFO] Recreating MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
        SQL="";
        SQL=$SQL"DROP DATABASE IF EXISTS ${DEPLOYMENT_DATABASE_NAME};"
        SQL=$SQL"CREATE DATABASE IF NOT EXISTS ${DEPLOYMENT_DATABASE_NAME} CHARACTER SET latin1 COLLATE latin1_bin;"
        mysql -e "$SQL"
        echo "[INFO] Done."
      ;;
      HSQLDB)
        # Nothing to do, it will be deleted with data
      ;;
      *)
        echo "[ERROR] Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
        print_usage
        exit 1
      ;;
    esac
    echo "[INFO] Dropping data ..."
    rm -rf ${DEPLOYMENT_DIR}/gatein/data/*
    echo "[INFO] Done."
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
  update-repos)
    updateRepos
  ;;
  web-server)
    updateRepos
    do_load_php_server
  ;;
  *)
    echo "[ERROR] Invalid action \"${ACTION}\""
    print_usage
    exit 1
  ;;
esac

exit 0
