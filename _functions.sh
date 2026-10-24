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
source "${SCRIPT_DIR}/_functions_git.sh"
source "${SCRIPT_DIR}/_functions_ufw.sh"
source "${SCRIPT_DIR}/_functions_apache.sh"
source "${SCRIPT_DIR}/_functions_web.sh"
source "${SCRIPT_DIR}/_functions_logrotate.sh"
source "${SCRIPT_DIR}/_functions_awstats.sh"
source "${SCRIPT_DIR}/_functions_docker.sh"
source "${SCRIPT_DIR}/_functions_registry.sh"
source "${SCRIPT_DIR}/_functions_compose.sh"
source "${SCRIPT_DIR}/_functions_companions.sh"
source "${SCRIPT_DIR}/_functions_certbot.sh"

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

This script manages automated deployment of eXo Platform and Meeds (7.0 and later) for testing purpose.
Every instance is a docker compose project (application, database, search and nginx containers) on its own network.

Action
------
  deploy           Deploys (pulls the images and configures) the server
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
  build-web        Builds the adt-web front-end binary (web/, Go) into ADT_WEB_BIN (nothing to do when the sources did not change)
  deploy-web       Builds adt-web, writes its environment file from the ADT variables and restarts its service when something changed ("init" does it too)
  web-server       Builds and starts adt-web in the foreground to test the front-end, without Apache. It automatically activates the development mode.

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
  LDAP_ACCEPTANCE_APACHE2_ADMIN_DN     : The full DN of the LDAP group allowed to open the front-end debug pages (default: cn=exo-team-swf,ou=groups,dc=exoplatform,dc=org)
  CLOUDBEAVER_LDAP_ADMIN_GROUP      : The full DN of the LDAP group whose members administrate Cloudbeaver (default: none)
  ADT_SESSION_PASSPHRASE            : Secret used to encrypt the front-end login session cookie (default: none, required)
  ADT_WEB_BIN                       : Where "init" and "build-web" install the adt-web binary (default: \${ADT_DATA}/bin/adt-web)
  ADT_WEB_SOCKET                    : The unix socket adt-web listens on and Apache proxies to (default: /run/adt-web/adt-web.sock)
  ADT_WEB_SOCKET_GROUP              : The group given to that socket so Apache (www-data) can connect (default: www-data)
  ADT_WEB_SERVICE                   : The systemd service "init" restarts when adt-web or its environment changed (default: adt-web)
  ADT_WEB_ENV_FILE                  : The environment file "init" writes for that service (default: \${ADT_DATA}/conf/adt-web.env)
  ADT_WEB_CSP                       : The Content-Security-Policy of the adt-web pages: enforce, report-only (the browser only logs what it would block) or off (default: enforce)
  ADT_ADMIN_USERS                   : Comma-separated logins of the dashboard administrators, who can change the base branch of a feature branch (default: none)
  ADT_WEB_GO_IMAGE                  : The image used to build adt-web when no suitable Go is installed (default: a pinned golang:<go version>-alpine image, by digest)
  APACHE_SSL_CERTIFICATE_FILE       : Apache SSLCertificateFile for HTTPS setup (PEM bundle including certificate chain)
  APACHE_SSL_CERTIFICATE_KEY_FILE   : Apache SSLCertificateKeyFile for HTTPS setup

  ADT_DEBUG                         : Display debug details (default: false; values : true | false)
  ADT_DEV_MODE                      : Development mode. Apache server, awstats and ufw are deactivated, nginx is published without TLS. (default: false; values : true | false)
  ADT_OFFLINE                       : Use only local resources, don''t do any remote operations. (default: false; values : true | false)

  Instance Settings
  =================

  PRODUCT_NAME                      : The product you want to manage. Possible values are :
    meeds          Meeds.io                                - image meedsio/meeds
    plfcom         eXo Platform Community Edition          - image exoplatform/exo-community
    plfent         eXo Platform Enterprise Edition         - image exoplatform/exo-enterprise
  Only versions 7.0 and later are supported. DEPLOYMENT_IMAGE_REPO overrides the image repository.

  PRODUCT_VERSION                   : The version of the product, also the tag of the image. Can be a release (X.Y.Z, the newest rebuild X.Y.Z_N is used), a snapshot (X.Y.x-SNAPSHOT), or a build resolved from the tags of the registry: -MLT (latest) / -MBL (before latest) / -GA (latest GA release only, no milestone/RC/CP/build suffix) with optional Z wildcard for the patch version (e.g. 7.2.0-MLT, 7.2.Z-MLT, 7.2.Z-GA)
  INSTANCE_ID                       : The id of the instance. Use this property to deploy several time the same PRODUCT_NAME and PRODUCT_VERSION couple (default: none)

  DEPLOYMENT_LABELS                 : Comma separated labels for a deployment \" (default: none)
  DEPLOYMENT_PORT_PREFIX            : The prefix of the port of the instance (default: 80). The nginx of the instance is published on 127.0.0.1:<prefix>01
  DEPLOYMENT_APACHE_SECURITY        : private (LDAP login) or public (default: private)
  DEPLOYMENT_APACHE_VHOST_ALIAS     : An alias of the virtual host (default: none)
  DEPLOYMENT_APACHE_HTTPS_ENABLED   : Add an HTTPS virtual host. nginx then serves the same certificate as Apache (default: false)
  DEPLOYMENT_APACHE_HTTPSONLY_ENABLED : Redirect HTTP to HTTPS (default: false)
  DEPLOYMENT_APACHE_WEBSOCKET_ENABLED : Forward the websockets (default: true)

  DEPLOYMENT_JVM_SIZE_MAX           : Maximum heap memory size (default: 2g)
  DEPLOYMENT_JVM_SIZE_MIN           : Minimum heap memory size (default: 512m)
  DEPLOYMENT_OPTS                   : Additional JVM parameters (JAVA_OPTS of the image) (default: none)
  DEPLOYMENT_ADDONS                 : Comma separated list of add-ons to install (EXO_ADDONS_LIST / MEEDS_ADDONS_LIST). The jdbc driver of the database is added.
  DEPLOYMENT_LICENSE_FILE           : The license of plfent, mounted read-only as /etc/exo/license.xml (default: \${ADT_DATA}/conf/license.xml, none when it does not exist)
  DEPLOYMENT_ADDONS_TOREMOVE        : Comma separated list of add-ons to remove
  DEPLOYMENT_ADDONS_CATALOG         : URL of an add-ons catalog (default: the one of the image)
  DEPLOYMENT_PATCHES                : Comma separated list of patches to install
  DEPLOYMENT_UPLOAD_MAX_FILE_SIZE   : Configure the max size for file upload (in MB, default: 200)
  DEPLOYMENT_GZIP_ENABLED           : Compression done by the application server itself (default: false, nginx compresses)
  DEPLOYMENT_START_TIMEOUT          : Seconds to wait for the instance to be healthy at start (default: 1800)

  DEPLOYMENT_DOCKER_HOST            : The docker host to use to deploy containers (default: unix://)
  DEPLOYMENT_DOCKER_CMD             : The docker command to execute (default: docker)
  DEPLOYMENT_DOCKER_NETWORKS_MAX    : Number of docker bridge networks above which deploy refuses a new instance (default: 30, the capacity of the default address pools)

  DEPLOYMENT_DB_TYPE                : Which database do you want to use for your deployment ? (default: HSQLDB; values : HSQLDB | MYSQL | MARIADB | POSTGRES; DOCKER_MYSQL, DOCKER_MARIADB and DOCKER_POSTGRES are accepted too)
  DEPLOYMENT_DATABASE_VERSION       : Which database version do you want to use for your deployment ? (default: the one of the product version, required for MariaDB)

  DEPLOYMENT_MODE                   : How data are processed during a restart or deployment (default: KEEP_DATA for restart, NO_DATA for deploy; values : NO_DATA - All existing data are removed | KEEP_DATA - Existing data are kept)

  DEPLOYMENT_ES_IMAGE_VERSION       : Which version of the Elasticsearch image to use (default: the one of the product version)
  DEPLOYMENT_ES_HEAP                : Size of Elasticsearch heap (default: 512m)

  DEPLOYMENT_CERTBOT_ENABLED                : Enable Certbot integration for automatic SSL certificate issuance and renewal
  DEPLOYMENT_CERTBOT_CERT_EXPIRE_PERIOD     : Certificate renewal threshold in seconds (e.g., 2592000 = 30 days before expiry)
  DEPLOYMENT_CERTBOT_ACME_SERVER            : ACME server URL used for certificate issuance (e.g., Let\'s Encrypt endpoint)
  DEPLOYMENT_CERTBOT_EMAIL                  : Contact e-mail of the ACME account (default: certificates@exoplatform.com)
  DEPLOYMENT_CERTBOT_EAB_KID                : External Account Binding Key ID for ACME registration (leave empty if not required)
  DEPLOYMENT_CERTBOT_EAB_HMAC_KEY           : External Account Binding HMAC key for ACME (leave empty if not required)
  DEPLOYMENT_CERTBOT_FORCE_RENEWAL          : Force renewal of certificate even if not close to expiry
  DEPLOYMENT_CERTBOT_UNDEPLOY_CERT_REMOVAL  : Remove certificates from the system upon undeploy

  DEPLOYMENT_CERTBOT_CONFIG_FOLDER          : Filesystem path where Certbot stores certificates and configurations
  DEPLOYMENT_CERTBOT_WEBROOT_PATH           : Webroot path used by Certbot for HTTP-01 challenge validation


EOF
}

#
# Docker properties (needed by every action that looks at the containers)
#
initialize_docker_settings() {
  configurable_env_var "DEPLOYMENT_DOCKER_HOST"     "unix://"
  configurable_env_var "DEPLOYMENT_DOCKER_CMD"      "docker"
  configurable_env_var "DOCKER_CMD"                 "${DEPLOYMENT_DOCKER_CMD} -H ${DEPLOYMENT_DOCKER_HOST}"
}

#
# Decode command line parameters
#
initialize_product_settings() {
  validate_env_var "ACTION"

  initialize_docker_settings

  # ${PRODUCT_BRANCH} is computed from ${PRODUCT_VERSION} and is equal to the version up to the latest dot
  # and with x added. ex : 7.3.0-M4-SNAPSHOT => 7.3.x, 7.2.Z-GA => 7.2.x
  # Everything that depends on the minor version of the product (docker images, versions) is keyed on it.
  env_var PRODUCT_BRANCH `expr "${PRODUCT_VERSION}" : '\([0-9]*\.[0-9]*\).*'`".x"
  env_var PRODUCT_MAJOR_BRANCH `expr "${PRODUCT_VERSION}" : '\([0-9]*\).*'`".x"
  configurable_env_var "INSTANCE_ID" ""
  configurable_env_var "INSTANCE_TOKEN" ""

  if [ ! -z "${INSTANCE_TOKEN:-}" ]; then
    if [[ ! "${INSTANCE_TOKEN}" =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
      echo_error "${INSTANCE_TOKEN} must be a valid UUID Token!"
      exit 1
    fi
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${INSTANCE_TOKEN:0:8}"
  elif [ -z "${INSTANCE_ID}" ]; then
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${PRODUCT_VERSION}"
  else
    env_var "INSTANCE_KEY" "${PRODUCT_NAME}-${PRODUCT_VERSION}-${INSTANCE_ID}"
  fi

  # validate additional parameters
  case "${ACTION}" in
    start | stop | restart | undeploy | deploy)
    # Mandatory env vars. They need to be defined before launching the script
      validate_env_var "PRODUCT_NAME"
      validate_env_var "PRODUCT_VERSION"
      configurable_env_var "INSTANCE_ID" ""

      # Comma separated list of add-ons installed by the add-ons manager of the image. Empty string for none. (default: none)
      configurable_env_var "DEPLOYMENT_ADDONS" ""
      configurable_env_var "DEPLOYMENT_ADDONS_CATALOG" ""
      configurable_env_var "DEPLOYMENT_ADDONS_MANAGER_CONFLICT_MODE" "" # --conflict of the add-ons manager (fail / skip / overwrite)
      configurable_env_var "DEPLOYMENT_ADDONS_MANAGER_NOCOMPAT_MODE" "" # --no-compat of the add-ons manager (true / false)
      # Comma separated list of patches to install. Empty string for none. (default: none)
      configurable_env_var "DEPLOYMENT_PATCHES" ""
      configurable_env_var "DEPLOYMENT_PATCHES_CATALOG" "http://patches.exoplatform.org/catalog.json"
      # Comma separated list of add-ons to remove. Empty string for none. (default: none)
      configurable_env_var "DEPLOYMENT_ADDONS_TOREMOVE" ""
      # Additional JVM settings (JAVA_OPTS of the image)
      configurable_env_var "DEPLOYMENT_OPTS" ""
      env_var "DEPLOYMENT_DATABASE_ENABLED" true
      env_var "DEPLOYMENT_DATABASE_NAME" ""
      env_var "DEPLOYMENT_DATABASE_USER" ""

      env_var "DEPLOYMENT_BUILD_URL" "$(dirname ${BUILD_URL})"

      configurable_env_var "DEPLOYMENT_ES_ENABLED" true
      configurable_env_var "DEPLOYMENT_ES_HEAP" "512m"
      configurable_env_var "DEPLOYMENT_NGINX_IMAGE" "nginx"
      configurable_env_var "DEPLOYMENT_NGINX_IMAGE_VERSION" "1.30.2-alpine"
      # Throwaway container used when files created by the containers (other uids) have to be removed
      configurable_env_var "DEPLOYMENT_HELPER_IMAGE" "alpine:3"

      #
      # Companion services. They are not available yet in the compose project: a deployment that enables one is refused.
      #
      env_var "DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED" false
      configurable_env_var "DEPLOYMENT_ONLYOFFICE_SECRET" "$(fqdn_rand_string 64 'onlyoffice-secret' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_ONLYOFFICE_LINK_SECRET" "$(fqdn_rand_string 64 'onlyoffice-link-secret' ${INSTANCE_KEY})"

      configurable_env_var "DEPLOYMENT_LDAP_ENABLED" false
      configurable_env_var "DEPLOYMENT_LDAP_IMAGE" "dinkel/openldap"
      configurable_env_var "DEPLOYMENT_LDAP_IMAGE_VERSION" "2.4.44"
      # USER_DIRECTORY should have LDAP/MSAD as values
      configurable_env_var "USER_DIRECTORY" "LDAP"
      configurable_env_var "DEPLOYMENT_AD_HOST" "localhost"
      configurable_env_var "DEPLOYMENT_AD_PORT" "389"
      configurable_env_var "USER_DIRECTORY_BASE_DN" "dc=exoplatform,dc=com"
      configurable_env_var "GROUP_DIRECTORY_BASE_DN" ""
      configurable_env_var "USER_DIRECTORY_ADMIN_DN" "cn=admin,dc=exoplatform,dc=com"
      configurable_env_var "USER_DIRECTORY_ADMIN_PASSWORD" "exo"

      configurable_env_var "DEPLOYMENT_IFRAMELY_ENABLED" false
      configurable_env_var "DEPLOYMENT_IFRAMELY_IMAGE" "jolt/iframely"
      configurable_env_var "DEPLOYMENT_IFRAMELY_IMAGE_VERSION" "v2.3.0"

      configurable_env_var "DEPLOYMENT_MAILPIT_ENABLED" false
      configurable_env_var "DEPLOYMENT_MAILPIT_IMAGE" "axllent/mailpit"
      configurable_env_var "DEPLOYMENT_MAILPIT_IMAGE_VERSION" "v1.32.0"

      configurable_env_var "DEPLOYMENT_MATRIX_ENABLED" false
      configurable_env_var "DEPLOYMENT_MATRIX_IMAGE" "matrixdotorg/synapse"
      configurable_env_var "DEPLOYMENT_MATRIX_IMAGE_VERSION" "v1.118.0"
      configurable_env_var "DEPLOYMENT_MATRIX_ADMIN_USERNAME" "root"
      configurable_env_var "DEPLOYMENT_MATRIX_ADMIN_PASSWORD" "$(fqdn_rand_string 32 'admin-password' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_MATRIX_REGISTRATION_SHARED_KEY" "$(fqdn_rand_string 32 'reg-secret' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_MATRIX_JWT_SECRET" "$(fqdn_rand_string 32 'jwt-secret' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_MATRIX_MACARON_SECRET_KEY" "$(fqdn_rand_string 64 'macaroon-secret"' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_MATRIX_FORM_SECRET" "$(fqdn_rand_string 32 'form-secret' ${INSTANCE_KEY})"

      configurable_env_var "DEPLOYMENT_CLAMAV_ENABLED" false
      configurable_env_var "DEPLOYMENT_CLAMAV_IMAGE" "clamav/clamav"
      configurable_env_var "DEPLOYMENT_CLAMAV_IMAGE_VERSION" "1.5.1"

      configurable_env_var "DEPLOYMENT_AI_ENABLED" false
      configurable_env_var "DEPLOYMENT_AI_IMAGE" "ollama/ollama"
      configurable_env_var "DEPLOYMENT_AI_IMAGE_VERSION" "0.32.1"
      configurable_env_var "DEPLOYMENT_AI_OLLAMA_MEM_LIMIT" "8g"
      configurable_env_var "DEPLOYMENT_AI_OLLAMA_CPU_LIMIT" "4"
      configurable_env_var "DEPLOYMENT_AI_OLLAMA_NUM_PARALLEL" "4"
      configurable_env_var "DEPLOYMENT_AI_OLLAMA_KEEP_ALIVE" "5m"

      configurable_env_var "DEPLOYMENT_FRONTAIL_ENABLED" false
      configurable_env_var "DEPLOYMENT_FRONTAIL_IMAGE" "hbenali/frontail"
      configurable_env_var "DEPLOYMENT_FRONTAIL_IMAGE_VERSION" "2.37"

      configurable_env_var "DEPLOYMENT_KEYCLOAK_ENABLED" false
      configurable_env_var "DEPLOYMENT_KEYCLOAK_IMAGE" "quay.io/keycloak/keycloak"
      configurable_env_var "DEPLOYMENT_KEYCLOAK_IMAGE_VERSION" "26.8"
      configurable_env_var "DEPLOYMENT_KEYCLOAK_MODE" "SAML"

      configurable_env_var "DEPLOYMENT_CLOUDBEAVER_ENABLED" false
      configurable_env_var "DEPLOYMENT_CLOUDBEAVER_IMAGE" "exoplatform/cloudbeaver"
      configurable_env_var "DEPLOYMENT_CLOUDBEAVER_IMAGE_VERSION" "26.2.3-0"
      configurable_env_var "DEPLOYMENT_CLOUDBEAVER_READONLY" true
      configurable_env_var "DEPLOYMENT_CLOUDBEAVER_AI_CHAT_DISABLED" true

      configurable_env_var "DEPLOYMENT_LAM_ENABLED" false
      configurable_env_var "DEPLOYMENT_LAM_IMAGE" "ghcr.io/ldapaccountmanager/lam"
      configurable_env_var "DEPLOYMENT_LAM_IMAGE_VERSION" "stable"

      configurable_env_var "DEPLOYMENT_JITSI_ENABLED" false
      configurable_env_var "DEPLOYMENT_JITSI_MEM_LIMIT" 4g
      configurable_env_var "DEPLOYMENT_JITSI_JICOFO_XMX" 1g
      configurable_env_var "DEPLOYMENT_JITSI_JVB_XMX" 1g
      configurable_env_var "DEPLOYMENT_JITSI_IMAGE" "exoplatform/jitsi"
      configurable_env_var "DEPLOYMENT_JITSI_EXCALIDRAW_BACKEND_IMAGE_VERSION" "2026.3.0"
      configurable_env_var "DEPLOYMENT_JITSI_EXO_JWT_SECRET" "$(fqdn_rand_string 32 'exo-jwt' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_JITSI_JIBRI_RECORDER_PASSWORD" "$(fqdn_rand_string 32 'jibri-recorder' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_JITSI_JIBRI_XMPP_PASSWORD" "$(fqdn_rand_string 32 'jibri-xmpp' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_JITSI_JICOFO_AUTH_PASSWORD" "$(fqdn_rand_string 32 'jicofo-auth"' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_JITSI_JICOFO_COMPONENT_SECRET" "$(fqdn_rand_string 32 'jicofo-component' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_JITSI_JVB_AUTH_PASSWORD" "$(fqdn_rand_string 32 'jvb-auth' ${INSTANCE_KEY})"
      configurable_env_var "DEPLOYMENT_JITSI_JWT_APP_SECRET" "$(fqdn_rand_string 32 'jwt-app' ${INSTANCE_KEY})"

      configurable_env_var "DEPLOYMENT_SFTP_ENABLED" false
      configurable_env_var "DEPLOYMENT_SFTP_IMAGE" "atmoz/sftp"
      configurable_env_var "DEPLOYMENT_SFTP_IMAGE_VERSION" "latest"

      configurable_env_var "DEPLOYMENT_CALDAV_ENABLED" false
      configurable_env_var "DEPLOYMENT_CALDAV_IMAGE" "ckulka/baikal"
      configurable_env_var "DEPLOYMENT_CALDAV_IMAGE_VERSION" "nginx-php8.2"
      configurable_env_var "DEPLOYMENT_CALDAV_ADMIN_PASSWORD" "ba1kalAdm1n"
      configurable_env_var "DEPLOYMENT_CALDAV_CALENDAR_USERNAME" "calendar"
      configurable_env_var "DEPLOYMENT_CALDAV_CALENDAR_PASSWORD" "ba1kalUs3r"
      configurable_env_var "DEPLOYMENT_CALDAV_TIMEZONE" "UTC"
      configurable_env_var "DEPLOYMENT_CALDAV_DB_ENCRYPTION_KEY" ""

      configurable_env_var "DEPLOYMENT_DEBUG_ENABLED" false
      configurable_env_var "DEPLOYMENT_DEBUGPROXY_IMAGE" "ghcr.io/vi/websocat"
      configurable_env_var "DEPLOYMENT_DEBUGPROXY_IMAGE_VERSION" "v1.14.1"
      configurable_env_var "DEPLOYMENT_DEV_ENABLED" false
      configurable_env_var "DEPLOYMENT_CONTINUOUS_ENABLED" false

      # Renders the Jinja templates (when neither jinjanate nor j2 is installed on the host)
      configurable_env_var "DEPLOYMENT_J2CLI_IMAGE" "exoplatform/j2cli"
      configurable_env_var "DEPLOYMENT_J2CLI_VERSION" "2.0.0"

      configurable_env_var "DEPLOYMENT_GZIP_ENABLED" false
      configurable_env_var "DEPLOYMENT_UPLOAD_MAX_FILE_SIZE" "200"
      configurable_env_var "DEPLOYMENT_STAGING_ENABLED" false
      configurable_env_var "DEPLOYMENT_SELFSIGNEDCERTS_HOSTS" ""

      configurable_env_var "DEPLOYMENT_CERTBOT_ENABLED" false
      configurable_env_var "DEPLOYMENT_CERTBOT_CERT_EXPIRE_PERIOD" "2592000" # 30 days
      configurable_env_var "DEPLOYMENT_CERTBOT_ACME_SERVER" "https://acme-v02.api.letsencrypt.org/directory"
      configurable_env_var "DEPLOYMENT_CERTBOT_EMAIL" "certificates@exoplatform.com"
      configurable_env_var "DEPLOYMENT_CERTBOT_EAB_KID" ""
      configurable_env_var "DEPLOYMENT_CERTBOT_EAB_HMAC_KEY" ""
      configurable_env_var "DEPLOYMENT_CERTBOT_FORCE_RENEWAL" false
      configurable_env_var "DEPLOYMENT_CERTBOT_UNDEPLOY_CERT_REMOVAL" true

      env_var "DEPLOYMENT_CERTBOT_CONFIG_FOLDER" "/etc/letsencrypt"
      env_var "DEPLOYMENT_CERTBOT_WEBROOT_PATH" "/srv/wwwcertbot"

      configurable_env_var "DS_FILENAME" "${PRODUCT_NAME}-${PRODUCT_BRANCH}"
      configurable_env_var "DS_TARGET_SERVER" ""

      if [[ "$DEPLOYMENT_ADDONS" =~ "exo-onlyoffice" ]]; then
        env_var "DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED" true
      fi

      if [ "${DS_FILENAME:-}" = "CURRENT" ]; then
        env_var "DS_FILENAME" "${INSTANCE_KEY}"
      fi

      configurable_env_var "INSTANCE_SSL_CERTIFICATE_FILE" "${APACHE_SSL_CERTIFICATE_FILE}"
      configurable_env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${APACHE_SSL_CERTIFICATE_KEY_FILE}"
      configurable_env_var "INSTANCE_DOMAIN" "" # Default one

      configurable_env_var "DEPLOYMENT_APACHE_HTTPS_ENABLED" false
      configurable_env_var "DEPLOYMENT_APACHE_HTTPSONLY_ENABLED" false
      configurable_env_var "DEPLOYMENT_APACHE_WEBSOCKET_ENABLED" true

      configurable_env_var "DEPLOYMENT_LABELS" ""

      # Push notifications configuration
      # Enabled by default for the enterprise edition and if the exo-push-notifications addon is present on the deployed addons
      if [[ "$DEPLOYMENT_ADDONS" =~ "exo-push-notifications" ]]; then
        env_var "DEPLOYMENT_PUSH_NOTIFICATIONS_ENABLED" true
      fi
      configurable_env_var "DEPLOYMENT_PUSH_NOTIFICATIONS_CONFIGURATION_FILE" ""

      # The image of the product: they are set by the script
      env_var "ARTIFACT_GROUPID" ""
      env_var "ARTIFACT_ARTIFACTID" ""
      env_var "ARTIFACT_TIMESTAMP" ""
      env_var "ARTIFACT_DATE" ""
      env_var "ARTIFACT_DL_URL" ""
      env_var "DEPLOYMENT_IMAGE" ""
      env_var "DEPLOYMENT_DATE" ""
      env_var "DEPLOYMENT_DIR" ""
      env_var "DEPLOYMENT_LOG_URL" ""
      env_var "DEPLOYMENT_LIVE_LOG_URL" ""
      env_var "DEPLOYMENT_LOG_PATH" ""
      env_var "DEPLOYMENT_CERTBOT_DOMAIN" ""
      env_var "DEPLOYMENT_LDAP_LINK" ""
      env_var "DEPLOYMENT_IFRAMELY_LINK" ""
      env_var "DEPLOYMENT_SFTP_LINK" ""

      # Classifier to group together projects in the UI
      env_var PLF_BRANCH "UNKNOWN"

      # More user friendly description
      env_var "PRODUCT_DESCRIPTION" "${PRODUCT_NAME}"

      # Only eXo Platform / Meeds 7.0 and later are supported
      if ! [[ "${PRODUCT_VERSION}" =~ ^([7-9]|[1-9][0-9])\.[0-9]+ ]]; then
        echo_error "Product version \"${PRODUCT_VERSION}\" is not supported: only 7.0 and later are."
        print_usage
        exit 1
      fi
      # The docker image and the prefix of the environment variables of the image, by product.
      # Be careful, the product name should be no longer than 10 (because of the database user name limit)
      case "${PRODUCT_NAME}" in
        meeds)
          env_var PRODUCT_DESCRIPTION "Meeds.io"
          env_var DEPLOYMENT_ENV_PREFIX "MEEDS"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        plfcom)
          env_var PRODUCT_DESCRIPTION "Platform CE"
          env_var DEPLOYMENT_ENV_PREFIX "EXO"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
        ;;
        plfent)
          env_var PRODUCT_DESCRIPTION "Platform EE"
          env_var DEPLOYMENT_ENV_PREFIX "EXO"
          env_var PLF_BRANCH "${PRODUCT_BRANCH}"
          env_var "DEPLOYMENT_PUSH_NOTIFICATIONS_ENABLED" true
        ;;
        *)
          echo_error "Invalid product \"${PRODUCT_NAME}\": only meeds, plfcom and plfent are supported."
          print_usage
          exit 1
        ;;
      esac
      configurable_env_var "DEPLOYMENT_IMAGE_REPO" "$(image_repo_of_product ${PRODUCT_NAME})"

      if [ -z "${INSTANCE_ID}" ]; then
        env_var "INSTANCE_DESCRIPTION" "${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION}"
      else
        env_var "INSTANCE_DESCRIPTION" "${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} (${INSTANCE_ID})"
      fi

      # Versions of the images of the instance (search, database), of the jdbc driver add-ons and of the companions, by minor version
      # of the product. Add the block of the next minor version here when it is released.
      env_var "DEPLOYMENT_ES_IMAGE" "elasticsearch"
      env_var "DEPLOYMENT_POSTGRESQL_DEFAULT_VERSION" "17"
      configurable_env_var "DEPLOYMENT_ONLYOFFICE_IMAGE" "onlyoffice/documentserver"
      configurable_env_var "DEPLOYMENT_JITSI_CALL_IMAGE_VERSION" "latest"
      case "${PRODUCT_BRANCH}" in
        7.0.x)
          configurable_env_var "DEPLOYMENT_ES_IMAGE_VERSION" "8.14.3"
          env_var "DEPLOYMENT_MYSQL_DEFAULT_VERSION" "8.4.3"
          env_var "DEPLOYMENT_MYSQL_ADDON_VERSION" "2.1.0"
          env_var "DEPLOYMENT_POSTGRESQL_ADDON_VERSION" "2.5.0"
          configurable_env_var "DEPLOYMENT_JITSI_IMAGE_VERSION" "stable-9457"
          configurable_env_var "DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION" "8.2.2"
        ;;
        7.1.x)
          configurable_env_var "DEPLOYMENT_ES_IMAGE_VERSION" "8.14.3"
          env_var "DEPLOYMENT_MYSQL_DEFAULT_VERSION" "8.4.7"
          env_var "DEPLOYMENT_MYSQL_ADDON_VERSION" "2.1.0"
          env_var "DEPLOYMENT_POSTGRESQL_ADDON_VERSION" "2.5.1"
          configurable_env_var "DEPLOYMENT_JITSI_IMAGE_VERSION" "stable-10431"
          configurable_env_var "DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION" "9.1.0"
        ;;
        7.2.x)
          configurable_env_var "DEPLOYMENT_ES_IMAGE_VERSION" "8.18.8"
          env_var "DEPLOYMENT_MYSQL_DEFAULT_VERSION" "8.4.9"
          env_var "DEPLOYMENT_MYSQL_ADDON_VERSION" "2.2.0"
          env_var "DEPLOYMENT_POSTGRESQL_ADDON_VERSION" "2.5.3"
          configurable_env_var "DEPLOYMENT_JITSI_IMAGE_VERSION" "stable-10888"
          configurable_env_var "DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION" "9.4.0"
        ;;
        7.3.x)
          configurable_env_var "DEPLOYMENT_ES_IMAGE_VERSION" "9.4.5"
          env_var "DEPLOYMENT_MYSQL_DEFAULT_VERSION" "8.4.11"
          env_var "DEPLOYMENT_MYSQL_ADDON_VERSION" "2.3.0"
          env_var "DEPLOYMENT_POSTGRESQL_ADDON_VERSION" "2.5.4"
          configurable_env_var "DEPLOYMENT_JITSI_IMAGE_VERSION" "stable-11146-2"
          configurable_env_var "DEPLOYMENT_ONLYOFFICE_IMAGE_VERSION" "9.4.0"
        ;;
        *)
          echo_error "Product version \"${PRODUCT_VERSION}\" (${PRODUCT_BRANCH}) not yet managed"
          exit 1
        ;;
      esac

      # Keycloak SAML SP naming (7.2+): use gatein.sso.sp.* / gatein.sso.picketlink.* instead of gatein.sso.idp.*
      if [[ "${PRODUCT_VERSION}" =~ ^(7\.[2-9]|[89]\.|[1-9][0-9]\.) ]]; then
        env_var "DEPLOYMENT_SAML_SP_NAMING" "true"
      else
        env_var "DEPLOYMENT_SAML_SP_NAMING" "false"
      fi

      ## Global configuration checks
      if [ "${DEPLOYMENT_PUSH_NOTIFICATIONS_ENABLED:-false}" = "true" ] && [ -z "${DEPLOYMENT_PUSH_NOTIFICATIONS_CONFIGURATION_FILE}" ]; then
        echo_warn "Push notification are enabled but the firebase configuration file is not specified (\"DEPLOYMENT_PUSH_NOTIFICATIONS_CONFIGURATION_FILE\" property)"
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
}

