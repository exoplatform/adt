#!/bin/bash -eu

# Load shared functions (they are specific to ADT)
source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_aliases.sh"
source "${SCRIPT_DIR}/_functions_string.sh"
source "${SCRIPT_DIR}/_functions_system.sh"
source "${SCRIPT_DIR}/_functions_files.sh"
source "${SCRIPT_DIR}/_functions_download.sh"
source "${SCRIPT_DIR}/_functions_git.sh"
source "${SCRIPT_DIR}/_functions_ufw.sh"
source "${SCRIPT_DIR}/_functions_apache.sh"
source "${SCRIPT_DIR}/_functions_logrotate.sh"
source "${SCRIPT_DIR}/_functions_awstats.sh"
source "${SCRIPT_DIR}/_functions_tomcat.sh"
source "${SCRIPT_DIR}/_functions_jbosseap.sh"

# #################################################################################
#
# All following functions are usable only in ADT context using shared env variables
#
# #################################################################################

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
    gatein         GateIn Community edition                - Apache Tomcat bundle
    exogtn         GateIn eXo edition                      - Apache Tomcat bundle
    plf            eXo Platform Standard Edition           - Apache Tomcat bundle
    plfcom         eXo Platform Community Edition          - Apache Tomcat bundle
    plfent         eXo Platform Express/Enterprise Edition - Apache Tomcat bundle
    plfenteap      eXo Platform Express/Enterprise Edition - JBoss EAP bundle
    plftrial       eXo Platform Trial Edition              - Apache Tomcat bundle
    plfdemo        eXo Platform Demo Edition               - Apache Tomcat bundle
    addonchat      eXo Platform + eXo Addon Chat           - Apache Tomcat bundle
    compint        eXo Company Intranet                    - Apache Tomcat bundle
    docs           eXo Platform Documentations Website     - Apache Tomcat bundle
  PRODUCT_VERSION                : The version of the product. Can be either a release, a snapshot (the latest one) or a timestamped snapshot

  ADT_DATA                       : The path where data have to be stored (default: under the script path - ${SCRIPT_DIR})
  DEPLOYMENT_APACHE_SECURITY     : Do you want to have a public or a private deployment (default: private, values : private | public)
  DEPLOYMENT_APACHE_VHOST_ALIAS  : Do you want to add an Apache ServerAlias directive to access the deployed instance through a more userfriendly url (ex: try.exoplatform.com for a public demo)
  DEPLOYMENT_PORT_PREFIX         : Default prefix for all ports (2 digits will be added after it for each required port)

  DEPLOYMENT_JVM_SIZE_MAX        : Maximum heap memory size (default: 2g)
  DEPLOYMENT_JVM_SIZE_MIN        : Minimum heap memory size (default: 512m)
  DEPLOYMENT_JVM_PERMSIZE_MAX    : Maximum permgem memory size (default: 256m)

  DEPLOYMENT_DATABASE_TYPE       : Which database do you want to use for your deployment ? (default: HSQLDB, values : HSQLDB | MYSQL)

  DEPLOYMENT_MODE                : How data are processed during a restart or deployment (default: KEEP_DATA for restart, NO_DATA for deploy, values : NO_DATA - All existing data are removed | KEEP_DATA - Existing data are kept | RESTORE_DATASET - The latest dataset - if exists -  is restored)

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
  ADT_DEV_MODE                   : Development mode. Apache server, awstats and ufw are deactivated. (default: false)

EOF

}

