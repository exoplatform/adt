#!/bin/bash -eu                                                                                                                                                                                                             

# ####################################
# Generic bash functions library
# ####################################

# OS specific support. $var _must_ be set to either true or false.
CYGWIN=false
LINUX=false;
OS400=false
DARWIN=false
case "`uname`" in
  CYGWIN*) CYGWIN=true;;
  Linux*) LINUX=true;;
  OS400*) OS400=true;;
  Darwin*) DARWIN=true;;
esac

# Checks that the env var with the name provided in param is defined
validate_env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$(eval echo \${$1-UNSET})
  if [ "${PARAM_VALUE}" = "UNSET" ]; then 
	echo "[ERROR] Environment variable $PARAM_NAME is not set"; 
	echo "Please set it either : "
	echo "* in your shell environment (export $PARAM_NAME=xxx)"
	echo "* in the system file /etc/default/adt"
	echo "* in the user file \$HOME/.adtrc"
	exit 1; 
  fi	
  set -u
}

# Setup an env var
# The user can override the value in its environment. 
# In that case the default value won't be used.
configurable_env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$(eval echo \${$1-UNSET})
  if [ "${PARAM_VALUE}" = "UNSET" ]; then 
    PARAM_VALUE=$2
    eval ${PARAM_NAME}=\"${PARAM_VALUE}\"
    export eval ${PARAM_NAME}
  fi	
  if ( ${ADT_DEBUG} ); then
    echo "[DEBUG] $PARAM_NAME=$PARAM_VALUE"
  fi
  set -u
}

# Setup an env var
# The user cannot override the value
env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$2
  eval ${PARAM_NAME}=\"${PARAM_VALUE}\"
  export eval ${PARAM_NAME}
  if ( ${ADT_DEBUG} ); then
    echo "[DEBUG] $PARAM_NAME=$PARAM_VALUE"
  fi
  set -u
}

#
# Replace in file $1 the value $2 by $3
#
replace_in_file()
{
  mv $1 $1.orig
  sed "s|$2|$3|g" $1.orig > $1
  rm $1.orig
}

#
# find_file <VAR> <PATH1> ..  <PATHx>
# test all paths and the path of the latest one existing in parameters is set as VAR
#
find_file()
{
  set +u
  local _varName=$1
  shift;
  # default value set to UNSET
  env_var $_varName "UNSET"
  for i in $*
  do 
    [ -e "$i" ] && env_var $_varName "$i"
  done
  set -u
}

