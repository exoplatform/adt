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
source "${SCRIPT_DIR}/_functions_string.sh"
source "${SCRIPT_DIR}/_functions_system.sh"
source "${SCRIPT_DIR}/_functions_files.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"
source "${SCRIPT_DIR}/_functions_download.sh"
source "${SCRIPT_DIR}/_functions_compose.sh"
source "${SCRIPT_DIR}/_functions_nginx.sh"
source "${SCRIPT_DIR}/_functions_database.sh"
source "${SCRIPT_DIR}/_functions_dataset.sh"
source "${SCRIPT_DIR}/_functions_features.sh"
source "${SCRIPT_DIR}/_functions_git.sh"
source "${SCRIPT_DIR}/_functions_frontend.sh"

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

  usage: ${SCRIPT_NAME} <action>

This script manages automated deployment of eXo/Meeds products for testing purpose.
Each instance is deployed as an isolated docker compose project, fronted by an nginx
reverse-proxy registered with a Traefik v3 (TCP SNI passthrough) on the external
'reverse_proxy' docker network. All data is stored in named docker volumes.

Action
------
  deploy            Deploys (pull images + render configs + compose up) the instance
  download-dataset  Downloads the dataset required by the instance (if available)
  dump-dataset      Dumps the instance data (volumes + db) into a dataset archive
  import-dataset    Imports a v1 dataset tarball into the instance volumes
  start             Starts the instance (compose start)
  stop              Stops the instance (compose stop)
  restart           Restarts the instance (compose restart)
  undeploy          Undeploys (compose down -v + remove configs) the instance

  start-all         Starts all deployed instances
  stop-all          Stops all deployed instances
  restart-all       Restarts all deployed instances
  undeploy-all      Undeploys (deletes) all deployed instances
  list              Lists all deployed instances

  init              Initializes the environment (frontend network, dirs, dashboard)
  update-repos      Update Git repositories used by the web front-end
  web-server        Starts a local PHP web server to test the front-end (dev mode)

