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
  ADT_DATA=$(pwd -P)
  popd > /dev/null
fi
echo_info "ADT_DATA = ${ADT_DATA}"
# Create ADT_DATA if required
mkdir -p ${ADT_DATA}
env_var "TMP_DIR" "${ADT_DATA}/tmp"
export TMPDIR=${TMP_DIR}
env_var "DL_DIR" "${ADT_DATA}/downloads"
env_var "DS_DIR" "${ADT_DATA}/datasets"
env_var "PROJECTS_DIR" "${ADT_DATA}/projects"
env_var "SRC_DIR" "${ADT_DATA}/sources"
env_var "CONF_DIR" "${ADT_DATA}/conf"
env_var "ADT_CONF_DIR" "${ADT_DATA}/conf/adt"
env_var "INSTANCES_CONF_DIR" "${ADT_DATA}/conf/instances"
env_var "ETC_DIR" "${SCRIPT_DIR}/etc"

env_var "CURR_DATE" "$(date -u "+%Y%m%d.%H%M%S")"

# Docker / j2cli defaults
configurable_env_var "DEPLOYMENT_DOCKER_CMD" "docker"
configurable_env_var "DEPLOYMENT_DOCKER_HOST" "unix://"
env_var "DOCKER_CMD" "${DEPLOYMENT_DOCKER_CMD} -H ${DEPLOYMENT_DOCKER_HOST}"
configurable_env_var "DEPLOYMENT_J2CLI_IMAGE" "exoplatform/j2cli"
configurable_env_var "DEPLOYMENT_J2CLI_VERSION" "1.0.0"

# Frontend network & Traefik
configurable_env_var "DEPLOYMENT_FRONTEND_NETWORK" "reverse_proxy"
configurable_env_var "DEPLOYMENT_TRAEFIK_ENTRYPOINT" "websecure"

# TLS defaults (set in /etc/default/adt or ~/.adtrc)
configurable_env_var "ADT_SSL_CERTIFICATE_FILE" ""
configurable_env_var "ADT_SSL_CERTIFICATE_KEY_FILE" ""
configurable_env_var "ADT_SSL_CERTIFICATE_CHAIN_FILE" ""
configurable_env_var "MEEDSIO_SSL_CERTIFICATE_FILE" ""
configurable_env_var "MEEDSIO_SSL_CERTIFICATE_KEY_FILE" ""
configurable_env_var "MEEDSIO_SSL_CERTIFICATE_CHAIN_FILE" ""

# Repository
configurable_env_var "REPOSITORY_SERVER_BASE_URL" "https://repository.exoplatform.org"
configurable_env_var "REPOSITORY_USERNAME" ""
configurable_env_var "REPOSITORY_PASSWORD" ""

# Start timeout (seconds to wait for app healthcheck)
configurable_env_var "DEPLOYMENT_START_TIMEOUT" 600

# Repos list for the dashboard feature-branch scanning (Meeds + eXo public orgs)
env_var "REPOS_LIST" "meeds-io:gatein-wci meeds-io:kernel meeds-io:core meeds-io:ws meeds-io:gatein-sso meeds-io:portlet-container meeds-io:portal meeds-io:maven-depmgt-pom meeds-io:platform-ui meeds-io:commons meeds-io:social meeds-io:layout meeds-io:auth-server meeds-io:mcp-server meeds-io:analytics meeds-io:gamification meeds-io:poll meeds-io:gamification-github meeds-io:gamification-twitter meeds-io:gamification-crowdin meeds-io:gamification-evm meeds-io:wallet meeds-io:kudos meeds-io:perk-store meeds-io:app-center meeds-io:push-notifications meeds-io:notes meeds-io:content meeds-io:task meeds-io:pwa meeds-io:ide meeds-io:ai meeds-io:matrix meeds-io:deeds-tenant meeds-io:addons-manager meeds-io:meeds exoplatform:agenda exoplatform:agenda-connectors exoplatform:maven-exo-depmgt-pom exoplatform:commons-exo exoplatform:jcr exoplatform:ecms exoplatform:chat-application exoplatform:data-upgrade exoplatform:digital-workplace exoplatform:layout-management exoplatform:news exoplatform:onlyoffice exoplatform:saml2-addon exoplatform:processes exoplatform:web-conferencing exoplatform:jitsi exoplatform:jitsi-call exoplatform:external-visio-connector exoplatform:multifactor-authentication exoplatform:microservices exoplatform:automatic-translation exoplatform:documents exoplatform:dlp exoplatform:mail-integration exoplatform:email-connector exoplatform:anti-malware exoplatform:anti-bruteforce exoplatform:platform-private-distributions"