do_curl() {
  if [ $# -lt 4 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_curl !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local curlOptions="$1"; shift;
  local url="$1"; shift;
  local filePath="$1"; shift;
  local description="$1"; shift;
  
  echo "[INFO] Downloading $description from $url ..."
  set +e
  curl $curlOptions "$url" > $filePath
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, cannot download $description"
    rm -f $filePath # Remove potential corrupted file
    exit 1
  fi
  set -e
  echo "[INFO] $description downloaded"
  echo "[INFO] Local path : $filePath"
}

#
# Function that downloads an artifact from nexus
# It will be updated if a SNAPSHOT is asked and a more recent version exists
# Because Nexus REST APIs don't use Maven 3 metadata to download the latest SNAPSHOT
# of a given GAVCE we need to manually get the timestamp using xpath
# see https://issues.sonatype.org/browse/NEXUS-4423
#
do_download_from_nexus() {
  if [ $# -lt 10 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_download_from_nexus !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _repositoryURL="$1"; shift;
  local _repositoryUsername="$1"; shift;
  local _repositoryPassword="$1"; shift;
  local _artifactGroupId="$1"; shift;
  local _artifactArtifactId="$1"; shift;
  local _artifactVersion="$1"; shift;
  local _artifactPackaging="$1"; shift;
  local _artifactClassifier="$1"; shift;
  local _downloadDirectory="$1"; shift;
  local _fileBaseName="$1"; shift;
  local _prefix="$1"; shift; # Used to _prefix variables that store artifact details
    
  #
  # Local variables
  #
  local _artifactDate="" # We can compute the artifact date only for SNAPSHOTs
  local _artifactTimestamp="$_artifactVersion" # By default we set the timestamp to the given version (for a release)
  local _baseUrl="${_repositoryURL}/${_artifactGroupId//.//}/$_artifactArtifactId/$_artifactVersion" # base url where to download from

  # Credentials and options
  if [ -n "$_repositoryUsername" ]; then
    local curlOptions="--fail --show-error --location-trusted -u $_repositoryUsername:$_repositoryPassword" # Repository credentials and options  
  else
    local curlOptions="--fail --show-error --location-trusted"
  fi;
  
  # Create the directory where we will download it
  mkdir -p $_downloadDirectory

  #
  # For a SNAPSHOT we will need to manually compute its TIMESTAMP from maven metadata
  #
  if [[ "$_artifactVersion" =~ .*-SNAPSHOT ]]; then
    local metadataFile="$_downloadDirectory/$_fileBaseName-$_artifactVersion-maven-metadata.xml"
    local metadataUrl="$_baseUrl/maven-metadata.xml"
    # Backup lastest metadata to be able to use them if newest are wrong
    # (were removed from nexus for example thus we can use what we have in our local cache)
    if [ -e "$metadataFile" ]; then
      mv $metadataFile $metadataFile.bck
    fi
    do_curl "$curlOptions" "$metadataUrl" "$metadataFile" "Artifact Metadata"
    if [ -z "$_artifactClassifier" ]; then
      local xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(not(classifier))and(extension=\"$_artifactPackaging\")]/value/text()"
    else
      local xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$_artifactClassifier\")and(extension=\"$_artifactPackaging\")]/value/text()"
    fi
    set +e
    if $DARWIN; then
      _artifactTimestamp=`xpath $metadataFile $xpathQuery`
    fi 
    if $LINUX; then
      _artifactTimestamp=`xpath -q -e $xpathQuery $metadataFile`
    fi
    set -e
    if [ -z "$_artifactTimestamp" ] && [ -e "$metadataFile.bck" ]; then
      # We will restore the previous one to get its timestamp and redeploy it
      echo "[WARNING] Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv $metadataFile.bck $metadataFile
      if $DARWIN; then
        _artifactTimestamp=`xpath $METADATA $XPATH_QUERY`
      fi 
      if $LINUX; then
        _artifactTimestamp=`xpath -q -e $XPATH_QUERY $METADATA`
      fi
    fi
    if [ -z "$_artifactTimestamp" ]; then
      echo "[ERROR] No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f $metadataFile.bck
    echo "[INFO] Latest timestamp : $_artifactTimestamp"
    _artifactDate=`expr "$_artifactTimestamp" : '.*-\(.*\)-.*'`
  fi
  
  #
  # Compute the Download URL for the artifact
  #
  local filename=$_artifactArtifactId-$_artifactTimestamp  
  local name=$_artifactGroupId:$_artifactArtifactId:$_artifactVersion
  if [ -n "$_artifactClassifier" ]; then
    filename="$filename-$_artifactClassifier"
    name="$name:$_artifactClassifier"
  fi;
  filename="$filename.$_artifactPackaging"
  name="$name:$_artifactPackaging"  
  local artifactUrl="$_baseUrl/$filename"
  local artifactFile="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.$_artifactPackaging"
  
  #
  # Download the artifact SHA1
  #
  local sha1Url="${artifactUrl}.sha1"
  local sha1File="${artifactFile}.sha1"
  if [ ! -e "$sha1File" ]; then
    do_curl "$curlOptions" "$sha1Url" "$sha1File" "Artifact SHA1"
  fi
  
  #
  # Download the artifact
  #
  if [ -e "$artifactFile" ]; then
    echo "[INFO] $name was already downloaded. Skip artifact download !"
  else
    do_curl "$curlOptions" "$artifactUrl" "$artifactFile" "Artifact $name"
  fi  
  
  #
  # Validate download integrity
  #
  echo "[INFO] Validating download integrity ..."
  # Read the SHA1 from Maven
  read -r mavenSha1 < $sha1File || true
  echo "$mavenSha1  $artifactFile" > ${mavenSha1}.tmp
  set +e
  shasum -c $mavenSha1.tmp
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $name download integrity failed"
    rm -f $artifactFile
    rm -f $mavenSha1
    rm -f $mavenSha1.tmp
    exit 1
  fi
  set -e
  rm -f $mavenSha1.tmp
  echo "[INFO] Download integrity validated."

  #
  # Validate archive integrity
  #
  echo "[INFO] Validating archive integrity ..."
  set +e
  case "$_artifactPackaging" in
    zip)
      zip -T $artifactFile
      ;;
    jar|war|ear)
      jar -tf $artifactFile > /dev/null
      ;;
    tar.gz|tgz)
      gzip -t $artifactFile
      ;;
    *)
      echo "[WARNING] No method to validate \"$_artifactPackaging\" file type." 
      ;;
  esac
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $name archive integrity failed. Local copy is deleted."
    rm -f $artifactFile
    rm -f $mavenSha1
    exit 1
  fi
  set -e  
  echo "[INFO] Archive integrity validated."
  
  #
  # Create an info file with all details about the artifact
  #
  local artifactInfo="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.info"
  echo "[INFO] Creating archive descriptor ..."
  cat << EOF > $artifactInfo