init() {
  if ${ADT_DEV_MODE}; then
    configurable_env_var "ACCEPTANCE_HOST" "localhost"
    configurable_env_var "ACCEPTANCE_PORT" "8080"
  else
    configurable_env_var "ACCEPTANCE_HOST" "acceptance.exoplatform.org"
    configurable_env_var "ACCEPTANCE_PORT" "80"
  fi
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

# find_instance_file <VAR> <DIR> <BASENAME> <PRODUCT_NAME>
# Finds which file to use and store its path in <VAR>
# We'll try to find it in the directory <DIR> and we'll select it in this order :
# <PRODUCT_NAME>-${PRODUCT_VERSION}-<BASENAME>
# <PRODUCT_NAME>-${PRODUCT_BRANCH}-<BASENAME>
# <PRODUCT_NAME>-${PRODUCT_MAJOR_BRANCH}-<BASENAME>
# <PRODUCT_NAME>-<BASENAME>
# <BASENAME>.patch
find_instance_file() {
  local _variable=$1
  local _patchDir=$2
  local _basename=$3
  local _product=$4
  find_file ${_variable}  \
 "$_patchDir/$_basename"  \
 "$_patchDir/$_product-$_basename"  \
 "$_patchDir/$_product-${PRODUCT_MAJOR_BRANCH}-$_basename"  \
 "$_patchDir/$_product-${PRODUCT_BRANCH}-$_basename"  \
 "$_patchDir/$_product-${PRODUCT_VERSION}-$_basename"
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

      # Defaults values we can override by product/branch/version
      env_var "EXO_PROFILES" "-Dexo.profiles=all"
      env_var "DEPLOYMENT_DATABASE_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_NAME" ""
      env_var "DEPLOYMENT_DATABASE_USER" ""
      env_var "DEPLOYMENT_GATEIN_CONF_PATH" "gatein/conf/configuration.properties"
      env_var "DEPLOYMENT_SERVER_SCRIPT" "bin/gatein.sh"
      env_var "DEPLOYMENT_SERVER_LOG_FILE" "catalina.out"
      env_var "DEPLOYMENT_APPSRV_TYPE" "tomcat" #Server type
      env_var "DEPLOYMENT_APPSRV_VERSION" "6.0.35" #Default version used to download additional resources like JMX lib
      env_var "DEPLOYMENT_MYSQL_DRIVER_VERSION" "5.1.25" #Default version used to download additional mysql driver
      env_var "DEPLOYMENT_CRASH_ENABLED" false

      configurable_env_var "DEPLOYMENT_CHAT_ENABLED" false
      env_var "DEPLOYMENT_CHAT_MONGODB_HOSTNAME" "localhost"
      env_var "DEPLOYMENT_CHAT_MONGODB_PORT" "27017"

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
      env_var "SET_ENV_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "STANDALONE_PRODUCT_NAME" "${PRODUCT_NAME}"

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
	          env_var ARTIFACT_CLASSIFIER "bundle"
            ;;
            "4.0.x")
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "portal.web"
	          env_var ARTIFACT_CLASSIFIER "tomcat-distrib"
              env_var ARTIFACT_PACKAGING "tar.gz"
              env_var DEPLOYMENT_APPSRV_VERSION "7.0.30"
              env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
	          env_var DEPLOYMENT_DATABASE_ENABLED false
            ;;
            *)
            # 3.5.x and +
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.tomcat7"
              env_var DEPLOYMENT_APPSRV_VERSION "7.0.30"
	          env_var ARTIFACT_CLASSIFIER "bundle"
            ;;
          esac
          case "${PRODUCT_BRANCH}" in
            "3.5.x")
              env_var PLF_BRANCH "4.0.x"
            ;;
            "3.6.x"|"4.0.x")
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
          env_var PRODUCT_DESCRIPTION "Platform SE"
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
              echo_error "Product 'plf' not supported for versions > 3.x. Please use plfcom or plfent."
              print_usage
              exit 1
            ;;
          esac
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        plftrial)
          case "${PRODUCT_BRANCH}" in
            "3.5.x")
              env_var PRODUCT_DESCRIPTION "Platform TE"
              env_var ARTIFACT_GROUPID "org.exoplatform.platform"
              env_var ARTIFACT_ARTIFACTID "exo.platform.packaging.trial"
              env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
              env_var PORTS_SERVER_PATCH_PRODUCT_NAME "plf"
              env_var JMX_SERVER_PATCH_PRODUCT_NAME "plf"
              env_var DB_SERVER_PATCH_PRODUCT_NAME "plf"
              env_var DB_GATEIN_PATCH_PRODUCT_NAME "plf"
              env_var PLF_BRANCH "${PRODUCT_BRANCH}"
            ;;
            *)
              # 4.0.x and +
              echo_error "Product 'plftrial' not supported for versions > 3.x. Please use plfcom or plfent."
              print_usage
              exit 1
            ;;
          esac
        ;;
        plfcom)
          env_var PRODUCT_DESCRIPTION "Platform CE"
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
              env_var DEPLOYMENT_APPSRV_VERSION "7.0.40"
              env_var PLF_BRANCH "${PRODUCT_BRANCH}"
              env_var EXO_PROFILES "all"
            ;;
          esac
        ;;
        plfdemo)
          env_var PRODUCT_DESCRIPTION "Platform 4.0 EE Public Demo"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.demo"
          env_var ARTIFACT_ARTIFACTID "demo-login-enterprise-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_APPSRV_VERSION "7.0.40"
          env_var PLF_BRANCH "${PRODUCT_BRANCH} Demo"
          env_var EXO_PROFILES "all"
        ;;
        plfent)
          env_var PRODUCT_DESCRIPTION "Platform EE"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_APPSRV_VERSION "7.0.40"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          env_var EXO_PROFILES "all"
        ;;
        plfenteap)
          env_var PRODUCT_DESCRIPTION "Platform EE"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-jbosseap-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/standalone.sh"
          env_var DEPLOYMENT_APPSRV_TYPE "jbosseap"
          env_var DEPLOYMENT_APPSRV_VERSION "6.0.1"
          env_var DEPLOYMENT_SERVER_LOG_FILE "server.log"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          env_var EXO_PROFILES "all"
        ;;
        addonchat)
          env_var PRODUCT_DESCRIPTION "Platform 4.0 EE + Chat eXo Addon"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.addons.chat.distribution"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-chat-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_APPSRV_VERSION "7.0.40"
          env_var PLF_BRANCH "${PRODUCT_BRANCH} Demo"
          env_var EXO_PROFILES "all"
          env_var DEPLOYMENT_CHAT_ENABLED true
        ;;
        compint)
          env_var PRODUCT_DESCRIPTION           "eXo Company Intranet"
          env_var ARTIFACT_REPO_GROUP           "cp"
          env_var ARTIFACT_GROUPID              "com.exoplatform.intranet"
          # 4.0.x and +
          env_var ARTIFACT_ARTIFACTID           "company-intranet-package"
          env_var DEPLOYMENT_APPSRV_VERSION     "7.0.40"
          env_var PLF_BRANCH                    "COMPANY"
          env_var DEPLOYMENT_SERVER_SCRIPT      "bin/catalina.sh"
          env_var EXO_PROFILES                  "all"
          env_var DEPLOYMENT_DATABASE_TYPE      "MYSQL"
          env_var DEPLOYMENT_JVM_SIZE_MAX       "3g"
          env_var DEPLOYMENT_JVM_SIZE_MIN       "2g"
          env_var DEPLOYMENT_JVM_PERMSIZE_MAX   "512m"
          # Datasets remote location
          env_var DATASET_DATA_VALUES_ARCHIVE    "bckintranet@storage.exoplatform.org:/home/bckintranet/intranet-data-values-latest.tar.bz2"
          env_var DATASET_DATA_INDEX_ARCHIVE     "bckintranet@storage.exoplatform.org:/home/bckintranet/intranet-data-index-latest.tar.bz2"
          env_var DATASET_DB_ARCHIVE             "bckintranet@storage.exoplatform.org:/home/bckintranet/intranet-db-latest.tar.bz2"
        ;;
        docs)
          env_var ARTIFACT_REPO_GROUP "private"
          env_var PRODUCT_DESCRIPTION "eXo Platform Documentations Website"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.documentation"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var DEPLOYMENT_DATABASE_ENABLED false
          case "${PRODUCT_BRANCH}" in
            "3.5.x")
              env_var PLF_BRANCH "3.5.x"
		          env_var ARTIFACT_ARTIFACTID "platform-documentation-website-packaging"
            ;;
            *)
              env_var PLF_BRANCH "4.0.x"
		          env_var ARTIFACT_ARTIFACTID "platform-documentation-packaging"
            ;;
          esac
        ;;
        *)
          echo_error "Invalid product \"${PRODUCT_NAME}\""
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
      if ${DEPLOYMENT_CHAT_ENABLED}; then
        # Build a database name without dot, minus ...
        env_var DEPLOYMENT_CHAT_MONGODB_NAME "${PRODUCT_NAME}_${PRODUCT_VERSION}"
        env_var DEPLOYMENT_CHAT_MONGODB_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME//./_}"
        env_var DEPLOYMENT_CHAT_MONGODB_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME//-/_}"
      fi
    ;;
    start | stop | restart | undeploy )
    # Mandatory env vars. They need to be defined before launching the script
      validate_env_var "PRODUCT_NAME"
      validate_env_var "PRODUCT_VERSION" 
      if ${DEPLOYMENT_CHAT_ENABLED}; then
        validate_env_var "DEPLOYMENT_CHAT_WEEMO_KEY"
      fi ;;
    list | start-all | stop-all | restart-all | undeploy-all)
    # Nothing to do
    ;;
    *)
      echo_error "Invalid action \"${ACTION}\""
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

  configurable_env_var "REPOSITORY_SERVER_BASE_URL" "https://repository.exoplatform.org"
  configurable_env_var "REPOSITORY_USERNAME" ""
  configurable_env_var "REPOSITORY_PASSWORD" ""


  if ! ${ADT_OFFLINE}; then
    # Downloads the product from Nexus
    do_download_maven_artifact  \
   "${REPOSITORY_SERVER_BASE_URL}/${ARTIFACT_REPO_GROUP}" "${REPOSITORY_USERNAME}" "${REPOSITORY_PASSWORD}"  \
   "${ARTIFACT_GROUPID}" "${ARTIFACT_ARTIFACTID}" "${PRODUCT_VERSION}" "${ARTIFACT_PACKAGING}" "${ARTIFACT_CLASSIFIER}"  \
   "${DL_DIR}" "${PRODUCT_NAME}" "PRODUCT"
  else
    echo_warn "ADT is offline and won't try to download the server !"
  fi
  do_load_artifact_descriptor "${DL_DIR}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}"
  env_var ARTIFACT_TIMESTAMP ${PRODUCT_ARTIFACT_TIMESTAMP}
  env_var ARTIFACT_DATE ${PRODUCT_ARTIFACT_DATE}
  env_var ARTIFACT_REPO_URL ${PRODUCT_ARTIFACT_URL}
  env_var ARTIFACT_LOCAL_PATH ${PRODUCT_ARTIFACT_LOCAL_PATH}
  env_var ARTIFACT_DL_URL $(do_build_url "http" "${ACCEPTANCE_HOST}" "${ACCEPTANCE_PORT}" "/downloads/${PRODUCT_NAME}-${ARTIFACT_TIMESTAMP}.${ARTIFACT_PACKAGING}")
}

