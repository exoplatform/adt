#!/bin/bash -eu

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

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
source "${SCRIPT_DIR}/_functions_plf.sh"
source "${SCRIPT_DIR}/_functions_tomcat.sh"
source "${SCRIPT_DIR}/_functions_jbosseap.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"
source "${SCRIPT_DIR}/_functions_database.sh"
source "${SCRIPT_DIR}/_functions_es.sh"

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

Action
------
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
  web-server       Starts a local PHP web server to test the front-end (requires PHP >= 5.4). It automatically activates the development mode.

Environment Variables
---------------------

  They may be configured in the current shell environment or /etc/default/adt or \$HOME/.adtrc

  Global Settings
  ===============

  ADT_DATA                          : The path where data have to be stored (default: under the script path - ${SCRIPT_DIR})

  ACCEPTANCE_SCHEME                 : The scheme to use to deploy the acceptance server (default: 'http' if ADT_DEV_MODE=true, 'https' otherwise; values : http | https)
  ACCEPTANCE_HOST                   : The hostname (vhost) where is deployed the acceptance server (default: 'localhost' if ADT_DEV_MODE=true, 'acceptance.exoplatform.org' otherwise)
  ACCEPTANCE_PORT                   : The server port on which the acceptance front-end is listening (default: '8080' if ADT_DEV_MODE=true, '80' otherwise)
  ACCEPTANCE_SERVERS                : A comma separated list of all acceptance front-end URLs to aggregate (default: 'http://localhost:8080' if ADT_DEV_MODE=true, 'https://acceptance.exoplatform.org' otherwise)
  CROWD_ACCEPTANCE_APP_NAME         : The crowd application used to authenticate the front-end (default: none)
  CROWD_ACCEPTANCE_APP_PASSWORD     : The crowd application's password used to authenticate the front-end (default: none)
  LDAP_ACCEPTANCE_BIND_DN           : The LDAP Bind DN used to authenticate the front-end (default: none)
  LDAP_ACCEPTANCE_BIND_PASSWORD     : The LDAP Bind DN's password used to authenticate the front-end (default: none)
  APACHE_SSL_CERTIFICATE_FILE       : Apache SSLCertificateFile for HTTPS setup
  APACHE_SSL_CERTIFICATE_KEY_FILE   : Apache SSLCertificateKeyFile for HTTPS setup
  APACHE_SSL_CERTIFICATE_CHAIN_FILE : Apache SSLCertificateChainFile for HTTPS setup

  REPOSITORY_SERVER_BASE_URL        : The Maven repository URL used to download artifacts (default: https://repository.exoplatform.org)
  REPOSITORY_USERNAME               : The username to logon on \$REPOSITORY_SERVER_BASE_URL if necessary (default: none)
  REPOSITORY_PASSWORD               : The password to logon on \$REPOSITORY_SERVER_BASE_URL if necessary (default: none)

  ADT_DEBUG                         : Display debug details (default: false; values : true | false)
  ADT_DEV_MODE                      : Development mode. Apache server, awstats and ufw are deactivated. (default: false; values : true | false)
  ADT_OFFLINE                       : Use only local resources, don''t do any remote operations. (default: false; values : true | false)

  Instance Settings
  =================

  PRODUCT_NAME                      : The product you want to manage. Possible values are :
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
    community      eXo Community Website                   - Apache Tomcat bundle
    docs           eXo Platform Documentations Website     - Apache Tomcat bundle

  PRODUCT_VERSION                   : The version of the product. Can be either a release, a snapshot (the latest one) or a timestamped snapshot
  INSTANCE_ID                       : The id of the instance. Use this property to deploy several time the same PRODUCT_NAME and PRODUCT_VERSION couple (default: none)

  DEPLOYMENT_LABELS                 : Comma separated labels for a deployment \" (default: none)

  DEPLOYMENT_SKIP_ACCOUNT_SETUP     : Do you want to skip the account creation form and use default accounts (default: false; values : true | false)

  DEPLOYMENT_APACHE_SECURITY        : Do you want to have a public or a private deployment (default: private; values : private | public)
  DEPLOYMENT_APACHE_VHOST_ALIAS     : Do you want to add an Apache ServerAlias directive to access the deployed instance through a more userfriendly url (ex: try.exoplatform.com for a public demo)
  DEPLOYMENT_APACHE_HTTPS_ENABLED   : Do you want to add an HTTPs VirtualHost (default: false; values : true | false)
  DEPLOYMENT_PORT_PREFIX            : Default prefix for all ports (2 digits will be added after it for each required port)

  DEPLOYMENT_JVM_SIZE_MAX           : Maximum heap memory size (default: 2g)
  DEPLOYMENT_JVM_SIZE_MIN           : Minimum heap memory size (default: 512m)
  DEPLOYMENT_JVM_PERMSIZE_MAX       : Maximum permgem memory size (default: 256m)
  DEPLOYMENT_OPTS                   : Additional JVM parameters to pass to the startup. Take care to escape characters like \" (default: none)

  DEPLOYMENT_DOCKER_HOST            : The docker host to use to deploy containers (default: unix://)
  DEPLOYMENT_DOCKER_CMD             : The docker command to execute (default: docker)

  DEPLOYMENT_DATABASE_TYPE          : Which database do you want to use for your deployment ? (default: HSQLDB; values : HSQLDB | MYSQL | DOCKER_MYSQL | DOCKER_POSTGRES | DOCKER_MARIADB | DOCKER_ORACLE | DOCKER_SQLSERVER)
  DEPLOYMENT_DATABASE_VERSION       : Which database version do you want to use for your deployment ? (no default)

  DEPLOYMENT_MODE                   : How data are processed during a restart or deployment (default: KEEP_DATA for restart, NO_DATA for deploy; values : NO_DATA - All existing data are removed | KEEP_DATA - Existing data are kept | RESTORE_DATASET - The latest dataset - if exists -  is restored)

  DEPLOYMENT_LDAP_URL               : LDAP URL to use if the server is using one (default: none)
  DEPLOYMENT_LDAP_ADMIN_DN          : LDAP DN to use to logon into the LDAP server
  DEPLOYMENT_LDAP_ADMIN_PWD         : LDAP password to use to logon into the LDAP server

  DEPLOYMENT_OAUTH_FACEBOOK_CLIENT_ID     : Identifier for Facebook OAuth integration (used by community)
  DEPLOYMENT_OAUTH_FACEBOOK_CLIENT_SECRET : Secret for Facebook OAuth integration (used by community)
  DEPLOYMENT_OAUTH_GOOGLE_CLIENT_ID       : Identifier for Google OAuth integration (used by community)
  DEPLOYMENT_OAUTH_GOOGLE_CLIENT_SECRET   : Secret for Facebook OAuth integration (used by community)
  DEPLOYMENT_OAUTH_LINKEDIN_CLIENT_ID     : Identifier for LinkedIn OAuth integration (used by community)
  DEPLOYMENT_OAUTH_LINKEDIN_CLIENT_SECRET : Secret for Facebook OAuth integration (used by community)

  DEPLOYMENT_EXTENSIONS             : Comma separated list of PLF extensions to install. "all" to install all extensions available. Empty string for none. (default: all)

  DEPLOYMENT_ES_ENABLED             : Do we need to configure elasticsearch (default: true; values : true|false)
  DEPLOYMENT_ES_EMBEDDED            : Do we use an embedded Elasticsearch deployment or not (default: true; values: true|false)
  DEPLOYMENT_ES_IMAGE               : Which docker image to use for standalone elasticsearch (default: exoplatform/elasticsearch)
  DEPLOYMENT_ES_IMAGE_VERSION       : Which version of the ES image to use (default 1.1.0)
  DEPLOYMENT_ES_HEAP                : Size of Elasticsearch heap (default: 512m)

EOF

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

  # Docker properties
  configurable_env_var "DEPLOYMENT_DOCKER_HOST"     "unix://"
  configurable_env_var "DEPLOYMENT_DOCKER_CMD"      "docker"
  configurable_env_var "DOCKER_CMD"                 "${DEPLOYMENT_DOCKER_CMD} -H ${DEPLOYMENT_DOCKER_HOST}"

  # ${PRODUCT_BRANCH} is computed from ${PRODUCT_VERSION} and is equal to the version up to the latest dot
  # and with x added. ex : 3.5.0-M4-SNAPSHOT => 3.5.x, 1.1.6-SNAPSHOT => 1.1.x
  env_var PRODUCT_BRANCH `expr "${PRODUCT_VERSION}" : '\([0-9]*\.[0-9]*\).*'`".x"
  env_var PRODUCT_MAJOR_BRANCH `expr "${PRODUCT_VERSION}" : '\([0-9]*\).*'`".x"
  configurable_env_var "INSTANCE_ID" ""

  if [ -z "${INSTANCE_ID}" ]; then
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${PRODUCT_VERSION}"
  else
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${PRODUCT_VERSION}-${INSTANCE_ID}"
  fi

  # validate additional parameters
  case "${ACTION}" in
    start | stop | restart | undeploy | deploy | download-dataset)
    # Mandatory env vars. They need to be defined before launching the script
      validate_env_var "PRODUCT_NAME"
      validate_env_var "PRODUCT_VERSION"
      configurable_env_var "INSTANCE_ID" ""

      # Defaults values we can override by product/branch/version
      env_var "EXO_PROFILES" "-Dexo.profiles=all"
      # Comma separated list of PLF extensions to install. all (by default) to install all extensions available. Empty string for none.
      configurable_env_var "DEPLOYMENT_EXTENSIONS" "all"
      # Comma separated list of PLF add-ons to install using the add-ons manager. Empty string for none. (default: none)
      configurable_env_var "DEPLOYMENT_ADDONS" ""
      configurable_env_var "DEPLOYMENT_ADDONS_CATALOG" ""
      configurable_env_var "DEPLOYMENT_ADDONS_MANAGER_CONFLICT_MODE" "" # used for add-on manager --conflict parameter (default: none) (possible values: fail / skip / overwrite)
      # Additional command line settings to pass to the startup
      configurable_env_var "DEPLOYMENT_OPTS" ""
      configurable_env_var "DEPLOYMENT_APPSRV_VERSION" "7.0.75" #Default version used to download additional resources like JMX lib
      env_var "DEPLOYMENT_DATABASE_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_NAME" ""
      env_var "DEPLOYMENT_DATABASE_USER" ""
      env_var "DEPLOYMENT_GATEIN_CONF_PATH" "gatein/conf/configuration.properties"
      env_var "DEPLOYMENT_SERVER_SCRIPT" "bin/gatein.sh"
      env_var "DEPLOYMENT_SERVER_LOG_FILE" "catalina.out"
      env_var "DEPLOYMENT_APPSRV_TYPE" "tomcat" #Server type

      env_var "DEPLOYMENT_ADDONS_MANAGER_VERSION" "1.0.0-RC4" #Add-ons Manager to use      

      configurable_env_var "REPOSITORY_SERVER_BASE_URL" "https://repository.exoplatform.org"
      configurable_env_var "REPOSITORY_USERNAME" ""
      configurable_env_var "REPOSITORY_PASSWORD" ""

      env_var "DEPLOYMENT_CRASH_ENABLED" false

      configurable_env_var "DEPLOYMENT_ES_ENABLED" true
      configurable_env_var "DEPLOYMENT_ES_EMBEDDED" true
      configurable_env_var "DEPLOYMENT_ES_IMAGE" "exoplatform/elasticsearch"
      configurable_env_var "DEPLOYMENT_ES_IMAGE_VERSION" "1.1.0"

      configurable_env_var "DEPLOYMENT_APACHE_HTTPS_ENABLED" false
      configurable_env_var "DEPLOYMENT_APACHE_WEBSOCKET_ENABLED" true

      configurable_env_var "DEPLOYMENT_CHAT_ENABLED" false
      configurable_env_var "DEPLOYMENT_CHAT_MONGODB_HOSTNAME" "localhost"
      configurable_env_var "DEPLOYMENT_CHAT_MONGODB_PORT" "27017"

      configurable_env_var "DEPLOYMENT_SKIP_ACCOUNT_SETUP" false

      configurable_env_var "DEPLOYMENT_LABELS" ""

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
      env_var "TOMCAT_SETENV_SCRIPT_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "PORTS_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "JMX_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "DB_SERVER_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "DB_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "EMAIL_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "JOD_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "LDAP_GATEIN_PATCH_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "SET_ENV_PRODUCT_NAME" "${PRODUCT_NAME}"
      env_var "STANDALONE_PRODUCT_NAME" "${PRODUCT_NAME}"

      # Validate product and load artifact details
      # Be careful, this id should be no longer than 10 (because of mysql user name limit)
      case "${PRODUCT_NAME}" in
        gatein)
          env_var PRODUCT_DESCRIPTION "GateIn Community edition"
          case "${PRODUCT_BRANCH}" in
            "3.0.x" | "3.1.x" | "3.2.x" | "3.3.x" | "3.4.x")
              env_var ARTIFACT_GROUPID "org.exoplatform.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.pkg.tc6"
              env_var ARTIFACT_CLASSIFIER "bundle"
              env_var DEPLOYMENT_APPSRV_VERSION "6.0.35"
            ;;
            "4.0.x")
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "portal.packaging"
              env_var ARTIFACT_CLASSIFIER "tomcat-distrib"
              env_var ARTIFACT_PACKAGING "tar.gz"
              env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
              env_var DEPLOYMENT_DATABASE_ENABLED false
            ;;
            *)
            # 3.5.x and +
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.tomcat7"
              env_var ARTIFACT_CLASSIFIER "bundle"
            ;;
          esac
          case "${PRODUCT_BRANCH}" in
            "3.5.x")
              env_var PLF_BRANCH "4.1.x"
            ;;
            "3.6.x"|"3.7.x")
              env_var PLF_BRANCH "4.3.x"
            ;;
            "3.8.x"|"4.0.x")
              env_var PLF_BRANCH "4.x"
            ;;
          esac
        ;;
        exogtn)
          env_var PRODUCT_DESCRIPTION "GateIn eXo edition"
          case "${PRODUCT_BRANCH}" in
            "3.2.x")
              env_var PLF_BRANCH "3.5.x"
              env_var ARTIFACT_GROUPID "org.exoplatform.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.assembly"
              env_var ARTIFACT_CLASSIFIER "tomcat"
            ;;
            "3.5.x")
              # for PLF 4.0.x and 4.1.x
              env_var PLF_BRANCH "4.0.x"
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.tomcat7"
              env_var ARTIFACT_CLASSIFIER "bundle"
            ;;
            "3.7.x")
              env_var PLF_BRANCH "4.x"
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.tomcat7"
              env_var ARTIFACT_CLASSIFIER "bundle"
            ;;
            "4.2.x")
              env_var PLF_BRANCH "4.2.x"
              env_var ARTIFACT_GROUPID "org.gatein.portal"
              env_var ARTIFACT_ARTIFACTID "exo.portal.packaging.tomcat.tomcat7"
              env_var ARTIFACT_CLASSIFIER "bundle"
            ;;
            *)
              echo_error "Product 'exogtn' not supported for versions != 3.2.x / 3.5.x / 3.7.x / 4.2.x Please create a SWF to modify acceptance."
              print_usage
              exit 1
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
              env_var DEPLOYMENT_APPSRV_VERSION "6.0.35"
            ;;
            *)
            # 4.0.x and +
              env_var ARTIFACT_GROUPID "org.exoplatform.platform.distributions"
              env_var ARTIFACT_ARTIFACTID "plf-community-tomcat-standalone"
              env_var PLF_BRANCH "${PRODUCT_BRANCH}"
              env_var EXO_PROFILES "all"
            ;;
          esac
        ;;
        codefest)
          env_var PRODUCT_DESCRIPTION "Platform CE"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PLF_BRANCH "CODEFEST"
          env_var ARTIFACT_GROUPID "org.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-community-tomcat-standalone"
          env_var EXO_PROFILES "all"
        ;;
        plfdemo)
          env_var PRODUCT_DESCRIPTION "Platform 4.0 EE Public Demo"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.demo"
          env_var ARTIFACT_ARTIFACTID "demo-login-enterprise-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PLF_BRANCH "${PRODUCT_BRANCH} Demo"
          env_var EXO_PROFILES "all"
          env_var DEPLOYMENT_EXTENSIONS "acme,cmis,crash,ide,wai"
          env_var DEPLOYMENT_SKIP_ACCOUNT_SETUP true
        ;;
        plfent|plfentdemo)
          env_var PRODUCT_DESCRIPTION "Platform EE"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          if [ "${PRODUCT_NAME}" = "plfentdemo" ]; then
            env_var PLF_BRANCH "${PRODUCT_BRANCH} Demo"
          else
            env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          fi
          env_var EXO_PROFILES "all"
        ;;
        plfenteap)
          env_var PRODUCT_DESCRIPTION "Platform EE"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-jbosseap-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/standalone.sh"
          env_var DEPLOYMENT_APPSRV_TYPE "jbosseap"
          env_var DEPLOYMENT_SERVER_LOG_FILE "server.log"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          env_var EXO_PROFILES "all"
        ;;
        # ID should be no longer than 10 (plfenttrial is too long)
        plfentrial|plfsales)
          # Platform EE + chat, remote-edit, site-template, task, video
          env_var PRODUCT_DESCRIPTION "Platform EE Trial"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.platform.distributions"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-trial-tomcat-standalone"
          env_var ARTIFACT_CLASSIFIER "trial"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          env_var EXO_PROFILES "all"
          env_var DEPLOYMENT_CHAT_ENABLED true
        ;;
        addonchat)
          env_var PRODUCT_DESCRIPTION "Platform 4.0 EE + Chat eXo Addon"
          env_var ARTIFACT_REPO_GROUP "private"
          env_var ARTIFACT_GROUPID "com.exoplatform.addons.chat.distribution"
          env_var ARTIFACT_ARTIFACTID "plf-enterprise-chat-tomcat-standalone"
          env_var DEPLOYMENT_SERVER_SCRIPT "bin/catalina.sh"
          env_var PLF_BRANCH "${PRODUCT_BRANCH} Demo"
          env_var EXO_PROFILES "all"
          env_var DEPLOYMENT_EXTENSIONS "crash,ide,chat"
          env_var DEPLOYMENT_CHAT_ENABLED true
        ;;
        compint)
          env_var PRODUCT_DESCRIPTION           "eXo Company Intranet"
          env_var ARTIFACT_REPO_GROUP           "cp"
          env_var ARTIFACT_GROUPID              "com.exoplatform.intranet"
          # 4.0.x and +
          env_var ARTIFACT_ARTIFACTID           "company-intranet-package"
          env_var PLF_BRANCH                    "COMPANY"
          env_var DEPLOYMENT_SERVER_SCRIPT      "bin/catalina.sh"
          env_var EXO_PROFILES                  "all"
          env_var DEPLOYMENT_EXTENSIONS         "crash,ide,chat,newrelic"
          env_var DEPLOYMENT_DATABASE_TYPE      "MYSQL"
          env_var DEPLOYMENT_JVM_SIZE_MAX       "3g"
          env_var DEPLOYMENT_JVM_SIZE_MIN       "2g"
          env_var DEPLOYMENT_JVM_PERMSIZE_MAX   "512m"
          # Datasets remote location
          env_var DATASET_DATA_VALUES_ARCHIVE    "bckintranet@backup.exoplatform.org:/home/bckintranet/intranet-data-values-latest.tar.bz2"
          env_var DATASET_DATA_INDEX_ARCHIVE     "bckintranet@backup.exoplatform.org:/home/bckintranet/intranet-data-index-latest.tar.bz2"
          env_var DATASET_DB_ARCHIVE             "bckintranet@backup.exoplatform.org:/home/bckintranet/intranet-db-latest.tar.bz2"
        ;;
        community)
          env_var PRODUCT_DESCRIPTION           "eXo Community Website"
          env_var ARTIFACT_REPO_GROUP           "cp"
          env_var ARTIFACT_GROUPID              "org.exoplatform.community"
          # 4.0.x and +
          env_var ARTIFACT_ARTIFACTID           "exo-community-package"
          env_var PLF_BRANCH                    "COMPANY"
          env_var DEPLOYMENT_SERVER_SCRIPT      "bin/catalina.sh"
          env_var EXO_PROFILES                  "all"
          env_var DEPLOYMENT_EXTENSIONS         "crash,ide,chat,newrelic"
          env_var DEPLOYMENT_DATABASE_TYPE      "MYSQL"
          # Datasets remote location
          env_var DATASET_DATA_VALUES_ARCHIVE   "bckcommunity@backup.exoplatform.org:/home/bckcommunity_pro05/community-data-values-latest.tar.bz2"
          env_var DATASET_DATA_INDEX_ARCHIVE    "bckcommunity@backup.exoplatform.org:/home/bckcommunity_pro05/community-data-index-latest.tar.bz2"
          env_var DATASET_DB_ARCHIVE            "bckcommunity@backup.exoplatform.org:/home/bckcommunity_pro05/community-db-latest.tar.bz2"
        ;;
        buypage)
          env_var PRODUCT_DESCRIPTION           "eXo Buy Page"
          env_var PLF_BRANCH                    "COMPANY"
          env_var ARTIFACT_REPO_GROUP           "private"
          env_var ARTIFACT_GROUPID              "com.exoplatform.buypage"
          env_var ARTIFACT_ARTIFACTID           "buy-page-package"
          env_var ARTIFACT_CLASSIFIER           "tomcat"
          env_var DEPLOYMENT_SERVER_SCRIPT      "bin/catalina.sh"
          env_var DEPLOYMENT_DATABASE_ENABLED   false
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
            "4.0.x")
              env_var PLF_BRANCH "4.0.x"
              env_var ARTIFACT_ARTIFACTID "platform-documentation-packaging"
            ;;
            "4.1.x")
              env_var PLF_BRANCH "4.1.x"
              env_var ARTIFACT_ARTIFACTID "platform-documentation-packaging"
            ;;
            "4.2.x")
              env_var PLF_BRANCH "4.2.x"
              env_var ARTIFACT_ARTIFACTID "platform-documentation-packaging"
            ;;
            "4.3.x")
              env_var PLF_BRANCH "4.3.x"
              env_var ARTIFACT_ARTIFACTID "platform-documentation-packaging"
            ;;
            *)
              env_var PLF_BRANCH "4.x"
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
      if ${DEPLOYMENT_CHAT_ENABLED}; then
        # Build a database name without dot, minus ...
        env_var DEPLOYMENT_CHAT_MONGODB_NAME "${INSTANCE_KEY}"
        env_var DEPLOYMENT_CHAT_MONGODB_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME//./_}"
        env_var DEPLOYMENT_CHAT_MONGODB_NAME "${DEPLOYMENT_CHAT_MONGODB_NAME//-/_}"
      fi

      if [ -z "${INSTANCE_ID}" ]; then
        env_var "INSTANCE_DESCRIPTION" "${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION}"
      else
        env_var "INSTANCE_DESCRIPTION" "${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} (${INSTANCE_ID})"
      fi

      if [[ "${PRODUCT_NAME}" =~ ^(plf) ]]; then
        # specific configuration for plf deployments
        # - Database drivers
        # - TODO add DEPLOYMENT_APPSRV_VERSION
        if [[ "${PRODUCT_BRANCH}" =~ ^(5.0) ]]; then
          env_var "DEPLOYMENT_FORCE_JDBC_DRIVER_ADDON" "true"
          env_var "DEPLOYMENT_MYSQL_ADDON_VERSION" "1.1.0" # Default version of the mysql driver addon to use
          env_var "DEPLOYMENT_MYSQL_DRIVER_VERSION" "5.1.44" #Default version used to download additional mysql driver
          env_var "DEPLOYMENT_POSTGRESQL_ADDON_VERSION" "1.1.0" # Default version of the jdbc postgresql driver addon to use
          env_var "DEPLOYMENT_POSTGRESQL_DRIVER_VERSION" "42.1.4" #Default version used to download additional postgresql driver
          env_var "DEPLOYMENT_ORACLE_ADDON_VERSION" "1.1.0" # Default version of the oracle jdbc driver addon to use
          env_var "DEPLOYMENT_ORACLE_DRIVER_VERSION" "12.2.0.1"
          env_var "DEPLOYMENT_SQLSERVER_ADDON_VERSION" "1.1.0" # Default version of the sqlserver jdbc driver addon to use
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_GROUPID" "com.microsoft.sqlserver"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_ARTIFACTID" "mssql-jdbc"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_REPO" "public"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_VERSION" "6.2.2.jre8"
        elif [[ "${PRODUCT_BRANCH}" =~ ^([43]) ]]; then
          env_var "DEPLOYMENT_FORCE_JDBC_DRIVER_ADDON" "false"
          env_var "DEPLOYMENT_MYSQL_DRIVER_VERSION" "5.1.25" #Default version used to download additional mysql driver
          env_var "DEPLOYMENT_POSTGRESQL_ADDON_VERSION" "1.0.0" # Default version of the jdbc postgresql driver addon to use
          env_var "DEPLOYMENT_POSTGRESQL_DRIVER_VERSION" "9.4.1208" #Default version used to download additional postgresql driver
          env_var "DEPLOYMENT_ORACLE_DRIVER_VERSION" "12.1.0.1"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_GROUPID" "com.microsoft"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_ARTIFACTID" "sqljdbc"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_REPO" "private"
          env_var "DEPLOYMENT_SQLSERVER_DRIVER_VERSION" "4.0.2206.100"
        else 
          echo_error "Invalid plf version \"${PRODUCT_BRANCH}\""
          exit 1
        fi
      fi

    ;;
    list | start-all | stop-all | restart-all | undeploy-all)
    # Nothing to do
    ;;
    *)
      echo_error "Invalid action \"${ACTION}\""
      print_usage
      exit 1
    ;;
  esac

   do_get_plf_settings
   do_get_database_settings
   do_get_es_settings
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
  env_var ARTIFACT_DL_URL $(do_build_url "${ACCEPTANCE_SCHEME}" "${ACCEPTANCE_HOST}" "${ACCEPTANCE_PORT}" "/downloads/${PRODUCT_NAME}-${ARTIFACT_TIMESTAMP}.${ARTIFACT_PACKAGING}")
  echo_info "Remove downloads older than 15 days ..."
  find ${DL_DIR} -type f -mtime +15 -exec rm {} \;
  echo_info "Remove broken symlinks ..."
  find -L ${DL_DIR} -type l -exec rm {} \;
  echo_info "Remove empty directories ..."
  find ${DL_DIR} -depth -empty -delete
}