${_prefix}_VERSION="$_artifactVersion"
${_prefix}_ARTIFACT_GROUPID="$_artifactGroupId"
${_prefix}_ARTIFACT_ARTIFACTID="$_artifactArtifactId"
${_prefix}_ARTIFACT_TIMESTAMP="$_artifactTimestamp"
${_prefix}_ARTIFACT_DATE="$_artifactDate"
${_prefix}_ARTIFACT_CLASSIFIER="$_artifactClassifier"
${_prefix}_ARTIFACT_PACKAGING="$_artifactPackaging"
${_prefix}_ARTIFACT_URL="$artifactUrl"
${_prefix}_ARTIFACT_LOCAL_PATH="$artifactFile"
EOF
  echo "[INFO] Done."
  #Display the deployment descriptor
  echo "[INFO] ========================== Archive Descriptor ==========================="
  cat $artifactInfo
  echo "[INFO] ========================================================================="
  
  #
  # Create a symlink if it is a SNAPSHOT to the TIMESTAMPED version
  #
  if [[ "$_artifactVersion" =~ .*-SNAPSHOT ]]; then
    ln -fs "$_fileBaseName-$_artifactTimestamp.$_artifactPackaging" "$_downloadDirectory/$_fileBaseName-$_artifactVersion.$_artifactPackaging"
    ln -fs "$_fileBaseName-$_artifactTimestamp.info" "$_downloadDirectory/$_fileBaseName-$_artifactVersion.info"
  fi 
}

do_load_artifact_descriptor() {
  if [ $# -lt 3 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_load_artifact_descriptor !"
    exit 1;
  fi  
  local _downloadDirectory="$1"; shift;
  local _fileBaseName="$1"; shift;
  local _artifactVersion="$1"; shift;  
  source $_downloadDirectory/$_fileBaseName-$_artifactVersion.info
}

#
# Function that downloads a dataset from a web server
#
do_download() {
  if [ $# -lt 5 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_download !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local fileURL="$1"; shift;
  local httpUsername="$1"; shift;
  local httpPassword="$1"; shift;
  local localPath="$1"; shift;
  local description="$1"; shift;
  
  # Credentials and options
  if [ -n "$httpUsername" ]; then
    local curlOptions="--fail --show-error --location-trusted -u $httpUsername:$httpPassword" # Repository credentials and options  
  else
    local curlOptions="--fail --show-error --location-trusted"
  fi;
  
  # Create the directory where we will download it
  local _downloadDirectory=`dirname "$localPath"`
  mkdir -p $_downloadDirectory

  #
  # Download the SHA1
  #
  local sha1Url="${fileURL}.sha1"
  local sha1File="${localPath}.sha1"
  if [ ! -e "$sha1File" ]; then
    do_curl "$curlOptions" "$sha1Url" "$sha1File" "File SHA1"
  fi
  
  #
  # Download the file
  #
  if [ -e "$localPath" ]; then
    echo "[INFO] $description was already downloaded. Skip file download !"
  else
    do_curl "$curlOptions" "$fileURL" "$localPath" "$description"
  fi

  #
  # Validate download integrity
  #
  echo "[INFO] Validating download integrity ..."
  set +e
  cd `dirname ${localPath}`
  shasum -c $sha1File
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $description download integrity failed"
    rm -f $localPath
    rm -f $sha1File
    exit 1
  fi
  cd -
  set -e
  echo "[INFO] Download integrity validated."
  
  #
  # Validate archive integrity
  #
  echo "[INFO] Validating archive integrity ..."
  set +e
  zip -T $localPath
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $description archive integrity failed"
    rm -f $localPath
    exit 1
  fi
  set -e  
  echo "[INFO] Archive integrity validated."
}