Environment Variables
----------------------
  They may be configured in the current shell environment or /etc/default/adt or \$HOME/.adtrc

  Global Settings
  ===============
  ADT_DATA                          : The path where data have to be stored (default: script dir)
  ACCEPTANCE_SCHEME                 : The scheme to use (default: 'https')
  ACCEPTANCE_HOST                   : The hostname (vhost) base (default: 'acceptance.exoplatform.org')
  ACCEPTANCE_PORT                   : The server port (default: '443')
  ACCEPTANCE_SERVERS                : Comma separated list of all acceptance front-end URLs to aggregate
  REPOSITORY_SERVER_BASE_URL        : The Maven repository URL used to resolve artifact metadata (default: https://repository.exoplatform.org)
  REPOSITORY_USERNAME               : Username to logon on \$REPOSITORY_SERVER_BASE_URL (default: none)
  REPOSITORY_PASSWORD               : Password to logon on \$REPOSITORY_SERVER_BASE_URL (default: none)

  ADT_DEBUG                         : Display debug details (default: false; values : true | false)
  ADT_DEV_MODE                      : Development mode (default: false; values : true | false)
  ADT_OFFLINE                       : Use only local resources, don't do any remote operations (default: false)

  TLS / Frontend network
  ======================
  ADT_SSL_CERTIFICATE_FILE          : Default TLS certificate file (PEM) for *.<ACCEPTANCE_HOST>
  ADT_SSL_CERTIFICATE_KEY_FILE      : Default TLS key file for *.<ACCEPTANCE_HOST>
  ADT_SSL_CERTIFICATE_CHAIN_FILE    : Default TLS chain file for *.<ACCEPTANCE_HOST>
  MEEDSIO_SSL_CERTIFICATE_FILE      : TLS certificate file for *.meeds.io (overrides default)
  MEEDSIO_SSL_CERTIFICATE_KEY_FILE  : TLS key file for *.meeds.io
  MEEDSIO_SSL_CERTIFICATE_CHAIN_FILE: TLS chain file for *.meeds.io
  INSTANCE_SSL_CERTIFICATE_FILE     : Per-instance effective cert file (defaults to the above)
  INSTANCE_SSL_CERTIFICATE_KEY_FILE : Per-instance effective key file
  INSTANCE_SSL_CERTIFICATE_CHAIN_FILE: Per-instance effective chain file
  DEPLOYMENT_FRONTEND_NETWORK       : External docker network where Traefik lives (default: reverse_proxy)
  DEPLOYMENT_TRAEFIK_ENTRYPOINT     : Traefik TCP entrypoint name for SNI passthrough (default: websecure)

  Deployment Settings
  ===================
  PRODUCT_NAME                      : The product to manage. Values : meeds | plfcom | plfent
  PRODUCT_VERSION                   : The version (release, -SNAPSHOT, -Mxx, -RCxx, continuous tag)
  INSTANCE_ID                       : An id to deploy several times the same product+version (default: none)

  DEPLOYMENT_MODE                   : How data are processed during deploy/restart
                                      (default: NO_DATA for deploy, KEEP_DATA for restart;
                                       values : NO_DATA | KEEP_DATA | RESTORE_DATASET | DUMP_DATASET)
  DEPLOYMENT_DATASET_FILE           : Path to a dataset archive (for RESTORE_DATASET)
  DEPLOYMENT_LABELS                 : Comma separated labels for a deployment (default: none)
  DEPLOYMENT_ADDONS                 : Comma separated list of add-ons to install at runtime (default: none)
  DEPLOYMENT_ADDONS_REMOVE_LIST     : Comma separated list of add-ons to remove (default: none)
  DEPLOYMENT_ADDONS_CATALOG         : URL of an add-on manager catalog file (default: none)
  DEPLOYMENT_ADDONS_CONFLICT_MODE   : add-on manager --conflict value (default: none; fail|skip|overwrite)
  DEPLOYMENT_PATCHES_LIST           : Comma separated list of patches to install (default: none)
  DEPLOYMENT_PATCHES_CATALOG_URL    : URL of a patches catalog (mandatory if patches list set)

  DEPLOYMENT_DB_TYPE                : Database type (default: postgres; values : postgres | mysql)
  DEPLOYMENT_DATABASE_VERSION       : Database image tag override (default: from versions.yaml)
  DEPLOYMENT_JVM_SIZE_MAX           : Maximum heap memory size (default: 3g)
  DEPLOYMENT_JVM_SIZE_MIN           : Minimum heap memory size (default: 512m)
  DEPLOYMENT_OPTS                   : Additional JVM parameters (default: none)
  DEPLOYMENT_UPLOAD_MAX_FILE_SIZE   : Max upload size in MB (default: 200)

  DEPLOYMENT_DOCKER_HOST            : The docker host to use (default: unix://)
  DEPLOYMENT_DOCKER_CMD             : The docker command (default: docker)
  DEPLOYMENT_EXPOSE_MANAGEMENT_PORTS: Expose JMX/DB/mailpit to 127.0.0.1 (default: false; values: true|false)
  DEPLOYMENT_PORT_PREFIX            : Prefix for management ports (when exposed, 2 digits added)

  Image overrides
  ===============
  DEPLOYMENT_IMAGE                  : Override the app image (default: from versions.yaml)
  DEPLOYMENT_IMAGE_TAG              : Override the app image tag (default: from versions.yaml)

  Feature sidecars (defaults from versions.yaml; set to true|false to enable/disable)
  ==================================================================================
  DEPLOYMENT_ONLYOFFICE_ENABLED     : OnlyOffice document server (default: false)
  DEPLOYMENT_MAILPIT_ENABLED        : Mailpit SMTP capture (default: false)
  DEPLOYMENT_MATRIX_ENABLED         : Matrix Synapse + its postgres (default: false)
  DEPLOYMENT_JITSI_ENABLED          : Jitsi Meet full stack (default: false)
  DEPLOYMENT_AI_ENABLED             : Ollama local LLM (default: false)
  DEPLOYMENT_IFRAMELY_ENABLED       : Iframely oEmbed (default: false)
  DEPLOYMENT_CLOUDBEAVER_ENABLED    : CloudBeaver DB web UI (default: false)
  DEPLOYMENT_KEYCLOAK_ENABLED       : Keycloak SSO IdP (default: false)
  DEPLOYMENT_LDAP_ENABLED           : OpenLDAP + phpLDAPadmin (default: false)
  DEPLOYMENT_CALDAV_ENABLED         : Baikal CalDAV server (default: false)
  DEPLOYMENT_CLAMAV_ENABLED         : ClamAV antivirus (default: false)
  DEPLOYMENT_FRONTAIL_ENABLED       : Frontail live log viewer (default: false)
  DEPLOYMENT_DOZZLE_ENABLED         : Dozzle container log viewer (default: true)

EOF
}

# #############################################################################
# Instance orchestration
# #############################################################################

#
# deploy action
#
do_deploy() {
  echo_info "Deploying ${PRODUCT_NAME} ${PRODUCT_VERSION} (instance ${INSTANCE_KEY}) ..."

  # Project directory (rendered configs + docker-compose.yml live here)
  env_var "PROJECT_DIR" "${PROJECTS_DIR}/${INSTANCE_KEY}"

  # Data mode handling
  case "${DEPLOYMENT_MODE}" in
    NO_DATA)
      echo_info "Mode NO_DATA: removing any existing project data ..."
      compose_down "${PROJECT_DIR}" true
      ;;
    KEEP_DATA)
      echo_info "Mode KEEP_DATA: preserving existing volumes ..."
      compose_down "${PROJECT_DIR}" false
      ;;
    RESTORE_DATASET)
      echo_info "Mode RESTORE_DATASET: will restore dataset after project creation ..."
      compose_down "${PROJECT_DIR}" true
      ;;
    DUMP_DATASET)
      echo_info "Mode DUMP_DATASET: dumping current data before redeploy ..."
      do_dump_dataset
      compose_down "${PROJECT_DIR}" true
      ;;
    *)
      echo_error "Invalid deployment mode \"${DEPLOYMENT_MODE}\""
      print_usage
      exit 1
      ;;
  esac

  # Render the compose file and all configs
  do_render_instance

  # Restore dataset into freshly created volumes if requested
  if [ "${DEPLOYMENT_MODE}" = "RESTORE_DATASET" ]; then
    do_restore_dataset
  fi

  # Bring the project up
  compose_up "${PROJECT_DIR}" "--pull=always"

  # Write the deployment descriptor (read by `list` and the PHP dashboard)
  # Do this before waiting for health so the instance is manageable even during
  # a slow boot.
  do_create_deployment_descriptor

  # Wait for the app service to become healthy (non-fatal: the instance is
  # deployed regardless; the user can check status with `list` or logs)
  wait_service_healthy "${PROJECT_DIR}" "${APP_SERVICE_NAME}" ${DEPLOYMENT_START_TIMEOUT} || \
    echo_warn "Service ${APP_SERVICE_NAME} did not become healthy within ${DEPLOYMENT_START_TIMEOUT}s. Check logs with: docker compose -f ${PROJECT_DIR}/docker-compose.yml logs ${APP_SERVICE_NAME}"

  echo_info "Instance ${INSTANCE_KEY} deployed. URL: ${ACCEPTANCE_SCHEME}://${DEPLOYMENT_EXT_HOST}"
}