do_download_dataset() {
  validate_env_var "DS_DIR"
  validate_env_var "PRODUCT_NAME"
  validate_env_var "PRODUCT_BRANCH"
  validate_env_var "PRODUCT_DESCRIPTION"
  echo_info "Updating local dataset for ${PRODUCT_DESCRIPTION} ${PRODUCT_BRANCH} from the storage server ..."
  if [ ! -z "${DATASET_DATA_VALUES_ARCHIVE}" ] && [ ! -z "${DATASET_DATA_INDEX_ARCHIVE}" ] && [ ! -z "${DATASET_DB_ARCHIVE}" ]; then
    mkdir -p ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}
    display_time rsync -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DB_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2
    display_time rsync -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DATA_INDEX_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/index.tar.bz2
    display_time rsync -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DATA_VALUES_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/values.tar.bz2
  else
    echo_error "Datasets not configured"
    exit 1
  fi
  echo_info "Done"
}

do_restore_dataset(){
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      # System dependent settings
      if ${LINUX}; then
        TAR_BZIP2_COMPRESS_PRG=--use-compress-prog=pbzip2
        NICE_CMD="nice -n 20 ionice -c2 -n7"
      else
        TAR_BZIP2_COMPRESS_PRG=
        NICE_CMD="nice -n 20"
      fi
      do_drop_data
      do_drop_database
      do_create_database
      if ${DEPLOYMENT_CHAT_ENABLED}; then
        do_drop_chat_mongo_database
        do_create_chat_mongo_database
      fi
      mkdir -p ${DEPLOYMENT_DIR}/gatein/data/jcr/
      echo_info "Loading values ..."
      display_time ${NICE_CMD} tar ${TAR_BZIP2_COMPRESS_PRG} --directory ${DEPLOYMENT_DIR}/gatein/data/jcr/ -xf ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/values.tar.bz2
      echo_info "Done"
      echo_info "Loading indexes ..."
      display_time ${NICE_CMD} tar ${TAR_BZIP2_COMPRESS_PRG} --directory ${DEPLOYMENT_DIR}/gatein/data/jcr/ -xf ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/index.tar.bz2
      echo_info "Done"
      _tmpdir=`mktemp -d -t db-export.XXXXXXXXXX` || exit 1
      echo_info "Using temporary directory ${_tmpdir}"
      _restorescript="${_tmpdir}/__restoreAllData.sql"
      echo_info "Uncompressing ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2 into ${_tmpdir} ..."
      display_time ${NICE_CMD} tar ${TAR_BZIP2_COMPRESS_PRG} --directory ${_tmpdir} -xf ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2
      echo_info "Done"
      if [ ! -e ${_restorescript} ]; then
       echo_error "SQL file (${_restorescript}) doesn't exist."
       exit 1
      fi;
      echo_info "Importing database ${DEPLOYMENT_DATABASE_NAME} content ..."
      pushd ${_tmpdir} > /dev/null 2>&1
      if [ ! -e ${HOME}/.my.cnf ]; then
       echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
       exit 1
      fi;
      pv -p -t -e -a -r -b ${_restorescript} | mysql ${DEPLOYMENT_DATABASE_NAME}
      popd > /dev/null 2>&1
      echo_info "Done"
      echo_info "Drop if it exists the JCR_CONFIG table from ${DEPLOYMENT_DATABASE_NAME} ..."
      mysql ${DEPLOYMENT_DATABASE_NAME} -e "DROP TABLE IF EXISTS JCR_CONFIG;"
      echo_info "Done"
      rm -rf ${_tmpdir}
    ;;
    HSQLDB)
      echo_error "Dataset restoration isn't supported for database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      exit 1
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

