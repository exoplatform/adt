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

  # Jitsi: the images of 7.3 and later are the rootless ones; the XMPP domains are names of the network of the instance
  env_var "DEPLOYMENT_JITSI_ROOTLESS" "false"
  if [[ "${PRODUCT_VERSION}" =~ ^(7\.[3-9]|[89]\.|[1-9][0-9]\.) ]]; then
    env_var "DEPLOYMENT_JITSI_ROOTLESS" "true"
  fi
  env_var "DEPLOYMENT_JITSI_NETWORK_NAME" "$(tolower "${INSTANCE_KEY}").jitsi"
  env_var "DEPLOYMENT_JITSI_JVB_PORT" "${DEPLOYMENT_PORT_PREFIX}84"
  # the major version of the stable-XXXXX image (the environment of its services depends on it)
  env_var "jitsi_major_version" "10"
  if [[ "${DEPLOYMENT_JITSI_IMAGE_VERSION}" =~ ^stable-([0-9]+) ]]; then
    env_var "jitsi_major_version" "$(( ${BASH_REMATCH[1]} / 1000 ))"
  fi

  # Keycloak: the secret of the OpenID client is chosen here, so that the application can be given it without waiting for Keycloak
  env_var "DEPLOYMENT_KEYCLOAK_OIDC_SECRET" "$(fqdn_rand_string 32 'kc-oidc' "${INSTANCE_KEY}")"

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
  if ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED} && { [ -z "${DEPLOYMENT_ONLYOFFICE_SECRET}" ] || [ -z "${DEPLOYMENT_ONLYOFFICE_LINK_SECRET}" ]; }; then
    echo_error "Missing DEPLOYMENT_ONLYOFFICE_SECRET / DEPLOYMENT_ONLYOFFICE_LINK_SECRET: OnlyOffice may not be deployed"
    exit 1
  fi
  if ${DEPLOYMENT_KEYCLOAK_ENABLED}; then
    if [[ ! "${DEPLOYMENT_KEYCLOAK_MODE:-SAML}" =~ ^(SAML|OPENID)$ ]]; then
      echo_error "Keycloak deployment mode should be SAML or OPENID."
      exit 1
    fi
    if [ "${DEPLOYMENT_KEYCLOAK_MODE:-SAML}" = "SAML" ] && [[ ! "${DEPLOYMENT_ADDONS}" =~ .*exo-saml.* ]]; then
      echo_error "Keycloak deployment with saml2 mode is enabled, the exo-saml addon must be specified on the addon list."
      exit 1
    fi
  fi
  if ${DEPLOYMENT_MATRIX_ENABLED} && [ -z "${DEPLOYMENT_APACHE_VHOST_ALIAS}" ]; then
    echo_error "Matrix needs DEPLOYMENT_APACHE_VHOST_ALIAS: it is the name of its server."
    exit 1
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
  if ${DEPLOYMENT_MATRIX_ENABLED}; then
    mkdir -p "${DEPLOYMENT_DIR}/matrix" "${DEPLOYMENT_DIR}/matrix-wellknown" "${DEPLOYMENT_LOG_DIR}/matrix"
    chmod 777 "${DEPLOYMENT_LOG_DIR}/matrix"
    evaluate_file_content "${ETC_DIR}/matrix/homeserver.yaml.j2" "${DEPLOYMENT_DIR}/matrix/homeserver.yaml"
    evaluate_file_content "${ETC_DIR}/matrix/initialize.sh.j2" "${DEPLOYMENT_DIR}/matrix/initialize.sh"
    cp "${ETC_DIR}/matrix/matrix.host.signing.key" "${DEPLOYMENT_DIR}/matrix/matrix.host.signing.key"
    cp "${ETC_DIR}/matrix/matrix.log.config" "${DEPLOYMENT_DIR}/matrix/matrix.log.config"
    # Synapse runs as another uid than the user of ADT and has to read them
    chmod 644 "${DEPLOYMENT_DIR}/matrix/homeserver.yaml" "${DEPLOYMENT_DIR}/matrix/matrix.host.signing.key" "${DEPLOYMENT_DIR}/matrix/matrix.log.config"
    chmod 755 "${DEPLOYMENT_DIR}/matrix/initialize.sh"
    # what the server publishes at /.well-known/matrix/ (nginx serves this directory only)
    evaluate_file_content "${ETC_DIR}/matrix/client.j2" "${DEPLOYMENT_DIR}/matrix-wellknown/client"
    evaluate_file_content "${ETC_DIR}/matrix/server.j2" "${DEPLOYMENT_DIR}/matrix-wellknown/server"
    chmod 644 "${DEPLOYMENT_DIR}/matrix-wellknown/client" "${DEPLOYMENT_DIR}/matrix-wellknown/server"
  fi
  if ${DEPLOYMENT_KEYCLOAK_ENABLED}; then
    mkdir -p "${DEPLOYMENT_DIR}/keycloak/saml2" "${DEPLOYMENT_LOG_DIR}/keycloak"
    chmod 777 "${DEPLOYMENT_LOG_DIR}/keycloak"
    rm -rf "${DEPLOYMENT_DIR}/keycloak/themes"
    mkdir -p "${DEPLOYMENT_DIR}/keycloak/themes"
    cp -r "${ETC_DIR}/keycloak/themes/exo" "${DEPLOYMENT_DIR}/keycloak/themes/"
    chmod -R a+rX "${DEPLOYMENT_DIR}/keycloak/themes"
    # Keycloak matches the URLs case sensitively
    env_var DEP_URL "$(echo "${DEPLOYMENT_URL}" | tr '[:upper:]' '[:lower:]')"
    evaluate_file_content "${ETC_DIR}/keycloak/client_def.json.j2" "${DEPLOYMENT_DIR}/keycloak/client_def.json"
    chmod 600 "${DEPLOYMENT_DIR}/keycloak/client_def.json"
  fi
  if ${DEPLOYMENT_JITSI_ENABLED}; then
    mkdir -p "${DEPLOYMENT_DIR}/jitsi"
    evaluate_file_content "${ETC_DIR}/jitsi/jitsi.env.j2" "${DEPLOYMENT_DIR}/jitsi/jitsi.env"
    evaluate_file_content "${ETC_DIR}/jitsi/jibri/jibri.conf.j2" "${DEPLOYMENT_DIR}/jitsi/jibri.conf"
    cp "${ETC_DIR}/jitsi/finalize.sh" "${DEPLOYMENT_DIR}/jitsi/finalize.sh"
    chmod 600 "${DEPLOYMENT_DIR}/jitsi/jitsi.env"
    chmod 644 "${DEPLOYMENT_DIR}/jitsi/jibri.conf"
    chmod 755 "${DEPLOYMENT_DIR}/jitsi/finalize.sh"
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
  if ${DEPLOYMENT_JITSI_ENABLED:-false}; then
    "do_ufw_${_action}_port" "${DEPLOYMENT_JITSI_JVB_PORT}" "Jitsi video bridge (UDP)" "${ADT_DEV_MODE}"
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
# Keycloak: the docker container of the keycloak service is reached on its address in the network of the instance (nothing is published)
#
do_get_keycloak_api_base() {
  local _ip
  _ip=$(${DOCKER_CMD} inspect --format "{{(index .NetworkSettings.Networks \"${INSTANCE_KEY}\").IPAddress}}" "${INSTANCE_KEY}_keycloak")
  if [ -z "${_ip}" ]; then
    echo_error "Unable to find the address of ${INSTANCE_KEY}_keycloak"
    return 1
  fi
  env_var DEPLOYMENT_KEYCLOAK_API_BASE "http://${_ip}:8080"
}

