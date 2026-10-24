#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_REGISTRY_LOADED:-false} && return
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

# #############################################################################
# Resolution of the docker image tag of a product version.
#
#  - a literal version (7.2.2, 7.3.0-M16) or a snapshot (7.3.x-SNAPSHOT) is a tag
#    of the image: the newest rebuild (<version>_N) is used when the registry has some
#  - <X.Y.Z|X.Y.Z>-MLT : latest build of the line
#    -MBL               : the build before the latest one
#    -GA                : latest stable release (no milestone/RC/CP/date suffix)
#    X.Y.Z can be X.Y.Z (that exact release line) or X.Y.Z (wildcard: any X.Y.*)
#    With DEPLOYMENT_CONTINUOUS_ENABLED the dated continuous builds (X.Y.Z-YYYYMMDD_N)
#    are the candidates of MLT/MBL, otherwise the milestones, RC, CP and releases.
# #############################################################################

# Docker registry API (v2), with the anonymous pull token.
# $1 registry (docker.io | ghcr.io) $2 repository (exoplatform/exo-community)
registry_list_tags() {
  local _registry=$1 _repo=$2 _token_url _api _token _last="" _page _count
  case "${_registry}" in
    docker.io)
      _token_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${_repo}:pull"
      _api="https://registry-1.docker.io/v2/${_repo}/tags/list"
    ;;
    ghcr.io)
      _token_url="https://ghcr.io/token?scope=repository:${_repo}:pull"
      _api="https://ghcr.io/v2/${_repo}/tags/list"
    ;;
    *)
      echo_error "Registry ${_registry} not supported"
      return 1
    ;;
  esac
  _token=$(curl --silent --fail --max-time 30 "${_token_url}" | jq -r '.token // empty') || return 1
  [ -n "${_token}" ] || return 1
  while true; do
    _page=$(curl --silent --fail --max-time 60 -H "Authorization: Bearer ${_token}" \
      "${_api}?n=1000${_last:+&last=${_last}}") || return 1
    _count=$(jq -r '.tags // [] | length' <<< "${_page}")
    [ "${_count}" -gt 0 ] || break
    jq -r '.tags[]' <<< "${_page}"
    # the API has no cursor on the last page: stop on a short one
    [ "${_count}" -ge 1000 ] || break
    _last=$(jq -r '.tags[-1]' <<< "${_page}")
  done
}

# Tags of the images that are already pulled (offline mode).
# $1 repository
registry_list_local_tags() {
  ${DOCKER_CMD} images --format '{{.Tag}}' "$1" 2>/dev/null || true
}

# The sortable key of a build tag, so that "sort" orders them by version, then by kind
# (milestone < RC < release < CP < continuous build), number, date and rebuild.
# Reads the tags on stdin, writes "<key> <tag>"; the tags that are not builds are dropped.
# Dated continuous builds keep their own ranking (they only compete with each other).
image_tag_keys() {
  awk '
    function key(maj, min, pat, kind, num, date, rb) {
      return sprintf("%05d.%05d.%05d.%d.%05d.%08d.%05d", maj, min, pat, kind, num, date, rb)
    }
    {
      tag = $0; rb = 0; base = tag
      if (match(base, /_[0-9]+$/)) { rb = substr(base, RSTART + 1) + 0; base = substr(base, 1, RSTART - 1) }
      if (!match(base, /^[0-9]+\.[0-9]+\.[0-9]+/)) next
      split(substr(base, 1, RLENGTH), v, ".")
      rest = substr(base, RLENGTH + 1)
      kind = -1; num = 0; date = 0
      if (rest == "") { kind = 2 }
      else if (rest ~ /^-M[0-9]+$/)  { kind = 0; num = substr(rest, 3) + 0 }
      else if (rest ~ /^-RC[0-9]+$/) { kind = 1; num = substr(rest, 4) + 0 }
      else if (rest ~ /^-CP[0-9]+$/) { kind = 3; num = substr(rest, 4) + 0 }
      else if (rest ~ /^-[0-9]{8}$/) { kind = 4; date = substr(rest, 2) + 0 }
      if (kind < 0) next
      print key(v[1], v[2], v[3], kind, num, date, rb), tag
    }'
}

