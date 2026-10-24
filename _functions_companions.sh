#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_COMPANIONS_LOADED:-false} && return
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
source "${SCRIPT_DIR}/_functions_files.sh"
source "${SCRIPT_DIR}/_functions_string.sh"
source "${SCRIPT_DIR}/_functions_ufw.sh"

# #############################################################################
# The companion services of an instance (Mailpit, Frontail, CloudBeaver, LDAP, LAM, ClamAV, CalDAV, SFTP...) are blocks of the
# compose project: etc/compose/services/<service>.yml.j2 (the container), integrations/<service>.j2 (what the application needs
# to know) and locations/<service>.conf.j2 (the nginx locations), each active when DEPLOYMENT_<SERVICE>_ENABLED is true.
# What the templates cannot do is here: the derived settings, the checks, the files of the services and what has to be done
# in a service once it runs.
# #############################################################################

#
# Companion services that the compose project does not provide yet: a deployment that enables one is refused
#
do_check_supported_features() {
  local _feature _var
  for _feature in ONLYOFFICE_DOCUMENTSERVER MATRIX KEYCLOAK JITSI DEBUG; do
    _var="DEPLOYMENT_${_feature}_ENABLED"
    if [ "${!_var:-false}" = "true" ]; then
      echo_error "${_var}=true: this companion service is not available yet in the docker compose deployments."
      exit 1
    fi
  done
}

#
# Settings derived from the others, defined whatever the services enabled (the templates use them)
#
do_get_companion_settings() {
  # SFTP: the one companion published on the server (it is not an HTTP service)
  env_var "DEPLOYMENT_SFTP_PORT" "${DEPLOYMENT_PORT_PREFIX}99"
  if ${DEPLOYMENT_SFTP_ENABLED}; then
    DEPLOYMENT_SFTP_LINK="sftp://root:password@${DEPLOYMENT_EXT_HOST}:${DEPLOYMENT_SFTP_PORT}//upload"
  fi

  # LDAP: the entries loaded when the directory is created, when the user of ADT has some
  env_var "DEPLOYMENT_LDAP_PREPOPULATE_DIR" ""
  if ${DEPLOYMENT_LDAP_ENABLED} && [ "${USER_DIRECTORY}" == "LDAP" ] && [ -d "${HOME}/.eXo/Platform/LDAP" ]; then
    env_var "DEPLOYMENT_LDAP_PREPOPULATE_DIR" "${HOME}/.eXo/Platform/LDAP"
  fi
  if ${DEPLOYMENT_LDAP_ENABLED}; then
    if [ -z "${USER_DIRECTORY_BASE_DN}" ] || [ -z "${USER_DIRECTORY_ADMIN_DN}" ] || [ -z "${USER_DIRECTORY_ADMIN_PASSWORD}" ]; then
      echo_error "Directory Base DN: ${USER_DIRECTORY_BASE_DN} , ADMIN DN: ${USER_DIRECTORY_ADMIN_DN} (or/end) password not set"
      exit 1
    fi
  fi

  # CloudBeaver: the users of the dashboard log in with the LDAP of the company
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_HOST" "ldap2.exoplatform.org"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_PORT" "636"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_SSL" "true"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_BASE_DN" "dc=exoplatform,dc=org"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_LOGIN_ATTR" "cn"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_ADMIN_GROUP" "${CLOUDBEAVER_LDAP_ADMIN_GROUP:-}"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_BIND_USER" "${LDAP_ACCEPTANCE_BIND_DN:-}"
  env_var "DEPLOYMENT_CLOUDBEAVER_LDAP_BIND_PASSWORD" "${LDAP_ACCEPTANCE_BIND_PASSWORD:-}"
}

#
# What a companion service needs from the others or from the add-ons of the application
#
do_check_companions() {
  if ${DEPLOYMENT_LAM_ENABLED} && ! { ${DEPLOYMENT_LDAP_ENABLED} && [ "${USER_DIRECTORY}" == "LDAP" ]; }; then
    echo_error "LDAP Account Manager needs the LDAP of the instance: DEPLOYMENT_LDAP_ENABLED=true and USER_DIRECTORY=LDAP."
    exit 1
  fi
  if ${DEPLOYMENT_CLOUDBEAVER_ENABLED}; then
    if [ "${DEPLOYMENT_DATABASE_ENABLED}" != "true" ]; then
      echo_error "CloudBeaver needs a database container: DEPLOYMENT_DB_TYPE=MYSQL, MARIADB or POSTGRES."
      exit 1
    fi
    if [ -z "${DEPLOYMENT_CLOUDBEAVER_LDAP_BIND_USER}" ] || [ -z "${DEPLOYMENT_CLOUDBEAVER_LDAP_BIND_PASSWORD}" ]; then
      echo_warn "LDAP_ACCEPTANCE_BIND_DN / LDAP_ACCEPTANCE_BIND_PASSWORD are not set, nobody will be able to log in to CloudBeaver"
    fi
    if [ -z "${DEPLOYMENT_CLOUDBEAVER_LDAP_ADMIN_GROUP}" ]; then
      echo_warn "CLOUDBEAVER_LDAP_ADMIN_GROUP is not set, nobody will be able to administrate CloudBeaver"
    fi
  fi
  if ${DEPLOYMENT_SFTP_ENABLED} && [[ ! "${DEPLOYMENT_ADDONS}" =~ .*exo-lecko.* ]]; then
    echo_error "SFTP deployment is enabled, the exo-lecko addon must be specified on the addon list."
    exit 1
  fi
  if ${DEPLOYMENT_CALDAV_ENABLED} && [[ ! "${DEPLOYMENT_ADDONS}" =~ .*exo-caldav-integration.* ]]; then
    echo_error "CalDAV deployment is enabled, the exo-caldav-integration addon must be specified on the addon list."
    exit 1
  fi
}

