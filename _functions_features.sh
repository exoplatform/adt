#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_FEATURES_LOADED:-false} && return
set -u

if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_string.sh"

# #############################################################################
# Product settings + version matrix + feature toggles
#
# initialize_product_settings() reads etc/versions.yaml (via yq) and computes
# all the image tags, DB/ES versions, feature defaults and env-var prefix for
# the current PRODUCT_NAME + PRODUCT_VERSION. This replaces the v1 600-line
# if/elif chain.
# #############################################################################

# Path to the version matrix (shipped with adt). Set lazily in
# initialize_product_settings() because ETC_DIR is only exported by adt.sh
# after the function files are sourced.
VERSIONS_FILE=""

# yq read helper: .path -> value from VERSIONS_FILE
# $1 : yq path expression
yq_read() {
  yq -r "$1" "${VERSIONS_FILE}"
}

# Compute PRODUCT_BRANCH (X.Y.x) and PRODUCT_MAJOR_BRANCH (X.x) from PRODUCT_VERSION.
compute_product_branch() {
  local _v="${PRODUCT_VERSION}"
  # Strip trailing suffixes: -SNAPSHOT, -Mxx, -RCxx, -CPxx, _N, -meed-..., +...
  # to get the base version X.Y.Z
  local _base
  _base=$(echo "${_v}" | sed -E 's/(\+.*|-SNAPSHOT|-M[0-9]+|-RC[0-9]+|-CP[0-9]+|-meed-[0-9]+_[0-9]+|_[0-9]+)$//')
  # If nothing was stripped (e.g. floating tags like latest/develop/alpine),
  # fall back to a hardcoded 7.2 default for branch-pinning purposes.
  case "${_base}" in
    latest|develop|alpine|continuous) _base="7.2.0" ;;
  esac
  local _major _minor
  _major=$(echo "${_base}" | cut -d'.' -f1)
  _minor=$(echo "${_base}" | cut -d'.' -f2)
  env_var "PRODUCT_BRANCH" "${_major}.${_minor}.x"
  env_var "PRODUCT_MAJOR_BRANCH" "${_major}.x"
  env_var "PRODUCT_VERSION_SHORT" "${_major}.${_minor}"
}

# Resolve the image tag for the current product+version using tag_patterns.
# Sets IMAGE and IMAGE_TAG env vars.
resolve_image_tag() {
  local _image _patterns _tag
  _image=$(yq_read ".products.\"${PRODUCT_NAME}\".image")
  _patterns=$(yq_read ".products.\"${PRODUCT_NAME}\".tag_patterns")
  env_var "IMAGE" "${DEPLOYMENT_IMAGE:-${_image}}"

  # Determine the kind of version to pick the right tag pattern
  local _kind="release"
  case "${PRODUCT_VERSION}" in
    *-SNAPSHOT|latest|develop|alpine|*continuous) _kind="snapshot" ;;
  esac

  local _pattern
  _pattern=$(yq_read ".products.\"${PRODUCT_NAME}\".tag_patterns.\"${_kind}\" // .products.\"${PRODUCT_NAME}\".tag_patterns.release")
  # Substitute {v} with the raw version, {branch} with the short branch (e.g. 7.3)
  local _tag="${_pattern/\{v\}/${PRODUCT_VERSION}}"
  _tag="${_tag/\{branch\}/${PRODUCT_VERSION_SHORT}}"
  env_var "IMAGE_TAG" "${DEPLOYMENT_IMAGE_TAG:-${_tag}}"
}