do_download_dataset() {
  validate_env_var "DS_DIR"
  validate_env_var "PRODUCT_NAME"
  validate_env_var "PRODUCT_BRANCH"
  validate_env_var "INSTANCE_DESCRIPTION"
  echo_info "Updating local dataset for ${INSTANCE_DESCRIPTION} ${PRODUCT_BRANCH} from the storage server ..."
  if [ ! -z "${DATASET_DATA_VALUES_ARCHIVE}" ] && [ ! -z "${DATASET_DATA_INDEX_ARCHIVE}" ] && [ ! -z "${DATASET_DB_ARCHIVE}" ]; then
    mkdir -p ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}
    display_time rsync --ipv4 -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DB_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/db.tar.bz2
    display_time rsync --ipv4 -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DATA_INDEX_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/index.tar.bz2
    display_time rsync --ipv4 -e ssh --stats --temp-dir=${TMP_DIR} -aLP ${DATASET_DATA_VALUES_ARCHIVE} ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/values.tar.bz2
  else
    echo_error "Datasets not configured"
    exit 1
  fi
  echo_info "Done"
}

do_restore_dataset(){
  # System dependent settings
  if ${LINUX}; then
    env_var "TAR_BZIP2_COMPRESS_PRG" "--use-compress-prog=pbzip2"
    env_var "NICE_CMD" "nice -n 20 ionice -c2 -n7"
  else
    env_var "TAR_BZIP2_COMPRESS_PRG" ""
    env_var "NICE_CMD" "nice -n 20"
  fi

  do_drop_data

  mkdir -p ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/jcr/
  echo_info "Loading values ..."
  display_time ${NICE_CMD} tar ${TAR_BZIP2_COMPRESS_PRG} --directory ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/jcr/ -xf ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/values.tar.bz2
  echo_info "Done"
  echo_info "Loading indexes ..."
  display_time ${NICE_CMD} tar ${TAR_BZIP2_COMPRESS_PRG} --directory ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/jcr/ -xf ${DS_DIR}/${PRODUCT_NAME}-${PRODUCT_BRANCH}/index.tar.bz2
  echo_info "Done"

  if ${DEPLOYMENT_CHAT_ENABLED}; then
    do_drop_chat_mongo_database
    do_create_chat_mongo_database
  fi

  do_restore_database_dataset
}