if ${ADT_DEV_MODE}; then
  configurable_env_var "ACCEPTANCE_SCHEME"  "https"
  configurable_env_var "ACCEPTANCE_HOST"    "localhost"
  configurable_env_var "ACCEPTANCE_PORT"    "443"
  configurable_env_var "ACCEPTANCE_SERVERS" "localhost"
else
  configurable_env_var "ACCEPTANCE_SCHEME"  "https"
  configurable_env_var "ACCEPTANCE_HOST"    "acceptance.exoplatform.org"
  configurable_env_var "ACCEPTANCE_PORT"    "443"
  configurable_env_var "ACCEPTANCE_SERVERS" "https://acceptance.exoplatform.org"
fi

validate_env_var "SCRIPT_DIR"
validate_env_var "ADT_DATA"
validate_env_var "ETC_DIR"
validate_env_var "TMP_DIR"
validate_env_var "DL_DIR"
validate_env_var "DS_DIR"
validate_env_var "PROJECTS_DIR"
validate_env_var "CONF_DIR"
validate_env_var "ADT_CONF_DIR"
validate_env_var "INSTANCES_CONF_DIR"

mkdir -p ${TMP_DIR} ${DL_DIR} ${DS_DIR} ${PROJECTS_DIR} ${SRC_DIR} ${CONF_DIR} ${ADT_CONF_DIR} ${INSTANCES_CONF_DIR}

# no action ? provide help
if [ $# -lt 1 ]; then
  echo_error "No action defined !"
  print_usage
  exit 1
fi

# If help is asked
if [ $1 == "-h" ] || [ $1 == "--help" ]; then
  print_usage
  exit
fi

# Action to do
ACTION=$1
shift

case "${ACTION}" in
  init)
    do_init
  ;;
  deploy)
    configurable_env_var "DEPLOYMENT_MODE" "NO_DATA"
    validate_env_var "PRODUCT_NAME"
    validate_env_var "PRODUCT_VERSION"
    compute_instance_key
    initialize_product_settings
    do_deploy
  ;;
  download-dataset)
    validate_env_var "PRODUCT_NAME"
    validate_env_var "PRODUCT_VERSION"
    compute_instance_key
    initialize_product_settings
    do_download_dataset
  ;;
  dump-dataset)
    load_instance
    do_dump_dataset
  ;;
  import-dataset)
    validate_env_var "PRODUCT_NAME"
    validate_env_var "PRODUCT_VERSION"
    validate_env_var "DEPLOYMENT_DATASET_FILE"
    compute_instance_key
    initialize_product_settings
    do_import_v1_dataset
  ;;
  start)
    do_start
  ;;
  stop)
    do_stop
  ;;
  restart)
    configurable_env_var "DEPLOYMENT_MODE" "KEEP_DATA"
    do_restart
  ;;
  undeploy)
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
  web-server)
    env_var "ADT_DEV_MODE" "true"
    clone_or_fetch_git_repos ${ADT_OFFLINE} ${SRC_DIR} ${REPOS_LIST}
    do_load_php_server
  ;;
  *)
    echo_error "Invalid action \"${ACTION}\""
    print_usage
    exit 1
  ;;
esac

exit 0
