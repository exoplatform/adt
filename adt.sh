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

# Load functions
source "${SCRIPT_DIR}/_functions.sh"

echo_info "# ======================================================================="
echo_info "# $SCRIPT_NAME"
echo_info "# ======================================================================="

# Configurable env vars. These variables can be loaded
# from the env, /etc/default/adt or $HOME/.adtrc

# Development mode ?
configurable_env_var "ADT_DEV_MODE" false
${ADT_DEV_MODE} && echo_warn "Development Mode activated."

# Offline mode ?
configurable_env_var "ADT_OFFLINE" false
${ADT_OFFLINE} && echo_warn "Offline Mode activated !!!"

# Data directory (this script directory by default)
configurable_env_var "ADT_DATA" "${SCRIPT_DIR}"
if [ -d ${ADT_DATA} ]; then
  # Convert to an absolute path
  pushd ${ADT_DATA} > /dev/null
  ADT_DATA=`pwd -P`
  popd > /dev/null
fi
echo_info "ADT_DATA = ${ADT_DATA}"
# Create ADT_DATA if required
mkdir -p ${ADT_DATA}
env_var "TMP_DIR" "${ADT_DATA}/tmp"
export TMPDIR=${TMP_DIR}
env_var "DL_DIR" "${ADT_DATA}/downloads"
env_var "DS_DIR" "${ADT_DATA}/datasets"
env_var "SRV_DIR" "${ADT_DATA}/servers"
env_var "SRC_DIR" "${ADT_DATA}/sources"
env_var "CONF_DIR" "${ADT_DATA}/conf"
env_var "APACHE_CONF_DIR" "${ADT_DATA}/conf/apache"
env_var "AWSTATS_CONF_DIR" "${ADT_DATA}/conf/awstats"
env_var "ADT_CONF_DIR" "${ADT_DATA}/conf/adt"
env_var "FEATURES_CONF_DIR" "${ADT_DATA}/conf/features"
env_var "INSTANCES_CONF_DIR" "${ADT_DATA}/conf/instances"
env_var "ETC_DIR" "${ADT_DATA}/etc"

env_var "CURR_DATE" `date -u "+%Y%m%d.%H%M%S"`
env_var "REPOS_LIST" "meeds-io:gatein-wci meeds-io:kernel meeds-io:core meeds-io:ws meeds-io:gatein-sso meeds-io:portlet-container meeds-io:portal meeds-io:maven-depmgt-pom meeds-io:platform-ui meeds-io:commons meeds-io:social meeds-io:layout meeds-io:auth-server meeds-io:mcp-server Meeds-io:analytics meeds-io:gamification meeds-io:poll meeds-io:gamification-github meeds-io:gamification-twitter meeds-io:gamification-crowdin meeds-io:gamification-evm meeds-io:wallet meeds-io:kudos meeds-io:perk-store meeds-io:app-center meeds-io:push-notifications meeds-io:notes meeds-io:content Meeds-io:task Meeds-io:pwa Meeds-io:ide Meeds-io:ai Meeds-io:matrix meeds-io:deeds-tenant meeds-io:addons-manager meeds-io:meeds exoplatform:agenda exoplatform:agenda-connectors exoplatform:caldav-integration exoplatform:maven-exo-depmgt-pom exoplatform:commons-exo exoplatform:jcr exoplatform:ecms exoplatform:chat-application exoplatform:data-upgrade exoplatform:digital-workplace exoplatform:layout-management exoplatform:news exoplatform:onlyoffice exoplatform:saml2-addon exoplatform:processes exoplatform:web-conferencing exoplatform:jitsi exoplatform:jitsi-call exoplatform:external-visio-connector exoplatform:multifactor-authentication exoplatform:microservices exoplatform:automatic-translation exoplatform:documents exoplatform:forms exoplatform:dlp exoplatform:mail-integration exoplatform:email-connector exoplatform:anti-malware exoplatform:anti-bruteforce exoplatform:platform-private-distributions"

if ${ADT_DEV_MODE}; then
  configurable_env_var "ACCEPTANCE_SCHEME"  "http"
  configurable_env_var "ACCEPTANCE_HOST"    "localhost"
  configurable_env_var "ACCEPTANCE_PORT"    "8080"
  configurable_env_var "ACCEPTANCE_SERVERS" "localhost"