# Initialize all product settings from the version matrix.
# This is called early (before do_deploy/do_start/...) to populate:
# IMAGE, IMAGE_TAG, DB image, ES image, env prefix, app service name, volumes, ...
initialize_product_settings() {
  env_var "VERSIONS_FILE" "${ETC_DIR}/versions.yaml"
  validate_env_var "VERSIONS_FILE"
  if [ ! -f "${VERSIONS_FILE}" ]; then
    echo_error "Version matrix not found: ${VERSIONS_FILE}"
    exit 1
  fi
  compute_product_branch
  resolve_image_tag

  # Product env prefix (MEEDS or EXO) and app service name
  local _prefix
  _prefix=$(yq_read ".products.\"${PRODUCT_NAME}\".env_prefix")
  env_var "PRODUCT_ENV_PREFIX" "${_prefix}"
  env_var "APP_SERVICE_NAME" "${PRODUCT_NAME}"

  # License requirement (plfent)
  local _lic
  _lic=$(yq_read ".products.\"${PRODUCT_NAME}\".requires_license // false")
  env_var "PRODUCT_REQUIRES_LICENSE" "${_lic}"

  # Compute instance hostname
  compute_instance_key
  env_var "DEPLOYMENT_EXT_HOST" "${INSTANCE_KEY}.${ACCEPTANCE_HOST}"

  # DB
  configurable_env_var "DEPLOYMENT_DB_TYPE" "postgres"
  local _db_image
  _db_image=$(yq_read ".defaults.db_image.\"${DEPLOYMENT_DB_TYPE}\" // .defaults.db_image.postgres")
  local _db_version
  _db_version=$(yq_read ".products.\"${PRODUCT_NAME}\".versions.\"${PRODUCT_BRANCH}\".db.\"${DEPLOYMENT_DB_TYPE}\" // .defaults.db_image.\"${DEPLOYMENT_DB_TYPE}\"")
  # If the version matrix returned a full image, use it; else combine image:version
  if [ -n "${_db_version}" ] && [[ "${_db_version}" == *":"* ]]; then
    env_var "DB_IMAGE" "${_db_version}"
  elif [ -n "${DEPLOYMENT_DATABASE_VERSION:-}" ]; then
    env_var "DB_IMAGE" "${_db_image}:${DEPLOYMENT_DATABASE_VERSION}"
  else
    # Extract the tag part from the default image
    local _default_tag="${_db_image##*:}"
    env_var "DB_IMAGE" "${_db_image%%:*}:${_default_tag}"
  fi
  env_var "DB_VOLUME" "${COMPOSE_PROJECT}_db_data"

  # DB port (internal) and management port (when exposed on loopback)
  case "${DEPLOYMENT_DB_TYPE}" in
    postgres) env_var "DB_PORT" "5432" ;;
    mysql)    env_var "DB_PORT" "3306" ;;
    *)        env_var "DB_PORT" "5432" ;;
  esac
  # Management ports exposure (must be set before DB_MANAGEMENT_PORT uses it)
  configurable_env_var "DEPLOYMENT_EXPOSE_MANAGEMENT_PORTS" false
  configurable_env_var "DEPLOYMENT_PORT_PREFIX" "100"
  # Management port = PORT_PREFIX + "20"
  env_var "DB_MANAGEMENT_PORT" "${DEPLOYMENT_PORT_PREFIX}20"

  # ES
  local _es_image
  _es_image=$(yq_read ".products.\"${PRODUCT_NAME}\".versions.\"${PRODUCT_BRANCH}\".es // .defaults.es_image")
  env_var "ES_IMAGE" "${_es_image}"
  env_var "ES_VOLUME" "${COMPOSE_PROJECT}_es_data"
  configurable_env_var "ES_HEAP" "512m"

  # DB connection defaults (compose service 'db')
  configurable_env_var "DEPLOYMENT_DB_NAME"   "${PRODUCT_NAME}"
  configurable_env_var "DEPLOYMENT_DB_USER"   "${PRODUCT_NAME}"
  configurable_env_var "DEPLOYMENT_DB_PASSWORD" "$(getrandomstring 16)"

  # JVM
  configurable_env_var "DEPLOYMENT_JVM_SIZE_MAX" "3g"
  configurable_env_var "DEPLOYMENT_JVM_SIZE_MIN" "512m"
  configurable_env_var "DEPLOYMENT_UPLOAD_MAX_FILE_SIZE" "200"
  configurable_env_var "DEPLOYMENT_OPTS" ""

  # License (plfent)
  configurable_env_var "EXO_LICENSE_FILE" ""

  # Add-ons
  configurable_env_var "DEPLOYMENT_ADDONS" ""
  configurable_env_var "DEPLOYMENT_ADDONS_REMOVE_LIST" ""
  configurable_env_var "DEPLOYMENT_ADDONS_CATALOG" ""
  configurable_env_var "DEPLOYMENT_ADDONS_CONFLICT_MODE" ""
  configurable_env_var "DEPLOYMENT_PATCHES_LIST" ""
  configurable_env_var "DEPLOYMENT_PATCHES_CATALOG_URL" ""
  configurable_env_var "DEPLOYMENT_LABELS" ""

  # Feature toggles (defaults from versions.yaml, overridable per-deploy)
  # Must be initialized BEFORE any code that branches on them (e.g. mail host)
  init_feature_toggle "DEPLOYMENT_ONLYOFFICE_ENABLED"
  init_feature_toggle "DEPLOYMENT_MAILPIT_ENABLED"
  init_feature_toggle "DEPLOYMENT_MATRIX_ENABLED"
  init_feature_toggle "DEPLOYMENT_JITSI_ENABLED"
  init_feature_toggle "DEPLOYMENT_AI_ENABLED"
  init_feature_toggle "DEPLOYMENT_IFRAMELY_ENABLED"
  init_feature_toggle "DEPLOYMENT_CLOUDBEAVER_ENABLED"
  init_feature_toggle "DEPLOYMENT_KEYCLOAK_ENABLED"
  init_feature_toggle "DEPLOYMENT_LDAP_ENABLED"
  init_feature_toggle "DEPLOYMENT_CALDAV_ENABLED"
  init_feature_toggle "DEPLOYMENT_CLAMAV_ENABLED"
  init_feature_toggle "DEPLOYMENT_FRONTAIL_ENABLED"
  init_feature_toggle "DEPLOYMENT_DOZZLE_ENABLED" "true"

  # Mail (defaults to mailpit when enabled, else localhost)
  # Depends on DEPLOYMENT_MAILPIT_ENABLED being set above
  if [ "${DEPLOYMENT_MAILPIT_ENABLED}" = "true" ]; then
    env_var "MAIL_SMTP_HOST" "mailpit"
    env_var "MAIL_SMTP_PORT" "1025"
  else
    configurable_env_var "MAIL_SMTP_HOST" "localhost"
    configurable_env_var "MAIL_SMTP_PORT" "25"
  fi

  # Sidecar image versions (from versions.yaml features section)
  init_feature_version "ONLYOFFICE_VERSION"  "onlyoffice"
  init_feature_version "MAILPIT_VERSION"     "mailpit"
  init_feature_version "MATRIX_VERSION"      "matrix"
  init_feature_version "OLLAMA_VERSION"      "ollama"
  init_feature_version "IFRAMELY_VERSION"    "iframely"
  init_feature_version "CLOUDBEAVER_VERSION" "cloudbeaver"
  init_feature_version "KEYCLOAK_VERSION"    "keycloak"
  init_feature_version "LDAP_VERSION"        "ldap"
  init_feature_version "PHPLDAPADMIN_VERSION" "phpldapadmin"
  init_feature_version "BAIKAL_VERSION"      "baikal"
  init_feature_version "CLAMAV_VERSION"      "clamav"
  init_feature_version "FRONTAIL_VERSION"    "frontail"
  init_feature_version "DOZZLE_VERSION"      "dozzle"
  init_feature_version "JITSI_VERSION"       "jitsi"

  # Feature passwords/secrets (generated, overridable)
  configurable_env_var "KEYCLOAK_ADMIN_PASSWORD"  "$(getrandomstring 16)"
  configurable_env_var "KEYCLOAK_CLIENT_SECRET"   "$(getrandomstring 24)"
  configurable_env_var "LDAP_ADMIN_PASSWORD"      "$(getrandomstring 16)"
  configurable_env_var "MATRIX_DB_PASSWORD"       "$(getrandomstring 16)"

  # TLS cert resolution
  resolve_instance_certs

  echo_debug "initialize_product_settings: IMAGE=${IMAGE}:${IMAGE_TAG} DB=${DB_IMAGE} ES=${ES_IMAGE} prefix=${PRODUCT_ENV_PREFIX}"
}