#
# The descriptor of the instance (conf/adt/<instance key>.<host>): read by the other actions and by the front-end
#
do_create_deployment_descriptor() {
  echo_info "Creating deployment descriptor ..."
  mkdir -p ${ADT_CONF_DIR}
  evaluate_file_content ${ETC_DIR}/adt/config.j2 ${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}
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
# The database of the instance: a container of the project (MYSQL, MARIADB, POSTGRES) or the HSQLDB of the application.
# The names of the former docker deployments are accepted (DOCKER_MYSQL...).
#
do_get_database_settings() {
  case "${DEPLOYMENT_DB_TYPE}" in
    HSQLDB)
      env_var DEPLOYMENT_DB_TYPE "HSQLDB"
      env_var DEPLOYMENT_DB_ENV_TYPE "hsqldb"
      env_var DEPLOYMENT_DATABASE_ENABLED false
      return
    ;;
    MYSQL | DOCKER_MYSQL)
      env_var DEPLOYMENT_DB_TYPE "MYSQL"
      env_var DEPLOYMENT_DB_ENV_TYPE "mysql"
      env_var DEPLOYMENT_DATABASE_PORT "3306"
      configurable_env_var "DEPLOYMENT_DATABASE_VERSION" "${DEPLOYMENT_MYSQL_DEFAULT_VERSION}"
    ;;
    MARIADB | DOCKER_MARIADB)
      env_var DEPLOYMENT_DB_TYPE "MARIADB"
      env_var DEPLOYMENT_DB_ENV_TYPE "mysql"
      env_var DEPLOYMENT_DATABASE_PORT "3306"
      validate_env_var "DEPLOYMENT_DATABASE_VERSION"
    ;;
    POSTGRES | DOCKER_POSTGRES)
      env_var DEPLOYMENT_DB_TYPE "POSTGRES"
      env_var DEPLOYMENT_DB_ENV_TYPE "pgsql"
      env_var DEPLOYMENT_DATABASE_PORT "5432"
      configurable_env_var "DEPLOYMENT_DATABASE_VERSION" "${DEPLOYMENT_POSTGRESQL_DEFAULT_VERSION}"
    ;;
    *)
      echo_error "Database type ${DEPLOYMENT_DB_TYPE} not supported (HSQLDB, MYSQL, MARIADB or POSTGRES)"
      exit 1
    ;;
  esac
  env_var DEPLOYMENT_DATABASE_ENABLED true
  # Build a database name and a user without dot, minus ... (the user uses the branch because limited in length)
  env_var DEPLOYMENT_DATABASE_NAME "${INSTANCE_KEY}"
  env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//./_}"
  env_var DEPLOYMENT_DATABASE_NAME "${DEPLOYMENT_DATABASE_NAME//-/_}"
  if [ -z "${INSTANCE_TOKEN:-}" ]; then
    env_var DEPLOYMENT_DATABASE_USER "${PRODUCT_NAME}_${PRODUCT_BRANCH}"
  else
    env_var DEPLOYMENT_DATABASE_USER "${PRODUCT_NAME}_${INSTANCE_TOKEN:0:8}"
  fi
  env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//./_}"
  env_var DEPLOYMENT_DATABASE_USER "${DEPLOYMENT_DATABASE_USER//-/_}"
}

