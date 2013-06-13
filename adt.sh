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
# Convert to an absolute path
pushd ${ADT_DATA} > /dev/null
ADT_DATA=`pwd -P`
popd > /dev/null
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
env_var "ETC_DIR" "${ADT_DATA}/etc"

env_var "CURR_DATE" `date -u "+%Y%m%d.%H%M%S"`
env_var "REPOS_LIST" "exodev:platform-ui exodev:commons exodev:calendar exodev:forum exodev:wiki exodev:social exodev:ecms exodev:integration exodev:platform exoplatform:platform-public-distributions exoplatform:platform-private-distributions"

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
    init
    clone_or_fetch_git_repos ${ADT_OFFLINE} ${SRC_DIR} ${REPOS_LIST}
    # Create the main vhost from the template
    configurable_env_var "CROWD_ACCEPTANCE_APP_NAME" ""
    configurable_env_var "CROWD_ACCEPTANCE_APP_PASSWORD" ""
    validate_env_var "ADT_DATA"
    validate_env_var "ACCEPTANCE_HOST"
    validate_env_var "CROWD_ACCEPTANCE_APP_NAME"
    validate_env_var "CROWD_ACCEPTANCE_APP_PASSWORD"
    evaluate_file_content ${ETC_DIR}/apache2/conf.d/adt.conf.template ${APACHE_CONF_DIR}/conf.d/adt.conf
    evaluate_file_content ${ETC_DIR}/apache2/sites-available/frontend.template ${APACHE_CONF_DIR}/sites-available/acceptance.exoplatform.org
    if ! ${ADT_DEV_MODE}; then
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
    init
    initialize_product_settings
    do_deploy
  ;;
  download-dataset)
    init
    initialize_product_settings
    do_download_dataset
  ;;
  start)
    init
    initialize_product_settings
    do_start
  ;;
  stop)
    init
    initialize_product_settings
    do_stop
  ;;
  restart)
    configurable_env_var "DEPLOYMENT_MODE" "KEEP_DATA"
    init
    initialize_product_settings
    do_stop
    case "${DEPLOYMENT_MODE}" in
      NO_DATA)
        do_init_empty_data
      ;;
      KEEP_DATA)
        # We have nothing to touch
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
    do_start
  ;;
  undeploy)
    init
    initialize_product_settings
    do_undeploy
  ;;
  list)
    init
    do_list
  ;;
  start-all)
    init
    do_start_all
  ;;
  stop-all)
    init
    do_stop_all
  ;;
  restart-all)
    configurable_env_var "DEPLOYMENT_MODE" "KEEP_DATA"
    init
    do_restart_all
  ;;
  undeploy-all)
    init
    do_undeploy_all
  ;;
  update-repos)
    init
    clone_or_fetch_git_repos ${ADT_OFFLINE} ${SRC_DIR} ${REPOS_LIST}
  ;;
  web-server)
    env_var "ADT_DEV_MODE" "true"
    init
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