do_init_empty_data(){
  echo_info "Deleting all existing data for ${INSTANCE_DESCRIPTION} ..."
  if ${DEPLOYMENT_DATABASE_ENABLED}; then
    do_drop_database
    do_create_database
  fi
  if ${DEPLOYMENT_CHAT_ENABLED}; then
    do_drop_chat_mongo_database
    do_create_chat_mongo_database
  fi
  do_drop_es_data
  do_drop_data

  do_create_data
  do_create_es
  echo_info "Done"
}

#
# Drops all data used by the instance.
#
do_drop_data() {
  echo_info "Drops instance indexes ..."
  rm -rf ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/jcr/index/
  echo_info "Done."
  echo_info "Drops instance values ..."
  rm -rf ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}/jcr/values/
  echo_info "Done."
}

#
# Function that unpacks the app server archive
#
do_unpack_server() {
  rm -rf ${TMP_DIR}/${INSTANCE_KEY}
  echo_info "Unpacking server ..."
  mkdir -p ${TMP_DIR}/${INSTANCE_KEY}
  set +e
  case ${ARTIFACT_PACKAGING} in
    zip)
      unzip -q ${ARTIFACT_LOCAL_PATH} -d ${TMP_DIR}/${INSTANCE_KEY}
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo_warn "unpack of the server failed. We will try to download it a second time."
        rm ${ARTIFACT_LOCAL_PATH}
        do_download_server
        unzip -q ${ARTIFACT_LOCAL_PATH} -d ${TMP_DIR}/${INSTANCE_KEY}
        if [ "$?" -ne "0" ]; then
          echo_error "Unable to unpack the server."
          exit 1
        fi
      fi
    ;;
    tar.gz)
      cd ${TMP_DIR}/${INSTANCE_KEY}
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
  DEPLOYMENT_PID_FILE=${SRV_DIR}/${INSTANCE_KEY}.pid
  mkdir -p ${SRV_DIR}
  echo_info "Deleting existing server ..."
  rm -rf ${SRV_DIR}/${INSTANCE_KEY}
  echo_info "Done"
  cp -rf ${TMP_DIR}/${INSTANCE_KEY} ${SRV_DIR}/${INSTANCE_KEY}
  rm -rf ${TMP_DIR}/${INSTANCE_KEY}

  # We search the server directory
  pushd `find ${SRV_DIR}/${INSTANCE_KEY} -maxdepth 4 -mindepth 1 -name bin -type d`/.. > /dev/null
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
  if ${DEPLOYMENT_APACHE_WEBSOCKET_ENABLED}; then
    evaluate_file_content ${ETC_DIR}/apache2/includes/instance-ws.include.template ${APACHE_CONF_DIR}/includes/${DEPLOYMENT_EXT_HOST}.include
  else
    evaluate_file_content ${ETC_DIR}/apache2/includes/instance.include.template ${APACHE_CONF_DIR}/includes/${DEPLOYMENT_EXT_HOST}.include
  fi
  case ${DEPLOYMENT_APACHE_SECURITY} in
    public)
      if ${DEPLOYMENT_APACHE_HTTPS_ENABLED}; then
        if [ -f "${APACHE_SSL_CERTIFICATE_FILE}" ] && [ -f "${APACHE_SSL_CERTIFICATE_KEY_FILE}" ] && [ -f "${APACHE_SSL_CERTIFICATE_CHAIN_FILE}" ]; then
          echo_n_info "Deploying Apache instance configuration for HTTP and HTTPS..."
          evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-public-with-https.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
          echo "OK."
        else
          echo_error "Deploying instance with HTTPS scheme but one of \${APACHE_SSL_CERTIFICATE_FILE} (\"${APACHE_SSL_CERTIFICATE_FILE}\"),\${APACHE_SSL_CERTIFICATE_KEY_FILE} (\"${APACHE_SSL_CERTIFICATE_KEY_FILE}\"),\${APACHE_SSL_CERTIFICATE_CHAIN_FILE} (\"${APACHE_SSL_CERTIFICATE_CHAIN_FILE}\") is invalid"
          print_usage
          exit 1
        fi
      else
          echo_n_info "Deploying Apache instance configuration for HTTP only..."
          evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-public.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
          echo "OK."
      fi
    ;;
    private)
      if ${DEPLOYMENT_APACHE_HTTPS_ENABLED}; then
        if [ -f "${APACHE_SSL_CERTIFICATE_FILE}" ] && [ -f "${APACHE_SSL_CERTIFICATE_KEY_FILE}" ] && [ -f "${APACHE_SSL_CERTIFICATE_CHAIN_FILE}" ]; then
          echo_n_info "Deploying Apache instance configuration for HTTP and HTTPS..."
          evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-private-with-https.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
          echo "OK."
        else
          echo_error "Deploying instance with HTTPS scheme but one of \${APACHE_SSL_CERTIFICATE_FILE} (\"${APACHE_SSL_CERTIFICATE_FILE}\"),\${APACHE_SSL_CERTIFICATE_KEY_FILE} (\"${APACHE_SSL_CERTIFICATE_KEY_FILE}\"),\${APACHE_SSL_CERTIFICATE_CHAIN_FILE} (\"${APACHE_SSL_CERTIFICATE_CHAIN_FILE}\") is invalid"
          print_usage
          exit 1
        fi
      else
          echo_n_info "Deploying Apache instance configuration for HTTP only..."
          evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-private.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
          echo "OK."
      fi
    ;;
    *)
      echo_error "Invalid apache security type \"${DEPLOYMENT_APACHE_SECURITY}\""
      print_usage
      exit 1
    ;;
  esac
  DEPLOYMENT_LOG_URL=${DEPLOYMENT_URL}/logs/${DEPLOYMENT_SERVER_LOG_FILE}
  echo_info "Done."
  echo_info "Rotate Apache logs ..."

  evaluate_file_content ${ETC_DIR}/logrotate.d/instance.template ${TMP_DIR}/logrotate-${INSTANCE_KEY}
  do_logrotate "${TMP_DIR}/logrotate-${INSTANCE_KEY}" ${ADT_DEV_MODE}
  rm ${TMP_DIR}/logrotate-${INSTANCE_KEY}

  evaluate_file_content ${ETC_DIR}/logrotate.d/frontend.template ${TMP_DIR}/logrotate-acceptance
  do_logrotate "${TMP_DIR}/logrotate-acceptance" ${ADT_DEV_MODE}
  rm ${TMP_DIR}/logrotate-acceptance

  do_reload_apache ${ADT_DEV_MODE}

  echo_info "Done."
}

