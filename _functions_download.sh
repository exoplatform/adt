#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_DOWNLOAD_LOADED:-false} && return
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
# Download related functions
# #############################################################################

do_curl() {
  if [ $# -lt 4 ]; then
    echo_error "No enough parameters for function do_curl !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _curlOptions="$1";
  shift;
  local _url="$1";
  shift;
  local _filePath="$1";
  shift;
  local _description="$1";
  shift;

  echo_info "Downloading $_description from $_url ..."
  set +e
  curl ${_curlOptions} "$_url" > ${_filePath}
  if [ "$?" -ne "0" ]; then
    echo_error "Sorry, cannot download $_description"
    rm -f ${_filePath} # Remove potential corrupted file
    exit 1
  fi
  set -e
  echo_info "$_description downloaded"
  echo_info "Local path : $_filePath"
}

#
# Function that downloads an artifact from a repository
# It will be updated if a SNAPSHOT is asked and a more recent version exists
# Because Nexus REST APIs don't use Maven 3 metadata to download the latest SNAPSHOT
# of a given GAVCE we need to manually get the timestamp using xpath
# see https://issues.sonatype.org/browse/NEXUS-4423
#
do_download_maven_artifact() {
  if [ $# -lt 10 ]; then
    echo_error "No enough parameters for function do_download_maven_artifact !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _repositoryURL="$1";
  shift;
  local _repositoryUsername="$1";
  shift;
  local _repositoryPassword="$1";
  shift;
  local _artifactGroupId="$1";
  shift;
  local _artifactArtifactId="$1";
  shift;
  local _artifactVersion="$1";
  shift;
  local _artifactPackaging="$1";
  shift;
  local _artifactClassifier="$1";
  shift;
  local _downloadDirectory="$1";
  shift;
  local _fileBaseName="$1";
  shift;
  local _prefix="$1";
  shift; # Used to _prefix variables that store artifact details

  #
  # Local variables
  #
  local _artifactDate="" # We can compute the artifact date only for SNAPSHOTs
  local _artifactTimestamp="$_artifactVersion" # By default we set the timestamp to the given version (for a release)
  local _baseUrl="${_repositoryURL}/${_artifactGroupId//.//}/$_artifactArtifactId/$_artifactVersion" # base url where to download from
  local _curlOptions="";

  # Credentials and options
  if [ -n "$_repositoryUsername" ]; then
    _curlOptions="--fail --show-error --location-trusted -u $_repositoryUsername:$_repositoryPassword" # Repository credentials and options
  else
    _curlOptions="--fail --show-error --location-trusted"
  fi

  # Create the directory where we will download it
  mkdir -p ${_downloadDirectory}

  #
  # For a SNAPSHOT we will need to manually compute its TIMESTAMP from maven metadata
  #
  if [[ "$_artifactVersion" =~ .*-SNAPSHOT ]]; then
    local _metadataFile="$_downloadDirectory/$_fileBaseName-$_artifactVersion-maven-metadata.xml"
    local _metadataUrl="$_baseUrl/maven-metadata.xml"
    # Backup lastest metadata to be able to use them if newest are wrong
    # (were removed from nexus for example thus we can use what we have in our local cache)
    if [ -e "$_metadataFile" ]; then
      mv ${_metadataFile} ${_metadataFile}.bck
    fi
    do_curl "$_curlOptions" "$_metadataUrl" "$_metadataFile" "Artifact Metadata"
    local _xpathQuery="";
    if [ -z "$_artifactClassifier" ]; then
      _xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(not(classifier))and(extension=\"$_artifactPackaging\")]/value/text()"
    else
      _xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$_artifactClassifier\")and(extension=\"$_artifactPackaging\")]/value/text()"
    fi
    set +e
    if ${DARWIN}; then
      _artifactTimestamp=`xpath ${_metadataFile} ${_xpathQuery}`
    fi
    if ${LINUX}; then
      _artifactTimestamp=`xpath -q -e ${_xpathQuery} ${_metadataFile}`
    fi
    set -e
    if [ -z "$_artifactTimestamp" ] && [ -e "$_metadataFile.bck" ]; then
      # We will restore the previous one to get its timestamp and redeploy it
      echo_warn "Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv ${_metadataFile}.bck ${_metadataFile}
      if ${DARWIN}; then
        _artifactTimestamp=`xpath ${_metadataFile} ${_xpathQuery}`
      fi
      if ${LINUX}; then
        _artifactTimestamp=`xpath -q -e ${_xpathQuery} ${_metadataFile}`
      fi
    fi
    if [ -z "$_artifactTimestamp" ]; then
      echo_error "No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f ${_metadataFile}.bck
    echo_info "Latest timestamp : $_artifactTimestamp"
    _artifactDate=`expr "$_artifactTimestamp" : '.*-\(.*\)-.*'`
  fi
  
  #
  # For the latest milestone (LT) or before the latest one (BL), we will need to manually compute its TIMESTAMP from maven metadata
  #
  if [[ "$_artifactVersion" =~ .*-M(BL|LT)$ ]]; then
    local _metadataFile="$_downloadDirectory/$_fileBaseName-$_artifactVersion-maven-metadata.xml"
    local _metadataUrl="$(dirname $_baseUrl)/maven-metadata.xml"
    if [ -e "$_metadataFile" ]; then
      mv ${_metadataFile} ${_metadataFile}.bck
    fi
    do_curl "$_curlOptions" "$_metadataUrl" "$_metadataFile" "Artifact Metadata"
    local _xpathQuery="";
    _xpathQuery="/metadata/versioning/versions"
    local plfversionprefix=$(echo $_artifactVersion | grep -oP ^[0-9]+\.[0-9]+\.[0-9]+)   
    set +e
    if ${DARWIN}; then
      if ${DEPLOYMENT_CONTINUOUS_ENABLED:-false}; then
        _artifactTimestampArray=($(xpath ${_metadataFile} ${_xpathQuery} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -P .*-[0-9]{8}$ | sort -r | xargs))
      else 
        _artifactTimestampArray=($(xpath ${_metadataFile} ${_xpathQuery} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -Pv .*-[0-9]{8}$ | xargs))
      fi
    fi
    if ${LINUX}; then
      if ${DEPLOYMENT_CONTINUOUS_ENABLED:-false}; then
        _artifactTimestampArray=($(xpath -q -e ${_xpathQuery} ${_metadataFile} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -P .*-[0-9]{8}$ | sort -r | xargs))
      else 
        _artifactTimestampArray=($(xpath -q -e ${_xpathQuery} ${_metadataFile} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -Pv .*-[0-9]{8}$ | xargs))
      fi
    fi
    set -e
    if [ -z "${_artifactTimestampArray}" ] && [ -e "$_metadataFile.bck" ]; then
      echo_warn "Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv ${_metadataFile}.bck ${_metadataFile}
      if ${DARWIN}; then
        if ${DEPLOYMENT_CONTINUOUS_ENABLED:-false}; then
          _artifactTimestampArray=($(xpath ${_metadataFile} ${_xpathQuery} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -P .*-[0-9]{8}$ | sort -r | xargs))
        else 
          _artifactTimestampArray=($(xpath ${_metadataFile} ${_xpathQuery} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -Pv .*-[0-9]{8}$ | xargs))
        fi
      fi
      if ${LINUX}; then
        if ${DEPLOYMENT_CONTINUOUS_ENABLED:-false}; then
          _artifactTimestampArray=($(xpath -q -e ${_xpathQuery} ${_metadataFile} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -P .*-[0-9]{8}$ | sort -r | xargs))
        else
          _artifactTimestampArray=($(xpath -q -e ${_xpathQuery} ${_metadataFile} | grep ${plfversionprefix} |  sed -e 's/<[^>]*>//g' | grep -Pv .*-[0-9]{8}$ | xargs))
        fi
      fi
    fi
    if [ -z "${_artifactTimestampArray}" ]; then
      echo_error "No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f ${_metadataFile}.bck
    _artifactTimestamp="${_artifactTimestampArray[-1]}"
    if [[ "$_artifactVersion" =~ .*-MBL$ ]] && [ ${#_artifactTimestampArray[@]} -gt 1 ]; then
        _artifactTimestamp="${_artifactTimestampArray[-2]}" 
    fi
    
    local latestmilestonesuffix=$(echo $_artifactTimestamp | grep -oP "[0-9]+$")
    local latestmilestoneprefix=$(echo $_artifactTimestamp | grep -oP "([0-9]+\.)+[0-9]+(\-(M|RC|CP|[0-9]+))?")
    
    # Stable version detected
    if [[ ! "$latestmilestoneprefix" =~ .*-(M|RC|CP|[0-9]+)$ ]]; then
      _artifactTimestamp="$latestmilestoneprefix"
      env_var MILESTONE_PREFIX ""
    else 
      env_var MILESTONE_SUFFIX "$latestmilestonesuffix"
      env_var MILESTONE_PREFIX "$(echo $latestmilestoneprefix | grep -oP '\-(M|RC|CP|[0-9]{8})')"
    fi    

    echo_info "Latest timestamp : $_artifactTimestamp"
    _artifactDate=""
    _baseUrl=$(echo $_baseUrl | sed "s/$_artifactVersion/$_artifactTimestamp/g" )
  fi

  if ${DEPLOYMENT_CONTINUOUS_ENABLED:-false}; then 
    if [ -z "${DEPLOYMENT_ADDONS_CATALOG:-}" ]; then 
      env_var "DEPLOYMENT_ADDONS_CATALOG" "${ACCEPTANCE_SERVERS}/rest/local-catalog-php?plfversion=$_artifactTimestamp"
    else 
      env_var "DEPLOYMENT_ADDONS_CATALOG" "${ACCEPTANCE_SERVERS}/rest/local-catalog-php?plfversion=$_artifactTimestamp&remote=${DEPLOYMENT_ADDONS_CATALOG}"
    fi
  fi

  #
  # Compute the Download URL for the artifact
  #

  local _filename=${_artifactArtifactId}-${_artifactTimestamp}
  local _name=${_artifactGroupId}:${_artifactArtifactId}:${_artifactVersion}
  if [ -n "$_artifactClassifier" ]; then
    _filename="$_filename-$_artifactClassifier"
    _name="$_name:$_artifactClassifier"
  fi
  _filename="$_filename.$_artifactPackaging"
  _name="$_name:$_artifactPackaging"
  local _artifactUrl="$_baseUrl/$_filename"
  local _artifactFile="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.$_artifactPackaging"

  #
  # Download the artifact SHA1
  #
  local _sha1Url="${_artifactUrl}.sha1"
  local _sha1File="${_artifactFile}.sha1"
  if [[ ! -e "$_artifactFile" ]] || [[ ! -e "$_sha1File" ]]; then
    do_curl "$_curlOptions" "$_sha1Url" "$_sha1File" "Artifact SHA1"
  fi

  #
  # Download the artifact
  #
  if [ -e "$_artifactFile" ]; then
    echo_info "$_name was already downloaded. Skip artifact download !"
  else
    do_curl "$_curlOptions" "$_artifactUrl" "$_artifactFile" "Artifact $_name"
  fi

  #
  # Validate download integrity
  #
  echo_info "Validating download integrity ..."
  # Read the SHA1 from Maven
  read -r mavenSha1 < ${_sha1File} || true
  echo "$mavenSha1  $_artifactFile" > ${_sha1File}.tmp
  set +e
  shasum -c ${_sha1File}.tmp
  if [ "$?" -ne "0" ]; then
    echo_error "Sorry, $_name download integrity failed"
    rm -f ${_artifactFile}
    rm -f ${_sha1File}
    rm -f ${_sha1File}.tmp
    exit 1
  fi
  set -e
  rm -f ${_sha1File}.tmp
  echo_info "Download integrity validated."

  #
  # Validate archive integrity
  #
  echo_info "Validating archive integrity ..."
  set +e
  case "$_artifactPackaging" in
    zip)
      zip -T ${_artifactFile}
    ;;
    jar | war | ear)
      jar -tf ${_artifactFile} > /dev/null
    ;;
    tar.gz | tgz)
      gzip -t ${_artifactFile}
    ;;
    *)
      echo_warn "No method to validate \"$_artifactPackaging\" file type."
    ;;
  esac
  if [ "$?" -ne "0" ]; then
    echo_error "Sorry, $_name archive integrity failed. Local copy is deleted."
    rm -f ${_artifactFile}
    rm -f ${mavenSha1}
    exit 1
  fi
  set -e
  echo_info "Archive integrity validated."

  #
  # Create an info file with all details about the artifact
  #
  local _artifactInfo="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.info"
  echo_info "Creating archive descriptor ..."
  cat << EOF > ${_artifactInfo}
${_prefix}_VERSION="${_artifactVersion}"
${_prefix}_ARTIFACT_GROUPID="${_artifactGroupId}"
${_prefix}_ARTIFACT_ARTIFACTID="${_artifactArtifactId}"
${_prefix}_ARTIFACT_TIMESTAMP="${_artifactTimestamp}"
${_prefix}_ARTIFACT_DATE="${_artifactDate}"
${_prefix}_ARTIFACT_CLASSIFIER="${_artifactClassifier}"
${_prefix}_ARTIFACT_PACKAGING="${_artifactPackaging}"
${_prefix}_ARTIFACT_URL="${_artifactUrl}"
${_prefix}_ARTIFACT_LOCAL_PATH="${_artifactFile}"
EOF

  echo_info "Done."
  #Display the deployment descriptor
  echo_info "========================== Archive Descriptor ==========================="
  cat ${_artifactInfo}
  echo_info "========================================================================="

  #
  # Create a symlink if it is a SNAPSHOT to the TIMESTAMPED version
  #
  if [[ "$_artifactVersion" =~ .*-(SNAPSHOT|MBL|MLT) ]]; then
    ln -fs "$_fileBaseName-$_artifactTimestamp.$_artifactPackaging" "$_downloadDirectory/$_fileBaseName-$_artifactVersion.$_artifactPackaging"
    ln -fs "$_fileBaseName-$_artifactTimestamp.info" "$_downloadDirectory/$_fileBaseName-$_artifactVersion.info"
  fi
}

do_load_artifact_descriptor() {
  if [ $# -lt 3 ]; then
    echo_error "No enough parameters for function do_load_artifact_descriptor !"
    exit 1;
  fi
  local _downloadDirectory="$1";
  shift;
  local _fileBaseName="$1";
  shift;
  local _artifactVersion="$1";
  shift;
  source "$_downloadDirectory/$_fileBaseName-$_artifactVersion.info"
}

#
# Function that downloads a file from a web server
#
do_http_download_with_sha1() {
  if [ $# -lt 5 ]; then
    echo_error "No enough parameters for function do_http_download_with_sha1 !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _fileURL="$1";
  shift;
  local _httpUsername="$1";
  shift;
  local _httpPassword="$1";
  shift;
  local _localPath="$1";
  shift;
  local _description="$1";
  shift;

  local _curlOptions="";
  # Credentials and options
  if [ -n "$_httpUsername" ]; then
    _curlOptions="--fail --show-error --location-trusted -u $_httpUsername:$_httpPassword" # Repository credentials and options
  else
    _curlOptions="--fail --show-error --location-trusted"
  fi

  # Create the directory where we will download it
  local _downloadDirectory=`dirname "$_localPath"`
  mkdir -p ${_downloadDirectory}

  #
  # Download the SHA1
  #
  local _sha1Url="${_fileURL}.sha1"
  local _sha1File="${_localPath}.sha1"
  if [[ ! -e "$_localPath" ]] || [[ ! -e "$_sha1File" ]]; then
    do_curl "$_curlOptions" "$_sha1Url" "$_sha1File" "File SHA1"
  fi

  #
  # Download the file
  #
  if [ -e "$_localPath" ]; then
    echo_info "$_description was already downloaded. Skip file download !"
  else
    do_curl "$_curlOptions" "$_fileURL" "$_localPath" "$_description"
  fi

  #
  # Validate download integrity
  #
  echo_info "Validating download integrity ..."
  set +e
  cd `dirname ${_localPath}`
  shasum -c ${_sha1File}
  if [ "$?" -ne "0" ]; then
    echo_error "Sorry, $_description download integrity failed"
    rm -f ${_localPath}
    rm -f ${_sha1File}
    exit 1
  fi
  cd -
  set -e
  echo_info "Download integrity validated."

  #
  # Validate archive integrity
  #
  echo_info "Validating archive integrity ..."
  set +e
  zip -T ${_localPath}
  if [ "$?" -ne "0" ]; then
    echo_error "Sorry, $_description archive integrity failed"
    rm -f ${_localPath}
    exit 1
  fi
  set -e
  echo_info "Archive integrity validated."
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DOWNLOAD_LOADED=true
echo_debug "_functions_download.sh Loaded"