do_init_empty_data(){
  echo_info "Deleting all existing data for ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    do_drop_database
    do_create_database
  fi
  if ${DEPLOYMENT_CHAT_ENABLED}; then
    do_drop_chat_mongo_database
    do_create_chat_mongo_database
  fi
  do_drop_data
  do_create_data
  echo_info "Done"
}

#
# Function that unpacks the app server archive
#
do_unpack_server() {
  rm -rf ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  echo_info "Unpacking server ..."
  mkdir -p ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  set +e
  case ${ARTIFACT_PACKAGING} in
    zip)
      unzip -q ${ARTIFACT_LOCAL_PATH} -d ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo_warn "unpack of the server failed. We will try to download it a second time."
        rm ${ARTIFACT_LOCAL_PATH}
        do_download_server
        unzip -q ${ARTIFACT_LOCAL_PATH} -d ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
        if [ "$?" -ne "0" ]; then
          echo_error "Unable to unpack the server."
          exit 1
        fi
      fi
    ;;
    tar.gz)
      cd ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
      tar -xzf ${ARTIFACT_LOCAL_PATH}
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo_warn "unpack of the server failed. We will try to download it a second time."
        rm ${ARTIFACT_LOCAL_PATH}
        do_download_server
        tar -xzf ${ARTIFACT_LOCAL_PATH}
        if [ "$?" -ne "0" ]; then
          echo_error "Unable to unpack the server."
          exit 1
        fi
      fi
      cd -
    ;;
    *)
      echo_error "Invalid packaging \"${ARTIFACT_PACKAGING}\""
      print_usage
      exit 1
    ;;
  esac
  set -e
  DEPLOYMENT_PID_FILE=${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.pid
  mkdir -p ${SRV_DIR}
  echo_info "Deleting existing server ..."
  rm -rf ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  echo_info "Done"
  cp -rf ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION} ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
  rm -rf ${TMP_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}

  # We search the server directory
  pushd `find ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION} -maxdepth 4 -mindepth 1 -name bin -type d`/.. > /dev/null
  DEPLOYMENT_DIR=`pwd -P`
  popd > /dev/null

  case ${DEPLOYMENT_APPSRV_TYPE} in
    tomcat)
      DEPLOYMENT_LOG_PATH=${DEPLOYMENT_DIR}/logs/${DEPLOYMENT_SERVER_LOG_FILE}
    ;;
    jbosseap)
      DEPLOYMENT_LOG_PATH=${DEPLOYMENT_DIR}/standalone/log/${DEPLOYMENT_SERVER_LOG_FILE}
    ;;
    *)
      echo_error "Invalid application server type \"${DEPLOYMENT_APPSRV_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  echo_info "Server unpacked"
}

