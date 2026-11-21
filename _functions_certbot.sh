#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CERTBOT_LOADED:-false} && return
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

do_get_certbot_settings() {
  if [ "${DEPLOYMENT_CERTBOT_ENABLED:-false}" == "false" ]; then 
    return 0
  fi 
  local certbot_bin="$(command -v certbot)"
  if [[ -z "$certbot_bin" ]]; then
    echo_error "Certbot is not installed or not in PATH."
    exit 1
  fi
  if [ ! -d "${DEPLOYMENT_CERTBOT_WEBROOT_PATH}" ]; then 
    echo_error "Certbot webroot folder must be created to continue."
    exit 1
  fi
}

# The domain names a folder of the certificates of Let's Encrypt (removed with sudo rm -rf when an instance is undeployed) and is an
# argument of sudo certbot: a host name, nothing else (not '..', not an option, not two words).
certbot_domain_is_valid() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$ ]] && [[ "$1" != *..* ]]
}

# Issuing a certificate for something else is refused.
certbot_check_domain() {
  if ! certbot_domain_is_valid "$1"; then
    echo_error "'$1' is not a valid domain name for a certificate"
    exit 1
  fi
}

do_generate_certbot_certificate() {
  local certbotAction="certonly"
  local certbot_domain=$(getdomainfromUrl "${DEPLOYMENT_URL}")
  certbot_check_domain "${certbot_domain}"
  local certbot_certs_folder="${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}/live"
  local certFile="${certbot_certs_folder}/${certbot_domain}/cert.pem"
  if [ "${DEPLOYMENT_CERTBOT_FORCE_RENEWAL:-false}" == "false" ] && sudo test -f "${certFile}"; then
    if ! do_check_certificate_expiration ${certFile}; then 
      echo_warn "Certificate ${certFile} will expire soon. Ask ITOP for checking certbot's cron job issues"
      certbotAction="renew"
    else 
      env_var "INSTANCE_SSL_CERTIFICATE_FILE" "${certbot_certs_folder}/${certbot_domain}/fullchain.pem"
      env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${certbot_certs_folder}/${certbot_domain}/privkey.pem"
      return 0
    fi
  fi

  # The arguments of sudo certbot are an array, each value one argument, and every option that takes a value is written
  # --option=value: the values of the EAB account come from CI parameters, they were word-split ('x --deploy-hook cmd' ran cmd as
  # root after the issuance), and with the = form a value that starts with '-' can never be taken for an option of its own
  local -a certbotArgs=(--config-dir="${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}" --text --agree-tos --non-interactive "${certbotAction}"
    --rsa-key-size=4096 --authenticator=webroot --webroot-path="${DEPLOYMENT_CERTBOT_WEBROOT_PATH}" --cert-name="${certbot_domain}")

  if [[ "${certbotAction}" == "certonly" ]]; then
    certbotArgs+=(--domains="${certbot_domain}")
  fi
  certbotArgs+=(--server="${DEPLOYMENT_CERTBOT_ACME_SERVER}" --email="certificates@exoplatform.com")

  if [[ -n "${DEPLOYMENT_CERTBOT_EAB_KID:-}" && -n "${DEPLOYMENT_CERTBOT_EAB_HMAC_KEY:-}" ]]; then
    validate_value DEPLOYMENT_CERTBOT_EAB_KID      '^[A-Za-z0-9_-]{1,512}$' "letters, digits, '-' and '_' only (the key id of the ACME account)"
    validate_value DEPLOYMENT_CERTBOT_EAB_HMAC_KEY '^[A-Za-z0-9_=+/-]{1,1024}$' "base64 characters only (the HMAC key of the ACME account)"
    certbotArgs+=(--eab-kid="${DEPLOYMENT_CERTBOT_EAB_KID}" --eab-hmac-key="${DEPLOYMENT_CERTBOT_EAB_HMAC_KEY}")
  fi

  if [[ "${certbotAction}" == "renew" ]] && [[ "${DEPLOYMENT_CERTBOT_FORCE_RENEWAL:-false}" == "true" ]]; then
    echo_info "Forcing Certificate renewal..."
    certbotArgs+=(--force-renewal)
  fi

  echo_info "Deploying Basic Apache instance configuration for generating/renewing certificate..."
  evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-certbot.j2 ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
  do_reload_apache ${ADT_DEV_MODE}

  sudo certbot "${certbotArgs[@]}"

  echo_info "Certificate has been generated/renewed successfully"

  env_var "INSTANCE_SSL_CERTIFICATE_FILE" "${certbot_certs_folder}/${certbot_domain}/fullchain.pem"
  env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${certbot_certs_folder}/${certbot_domain}/privkey.pem"
}

do_check_certificate_expiration() {
  local certFile=$1
  local expirationDate=$(sudo openssl x509 -enddate -noout -in "${certFile}" | cut -d '=' -f2)
  echo_info "Certbot Certificate Expiration date: ${expirationDate}"
  sudo openssl x509 -checkend ${DEPLOYMENT_CERTBOT_CERT_EXPIRE_PERIOD} -noout -in "${certFile}"
}

do_unregister_certbot_certificate() {
  local certbot_domain=$(getdomainfromUrl "${DEPLOYMENT_URL}")
  # Undeploying must not stop for a name no certificate can have been issued for: nothing is removed, the rest goes on
  if ! certbot_domain_is_valid "${certbot_domain}"; then
    echo_warn "'${certbot_domain}' is not a valid domain name for a certificate: no certificate removed"
    return 0
  fi

  echo_info "Attempting to unregister certificate: $certbot_domain"

  sudo certbot delete --cert-name="${certbot_domain}" 2>/dev/null || \
  echo_warn "certbot delete failed or cert already removed"

  local paths=(
    "${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}/live/${certbot_domain}"
    "${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}/archive/${certbot_domain}"
    "${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}/renewal/${certbot_domain}.conf"
  )

  for path in "${paths[@]}"; do
    if sudo test -e "${path}"; then
      sudo rm -rf "${path}"
    fi
  done

  echo_info "Certbot Unregister complete for: $certbot_domain"
}



# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CERTBOT_LOADED=true
echo_debug "_function_certbot.sh Loaded"