else
  configurable_env_var "ACCEPTANCE_SCHEME"  "https"
  configurable_env_var "ACCEPTANCE_HOST"    "acceptance.exoplatform.org"
  configurable_env_var "ACCEPTANCE_PORT"    "443"
  configurable_env_var "ACCEPTANCE_SERVERS" "https://acceptance.exoplatform.org"
fi
# The front-end (adt-web): binary, unix socket Apache proxies to, service and its environment file
configurable_env_var "ADT_WEB_BIN"          "${ADT_DATA}/bin/adt-web"
configurable_env_var "ADT_WEB_SOCKET"       "/run/adt-web/adt-web.sock"
configurable_env_var "ADT_WEB_SOCKET_GROUP" "www-data"
configurable_env_var "ADT_WEB_SERVICE"      "adt-web"
configurable_env_var "ADT_WEB_ENV_FILE"     "${ADT_DATA}/conf/adt-web.env"
configurable_env_var "ADT_WEB_CSP"          "enforce"
configurable_env_var "ADT_ADMIN_USERS"      ""
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
validate_env_var "INSTANCES_CONF_DIR"
mkdir -p ${ETC_DIR}
mkdir -p ${TMP_DIR}
mkdir -p ${DL_DIR}
mkdir -p ${DS_DIR}
mkdir -p ${SRV_DIR}
mkdir -p ${SRC_DIR}
mkdir -p ${CONF_DIR}
mkdir -p ${APACHE_CONF_DIR}/conf.d
mkdir -p ${APACHE_CONF_DIR}/sites-available
mkdir -p ${APACHE_CONF_DIR}/includes
mkdir -p ${ADT_CONF_DIR}
mkdir -p ${FEATURES_CONF_DIR}
chmod 777 ${FEATURES_CONF_DIR} # apache needs to write here
mkdir -p ${INSTANCES_CONF_DIR}
chmod 777 ${INSTANCES_CONF_DIR} # apache needs to write here
mkdir -p ${ADT_DATA}/var/sessions
chmod 777 ${ADT_DATA}/var/sessions # apache tracks login sessions here
# Read by Apache on every request (evicted sessions): must exist, even empty
touch ${ADT_DATA}/var/sessions/revoked.txt
chmod 666 ${ADT_DATA}/var/sessions/revoked.txt
mkdir -p ${ADT_DATA}/var/audit
chmod 777 ${ADT_DATA}/var/audit # apache appends the audit log of dashboard actions here
# Recopy default data
# Copy everything in it
if [[ "${SCRIPT_DIR}" != "${ADT_DATA}" ]]; then
  rm -rf ${ETC_DIR}/*
  cp -rf ${SCRIPT_DIR}/* ${ADT_DATA}
fi

# no action ? provide help
if [ $# -lt 1 ]; then
  echo_error "No action defined !"
  print_usage
  exit 1
fi

# If help is asked
if [ $1 == "-h" ]; then
  print_usage
  exit
fi

# Action to do
ACTION=$1
shift

case "${ACTION}" in
  init)
    clone_or_fetch_git_repos ${ADT_OFFLINE} ${SRC_DIR} ${REPOS_LIST}
    validate_env_var "ADT_DATA"
    validate_env_var "ACCEPTANCE_SCHEME"
    validate_env_var "ACCEPTANCE_HOST"
    # Create the main vhost from the template
    configurable_env_var "CROWD_ACCEPTANCE_APP_NAME" ""
    configurable_env_var "CROWD_ACCEPTANCE_APP_PASSWORD" ""
    configurable_env_var "LDAP_ACCEPTANCE_APACHE2_ADMIN_DN" "cn=exo-team-swf,ou=groups,dc=exoplatform,dc=org"
    configurable_env_var "APACHE_SSL_CERTIFICATE_FILE" ""
    configurable_env_var "APACHE_SSL_CERTIFICATE_KEY_FILE" ""
    validate_env_var "CROWD_ACCEPTANCE_APP_NAME"
    validate_env_var "CROWD_ACCEPTANCE_APP_PASSWORD"
    evaluate_file_content ${ETC_DIR}/apache2/conf.d/adt.conf.j2 ${APACHE_CONF_DIR}/conf.d/adt.conf
    # The parts the virtual hosts share: compression, TLS settings and the security headers
    for _include in compression tls security-headers; do
      evaluate_file_content ${ETC_DIR}/apache2/includes/${_include}.include.j2 ${APACHE_CONF_DIR}/includes/${_include}.include
    done
    evaluate_file_content ${ETC_DIR}/apache2/includes/frontend.include.j2 ${APACHE_CONF_DIR}/includes/acceptance-frontend.include
    # holds the LDAP bind password and the session passphrase: Apache reads its configuration as root
    chmod 600 ${APACHE_CONF_DIR}/includes/acceptance-frontend.include
    # Fix : Remove any include in the wrong directory
    rm -f ${APACHE_CONF_DIR}/sites-available/*.include
    case "${ACCEPTANCE_SCHEME}" in
      http)
        echo_info "Deploying Apache FrontEnd configuration for HTTP"
        evaluate_file_content ${ETC_DIR}/apache2/sites-available/frontend.j2 ${APACHE_CONF_DIR}/sites-available/acceptance.exoplatform.org
        echo_info "Done."
      ;;
      https)
        if [ -f "${APACHE_SSL_CERTIFICATE_FILE}" ] && [ -f "${APACHE_SSL_CERTIFICATE_KEY_FILE}" ]; then
          echo_info "Deploying Apache FrontEnd configuration for HTTP/HTTPS"
          evaluate_file_content ${ETC_DIR}/apache2/sites-available/frontend-full-https.j2 ${APACHE_CONF_DIR}/sites-available/acceptance.exoplatform.org
          echo_info "Done."
        else
          echo_error "Deploying Front End with HTTPS scheme but one of \${APACHE_SSL_CERTIFICATE_FILE} (\"${APACHE_SSL_CERTIFICATE_FILE}\"),\${APACHE_SSL_CERTIFICATE_KEY_FILE} (\"${APACHE_SSL_CERTIFICATE_KEY_FILE}\") is invalid"
          print_usage
          exit 1
        fi
      ;;
      *)
        echo_error "Invalid scheme \"${ACCEPTANCE_SCHEME}\""
        print_usage
        exit 1
      ;;
    esac
    if ! ${ADT_DEV_MODE}; then
      # The vhost proxies to adt-web: it must be built, configured and answering before Apache is reloaded
      do_deploy_web
      if [ -e /usr/sbin/service -a -e /etc/init.d/apache2 ]; then
        echo_info "Reloading Apache server ..."
        sudo /usr/sbin/service apache2 reload
        echo_info "Done."
      else
        echo_error "It is impossible to reload Apache. Did you install Apache2 ?"
      fi
    else
      echo_warn "Development Mode: No Apache server reload."
    fi
  ;;
  deploy)
    configurable_env_var "DEPLOYMENT_MODE" "NO_DATA"
    initialize_product_settings
    do_deploy
  ;;
  download-dataset)
    echo_error "download-dataset is gone: it fetched the datasets of products that are no longer supported. Datasets are written by DEPLOYMENT_MODE=DUMP_DATASET, or copied to ${DS_DIR}."
    exit 1
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
    configurable_env_var "DEPLOYMENT_MODE" "KEEP_DATA"
    initialize_product_settings
    do_restart
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
    configurable_env_var "DEPLOYMENT_MODE" "KEEP_DATA"
    do_restart_all
  ;;
  undeploy-all)
    do_undeploy_all
  ;;
  update-repos)
    clone_or_fetch_git_repos ${ADT_OFFLINE} ${SRC_DIR} ${REPOS_LIST}
  ;;
  build-web)
    do_build_web
  ;;
  deploy-web)
    do_deploy_web
  ;;
  web-server)
    env_var "ADT_DEV_MODE" "true"
    clone_or_fetch_git_repos ${ADT_OFFLINE} ${SRC_DIR} ${REPOS_LIST}
    do_load_web_server
  ;;
  *)
    echo_error "Invalid action \"${ACTION}\""
    print_usage
    exit 1
  ;;
esac

exit 0