#
# Creates a database for the instance. Don't drop it if it already exists.
#
do_create_database() {
  case ${DEPLOYMENT_DATABASE_TYPE} in
    MYSQL)
      echo_info "Creating MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
      if [ ! -e ${HOME}/.my.cnf ]; then
       echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
       exit 1
      fi;
      SQL=""
      SQL=${SQL}"CREATE DATABASE IF NOT EXISTS ${DEPLOYMENT_DATABASE_NAME};"
      SQL=${SQL}"GRANT ALL ON ${DEPLOYMENT_DATABASE_NAME}.* TO '${DEPLOYMENT_DATABASE_USER}'@'localhost' IDENTIFIED BY '${DEPLOYMENT_DATABASE_USER}';"
      SQL=${SQL}"FLUSH PRIVILEGES;"
      SQL=${SQL}"SHOW DATABASES;"
      mysql -e "$SQL"
      echo_info "Done."
    ;;
    HSQLDB)
      echo_info "Using default HSQLDB database. Nothing to do to create the Database."
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
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
      echo_info "Drops MySQL database ${DEPLOYMENT_DATABASE_NAME} ..."
      if [ ! -e ${HOME}/.my.cnf ]; then
       echo_error "\${HOME}/.my.cnf doesn't exist. Please create it to define your credentials to manage your MySQL Server"
       exit 1
      fi;
      SQL=""
      SQL=${SQL}"DROP DATABASE IF EXISTS ${DEPLOYMENT_DATABASE_NAME};"
      SQL=${SQL}"SHOW DATABASES;"
      mysql -e "$SQL"
      echo_info "Done."
    ;;
    HSQLDB)
      echo_info "Drops HSQLDB database ..."
      rm -rf ${DEPLOYMENT_DIR}/gatein/data/hsqldb
      echo_info "Done."
    ;;
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
}

#
# Drops all data used by the instance.
#
do_drop_data() {
  echo_info "Drops instance indexes ..."
  rm -rf ${DEPLOYMENT_DIR}/gatein/data/jcr/index/
  echo_info "Done."
  echo_info "Drops instance values ..."
  rm -rf ${DEPLOYMENT_DIR}/gatein/data/jcr/values/
  echo_info "Done."
}

#
# Creates a MongoDB database for the instance. Don't drop it if it already exists.
#
do_create_chat_mongo_database() {
  echo_info "Creating MongoDB database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."
  if [ ! command -v mongo &>/dev/null ]; then
   echo_error "mongo binary doesn't exist on the system. Please install MongoDB client to be able to manage the MongoDB Server"
   exit 1
  fi;
  # Database are automatically created the first time we access it
  mongo ${DEPLOYMENT_CHAT_MONGODB_NAME} --quiet --eval "db.getCollectionNames()" > /dev/null
  echo 'show dbs' | mongo --quiet
  echo_info "Done."
}

#
# Drops the MongoDB database used by the instance.
#
do_drop_chat_mongo_database() {
  echo_info "Drops MongoDB database ${DEPLOYMENT_CHAT_MONGODB_NAME} ..."
  if [ ! command -v mongo &>/dev/null ]; then
   echo_error "mongo binary doesn't exist on the system. Please install MongoDB client to be able to manage the MongoDB Server"
   exit 1
  fi;
  mongo ${DEPLOYMENT_CHAT_MONGODB_NAME} --quiet --eval "db.dropDatabase()" > /dev/null
  echo 'show dbs' | mongo --quiet
  echo_info "Done."
}

#
# Creates all data directories used by the instance.
#
do_create_data() {
  echo_info "Creates instance indexes directory ..."
  mkdir -p ${DEPLOYMENT_DIR}/gatein/data/jcr/index/
  echo_info "Done."
  echo_info "Creates instance values directory ..."
  mkdir -p ${DEPLOYMENT_DIR}/gatein/data/jcr/values/
  echo_info "Done."
}

do_configure_apache() {
  echo_info "Configure and update AWStats ..."
  mkdir -p ${AWSTATS_CONF_DIR}
  # Regenerates stats for this Vhosts
  export DOMAIN=${DEPLOYMENT_EXT_HOST}
  evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.template ${AWSTATS_CONF_DIR}/awstats.${DEPLOYMENT_EXT_HOST}.conf
  [ -e ${ADT_DATA}/var/log/apache2/${DOMAIN}-access.log ] && do_generate_awstats ${DOMAIN} ${ADT_DEV_MODE}
  unset DOMAIN
  # Regenerates stats for root vhosts
  export DOMAIN=${ACCEPTANCE_HOST}
  evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.template ${AWSTATS_CONF_DIR}/awstats.${ACCEPTANCE_HOST}.conf
  [ -e ${ADT_DATA}/var/log/apache2/${DOMAIN}-access.log ] && do_generate_awstats ${DOMAIN} ${ADT_DEV_MODE}
  unset DOMAIN
  echo_info "Done."
  echo_info "Creating Apache Virtual Host ..."
  mkdir -p ${APACHE_CONF_DIR}
  case ${DEPLOYMENT_APACHE_SECURITY} in
    public)
      evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-public.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
    ;;
    private)
      evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-private.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
    ;;
    *)
      echo_error "Invalid apache security type \"${DEPLOYMENT_DATABASE_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  DEPLOYMENT_LOG_URL=${DEPLOYMENT_URL}/logs/${DEPLOYMENT_SERVER_LOG_FILE}
  echo_info "Done."
  echo_info "Rotate Apache logs ..."

  evaluate_file_content ${ETC_DIR}/logrotate.d/instance.template ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}
  do_logrotate "${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}" ${ADT_DEV_MODE}
  rm ${TMP_DIR}/logrotate-${PRODUCT_NAME}-${PRODUCT_VERSION}

  evaluate_file_content ${ETC_DIR}/logrotate.d/frontend.template ${TMP_DIR}/logrotate-acceptance
  do_logrotate "${TMP_DIR}/logrotate-acceptance" ${ADT_DEV_MODE}
  rm ${TMP_DIR}/logrotate-acceptance

  do_reload_apache ${ADT_DEV_MODE}

  echo_info "Done."
}

do_create_deployment_descriptor() {
  echo_info "Creating deployment descriptor ..."
  mkdir -p ${ADT_CONF_DIR}
  evaluate_file_content ${ETC_DIR}/adt/config.template ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  echo_info "Done."
}