#
# start action
#
do_start() {
  load_instance
  echo_info "Starting ${INSTANCE_KEY} ..."
  compose_up "${PROJECT_DIR}" "--no-recreate"
  wait_service_healthy "${PROJECT_DIR}" "${APP_SERVICE_NAME}" ${DEPLOYMENT_START_TIMEOUT} || \
    echo_warn "Service ${APP_SERVICE_NAME} did not become healthy within ${DEPLOYMENT_START_TIMEOUT}s."
  echo_info "Instance ${INSTANCE_KEY} started. URL: ${ACCEPTANCE_SCHEME}://${DEPLOYMENT_EXT_HOST}"
}

#
# stop action
#
do_stop() {
  load_instance
  echo_info "Stopping ${INSTANCE_KEY} ..."
  compose_stop "${PROJECT_DIR}"
  echo_info "Instance ${INSTANCE_KEY} stopped."
}

#
# restart action
#
do_restart() {
  load_instance
  echo_info "Restarting ${INSTANCE_KEY} ..."
  case "${DEPLOYMENT_MODE}" in
    NO_DATA)
      do_init_empty_data
      ;;
    KEEP_DATA)
      : # nothing to touch
      ;;
    RESTORE_DATASET)
      do_restore_dataset
      ;;
    DUMP_DATASET)
      do_dump_dataset
      ;;
    *)
      echo_error "Invalid deployment mode \"${DEPLOYMENT_MODE}\""
      print_usage
      exit 1
      ;;
  esac
  compose_restart "${PROJECT_DIR}"
  wait_service_healthy "${PROJECT_DIR}" "${APP_SERVICE_NAME}" ${DEPLOYMENT_START_TIMEOUT} || \
    echo_warn "Service ${APP_SERVICE_NAME} did not become healthy within ${DEPLOYMENT_START_TIMEOUT}s."
  echo_info "Instance ${INSTANCE_KEY} restarted."
}

#
# undeploy action
#
do_undeploy() {
  load_instance
  echo_info "Undeploying ${INSTANCE_KEY} ..."
  compose_down "${PROJECT_DIR}" true
  do_remove_instance_configs
  do_delete_deployment_descriptor
  echo_info "Instance ${INSTANCE_KEY} undeployed."
}