#
# Warn when the ports of the instance are in the range of the ephemeral (client) ports of the server
#
do_check_port_prefix() {
  if [ -z "$(sysctl net.ipv4.ip_local_port_range 2>/dev/null)" ]; then
    echo_warn "net.ipv4.ip_local_port_range isn't specified. We cannot check DEPLOYMENT_PORT_PREFIX."
    return 0
  fi
  local _min _max _first="${DEPLOYMENT_PORT_PREFIX}00"
  _min=$(sysctl net.ipv4.ip_local_port_range | awk '{print $3}')
  _max=$(sysctl net.ipv4.ip_local_port_range | awk '{print $4}')
  if [[ "${_first}" -ge "${_min}" && "${_first}" -lt "${_max}" ]]; then
    echo_warn "Port ${DEPLOYMENT_PORT_PREFIX}XX is inside the server ephermal ports range (${_min} - ${_max})"
    echo_warn "This increases the risk of deployment failures. DEPLOYMENT_PORT_PREFIX or ip_local_port_range needs to be reviewed!"
  else
    echo_info "Port ${DEPLOYMENT_PORT_PREFIX}XX is outside the server ephermal ports range (${_min} - ${_max})."
  fi
}

#
# The name, the port and the URL of the instance, and what the application must know about the proxies in front of it
#
do_get_deployment_urls() {
  # The only published port of the instance: its nginx (Apache forwards the virtual host to it)
  env_var "DEPLOYMENT_HTTP_PORT" "${DEPLOYMENT_PORT_PREFIX}01"

  if ${ADT_DEV_MODE}; then
    env_var "DEPLOYMENT_EXT_HOST" "localhost"
    env_var "DEPLOYMENT_EXT_PORT" "${DEPLOYMENT_HTTP_PORT}"
  else
    if [ -z "${INSTANCE_TOKEN:-}" ]; then
      env_var "DEPLOYMENT_EXT_HOST" "${INSTANCE_KEY}.${ACCEPTANCE_HOST}"
    else
      if [ -z "${INSTANCE_ID}" ]; then
        env_var "DEPLOYMENT_EXT_HOST" "${PRODUCT_NAME}-${DEPLOYMENT_PORT_PREFIX}.${ACCEPTANCE_HOST}"
      else
        env_var "DEPLOYMENT_EXT_HOST" "${PRODUCT_NAME}-${DEPLOYMENT_PORT_PREFIX}-${INSTANCE_ID}.${ACCEPTANCE_HOST}"
      fi
    fi
    env_var "DEPLOYMENT_EXT_PORT" "80"
  fi
  # HTTPS only implies HTTPS
  if ${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED}; then
    env_var "DEPLOYMENT_APACHE_HTTPS_ENABLED" true
  fi
  DEPLOYMENT_URL_SCHEME="http"
  ${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED} && DEPLOYMENT_URL_SCHEME="https"

  local _vhost="${DEPLOYMENT_EXT_HOST}"
  [ -n "${DEPLOYMENT_APACHE_VHOST_ALIAS}" ] && _vhost="${DEPLOYMENT_APACHE_VHOST_ALIAS}"
  env_var "DEPLOYMENT_URL" $(do_build_url "${DEPLOYMENT_URL_SCHEME}" "${_vhost}" "${DEPLOYMENT_EXT_PORT}" "")

  # The application builds its URLs from the host and the scheme of the proxy in front of it (https as soon as HTTPS is enabled)
  env_var "DEPLOYMENT_PROXY_VHOST" "${_vhost}"
  if ${DEPLOYMENT_APACHE_HTTPS_ENABLED} && ! ${ADT_DEV_MODE}; then
    env_var "DEPLOYMENT_PROXY_SSL" "true"
    env_var "DEPLOYMENT_PROXY_PORT" "443"
    # nginx serves the same certificate as Apache
    env_var "DEPLOYMENT_NGINX_TLS" "true"
  else
    env_var "DEPLOYMENT_PROXY_SSL" "false"
    env_var "DEPLOYMENT_PROXY_PORT" "${DEPLOYMENT_EXT_PORT}"
    env_var "DEPLOYMENT_NGINX_TLS" "false"
  fi
  env_var "DEPLOYMENT_LOG_URL" "${DEPLOYMENT_URL}/logs/platform.log"
}