do_load_deployment_descriptor() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo_warn "${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
    echo_warn "You need to deploy it first."
    exit 1
  else
    source ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
  fi
}

#
# Function that deploys (Download+configure) the app server
#
do_deploy() {
  configurable_env_var "DEPLOYMENT_APACHE_SECURITY" "private"
  configurable_env_var "DEPLOYMENT_APACHE_VHOST_ALIAS" ""
  configurable_env_var "DEPLOYMENT_DATABASE_TYPE" "HSQLDB"
  configurable_env_var "DEPLOYMENT_JVM_SIZE_MAX" "2g"
  configurable_env_var "DEPLOYMENT_JVM_SIZE_MIN" "512m"
  configurable_env_var "DEPLOYMENT_JVM_PERMSIZE_MAX" "256m"
  configurable_env_var "DEPLOYMENT_LDAP_URL" ""
  configurable_env_var "DEPLOYMENT_LDAP_ADMIN_DN" ""
  configurable_env_var "DEPLOYMENT_LDAP_ADMIN_PWD" ""
  configurable_env_var "DEPLOYMENT_PORT_PREFIX" "80"

  # Generic Ports
  env_var "DEPLOYMENT_HTTP_PORT" "${DEPLOYMENT_PORT_PREFIX}01"
  env_var "DEPLOYMENT_AJP_PORT" "${DEPLOYMENT_PORT_PREFIX}02"

  # JMX ports
  env_var "DEPLOYMENT_RMI_REG_PORT" "${DEPLOYMENT_PORT_PREFIX}03"
  env_var "DEPLOYMENT_RMI_SRV_PORT" "${DEPLOYMENT_PORT_PREFIX}04"

  # JOD ports
  #env_var "DEPLOYMENT_JOD_CONVERTER_PORTS" "${DEPLOYMENT_PORT_PREFIX}05,${DEPLOYMENT_PORT_PREFIX}06,${DEPLOYMENT_PORT_PREFIX}07"
  env_var "DEPLOYMENT_JOD_CONVERTER_PORTS" "${DEPLOYMENT_PORT_PREFIX}05"

  # CRaSH ports
  env_var "DEPLOYMENT_CRASH_TELNET_PORT" "${DEPLOYMENT_PORT_PREFIX}08"
  env_var "DEPLOYMENT_CRASH_SSH_PORT" "${DEPLOYMENT_PORT_PREFIX}09"

  if ${ADT_DEV_MODE}; then
    env_var "DEPLOYMENT_EXT_HOST" "localhost"
    env_var "DEPLOYMENT_EXT_PORT" "${DEPLOYMENT_HTTP_PORT}"
  else
    env_var "DEPLOYMENT_EXT_HOST" "${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}"
    env_var "DEPLOYMENT_EXT_PORT" "80"
  fi
  env_var "DEPLOYMENT_URL" $(do_build_url "http" "${DEPLOYMENT_EXT_HOST}" "${DEPLOYMENT_EXT_PORT}" "")

  echo_info "Deploying server ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
  if [ "${DEPLOYMENT_MODE}" == "KEEP_DATA" ]; then
    echo_info "Archiving existing data ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
    _tmpdir=`mktemp -d -t archive-data.XXXXXXXXXX` || exit 1
    echo_info "Using temporary directory ${_tmpdir}"
    if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
      echo_warn "This instance wasn't deployed before. Nothing to keep."
      mkdir -p ${_tmpdir}/data
      do_create_database
      if ${DEPLOYMENT_CHAT_ENABLED}; then
        do_create_chat_mongo_database
      fi
    else
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      # The server have been already deployed.
      # We load its settings from the configuration
      do_load_deployment_descriptor
      if [ -d "${DEPLOYMENT_DIR}/gatein/data" ]; then
        mv ${DEPLOYMENT_DIR}/gatein/data ${_tmpdir}
      else
        mkdir -p ${_tmpdir}/data
        do_create_database
        if ${DEPLOYMENT_CHAT_ENABLED}; then
          do_create_chat_mongo_database
        fi
      fi
      )
    fi
    echo_info "Done."
  fi
  if [ -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    # Stop the server
    do_stop
  fi
  do_download_server
  do_unpack_server
  case ${DEPLOYMENT_APPSRV_TYPE} in
    tomcat)
      do_configure_tomcat_server
    ;;
    jbosseap)
      do_configure_jbosseap_server
    ;;
    *)
      echo_error "Invalid application server type \"${DEPLOYMENT_APPSRV_TYPE}\""
      print_usage
      exit 1
    ;;
  esac
  do_configure_apache
  case "${DEPLOYMENT_MODE}" in
    NO_DATA)
      do_init_empty_data
    ;;
    KEEP_DATA)
      echo_info "Restoring previous data ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
      rm -rf ${DEPLOYMENT_DIR}/gatein/data
      mv ${_tmpdir}/data ${DEPLOYMENT_DIR}/gatein
      rm -rf ${_tmpdir}
      echo_info "Done."
    ;;
    RESTORE_DATASET)
      do_restore_dataset
    ;;
    *)
      echo_error "Invalid deployment mode \"${DEPLOYMENT_MODE}\""
      print_usage
      exit 1
    ;;
  esac
  do_create_deployment_descriptor
  echo_info "Server deployed"
}