# keytool of the application image (the host has no JDK to ask): the files it reads and writes are mounted at the same place
do_keytool() {
  ${DOCKER_CMD} run --rm --user "$(id -u):$(id -g)" \
    --volume "${DEPLOYMENT_DIR}/keycloak/saml2:${DEPLOYMENT_DIR}/keycloak/saml2" --volume "${TMP_DIR}:${TMP_DIR}" \
    --entrypoint keytool "${DEPLOYMENT_IMAGE}" "$@"
}

# Wait for Keycloak, then create what the application needs: a permanent administrator, the client of the application and, for SAML,
# the keystore with the keys Keycloak generated for it. It is repeated at every start (everything is idempotent).
do_provision_keycloak() {
  do_get_keycloak_api_base
  env_var DEP_URL "$(echo "${DEPLOYMENT_URL}" | tr '[:upper:]' '[:lower:]')"
  echo_info "Provisioning Keycloak ..."
  do_provision_keycloak_permanent_admin
  do_provision_keycloak_clients
  do_provision_saml_keystore
  echo_info "Keycloak provisioned"
}
do_provision_keycloak_permanent_admin() {
  local KEYCLOAK_URL="${DEPLOYMENT_KEYCLOAK_API_BASE}/auth"
  local KC_TOKEN=$(curl -s -X POST \
    -d "client_id=admin-cli" \
    -d "username=bootstrap_admin" \
    -d "password=b00tstrap_p@ssw0rd" \
    -d "grant_type=password" \
    "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r '.access_token')
  echo_info "Checking if user root already exists..."
  local rootUserId=$(curl -s -X GET \
    -H "Authorization: Bearer $KC_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/master/users?username=root" | jq -r '.[0].id')
  if [ "$rootUserId" != "null" ] && [ -n "$rootUserId" ]; then
    echo_info "User root already exists with ID: ${rootUserId}. Skipping creation."
  else
    echo_info "Creating a new admin user: root..."
    local creationResp=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $KC_TOKEN" \
      -d '{"username": "root", "enabled": true, "firstName": "Root", "lastName": "Root", "email": "root@gatein.com"}' \
      "$KEYCLOAK_URL/admin/realms/master/users")
    if [ "$creationResp" -ne 201 ]; then
        echo_error "Failed to create user. HTTP status code: $creationResp"
        exit 1
    fi
    echo_info "User created successfully."
    rootUserId=$(curl -s -X GET \
      -H "Authorization: Bearer $KC_TOKEN" \
      "$KEYCLOAK_URL/admin/realms/master/users?username=root" | jq -r '.[0].id')
    local setPassResp=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $KC_TOKEN" \
      -d '{ "type": "password", "value": "password", "temporary": false }' \
      "$KEYCLOAK_URL/admin/realms/master/users/${rootUserId}/reset-password")
    if [ "$setPassResp" -ne 204 ]; then
      echo_error "Failed to set password. HTTP status code: $setPassResp"
      exit 1
    fi
    echo_info "User root Password set successfully."
    echo_info "Assigning admin role to root..."
    local adminRoleId=$(curl -s -X GET \
      -H "Authorization: Bearer $KC_TOKEN" \
      "$KEYCLOAK_URL/admin/realms/master/roles" |  jq -r --arg ROLE_NAME "admin" '.[] | select(.name == $ROLE_NAME) | .id')
    if [ -z "$adminRoleId" ]; then
      echo "Realm admin role $adminRoleId not found."
      exit 1
    fi
    # Assign the realm role to the user
    local roleAssignmentResp=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      -H "Authorization: Bearer $KC_TOKEN" \
      -H "Content-Type: application/json" \
      -d '[{"id": "'"$adminRoleId"'", "name": "admin"}]' \
      "$KEYCLOAK_URL/admin/realms/master/users/${rootUserId}/role-mappings/realm")
    if [ "$roleAssignmentResp" -ne 204 ]; then
      echo_error "Failed to assign admin role. HTTP status code: $roleAssignmentResp"
      exit 1
    fi
    echo_info "Admin role assigned to user root successfully."
  fi
  echo_info "Updating realm login theme to exo..."
  local _rootToken=$(curl -s -X POST \
    -d "client_id=admin-cli" \
    -d "username=root" \
    -d "password=password" \
    -d "grant_type=password" \
    "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r '.access_token')
  local _realmJson=$(curl -s -X GET -H "Authorization: Bearer $_rootToken" "$KEYCLOAK_URL/admin/realms/master")
  local _updatedRealm=$(echo "$_realmJson" | jq '.loginTheme = "exo" | .rememberMe = true | .internationalizationEnabled = true | .supportedLocales = ["en","fr"] | .defaultLocale = "en"')
  local _realmUpdateResp=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $_rootToken" \
    -d "$_updatedRealm" \
    "$KEYCLOAK_URL/admin/realms/master")
  if [ "$_realmUpdateResp" -ne 204 ]; then
    echo_error "Failed to update realm theme. HTTP status code: $_realmUpdateResp"
    exit 1
  fi
  echo_info "Realm login theme set to exo."
}

do_provision_keycloak_clients() {
  local token=$(curl -X POST "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/realms/master/protocol/openid-connect/token" \
   -H "Content-Type: application/x-www-form-urlencoded" \
   -d "username=root" \
   -d "password=password" \
   -d 'grant_type=password' \
   -d 'client_id=admin-cli' | jq -r '.access_token')
  local keycloakRootUserId=$(curl -fssL "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/admin/realms/master/users" -H 'Content-Type: application/json' -H  "Authorization: Bearer $token" | jq -r '.[]| select(.username == "root") | .id')
  local keycloakCreatedTimestamp=$(curl -fssL "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/admin/realms/master/users" -H 'Content-Type: application/json' -H  "Authorization: Bearer $token" | jq -r '.[]| select(.username == "root") | .createdTimestamp')
  curl -s -X PUT --output /dev/null "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/admin/realms/master/users/${keycloakRootUserId}" \
   -H 'Content-type: application/json' \
   -H "Authorization: Bearer ${token}" \
   -d "{\"id\":\"${keycloakRootUserId}\",\"createdTimestamp\":${keycloakCreatedTimestamp},\"username\":\"root\",\"enabled\":true,\"totp\":false,\"emailVerified\":false,\"disableableCredentialTypes\":[],\"requiredActions\":[],\"notBefore\":0,\"access\":{\"manageGroupMembership\":true,\"view\":true,\"mapRoles\":true,\"impersonate\":true,\"manage\":true},\"attributes\":{},\"email\":\"root@gatein.com\",\"firstName\":\"Root\",\"lastName\":\"Root\"}" \
     && echo_info "Keycloak root user updated"
  # Upsert client: update if exists, create if new
  local _clientId=$(curl -s -H "Authorization: Bearer ${token}" \
    "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/admin/realms/master/clients?clientId=${DEP_URL}/portal/dologin" | jq -r '.[0].id')
  if [ -n "${_clientId}" ] && [ "${_clientId}" != "null" ]; then
    curl -s -X PUT --output /dev/null "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/admin/realms/master/clients/${_clientId}" \
      -H 'Content-type: application/json' \
      -H "Authorization: Bearer ${token}" \
      -d "@${DEPLOYMENT_DIR}/keycloak/client_def.json" && echo_info "Keycloak client updated"
  else
    curl -s -X POST --output /dev/null "${DEPLOYMENT_KEYCLOAK_API_BASE}/auth/admin/realms/master/clients" \
      -H 'Content-type: application/json' \
      -H "Authorization: Bearer ${token}" \
      -d "@${DEPLOYMENT_DIR}/keycloak/client_def.json" && echo_info "Keycloak client added"
  fi
}

do_provision_saml_keystore() {
  if [ "${DEPLOYMENT_KEYCLOAK_MODE:-SAML}" != "SAML" ]; then
    return
  fi
  echo_info "Provisioning SAML keystore from Keycloak..."

  local _kc_api="${DEPLOYMENT_KEYCLOAK_API_BASE}/auth"
  local _token=$(curl -s -X POST "${_kc_api}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=root" \
    -d "password=password" \
    -d 'grant_type=password' \
    -d 'client_id=admin-cli' | jq -r '.access_token')

  local _clientId=$(curl -s -H "Authorization: Bearer ${_token}" \
    "${_kc_api}/admin/realms/master/clients?clientId=${DEP_URL}/portal/dologin" | jq -r '.[0].id')

  if [ -z "${_clientId}" ] || [ "${_clientId}" = "null" ]; then
    echo_warn "Keycloak SAML client not found, skipping keystore provisioning"
    return
  fi

  local _samlDir="${DEPLOYMENT_DIR}/keycloak/saml2"
  mkdir -p "${_samlDir}"

  local _keystorePass="store123"
  local _keyPass="store123"

  # Fetch realm public cert (IDP)
  local _idpCertB64=$(curl -s -H "Authorization: Bearer ${_token}" \
    "${_kc_api}/admin/realms/master/keys" | jq -r '.keys[] | select(.algorithm=="RS256") | .certificate')

  # Fetch client SP cert + private key
  local _spCerts=$(curl -s -H "Authorization: Bearer ${_token}" \
    "${_kc_api}/admin/realms/master/clients/${_clientId}/certificates/saml.signing")
  local _spCertB64=$(echo "${_spCerts}" | jq -r '.certificate')
  local _spKeyB64=$(echo "${_spCerts}" | jq -r '.privateKey')
  if [ -z "${_spKeyB64}" ] || [ "${_spKeyB64}" = "null" ]; then
    # Keycloak 26.8+ no longer returns the private key from the certificates endpoint (download is deprecated),
    # it is still available in the client attributes.
    _spKeyB64=$(curl -s -H "Authorization: Bearer ${_token}" \
      "${_kc_api}/admin/realms/master/clients/${_clientId}" | jq -r '.attributes["saml.signing.private.key"]')
  fi

  if [ -z "${_spKeyB64}" ] || [ "${_spKeyB64}" = "null" ]; then
    # Keycloak keeps it to itself: it is the key of the client definition ADT sent (etc/keycloak/client_def.json.j2)
    _spKeyB64=$(jq -r '.attributes["saml.signing.private.key"]' "${DEPLOYMENT_DIR}/keycloak/client_def.json")
    _spCertB64=$(jq -r '.attributes["saml.signing.certificate"]' "${DEPLOYMENT_DIR}/keycloak/client_def.json")
  fi

  local _tmpdir="${TMP_DIR}/keycloak-saml-${INSTANCE_KEY}"
  rm -rf "${_tmpdir}"
  mkdir -p "${_tmpdir}"

  # Convert base64 DER to PEM files
  echo "${_idpCertB64}" | base64 -d > "${_tmpdir}/idp-cert.der" 2>/dev/null
  openssl x509 -in "${_tmpdir}/idp-cert.der" -inform DER -out "${_tmpdir}/idp-cert.pem" 2>/dev/null || true

  echo "${_spCertB64}" | base64 -d > "${_tmpdir}/sp-cert.der" 2>/dev/null
  openssl x509 -in "${_tmpdir}/sp-cert.der" -inform DER -out "${_tmpdir}/sp-cert.pem" 2>/dev/null || true

  echo "${_spKeyB64}" | base64 -d > "${_tmpdir}/sp-key.der" 2>/dev/null
  openssl rsa -in "${_tmpdir}/sp-key.der" -inform DER -out "${_tmpdir}/sp-key.pem" 2>/dev/null || true

  local _f
  for _f in idp-cert.pem sp-cert.pem sp-key.pem; do
    if [ ! -s "${_tmpdir}/${_f}" ]; then
      echo_error "SAML keystore: ${_f} could not be built from the keys of Keycloak"
      return 1
    fi
  done

  # Create PKCS12 with SP keypair
  openssl pkcs12 -export -out "${_tmpdir}/sp-keystore.p12" \
    -inkey "${_tmpdir}/sp-key.pem" -in "${_tmpdir}/sp-cert.pem" \
    -passout pass:"${_keystorePass}" -name exo-sp 2>/dev/null

  # Create fresh JKS with IDP cert + SP keypair
  local _keystoreFile="${_samlDir}/keystore.jks"
  rm -f "${_keystoreFile}"
  do_keytool -genkeypair -alias _dummy -keyalg RSA -keysize 2048 \
    -keystore "${_keystoreFile}" -storepass "${_keystorePass}" -keypass "${_keyPass}" \
    -storetype JKS -dname "CN=temp" -validity 1 2>/dev/null
  do_keytool -delete -alias _dummy -keystore "${_keystoreFile}" -storepass "${_keystorePass}" -storetype JKS 2>/dev/null

  # Import IDP public cert (used to validate IDP signatures)
  do_keytool -import -noprompt -keystore "${_keystoreFile}" -file "${_tmpdir}/idp-cert.pem" \
    -alias master -storepass "${_keystorePass}" -storetype JKS 2>/dev/null

  # Import SP private key (used by eXo to sign SP assertions)
  do_keytool -v -importkeystore -srckeystore "${_tmpdir}/sp-keystore.p12" -srcstoretype PKCS12 \
    -destkeystore "${_keystoreFile}" -deststoretype JKS \
    -srcalias exo-sp -destalias exo-sp \
    -srcstorepass "${_keystorePass}" -deststorepass "${_keystorePass}" \
    -destkeypass "${_keyPass}" 2>/dev/null

  rm -rf "${_tmpdir}"
  echo_info "SAML keystore provisioned at ${_keystoreFile}"
}


#
# What has to be done in the companion services once they run (idempotent: it is also called when an instance starts)
#
do_provision_companions() {
  if ${DEPLOYMENT_CALDAV_ENABLED:-false}; then
    do_provision_caldav
  fi
  if ${DEPLOYMENT_JITSI_ENABLED:-false}; then
    do_provision_jitsi
  fi
}

# The logo and the watermark link of the Jitsi web application (its configuration is generated when the container starts)
do_provision_jitsi() {
  local _web="${INSTANCE_KEY}_jitsi_web" _config="/config/interface_config.js"
  ${DOCKER_CMD} exec "${_web}" bash -c "grep -q DEFAULT_LOGO_URL ${_config} || echo \"interfaceConfig['DEFAULT_LOGO_URL'] = '${DEPLOYMENT_URL}/jitsicall/images/logo.png';\" >> ${_config}"
  ${DOCKER_CMD} exec "${_web}" bash -c "grep -q JITSI_WATERMARK_LINK ${_config} || echo \"interfaceConfig['JITSI_WATERMARK_LINK'] = '';\" >> ${_config}"
  if [ "${DEPLOYMENT_JITSI_ROOTLESS}" != "true" ]; then
    ${DOCKER_CMD} exec "${_web}" bash -c "rm -fv /usr/share/jitsi-meet/sounds/recordingOff.mp3 /usr/share/jitsi-meet/sounds/recordingOn.mp3"
  fi
}

#
# Start the instance: Keycloak first when there is one (the application needs its keystore and client when it starts), then
# everything, then what has to be done inside the services
#
do_start_instance() {
  if ${DEPLOYMENT_KEYCLOAK_ENABLED:-false}; then
    echo_info "Starting Keycloak first ..."
    do_compose up --detach --wait --wait-timeout "${DEPLOYMENT_START_TIMEOUT:-1800}" keycloak
    do_provision_keycloak
  fi
  do_compose_up
  do_provision_companions
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_COMPANIONS_LOADED=true
echo_debug "_functions_companions.sh Loaded"