#
# list action
#
do_list() {
  local _count=0
  if [ ! -d "${ADT_CONF_DIR}" ] || [ -z "$(ls -A ${ADT_CONF_DIR} 2>/dev/null)" ]; then
    echo_info "No deployed instance."
    return 0
  fi
  printf "%-40s %-12s %-12s %-10s %s\n" "INSTANCE" "PRODUCT" "VERSION" "STATUS" "URL"
  printf "%-40s %-12s %-12s %-10s %s\n" "--------" "-------" "-------" "------" "---"
  for _descriptor in ${ADT_CONF_DIR}/*; do
    [ -f "${_descriptor}" ] || continue
    (
      source "${_descriptor}"
      local _status="stopped"
      local _ps
      _ps=$(compose_ps_json "${PROJECT_DIR}" 2>/dev/null)
      if [ -n "${_ps}" ]; then
        # `docker compose ps --format json` emits one JSON object per line.
        # Count the running services; if at least the app service is running,
        # consider the instance running.
        local _running
        _running=$(echo "${_ps}" | jq -s 'map(select(.State == "running")) | length' 2>/dev/null || echo 0)
        if [ "${_running}" != "0" ] && [ -n "${_running}" ]; then
          _status="running"
        fi
      fi
      printf "%-40s %-12s %-12s %-10s %s\n" "${INSTANCE_KEY}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${_status}" "${ACCEPTANCE_SCHEME}://${DEPLOYMENT_EXT_HOST}"
    )
    _count=$((_count + 1))
  done
  echo_info "${_count} instance(s)."
}

#
# start-all / stop-all / restart-all / undeploy-all
#
do_start_all()   { iterate_instances start; }
do_stop_all()    { iterate_instances stop; }
do_restart_all() { iterate_instances restart; }
do_undeploy_all() { iterate_instances undeploy; }

# Run an action against all deployed instances.
# $1 : action (start|stop|restart|undeploy)
iterate_instances() {
  local _action=$1
  if [ ! -d "${ADT_CONF_DIR}" ] || [ -z "$(ls -A ${ADT_CONF_DIR} 2>/dev/null)" ]; then
    echo_info "No deployed instance."
    return 0
  fi
  for _descriptor in ${ADT_CONF_DIR}/*; do
    [ -f "${_descriptor}" ] || continue
    (
      source "${_descriptor}"
      export PRODUCT_NAME PRODUCT_VERSION INSTANCE_ID INSTANCE_KEY
      export DEPLOYMENT_DB_TYPE DEPLOYMENT_MODE
      case "${_action}" in
        start)    do_start ;;
        stop)     do_stop ;;
        restart)  do_restart ;;
        undeploy) do_undeploy ;;
      esac
    )
  done
}

# Load an instance from its deployment descriptor (set by load_instance).
# Reads INSTANCE_KEY from env (set by adt.sh before calling do_start/stop/...).
load_instance() {
  validate_env_var "PRODUCT_NAME"
  validate_env_var "PRODUCT_VERSION"
  compute_instance_key
  initialize_product_settings
  if [ ! -f "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
    echo_error "Instance ${INSTANCE_KEY} is not deployed. Use 'deploy' first."
    exit 1
  fi
  source "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}"
}

# Compute INSTANCE_KEY from PRODUCT_NAME/PRODUCT_VERSION/INSTANCE_ID.
compute_instance_key() {
  if [ -n "${INSTANCE_ID:-}" ]; then
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${PRODUCT_VERSION}-${INSTANCE_ID}"
  else
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${PRODUCT_VERSION}"
  fi
  env_var "COMPOSE_PROJECT" "$(compose_project_name ${INSTANCE_KEY})"
}

# Write the deployment descriptor (INI-style, readable by bash `source` and PHP parse_ini_file).
do_create_deployment_descriptor() {
  local _descriptor="${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}"
  evaluate_file_content "${ETC_DIR}/adt/config.template.j2" "${_descriptor}"
  echo_info "Deployment descriptor written to ${_descriptor}"
}

# Delete the deployment descriptor.
do_delete_deployment_descriptor() {
  rm -f "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}"
}

# Remove rendered instance configs (project dir).
do_remove_instance_configs() {
  if [ -n "${PROJECT_DIR:-}" ] && [ -d "${PROJECT_DIR}" ]; then
    echo_info "Removing instance configs ${PROJECT_DIR} ..."
    rm -rf "${PROJECT_DIR}"
  fi
}

# Drop all data (volumes) for the current instance - used by restart NO_DATA.
do_init_empty_data() {
  echo_info "Mode NO_DATA: removing volumes for ${INSTANCE_KEY} ..."
  compose_down "${PROJECT_DIR}" true
}
