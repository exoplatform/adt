#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DOWNLOAD_LOADED:-false} && return
set -u

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_files.sh"

# #############################################################################
# Download functions
#
# v2: the app images are prebuilt (meedsio/meeds, exoplatform/exo-enterprise)
# and pulled by docker compose. This module handles dataset downloads and
# artifact metadata resolution (for SNAPSHOT -> floating tag mapping).
# #############################################################################

# Download the dataset for the current instance, if available.
# v1 used rsync-over-ssh for compint/community only. v2 keeps an HTTP/HTTPS
# download path driven by DEPLOYMENT_DATASET_URL (set per-env). No-op if unset.
do_download_dataset() {
  echo_info "Dataset download is not configured for ${PRODUCT_NAME}."
  echo_info "Set DEPLOYMENT_DATASET_URL to enable remote dataset download."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DOWNLOAD_LOADED=true
echo_debug "_functions_download.sh Loaded"