#
# The docker image to deploy: the tag of a snapshot or a release, or the build chosen in the registry for -MLT / -MBL / -GA
#
do_resolve_image() {
  local _tag
  _tag=$(resolve_image_tag "${DEPLOYMENT_IMAGE_REPO}" "${PRODUCT_VERSION}")
  env_var "DEPLOYMENT_IMAGE" "${DEPLOYMENT_IMAGE_REPO}:${_tag}"
  env_var "ARTIFACT_GROUPID" "${DEPLOYMENT_IMAGE_REPO%%/*}"
  env_var "ARTIFACT_ARTIFACTID" "${DEPLOYMENT_IMAGE_REPO#*/}"
  env_var "ARTIFACT_TIMESTAMP" "${_tag}"
  env_var "ARTIFACT_DL_URL" "https://hub.docker.com/r/${DEPLOYMENT_IMAGE_REPO}/tags?name=${_tag}"
  echo_info "Image ${DEPLOYMENT_IMAGE}"
}

#
# The jdbc driver of the database is an add-on of the product
#
do_add_jdbc_driver_addon() {
  [ "${DEPLOYMENT_DATABASE_ENABLED}" = "true" ] || return 0
  local _vendor="exo" _driver _version
  [ "${PRODUCT_NAME}" = "meeds" ] && _vendor="meeds"
  case "${DEPLOYMENT_DB_TYPE}" in
    MYSQL | MARIADB) _driver="mysql";      _version="${DEPLOYMENT_MYSQL_ADDON_VERSION}" ;;
    POSTGRES)        _driver="postgresql"; _version="${DEPLOYMENT_POSTGRESQL_ADDON_VERSION}" ;;
  esac
  local _addon="${_vendor}-jdbc-driver-${_driver}:${_version}"
  echo_info "Using ${_addon} addon as jdbc driver"
  env_var "DEPLOYMENT_ADDONS" "${DEPLOYMENT_ADDONS:+${DEPLOYMENT_ADDONS},}${_addon}"
}