do_create_deployment_descriptor() {
  echo_info "Creating deployment descriptor ..."
  mkdir -p ${ADT_CONF_DIR}
  evaluate_file_content ${ETC_DIR}/adt/config.template ${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}
  echo_info "Done."
}

do_load_deployment_descriptor() {
  if [ ! -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
    echo_warn "${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
    echo_warn "You need to deploy it first."
    exit 1
  else
    source ${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}
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
  configurable_env_var "DEPLOYMENT_UMASK_VALUE" "0002"
  if ${DEPLOYMENT_CHAT_ENABLED}; then
    validate_env_var "DEPLOYMENT_CHAT_WEEMO_KEY"
  fi

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

  # Elasticsearch (ES) ports
  env_var "DEPLOYMENT_ES_HTTP_PORT" "${DEPLOYMENT_PORT_PREFIX}10"

  if ${ADT_DEV_MODE}; then
    env_var "DEPLOYMENT_EXT_HOST" "localhost"
    env_var "DEPLOYMENT_EXT_PORT" "${DEPLOYMENT_HTTP_PORT}"
  else
    env_var "DEPLOYMENT_EXT_HOST" "${INSTANCE_KEY}.${ACCEPTANCE_HOST}"
    env_var "DEPLOYMENT_EXT_PORT" "80"
  fi

  if [ -z ${DEPLOYMENT_APACHE_VHOST_ALIAS} ]; then
    env_var "DEPLOYMENT_URL" $(do_build_url "http" "${DEPLOYMENT_EXT_HOST}" "${DEPLOYMENT_EXT_PORT}" "")
  else
    env_var "DEPLOYMENT_URL" $(do_build_url "http" "${DEPLOYMENT_APACHE_VHOST_ALIAS}" "${DEPLOYMENT_EXT_PORT}" "")
  fi


  echo_info "Deploying server ${INSTANCE_DESCRIPTION} ..."

  do_download_server
  if [ -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
    # Stop the server
    do_stop
  fi

  if [ "${DEPLOYMENT_MODE}" == "KEEP_DATA" ]; then
    echo_info "Archiving existing data ${INSTANCE_DESCRIPTION} ..."
    _tmpdir=`mktemp -d -t archive-data.XXXXXXXXXX` || exit 1
    echo_info "Using temporary directory ${_tmpdir}"
    if [ ! -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
      echo_warn "This instance wasn't deployed before. Nothing to keep."
      mkdir -p ${_tmpdir}/$(basename ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR})
      do_create_database
      if ${DEPLOYMENT_CHAT_ENABLED}; then
        do_create_chat_mongo_database
      fi
      do_create_es
    else
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      # The server have been already deployed.
      # We load its settings from the configuration
      do_load_deployment_descriptor
      if [ -d "${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}" ]; then
        mv ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR} ${_tmpdir}
      else
        mkdir -p ${_tmpdir}/$(basename ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR})
        do_create_database
        if ${DEPLOYMENT_CHAT_ENABLED}; then
          do_create_chat_mongo_database
        fi
        do_create_es
      fi
      )
    fi
    echo_info "Done."
  fi

  do_unpack_server

  # Initialize database before configuratation
  # before with docker the datase must be started before to retreive the port number
  case "${DEPLOYMENT_MODE}" in
    NO_DATA)
      do_init_empty_data
    ;;
    KEEP_DATA)
      echo_info "Restoring previous data ${INSTANCE_DESCRIPTION} ..."
      rm -rf ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}
      mkdir -p $(dirname ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR})
      mv ${_tmpdir}/$(basename ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}) ${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}
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
  echo_info "Starting server ${INSTANCE_DESCRIPTION} ..."
  chmod 755 ${DEPLOYMENT_DIR}/bin/*.sh
  mkdir -p $(dirname ${DEPLOYMENT_LOG_PATH})
  cd `dirname ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT}`

  # We need to backup existing logs if they already exist
  backup_file $(dirname ${DEPLOYMENT_LOG_PATH}) "${DEPLOYMENT_SERVER_LOG_FILE}"

  do_start_database
  do_start_es

  case ${DEPLOYMENT_APPSRV_TYPE} in
    tomcat)
      END_STARTUP_MSG="Server startup in"
      CATALINA_OPTS=""

      if [ ! -f "${DEPLOYMENT_DIR}/bin/setenv-local.sh" ]; then
        export CATALINA_HOME=${DEPLOYMENT_DIR}
        export CATALINA_PID=${DEPLOYMENT_PID_FILE}
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
        # Elasticsearch
        CATALINA_OPTS="${CATALINA_OPTS} -Des.http.port=${DEPLOYMENT_ES_HTTP_PORT}"
        CATALINA_OPTS="${CATALINA_OPTS} -Dexo.es.index.server.url=http://127.0.0.1:${DEPLOYMENT_ES_HTTP_PORT}"
        CATALINA_OPTS="${CATALINA_OPTS} -Dexo.es.search.server.url=http://127.0.0.1:${DEPLOYMENT_ES_HTTP_PORT}"
        CATALINA_OPTS="${CATALINA_OPTS} -Des.path.data==${DEPLOYMENT_DIR}/${DEPLOYMENT_DATA_DIR}"
        export CATALINA_OPTS
        export EXO_PROFILES="${EXO_PROFILES}"
      fi
      # Additional settings
      export CATALINA_OPTS="${CATALINA_OPTS} ${DEPLOYMENT_OPTS}"
      # Startup the server
      ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT} start
    ;;
    jbosseap)
      case ${DEPLOYMENT_APPSRV_VERSION:0:1} in
        6)
          END_STARTUP_MSG="JBAS01587[45]"
        ;;
        7)
          END_STARTUP_MSG="WFLYSRV0025"
        ;;
        *)
          echo_error "Invalid JBoss EAP server version \"${DEPLOYMENT_APPSRV_VERSION}\""
          print_usage
          exit 1
        ;;
      esac
      # Additional settings
      export JAVA_OPTS="${DEPLOYMENT_OPTS}"
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
    sleep 1
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
    sleep 1
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
  if [ ! -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
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
      echo_info "Stopping server ${INSTANCE_DESCRIPTION} ... "

      if [ -e ${DEPLOYMENT_PID_FILE} ]; then
        # Testing if pid file is valid
        set +e
        ps $(cat ${DEPLOYMENT_PID_FILE}) > /dev/null
        if [ $? -ne 0 ]; then
          echo_warn "PID file detected but process is not running, removing it..."
          rm ${DEPLOYMENT_PID_FILE}
        fi
        set -e
      fi

      case ${DEPLOYMENT_APPSRV_TYPE} in
        tomcat)
          if [ ! -f "${DEPLOYMENT_DIR}/bin/setenv-local.sh" ]; then
            export CATALINA_HOME=${DEPLOYMENT_DIR}
            export CATALINA_PID=${DEPLOYMENT_PID_FILE}
          fi
          ${DEPLOYMENT_DIR}/${DEPLOYMENT_SERVER_SCRIPT} stop 60 -force > /dev/null 2>&1 || true
        ;;
        jbosseap)
          case ${DEPLOYMENT_APPSRV_VERSION:0:1} in
            6)
              ${DEPLOYMENT_DIR}/bin/jboss-cli.sh --controller=localhost:${DEPLOYMENT_MGT_NATIVE_PORT} --connect command=:shutdown > /dev/null 2>&1 || true
            ;;
            7)
              ${DEPLOYMENT_DIR}/bin/jboss-cli.sh --controller=localhost:${DEPLOYMENT_MGT_HTTP_PORT} --connect --command=shutdown > /dev/null 2>&1 || true
            ;;
            *)
              echo_error "Invalid JBoss EAP server version \"${DEPLOYMENT_APPSRV_VERSION}\""
              print_usage
              exit 1
            ;;
          esac
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

      do_stop_database
      do_stop_es

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
  if [ ! -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
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
    do_drop_es_data
    echo_info "Undeploying server ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
    # Delete Awstat config
    rm -f ${AWSTATS_CONF_DIR}/awstats.${DEPLOYMENT_EXT_HOST}.conf
    # Delete the vhost
    rm -f ${APACHE_CONF_DIR}/includes/${DEPLOYMENT_EXT_HOST}.include
    rm -f ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
    # Reload Apache to deactivate the config
    do_reload_apache ${ADT_DEV_MODE}
    # Delete the server
    rm -rf ${SRV_DIR}/${INSTANCE_KEY}
    # Close firewall ports
    do_ufw_close_port ${DEPLOYMENT_RMI_REG_PORT} "JMX RMI REG" ${ADT_DEV_MODE}
    do_ufw_close_port ${DEPLOYMENT_RMI_SRV_PORT} "JMX RMI SRV" ${ADT_DEV_MODE}
    do_ufw_close_port ${DEPLOYMENT_CRASH_SSH_PORT} "CRaSH SSH" ${ADT_DEV_MODE}
    echo_info "Server undeployed"
    # Delete the deployment descriptor
    rm ${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}
    )
  fi
}

#
# Function that lists all deployed servers
#
do_list() {
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
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
      printf "%-40s %-25s %-25s %-10s %-10s %10s %10s %10s %10s %10s %10s %-10s\n" "${PRODUCT_DESCRIPTION}" "${PRODUCT_VERSION}" "${INSTANCE_ID}" "${DEPLOYMENT_APPSRV_TYPE}" "${DEPLOYMENT_DATABASE_TYPE}" "${DEPLOYMENT_PORT_PREFIX}XX" "${DEPLOYMENT_HTTP_PORT}" "${DEPLOYMENT_AJP_PORT}" "${DEPLOYMENT_RMI_REG_PORT}" "${DEPLOYMENT_RMI_SRV_PORT}" "${DEPLOYMENT_CRASH_SSH_PORT}" "$STATUS"
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
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
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
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
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