#
# Function that starts the app server
#
do_start() {
  # Use a subshell to not expose settings loaded from the deployment descriptor
  (
  # The server is supposed to be already deployed.
  # We load its settings from the configuration
  do_load_deployment_descriptor
  echo_info "Starting server ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
  chmod 755 ${DEPLOYMENT_DIR}/bin/*.sh
  mkdir -p $(dirname ${DEPLOYMENT_LOG_PATH})
  cd `dirname ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT}`

  # We need to backup existing logs if they already exist
  backup_file $(dirname ${DEPLOYMENT_LOG_PATH}) "${DEPLOYMENT_SERVER_LOG_FILE}"

  case ${DEPLOYMENT_APPSRV_TYPE} in
    tomcat)
      END_STARTUP_MSG="Server startup in"

      if [ ! -f "${DEPLOYMENT_DIR}/bin/setenv-local.sh" ]; then
        export CATALINA_HOME=${DEPLOYMENT_DIR}
        export CATALINA_PID=${DEPLOYMENT_PID_FILE}
        CATALINA_OPTS=""
        # JVM
        CATALINA_OPTS="${CATALINA_OPTS} -XX:+HeapDumpOnOutOfMemoryError"
        CATALINA_OPTS="${CATALINA_OPTS} -XX:HeapDumpPath="$(dirname ${DEPLOYMENT_LOG_PATH})
        # JMX
        CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote=true"
        CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
        CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.password.file=${DEPLOYMENT_DIR}/conf/jmxremote.password"
        CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.access.file=${DEPLOYMENT_DIR}/conf/jmxremote.access"
        CATALINA_OPTS="${CATALINA_OPTS} -Djava.rmi.server.hostname=${DEPLOYMENT_EXT_HOST}"
        # Email
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.domain.url=${DEPLOYMENT_URL}"
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.from=noreply+acceptance@exoplatform.com"
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.username="
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.password="
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.host=localhost"
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.port=25"
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.starttls.enable=false"
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.auth=false"
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.socketFactory.port="
        CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.email.smtp.socketFactory.class="
        # JOD Server
        CATALINA_OPTS="${CATALINA_OPTS} -Dwcm.jodconverter.portnumbers=${DEPLOYMENT_JOD_CONVERTER_PORTS}"
        # CRaSH
        CATALINA_OPTS="${CATALINA_OPTS} -Dcrash.telnet.port=${DEPLOYMENT_CRASH_TELNET_PORT}"
        CATALINA_OPTS="${CATALINA_OPTS} -Dcrash.ssh.port=${DEPLOYMENT_CRASH_SSH_PORT}"
        export CATALINA_OPTS
        export EXO_PROFILES="${EXO_PROFILES}"
      fi
      # Startup the server
      ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT} start
    ;;
    jbosseap)
      END_STARTUP_MSG="JBAS01587[45]"
      # Startup the server
      ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT}  > /dev/null 2>&1 &
    ;;
    *)
      echo_error "Invalid application server type \"${DEPLOYMENT_APPSRV_TYPE}\""
      print_usage
      exit 1
    ;;
  esac


  # Wait for logs availability
  while [ true ];
  do
    if [ -e "${DEPLOYMENT_LOG_PATH}" ]; then
      break
    fi
  done
  # Display logs
  tail -f "${DEPLOYMENT_LOG_PATH}" &
  local _tailPID=$!
  # Check for the end of startup
  set +e
  while [ true ];
  do
    if grep -q "${END_STARTUP_MSG}" "${DEPLOYMENT_LOG_PATH}"; then
      kill ${_tailPID}
      wait ${_tailPID} 2> /dev/null
      break
    fi
  done
  set -e
  cd -
  echo_info "Server started"
  echo_info "URL  : ${DEPLOYMENT_URL}"
  echo_info "Logs : ${DEPLOYMENT_LOG_URL}"
  echo_info "JMX  : ${DEPLOYMENT_JMX_URL}"
  )
}

#
# Function that stops the app server
#
do_stop() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo_warn "${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
    echo_warn "The product cannot be stopped"
    exit 0
  else
    # Use a subshell to not expose settings loaded from the deployment descriptor
    (
    # The server is supposed to be already deployed.
    # We load its settings from the configuration
    do_load_deployment_descriptor
    if [ -n "${DEPLOYMENT_DIR}" ] && [ -e "${DEPLOYMENT_DIR}" ]; then
      echo_info "Stopping server ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ... "
      case ${DEPLOYMENT_APPSRV_TYPE} in
        tomcat)
          if [ ! -f "${DEPLOYMENT_DIR}/bin/setenv-local.sh" ]; then
            export CATALINA_HOME=${DEPLOYMENT_DIR}
            export CATALINA_PID=${DEPLOYMENT_PID_FILE}
          fi
          ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT} stop 60 -force > /dev/null 2>&1 || true
        ;;
        jbosseap)
          ${DEPLOYMENT_DIR}/bin/jboss-cli.sh --controller=localhost:${DEPLOYMENT_MGT_NATIVE_PORT} --connect command=:shutdown > /dev/null 2>&1 || true
          echo_n_info "Waiting for shutdown "
          while [ -e ${DEPLOYMENT_PID_FILE} ];
          do
            sleep 5
            echo -n "."
          done
          echo " OK."
        ;;
        *)
          echo_error "Invalid application server type \"${DEPLOYMENT_APPSRV_TYPE}\""
          print_usage
          exit 1
        ;;
      esac
      echo_info "Server stopped."
    else
      echo_warn "No server directory to stop it"
    fi
    )
  fi
}

#
# Function that undeploys (delete) the app server
#
do_undeploy() {
  if [ ! -e "${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}" ]; then
    echo_warn "${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
    echo_warn "The product cannot be undeployed"
    exit 0
  else
    # Use a subshell to not expose settings loaded from the deployment descriptor
    (
    # The server is supposed to be already deployed.
    # We load its settings from the configuration
    do_load_deployment_descriptor
    # Stop the server
    do_stop
    if ${DEPLOYMENT_DATABASE_ENABLED}; then
      do_drop_database
    fi
    if ${DEPLOYMENT_CHAT_ENABLED}; then
      do_drop_chat_mongo_database
    fi
    echo_info "Undeploying server ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
    # Delete Awstat config
    rm -f ${AWSTATS_CONF_DIR}/awstats.${DEPLOYMENT_EXT_HOST}.conf
    # Delete the vhost
    rm -f ${APACHE_CONF_DIR}/${DEPLOYMENT_EXT_HOST}
    # Reload Apache to deactivate the config
    do_reload_apache ${ADT_DEV_MODE}
    # Delete the server
    rm -rf ${SRV_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}
    # Close firewall ports
    do_ufw_open_port ${DEPLOYMENT_RMI_REG_PORT} "JMX RMI REG" ${ADT_DEV_MODE}
    do_ufw_open_port ${DEPLOYMENT_RMI_SRV_PORT} "JMX RMI SRV" ${ADT_DEV_MODE}
    do_ufw_open_port ${DEPLOYMENT_CRASH_SSH_PORT} "CRaSH SSH" ${ADT_DEV_MODE}
    echo_info "Server undeployed"
    # Delete the deployment descriptor
    rm ${ADT_CONF_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}.${ACCEPTANCE_HOST}
    )
  fi
}

#
# Function that lists all deployed servers
#
do_list() {
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
    TXT_GREEN=$(tput -Txterm-256color setaf 2)
    TXT_RED=$(tput -Txterm-256color setaf 1)
    TXT_CYAN=$(tput -Txterm-256color setaf 6)
    TXT_YELLOW=$(tput -Txterm-256color setaf 3)
    TXT_RESET=$(tput -Txterm-256color sgr0) # Text reset.
    echo_info "Deployed servers : "
    printf "%-40s %-25s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "========================================" "=========================" "==========" "==========" "==========" "==========" "==========" "==========" "==========" "==========" "=========="
    printf "%-40s %-25s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "Product" "Version" "Bundle" "Database" "Prefix" "HTTP_P" "AJP_P" "JMX_REG_P" "JMX_SRV_P" "CRASH_SSH" "RUNNING"
    printf "%-40s %-25s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n" "========================================" "=========================" "==========" "==========" "==========" "==========" "==========" "==========" "==========" "==========" "=========="
    for f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${f}
      if [ -f ${DEPLOYMENT_PID_FILE} ]; then
        set +e
        kill -0 `cat ${DEPLOYMENT_PID_FILE}` > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          STATUS="${TXT_GREEN}true${TXT_RESET}"
        else
          STATUS="${TXT_RED}false${TXT_RESET}"
        fi
        set -e
      else
        STATUS="${TXT_RED}false${TXT_RESET}"
      fi
      printf "%-40s %-25s %-10s %-10s %10s %10s %10s %10s %10s %10s %-10s\n" "${PRODUCT_DESCRIPTION}" "${PRODUCT_VERSION}" "${DEPLOYMENT_APPSRV_TYPE}" "${DEPLOYMENT_DATABASE_TYPE}" "${DEPLOYMENT_PORT_PREFIX}XX" "${DEPLOYMENT_HTTP_PORT}" "${DEPLOYMENT_AJP_PORT}" "${DEPLOYMENT_RMI_REG_PORT}" "${DEPLOYMENT_RMI_SRV_PORT}" "${DEPLOYMENT_CRASH_SSH_PORT}" "$STATUS"
      )
    done
  else
    echo_info "No server deployed."
  fi
}

#
# Function that starts all deployed servers
#
do_start_all() {
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
    echo_info "Starting all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${f}
      do_start
      )
    done
    echo_info "All servers started"
  else
    echo_info "No server deployed."
  fi
}

#
# Function that restarts all deployed servers
#
do_restart_all() {
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
    echo_info "Restarting all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${f}
      do_stop
      do_start
      )
    done
    echo_info "All servers restarted"
  else
    echo_info "No server deployed."
  fi
}

#
# Function that stops all deployed servers
#
do_stop_all() {
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
    echo_info "Stopping all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${f}
      do_stop
      )
    done
    echo_info "All servers stopped"
  else
    echo_info "No server deployed."
  fi
}

#
# Function that undeploys all deployed servers
#
do_undeploy_all() {
  if [ "$(ls -A ${ADT_CONF_DIR})" ]; then
    echo_info "Undeploying all servers ..."
    for f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${f}
      do_undeploy
      )
    done
    echo_info "All servers undeployed"
  else
    echo_info "No server deployed."
  fi
}

#
# Function that loads a php server to test Acceptance FrontEnd
# requires PHP >= 5.4
#
do_load_php_server() {
  local _php_ini_file="${ETC_DIR}/php/cli-server.ini"
  local _doc_root="${SCRIPT_DIR}/var/www"
  local _php_router_file="${SCRIPT_DIR}/var/www/router.php"
  set +e
  local _php_exe=$(which php)
  if [ $? != 0 ]; then
    echo_error "Unable to find PHP executable"
    exit 1
  fi
  set -e
  echo_info "Starting the web server (PHP 5.4+ is required)"
  ${_php_exe} -r \@phpinfo\(\)\; | grep 'PHP Version' -m 1
  set +e
  ${_php_exe} -S ${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT} -c ${_php_ini_file} -t ${_doc_root} ${_php_router_file}
  if [ $? != 0 ]; then
    echo_error "Unable to start PHP Web Server"
    exit 1
  fi
  set -e
}