#
# The certificate of the virtual host (Apache and nginx share it): the one of the domain, or a Certbot one
#
do_resolve_instance_certificate() {
  # Auto extract domain name
  if [ ! -z "${DEPLOYMENT_APACHE_VHOST_ALIAS:-}" ] && [ -z "${INSTANCE_DOMAIN:-}" ]; then
    env_var "INSTANCE_DOMAIN" "$(echo ${DEPLOYMENT_APACHE_VHOST_ALIAS} | cut -d'.' -f2,3)"
  fi
  env_var "DEPLOYMENT_CERTBOT_DOMAIN" "$(getdomainfromUrl ${DEPLOYMENT_URL})"

  # Selct Certificate according to the domain name
  case ${INSTANCE_DOMAIN:-} in
    exoplatform.org)
      if [ "${DEPLOYMENT_CERTBOT_ENABLED:-false}" = "true" ]; then
        echo_error "Certbot is not available for exoplatform.org domain name!"
        exit 1
      fi
    ;;
    meeds.io)
      # MEEDSIO_XXXXX vars must be set on Jenkins SLAVE or loaded as global envs
      env_var "INSTANCE_SSL_CERTIFICATE_FILE" "${MEEDSIO_SSL_CERTIFICATE_FILE}"
      env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${MEEDSIO_SSL_CERTIFICATE_KEY_FILE}"
    ;;
    *)
      if [ "${DEPLOYMENT_CERTBOT_ENABLED:-false}" = "true" ]; then
        if [ "${DEPLOYMENT_APACHE_HTTPS_ENABLED:-false}" = "true" ] || [ "${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED:-false}" = "true" ]; then
          do_generate_certbot_certificate
        else
          echo_error "HTTPS must be enabled when enabling certbot!"
          exit 1
        fi
      else
        echo_error "${INSTANCE_DOMAIN:-} domain isn't supported!"
        exit 1
      fi
    ;;
  esac
  if [ "${DEPLOYMENT_CERTBOT_ENABLED:-false}" != "true" ] && ! ([ -f "${INSTANCE_SSL_CERTIFICATE_FILE}" ] && [ -f "${INSTANCE_SSL_CERTIFICATE_KEY_FILE}" ]); then
    echo_error "Deploying instance with HTTPS scheme but one of \${INSTANCE_SSL_CERTIFICATE_FILE} (\"${INSTANCE_SSL_CERTIFICATE_FILE}\"),\${INSTANCE_SSL_CERTIFICATE_KEY_FILE} (\"${INSTANCE_SSL_CERTIFICATE_KEY_FILE}\") is invalid"
    print_usage
    exit 1
  fi
}

