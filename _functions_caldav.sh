#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CALDAV_LOADED:-false} && return
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

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_files.sh"
source "${SCRIPT_DIR}/_functions_string.sh"

do_get_caldav_settings() {
  if [ "${DEPLOYMENT_CALDAV_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_CALDAV_CONTAINER_NAME "${INSTANCE_KEY}_baikal"
  env_var DEPLOYMENT_CALDAV_CONFIG_VOLUME "${INSTANCE_KEY}_baikal_config"
  env_var DEPLOYMENT_CALDAV_SPECIFIC_VOLUME "${INSTANCE_KEY}_baikal_specific"
}

#
# Drops all CalDAV data used by the instance.
#
do_drop_caldav_data() {
  echo_info "Dropping CalDAV data ..."
  if [ "${DEPLOYMENT_CALDAV_ENABLED}" == "true" ]; then
    echo_info "Drops CalDAV container ${DEPLOYMENT_CALDAV_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_CALDAV_CONTAINER_NAME}
    echo_info "Done."
    echo_info "Drops CalDAV docker volumes ..."
    delete_docker_volume ${DEPLOYMENT_CALDAV_CONFIG_VOLUME}
    delete_docker_volume ${DEPLOYMENT_CALDAV_SPECIFIC_VOLUME}
    echo_info "CalDAV data dropped"
  else
    echo_info "Skip Drops CalDAV container ..."
  fi
}

do_create_caldav() {
  if [ "${DEPLOYMENT_CALDAV_ENABLED}" == "true" ]; then
    echo_info "Creation of the CalDAV Docker volumes ..."
    create_docker_volume ${DEPLOYMENT_CALDAV_CONFIG_VOLUME}
    create_docker_volume ${DEPLOYMENT_CALDAV_SPECIFIC_VOLUME}
    echo_info "CalDAV Docker volumes created"
  fi
}

do_stop_caldav() {
  echo_info "Stopping CalDAV ..."
  if [ "${DEPLOYMENT_CALDAV_ENABLED}" == "false" ]; then
    echo_info "CalDAV wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_CALDAV_CONTAINER_NAME}
  echo_info "CalDAV container ${DEPLOYMENT_CALDAV_CONTAINER_NAME} stopped."
}

do_start_caldav() {
  echo_info "Starting CalDAV..."
  if [ "${DEPLOYMENT_CALDAV_ENABLED}" == "false" ]; then
    echo_info "CalDAV not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting CalDAV container ${DEPLOYMENT_CALDAV_CONTAINER_NAME} based on image ${DEPLOYMENT_CALDAV_IMAGE}:${DEPLOYMENT_CALDAV_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_CALDAV_CONTAINER_NAME}

  ${DOCKER_CMD} run \
    -d \
    -p "127.0.0.1:${DEPLOYMENT_CALDAV_HTTP_PORT}:80" \
    -v ${DEPLOYMENT_CALDAV_CONFIG_VOLUME}:/var/www/baikal/config \
    -v ${DEPLOYMENT_CALDAV_SPECIFIC_VOLUME}:/var/www/baikal/Specific \
    -v ${ETC_DIR}/baikal/nginx-prefix.sh:/docker-entrypoint.d/50-baikal-prefix.sh:ro \
    --health-cmd="curl --fail http://localhost:80 || exit 1" \
    --health-interval=30s \
    --health-retries=3 \
    --name ${DEPLOYMENT_CALDAV_CONTAINER_NAME} ${DEPLOYMENT_CALDAV_IMAGE}:${DEPLOYMENT_CALDAV_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_CALDAV_CONTAINER_NAME} container started"
  check_caldav_availability
  do_provision_caldav
}

check_caldav_availability() {
  echo_info "Waiting for CalDAV availability on port ${DEPLOYMENT_CALDAV_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_CALDAV_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "CalDAV not yet available (${count} / ${try})..."
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "CalDAV ${DEPLOYMENT_CALDAV_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "CalDAV ${DEPLOYMENT_CALDAV_CONTAINER_NAME} up and available"
}

#
# Auto-provision Baikal: generate config, init DB, create default user
#
do_provision_caldav() {
  echo_info "Provisioning CalDAV configuration..."

  # Skip if already provisioned (check if INSTALL_DISABLED exists)
  if ${DOCKER_CMD} exec ${DEPLOYMENT_CALDAV_CONTAINER_NAME} test -f /var/www/baikal/Specific/INSTALL_DISABLED 2>/dev/null; then
    echo_info "CalDAV already provisioned, skipping."
    return
  fi

  local BAIKAL_ADMIN_PASSWORD="${DEPLOYMENT_CALDAV_ADMIN_PASSWORD:-password}"
  local BAIKAL_CALENDAR_USER="${DEPLOYMENT_CALDAV_CALENDAR_USERNAME:-calendar}"
  local BAIKAL_CALENDAR_PASS="${DEPLOYMENT_CALDAV_CALENDAR_PASSWORD:-password}"
  local BAIKAL_AUTH_REALM="BaikalDAV"
  local BAIKAL_TIMEZONE="${DEPLOYMENT_CALDAV_TIMEZONE:-UTC}"

  local ADMIN_PASSWORDHASH=$(echo -n "admin:${BAIKAL_AUTH_REALM}:${BAIKAL_ADMIN_PASSWORD}" | sha256sum | awk '{print $1}')
  local DB_ENCRYPTION_KEY="${DEPLOYMENT_CALDAV_DB_ENCRYPTION_KEY:-$(getrandomstring 32)}"
  local USER_DIGESTA1=$(echo -n "${BAIKAL_CALENDAR_USER}:${BAIKAL_AUTH_REALM}:${BAIKAL_CALENDAR_PASS}" | md5sum | awk '{print $1}')

  # Auto-detect Baikal version from the image
  local BAIKAL_VERSION=$(${DOCKER_CMD} exec ${DEPLOYMENT_CALDAV_CONTAINER_NAME} php -r "include '/var/www/baikal/Core/Distrib.php'; echo BAIKAL_VERSION;")
  echo_info "Detected Baikal version: ${BAIKAL_VERSION}"

  env_var DEPLOYMENT_CALDAV_ADMIN_PASSWORDHASH "${ADMIN_PASSWORDHASH}"
  env_var DEPLOYMENT_CALDAV_DB_ENCRYPTION_KEY "${DB_ENCRYPTION_KEY}"
  env_var DEPLOYMENT_CALDAV_TIMEZONE "${BAIKAL_TIMEZONE}"
  env_var DEPLOYMENT_CALDAV_VERSION "${BAIKAL_VERSION}"

  # Generate Baikal config YAML
  local _configTmp="${TMP_DIR}/baikal-config-${INSTANCE_KEY}.yaml"
  evaluate_file_content ${ETC_DIR}/baikal/config.yaml.template "${_configTmp}"

  echo_info "Writing Baikal config and initializing database..."

  # Copy config into the container
  ${DOCKER_CMD} cp "${_configTmp}" ${DEPLOYMENT_CALDAV_CONTAINER_NAME}:/var/www/baikal/config/baikal.yaml
  rm -f "${_configTmp}"

  # Write provisioning script with host values baked in
  local _provisionScript="${TMP_DIR}/baikal-provision-${INSTANCE_KEY}.sh"
  cat > "${_provisionScript}" << EOF
#!/bin/sh
set -e

SPECIFIC_DIR="/var/www/baikal/Specific"
DB_FILE="\${SPECIFIC_DIR}/db/db.sqlite"

mkdir -p "\${SPECIFIC_DIR}/db"

# Initialize DB schema
sqlite3 "\${DB_FILE}" < /var/www/baikal/Core/Resources/Db/SQLite/db.sql

# Create calendar user and default calendar in a single transaction (last_insert_rowid must be in same sqlite3 session)
sqlite3 "\${DB_FILE}" << DBSQL
INSERT INTO users (username, digesta1) VALUES ('${BAIKAL_CALENDAR_USER}', '${USER_DIGESTA1}');
INSERT INTO principals (uri, email, displayname) VALUES ('principals/${BAIKAL_CALENDAR_USER}', '${BAIKAL_CALENDAR_USER}@localhost', 'Calendar User');
INSERT INTO calendars (synctoken, components) VALUES (1, 'VEVENT,VTODO');
INSERT INTO calendarinstances (calendarid, principaluri, displayname, uri, description, calendarorder, calendarcolor, transparent) VALUES (last_insert_rowid(), 'principals/${BAIKAL_CALENDAR_USER}', 'Default', 'default', '', 0, '#3cb371', 0);
INSERT INTO addressbooks (principaluri, displayname, uri, description) VALUES ('principals/${BAIKAL_CALENDAR_USER}', 'Default Address Book', 'default', '');
DBSQL

touch "\${SPECIFIC_DIR}/INSTALL_DISABLED"

# Fix ownership for nginx/PHP-FPM user
chown -R nginx:nginx "\${SPECIFIC_DIR}" /var/www/baikal/config/baikal.yaml
EOF

  # Copy and execute the provisioning script inside the container
  ${DOCKER_CMD} cp "${_provisionScript}" ${DEPLOYMENT_CALDAV_CONTAINER_NAME}:/tmp/provision.sh
  ${DOCKER_CMD} exec ${DEPLOYMENT_CALDAV_CONTAINER_NAME} sh /tmp/provision.sh
  ${DOCKER_CMD} exec ${DEPLOYMENT_CALDAV_CONTAINER_NAME} rm /tmp/provision.sh
  rm -f "${_provisionScript}"

  echo_info "CalDAV provisioning completed."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CALDAV_LOADED=true
echo_debug "_function_caldav.sh Loaded"