# Resolve a sidecar image version from the versions.yaml features section.
# $1 : env var name to set
# $2 : feature key in versions.yaml `features:` section
init_feature_version() {
  local _var=$1
  local _feature=$2
  local _current
  _current=$(eval "echo \"\${${_var}-UNSET}\"")
  if [ "${_current}" = "UNSET" ]; then
    local _ver
    _ver=$(yq_read ".features.\"${_feature}\".\"${PRODUCT_BRANCH}\" // .features.\"${_feature}\".default // \"latest\"")
    eval "${_var}=\"\${_ver}\""
    export "${_var}"
  fi
  echo_debug "${_var}=$(eval echo \${${_var}})"
}

# Initialize a feature toggle env var from versions.yaml default if not set.
# $1 : env var name
# $2 : hardcoded fallback default (optional, default false)
init_feature_toggle() {
  local _var=$1
  local _fallback="${2:-false}"
  local _current
  _current=$(eval "echo \"\${${_var}-UNSET}\"")
  if [ "${_current}" = "UNSET" ]; then
    local _yaml_default
    _yaml_default=$(yq_read ".defaults.${_var} // \"${_fallback}\"")
    eval "${_var}=\"\${_yaml_default}\""
    export "${_var}"
  fi
  eval "echo_debug \"${_var}=\${${_var}}\""
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_FEATURES_LOADED=true
echo_debug "_functions_features.sh Loaded"