#
# The Apache virtual host of the instance: it terminates the TLS, authenticates and forwards to the nginx of the instance
#
do_configure_apache() {
  echo_info "Configure and update AWStats ..."
  mkdir -p ${AWSTATS_CONF_DIR}
  # Regenerates stats for this Vhosts
  export DOMAIN=${DEPLOYMENT_EXT_HOST}
  evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.j2 ${AWSTATS_CONF_DIR}/awstats.${DEPLOYMENT_EXT_HOST}.conf
  [ -e ${ADT_DATA}/var/log/apache2/${DOMAIN}-access.log ] && do_generate_awstats ${DOMAIN} ${ADT_DEV_MODE}
  unset DOMAIN
  # Regenerates stats for root vhosts
  export DOMAIN=${ACCEPTANCE_HOST}
  evaluate_file_content ${ETC_DIR}/awstats/awstats.conf.j2 ${AWSTATS_CONF_DIR}/awstats.${ACCEPTANCE_HOST}.conf
  [ -e ${ADT_DATA}/var/log/apache2/${DOMAIN}-access.log ] && do_generate_awstats ${DOMAIN} ${ADT_DEV_MODE}
  unset DOMAIN
  echo_info "Done."

  echo_info "Creating Apache Virtual Host ..."
  mkdir -p ${APACHE_CONF_DIR}

  # The parts the virtual hosts share (also rendered for the front-end by "init")
  for _include in compression tls; do
    evaluate_file_content ${ETC_DIR}/apache2/includes/${_include}.include.j2 ${APACHE_CONF_DIR}/includes/${_include}.include
  done
  evaluate_file_content ${ETC_DIR}/apache2/includes/instance.include.j2 ${APACHE_CONF_DIR}/includes/${DEPLOYMENT_EXT_HOST}.include

  case ${DEPLOYMENT_APACHE_SECURITY} in
    public | private) ;;
    *)
      echo_error "Invalid apache security type \"${DEPLOYMENT_APACHE_SECURITY}\""
      print_usage
      exit 1
    ;;
  esac
  if ${DEPLOYMENT_APACHE_HTTPS_ENABLED}; then
    if ${DEPLOYMENT_APACHE_HTTPSONLY_ENABLED}; then
      echo_n_info "Deploying Apache instance configuration for HTTPS only..."
    else
      echo_n_info "Deploying Apache instance configuration for HTTP and HTTPS..."
    fi
  else
    echo_n_info "Deploying Apache instance configuration for HTTP only..."
  fi
  # Security, HTTPS and the protection of each feature are handled with conditions inside the template
  evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance.j2 ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
  # holds the LDAP bind password: Apache reads its configuration as root
  chmod 600 ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
  echo "OK."
  echo_info "Done."
  echo_info "Rotate Apache logs ..."

  rm -f ${TMP_DIR}/logrotate-${INSTANCE_KEY}
  evaluate_file_content ${ETC_DIR}/logrotate.d/instance.j2 ${TMP_DIR}/logrotate-${INSTANCE_KEY}
  do_logrotate "${TMP_DIR}/logrotate-${INSTANCE_KEY}" ${ADT_DEV_MODE}
  rm -f ${TMP_DIR}/logrotate-${INSTANCE_KEY}

  rm -f ${TMP_DIR}/logrotate-acceptance
  evaluate_file_content ${ETC_DIR}/logrotate.d/frontend.j2 ${TMP_DIR}/logrotate-acceptance
  do_logrotate "${TMP_DIR}/logrotate-acceptance" ${ADT_DEV_MODE}
  rm -f ${TMP_DIR}/logrotate-acceptance

  do_reload_apache ${ADT_DEV_MODE}

  echo_info "Done."
}