# Pick the build of a rolling version among the tags on stdin.
# $1 version (7.3.0-MLT, 7.2.Z-GA ...) $2 continuous (true|false)
image_tag_pick() {
  local _version=$1 _continuous=${2:-false}
  local _mode="${_version##*-}"
  local _line="${_version%-*}"
  # 7.2.Z-meed-MLT : the optional middle token was only meaningful for the maven artifacts
  _line="${_line%%-*}"
  local _prefix
  if [[ "${_line}" == *.Z ]]; then
    _prefix="${_line%Z}"
  else
    _prefix="${_line}"
  fi
  if [ "${_mode}" = "GA" ]; then
    _continuous=false
  fi
  local _kinds
  case "${_mode}:${_continuous}" in
    GA:*)     _kinds="2" ;;
    *:true)   _kinds="4" ;;
    *)        _kinds="0 1 2 3" ;;
  esac
  local _candidates
  # the version keys start with the zero-padded numbers: filter on the unpadded tag
  _candidates=$(image_tag_keys | while read -r _key _tag; do
    [[ "${_tag}" == "${_prefix}"* ]] || continue
    # "7.3.0" must not match "7.3.01"
    [[ "${_line}" == *.Z || "${_tag}" == "${_prefix}" || "${_tag:${#_prefix}:1}" =~ [-_] ]] || continue
    _kind=$(cut -d. -f4 <<< "${_key}")
    [[ " ${_kinds} " == *" ${_kind} "* ]] || continue
    echo "${_key} ${_tag}"
  done | sort)
  [ -n "${_candidates}" ] || return 1
  if [ "${_mode}" = "MBL" ] && [ "$(wc -l <<< "${_candidates}")" -gt 1 ]; then
    tail -n 2 <<< "${_candidates}" | head -n 1 | cut -d' ' -f2
  else
    tail -n 1 <<< "${_candidates}" | cut -d' ' -f2
  fi
}

# The newest rebuild of a literal release: 7.3.0-M16 -> 7.3.0-M16_2 when it exists.
# $1 version, tags on stdin. Writes the tag (the version itself when there is no rebuild).
image_tag_rebuild() {
  local _version=$1 _best="" _n _bestn=-1 _tag
  while read -r _tag; do
    if [ "${_tag}" = "${_version}" ] && [ "${_bestn}" -lt 0 ]; then
      _best="${_tag}"
    elif [[ "${_tag}" =~ ^${_version//./\\.}_([0-9]+)$ ]]; then
      _n=${BASH_REMATCH[1]}
      if [ "${_n}" -gt "${_bestn}" ]; then
        _bestn=${_n}
        _best="${_tag}"
      fi
    fi
  done
  echo "${_best:-${_version}}"
}

# The docker repository of a product (DEPLOYMENT_IMAGE_REPO overrides it)
# $1 product
image_repo_of_product() {
  case "$1" in
    meeds)  echo "meedsio/meeds" ;;
    plfcom) echo "exoplatform/exo-community" ;;
    plfent) echo "exoplatform/exo-enterprise" ;;
    *)
      echo_error "No docker image for the product \"$1\""
      return 1
    ;;
  esac
}

# Resolve the tag to deploy. Writes it on stdout.
# $1 repository (docker.io namespace/name) $2 product version
resolve_image_tag() {
  local _repo=$1 _version=$2 _tags _tag
  if [[ "${_version}" == *-SNAPSHOT ]] && ${ADT_OFFLINE:-false}; then
    echo "${_version}"
    return 0
  fi
  if ${ADT_OFFLINE:-false}; then
    _tags=$(registry_list_local_tags "${_repo}")
  else
    _tags=$(registry_list_tags docker.io "${_repo}" 2>/dev/null) \
      || _tags=$(registry_list_tags ghcr.io "${_repo}" 2>/dev/null) \
      || _tags=""
    if [ -z "${_tags}" ]; then
      echo_warn "The tags of ${_repo} cannot be listed, falling back on the local images"
      _tags=$(registry_list_local_tags "${_repo}")
    fi
  fi
  if [[ "${_version}" == *-SNAPSHOT ]]; then
    # snapshots are moving tags of the image itself (7.3.x-SNAPSHOT, or one per feature branch: 7.3.x-<branch>-SNAPSHOT):
    # tell now when this repository does not publish the one asked, with the ones it has for that minor version
    if [ -n "${_tags}" ] && ! grep -qxF -- "${_version}" <<< "${_tags}"; then
      echo_error "The repository ${_repo} has no ${_version} tag. Snapshots of ${_version%%.x-*}.x it publishes:"
      grep -E -- "^${_version%%.x-*}\.x-.*SNAPSHOT$|^${_version%%.x-*}\.x-SNAPSHOT$" <<< "${_tags}" | sort | sed 's/^/  /' >&2 || true
      return 1
    fi
    echo "${_version}"
  elif [[ "${_version}" =~ -(MLT|MBL|GA)$ ]]; then
    if ! _tag=$(image_tag_pick "${_version}" "${DEPLOYMENT_CONTINUOUS_ENABLED:-false}" <<< "${_tags}"); then
      echo_error "No image of ${_repo} matches ${_version}"
      return 1
    fi
    echo "${_tag}"
  else
    image_tag_rebuild "${_version}" <<< "${_tags}"
  fi
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_REGISTRY_LOADED=true
echo_debug "_functions_registry.sh Loaded"
