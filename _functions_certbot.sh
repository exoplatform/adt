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

do_generate_certbot_certificate() {
  local certbotAction="certonly"
  local certbot_domain=$(getdomainfromUrl ${DEPLOYMENT_URL})
  local certbot_certs_folder="${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}/live"
  local certFile="${certbot_certs_folder}/${certbot_domain}/cert.pem"
  if [ "${DEPLOYMENT_CERTBOT_FORCE_RENEWAL:-false}" == "false" ] && sudo test -f "${certFile}"; then
    if ! do_check_certificate_expiration ${certFile}; then 
      echo_warn "Certificate ${certFile} will expire soon. Ask ITOP for checking certbot's cron job issues"
      certbotAction="renew"
    else 
      env_var "INSTANCE_SSL_CERTIFICATE_FILE" "${certbot_certs_folder}/${certbot_domain}/cert.pem"
      env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${certbot_certs_folder}/${certbot_domain}/privkey.pem"
      env_var "INSTANCE_SSL_CERTIFICATE_CHAIN_FILE" "${certbot_certs_folder}/${certbot_domain}/chain.pem"
      return 0
    fi
  fi

  local certbotMethodArgs="webroot --webroot-path ${DEPLOYMENT_CERTBOT_WEBROOT_PATH}"

  local eabOptions=""
  if [[ -n "${DEPLOYMENT_CERTBOT_EAB_KID:-}" && -n "${DEPLOYMENT_CERTBOT_EAB_HMAC_KEY:-}" ]]; then
    eabOptions="--eab-kid ${DEPLOYMENT_CERTBOT_EAB_KID} --eab-hmac-key ${DEPLOYMENT_CERTBOT_EAB_HMAC_KEY}"
  fi

  local domainOptions=""
  local renewalOptions=""
  if [[ "${certbotAction}" == "renew" ]] && [[ "${DEPLOYMENT_CERTBOT_FORCE_RENEWAL:-false}" == "true" ]]; then
    echo_info "Forcing Certificate renewal..."
    renewalOptions="--force-renewal"
  fi

  if [[ "${certbotAction}" == "certonly" ]]; then
    domainOptions="-d ${certbot_domain}"
  fi

  echo_info "Deploying Basic Apache instance configuration for generating/renewing certificate..."
  evaluate_file_content ${ETC_DIR}/apache2/sites-available/instance-certbot.template ${APACHE_CONF_DIR}/sites-available/${DEPLOYMENT_EXT_HOST}
  do_reload_apache ${ADT_DEV_MODE}

  sudo certbot --config-dir "${DEPLOYMENT_CERTBOT_CONFIG_FOLDER}" --text --agree-tos --non-interactive ${certbotAction} \
    --rsa-key-size 4096 -a ${certbotMethodArgs} \
    --cert-name "${certbot_domain}" ${domainOptions} \
    --server "${DEPLOYMENT_CERTBOT_ACME_SERVER}" --email "certificates@exoplatform.com" ${eabOptions} ${renewalOptions}

  echo_info "Certificate has been generated/renewed successfully"

  env_var "INSTANCE_SSL_CERTIFICATE_FILE" "${certbot_certs_folder}/${certbot_domain}/cert.pem"
  env_var "INSTANCE_SSL_CERTIFICATE_KEY_FILE"  "${certbot_certs_folder}/${certbot_domain}/privkey.pem"
  env_var "INSTANCE_SSL_CERTIFICATE_CHAIN_FILE" "${certbot_certs_folder}/${certbot_domain}/chain.pem"
}

do_check_certificate_expiration() {
  local certFile=$1
  local expirationDate=$(sudo openssl x509 -enddate -noout -in "${certFile}" | cut -d '=' -f2)
  echo_info "Certbot Certificate Expiration date: ${expirationDate}"
  sudo openssl x509 -checkend ${DEPLOYMENT_CERTBOT_CERT_EXPIRE_PERIOD} -noout -in "${certFile}"
}

do_unregister_certbot_certificate() {
  local certbot_domain=$(getdomainfromUrl ${DEPLOYMENT_URL})

  echo_info "Attempting to unregister certificate: $certbot_domain"

  sudo certbot delete --cert-name "${certbot_domain}" 2>/dev/null || \
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