#
# Remove the directory of an instance. The containers write in the bind mounted logs with their own uid: what the user cannot
# remove is removed by a throwaway container.
#
do_remove_instance_dir() {
  [ -d "${DEPLOYMENT_DIR}" ] || return 0
  if ! rm -rf "${DEPLOYMENT_DIR}" 2>/dev/null; then
    ${DOCKER_CMD} run --rm --volume "${DEPLOYMENT_DIR}:/instance" "${DEPLOYMENT_HELPER_IMAGE:-alpine:3}" sh -c 'rm -rf /instance/* /instance/.[!.]*'
    rm -rf "${DEPLOYMENT_DIR}"
  fi
}

#
# Function that deploys (pulls the images, configures) the instance
#
do_deploy() {
  configurable_env_var "DEPLOYMENT_APACHE_SECURITY" "private"
  configurable_env_var "DEPLOYMENT_APACHE_VHOST_ALIAS" ""
  configurable_env_var "DEPLOYMENT_DB_TYPE" "HSQLDB"
  configurable_env_var "DEPLOYMENT_JVM_SIZE_MAX" "2g"
  configurable_env_var "DEPLOYMENT_JVM_SIZE_MIN" "512m"
  configurable_env_var "DEPLOYMENT_PORT_PREFIX" "80"

  do_check_port_prefix
  case "${DEPLOYMENT_MODE}" in
    NO_DATA | KEEP_DATA) ;;
    RESTORE_DATASET | DUMP_DATASET)
      echo_error "DEPLOYMENT_MODE=${DEPLOYMENT_MODE}: the datasets are not available yet in the docker compose deployments."
      exit 1
    ;;
    *)
      echo_error "Invalid deployment mode \"${DEPLOYMENT_MODE}\""
      print_usage
      exit 1
    ;;
  esac
  if ${DEPLOYMENT_CONTINUOUS_ENABLED:-false}; then
    if [[ ! "${PRODUCT_VERSION}" =~ .*-(M(BL|LT)|GA)$ ]]; then
      echo_error "Continuous deployment is enabled and product version must ends with -MLT, -MBL or -GA (e.g. 7.2.0-MLT, 7.2.Z-MLT or 7.2.Z-GA)!"
      exit 1
    fi
  fi
  if [ -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ] && ! grep -q '^DEPLOYMENT_COMPOSE_PROJECT=' "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}"; then
    echo_error "${INSTANCE_KEY} was deployed by the previous version of ADT (no docker compose). Undeploy it with that version first."
    exit 1
  fi

  do_get_database_settings
  do_get_deployment_urls
  do_get_companion_settings
  do_get_compose_settings
  do_get_license_settings
  do_add_jdbc_driver_addon
  do_check_companions
  do_resolve_image
  do_get_certbot_settings
  if [ "${DEPLOYMENT_NGINX_TLS}" = "true" ] || ${DEPLOYMENT_APACHE_HTTPS_ENABLED}; then
    do_resolve_instance_certificate
  fi
  do_check_docker_network_capacity

  echo_info "Deploying server ${INSTANCE_DESCRIPTION} ..."

  if [ "${DEPLOYMENT_MODE}" = "NO_DATA" ] && [ -e "${DEPLOYMENT_COMPOSE_FILE}" ]; then
    echo_info "Deleting all existing data for ${INSTANCE_DESCRIPTION} ..."
    do_compose_down true
  fi
  do_prepare_compose_dirs
  do_render_companion_files
  do_render_compose_files
  do_compose_pull
  env_var "ARTIFACT_DATE" "$(do_get_image_build_date "${DEPLOYMENT_IMAGE}")"
  do_start_instance
  do_companion_firewall open
  do_configure_apache
  do_create_deployment_descriptor
  echo_info "Server deployed"
}