#
# The files the containers of the companion services mount, in ${DEPLOYMENT_DIR}
#
do_render_companion_files() {
  if ${DEPLOYMENT_CLAMAV_ENABLED}; then
    mkdir -p "${DEPLOYMENT_DIR}/clamav"
    cp "${ETC_DIR}/clamav/clamd.conf" "${DEPLOYMENT_DIR}/clamav/clamd.conf"
    cp "${ETC_DIR}/clamav/clamav-entrypoint.sh" "${DEPLOYMENT_DIR}/clamav/clamav-entrypoint.sh"
    chmod 644 "${DEPLOYMENT_DIR}/clamav/clamd.conf"
    chmod 755 "${DEPLOYMENT_DIR}/clamav/clamav-entrypoint.sh"
  fi
  if ${DEPLOYMENT_CLOUDBEAVER_ENABLED}; then
    mkdir -p "${DEPLOYMENT_DIR}/cloudbeaver"
    evaluate_file_content "${ETC_DIR}/cloudbeaver/data-sources.json.j2" "${DEPLOYMENT_DIR}/cloudbeaver/data-sources.json"
    chmod 644 "${DEPLOYMENT_DIR}/cloudbeaver/data-sources.json"
  fi
}

#
# Ports of the companion services that are open on the server
# $1 open | close
#
do_companion_firewall() {
  local _action=$1
  if ${DEPLOYMENT_SFTP_ENABLED:-false}; then
    "do_ufw_${_action}_port" "${DEPLOYMENT_SFTP_PORT}" "Sftp Port" "${ADT_DEV_MODE}"
  fi
}

do_provision_caldav() {
  echo_info "Provisioning CalDAV configuration..."

  # Skip if already provisioned (check if INSTALL_DISABLED exists)
  if ${DOCKER_CMD} exec ${INSTANCE_KEY}_baikal test -f /var/www/baikal/Specific/INSTALL_DISABLED 2>/dev/null; then
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
  local BAIKAL_VERSION=$(${DOCKER_CMD} exec ${INSTANCE_KEY}_baikal php -r "include '/var/www/baikal/Core/Distrib.php'; echo BAIKAL_VERSION;")
  echo_info "Detected Baikal version: ${BAIKAL_VERSION}"

  env_var DEPLOYMENT_CALDAV_ADMIN_PASSWORDHASH "${ADMIN_PASSWORDHASH}"
  env_var DEPLOYMENT_CALDAV_DB_ENCRYPTION_KEY "${DB_ENCRYPTION_KEY}"
  env_var DEPLOYMENT_CALDAV_TIMEZONE "${BAIKAL_TIMEZONE}"
  env_var DEPLOYMENT_CALDAV_VERSION "${BAIKAL_VERSION}"

  # Generate Baikal config YAML
  local _configTmp="${TMP_DIR}/baikal-config-${INSTANCE_KEY}.yaml"
  evaluate_file_content ${ETC_DIR}/baikal/config.yaml.j2 "${_configTmp}"

  echo_info "Writing Baikal config and initializing database..."

  # Copy config into the container
  ${DOCKER_CMD} cp "${_configTmp}" ${INSTANCE_KEY}_baikal:/var/www/baikal/config/baikal.yaml
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
  ${DOCKER_CMD} cp "${_provisionScript}" ${INSTANCE_KEY}_baikal:/tmp/provision.sh
  ${DOCKER_CMD} exec ${INSTANCE_KEY}_baikal sh /tmp/provision.sh
  ${DOCKER_CMD} exec ${INSTANCE_KEY}_baikal rm /tmp/provision.sh
  rm -f "${_provisionScript}"

  echo_info "CalDAV provisioning completed."
}

#
# What has to be done in the companion services once they run (idempotent: it is also called when an instance starts)
#
do_provision_companions() {
  if ${DEPLOYMENT_CALDAV_ENABLED:-false}; then
    do_provision_caldav
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_COMPANIONS_LOADED=true
echo_debug "_functions_companions.sh Loaded"