#
# Function that starts the instance
#
do_start() {
  # Use a subshell to not expose settings loaded from the deployment descriptor
  (
  # The server is supposed to be already deployed.
  # We load its settings from the configuration
  do_load_deployment_descriptor
  echo_info "Starting server ${INSTANCE_DESCRIPTION} ..."
  do_start_instance
  echo_info "Server started"
  )
}

#
# Function that stops the instance
#
do_stop() {
  # Use a subshell to not expose settings loaded from the deployment descriptor
  (
  do_load_deployment_descriptor
  echo_info "Stopping server ${INSTANCE_DESCRIPTION} ..."
  do_compose_stop
  echo_info "Server stopped."
  )
}

#
# Function that restarts the instance: it keeps its data (DEPLOYMENT_MODE=KEEP_DATA) or starts again from scratch (NO_DATA)
#
do_restart() {
  (
  do_load_deployment_descriptor
  case "${DEPLOYMENT_MODE}" in
    NO_DATA)
      echo_info "Deleting all existing data for ${INSTANCE_DESCRIPTION} ..."
      do_compose_down true
    ;;
    KEEP_DATA)
      do_compose_stop
    ;;
    *)
      echo_error "Invalid deployment mode \"${DEPLOYMENT_MODE}\" (NO_DATA or KEEP_DATA; the datasets are not available yet)"
      print_usage
      exit 1
    ;;
  esac
  echo_info "Starting server ${INSTANCE_DESCRIPTION} ..."
  do_start_instance
  echo_info "Server restarted"
  )
}

#
# Function that undeploys the instance: its containers, network, volumes, files and virtual host
#
do_undeploy() {
  if [ ! -e "${ADT_CONF_DIR}/${INSTANCE_KEY}.${ACCEPTANCE_HOST}" ]; then
    # a deployment that failed after its containers were created has a compose project but no descriptor yet
    if [ -e "${SRV_DIR}/${INSTANCE_KEY}/docker-compose.yml" ]; then
      echo_warn "${INSTANCE_KEY} has no descriptor: its deployment did not complete. Removing its compose project."
      (
      do_get_compose_settings
      do_compose_down true
      do_remove_instance_dir
      )
      echo_info "Server undeployed"
      exit 0
    fi
    echo_warn "${PRODUCT_NAME} ${PRODUCT_VERSION} isn't deployed !"
    echo_warn "The product cannot be undeployed"
    exit 0
  else
    # Use a subshell to not expose settings loaded from the deployment descriptor
    (
    # The server is supposed to be already deployed.
    # We load its settings from the configuration
    do_load_deployment_descriptor
    echo_info "Undeploying server ${PRODUCT_DESCRIPTION} ${PRODUCT_VERSION} ..."
    if [ -e "${DEPLOYMENT_COMPOSE_FILE}" ]; then
      do_compose_down true
    fi
    do_remove_instance_dir
    do_companion_firewall close
    # Delete Awstat config
    rm -f ${AWSTATS_CONF_DIR}/awstats.${DEPLOYMENT_EXT_HOST}.conf
    # Delete the vhost
    rm -f ${APACHE_CONF_DIR}/includes/${DEPLOYMENT_EXT_HOST}.include
    rm -f ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
    # Reload Apache to deactivate the config
    do_reload_apache ${ADT_DEV_MODE}

    if [ "${DEPLOYMENT_CERTBOT_ENABLED}" == "true" ] && [ "${DEPLOYMENT_CERTBOT_UNDEPLOY_CERT_REMOVAL:-true}" == "true" ]; then
      do_unregister_certbot_certificate
    fi

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
  initialize_docker_settings
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
    TXT_GREEN=$(tput -Txterm-256color setaf 2)
    TXT_RED=$(tput -Txterm-256color setaf 1)
    TXT_RESET=$(tput -Txterm-256color sgr0) # Text reset.
    local _line="%-40s %-25s %-25s %-10s %-10s %-10s %-10s\n"
    echo_info "Deployed servers : "
    printf "${_line}" "========================================" "=========================" "=========================" "==========" "==========" "==========" "=========="
    printf "${_line}" "Product" "Version" "Instance" "Database" "Prefix" "HTTP_P" "RUNNING"
    printf "${_line}" "========================================" "=========================" "=========================" "==========" "==========" "==========" "=========="
    for f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${f}
      if instance_is_running "${INSTANCE_KEY}"; then
        STATUS="${TXT_GREEN}true${TXT_RESET}"
      else
        STATUS="${TXT_RED}false${TXT_RESET}"
      fi
      printf "${_line}" "${PRODUCT_DESCRIPTION}" "${PRODUCT_VERSION}" "${INSTANCE_ID}" "${DEPLOYMENT_DB_TYPE}" "${DEPLOYMENT_PORT_PREFIX}XX" "${DEPLOYMENT_HTTP_PORT}" "${STATUS}"
      )
    done
  else
    echo_info "No server deployed."
  fi
}

#
# Functions that act on every deployed server
#
do_foreach_instance() {
  local _action=$1 _label=$2 _f
  initialize_docker_settings
  if [ "$(${CMD_LS} -A ${ADT_CONF_DIR})" ]; then
    echo_info "${_label} all servers ..."
    for _f in ${ADT_CONF_DIR}/*
    do
      # Use a subshell to not expose settings loaded from the deployment descriptor
      (
      source ${_f}
      ${_action}
      )
    done
    echo_info "All servers done"
  else
    echo_info "No server deployed."
  fi
}

do_start_all()     { do_foreach_instance do_start    "Starting"; }
do_stop_all()      { do_foreach_instance do_stop     "Stopping"; }
do_restart_all()   { do_foreach_instance do_restart  "Restarting"; }
do_undeploy_all()  { do_foreach_instance do_undeploy "Undeploying"; }
