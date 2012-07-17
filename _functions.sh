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

# Initialize the file where we will store environment settings
init_env_file() {
  validate_env_var "ADT_DATA"	
  validate_env_var "PRODUCT_NAME"
  validate_env_var "PRODUCT_VERSION"
  ENV_FILE=${ADT_DATA}/${PRODUCT_NAME}-${PRODUCT_VERSION}.env
  rm -f ${ENV_FILE}
  trap "save_env_file; exit" INT TERM EXIT
}

# Initialize the file where we will store environment settings
save_env_file() {
  validate_env_var "ENV_FILE"
  if [ -f ${ENV_FILE} ]
  then
    echo "[INFO] =========================================================="
    echo "[INFO] Environment details are saved in ${ENV_FILE}"
    echo "[INFO] =========================================================="
    cat ${ENV_FILE}
    echo "[INFO] =========================================================="
  fi
}

# Print in file $1 the content of $2 
print_file() {
  echo "$2" >> $1
}

# Print in file ${ENV_FILE} the content of $1
print_env_file() {
  validate_env_var "ENV_FILE"
  print_file "${ENV_FILE}" "$1"
}

# Checks that the env var with the name provided in param is defined
validate_env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$(eval echo \$$1)
  if [ "${PARAM_VALUE}xxx" = "xxx" ]; then 
	echo "[ERROR] Environment variable $PARAM_NAME is not set"; 
	echo "Please set it either : "
	echo "* in your shell environment (export $PARAM_NAME=xxx)"
	echo "* in the system file /etc/default/adt"
	echo "* in the user file \$HOME/.adtrc"
	exit 1; 
  fi	
  set -u
}

# Setup an env var and record it in the environment file
# The user can override the value in its environment. 
# In that case the default value won't be used.
configurable_env_var() {
  set +u
  PARAM_NAME=$1
  PARAM_VALUE=$(eval echo \$$1)
  if [ "${PARAM_VALUE}xxx" = "xxx" ]; then 
    shift
    PARAM_VALUE="$@"
    eval ${PARAM_NAME}=\"${PARAM_VALUE}\"
    export eval ${PARAM_NAME}
  fi	
  # Update the value
  print_env_file "${PARAM_NAME}=${PARAM_VALUE}"
  set -u
}

# Setup an env var and record it in the environment file
# The user cannot override the value
env_var() {
  set +u
  PARAM_NAME=$1
  shift
  PARAM_VALUE="$@"
  eval ${PARAM_NAME}=\"${PARAM_VALUE}\"
  export eval ${PARAM_NAME}
  print_env_file "${PARAM_NAME}=${PARAM_VALUE}"
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
  local repositoryURL="$1"; shift;
  local repositoryUsername="$1"; shift;
  local repositoryPassword="$1"; shift;
  local artifactGroupId="$1"; shift;
  local artifactArtifactId="$1"; shift;
  local artifactVersion="$1"; shift;
  local artifactPackaging="$1"; shift;
  local artifactClassifier="$1"; shift;
  local downloadDirectory="$1"; shift;
  local fileBaseName="$1"; shift;
  local prefix="$1"; shift; # Used to prefix variables that store artifact details
    
  #
  # Local variables
  #
  local artifactDate="" # We can compute the artifact date only for SNAPSHOTs
  local artifactTimestamp="$artifactVersion" # By default we set the timestamp to the given version (for a release)
  local baseUrl="${repositoryURL}/${artifactGroupId//.//}/$artifactArtifactId/$artifactVersion" # base url where to download from

  # Credentials and options
  if [ -n "$repositoryUsername" ]; then
    local curlOptions="--fail --show-error --location-trusted -u $repositoryUsername:$repositoryPassword" # Repository credentials and options  
  else
    local curlOptions="--fail --show-error --location-trusted"
  fi;
  
  # Create the directory where we will download it
  mkdir -p $downloadDirectory

  #
  # For a SNAPSHOT we will need to manually compute its TIMESTAMP from maven metadata
  #
  if [[ "$artifactVersion" =~ .*-SNAPSHOT ]]; then
    local metadataFile="$downloadDirectory/$fileBaseName-$artifactVersion-maven-metadata.xml"
    local metadataUrl="$baseUrl/maven-metadata.xml"
    # Backup lastest metadata to be able to use them if newest are wrong
    # (were removed from nexus for example thus we can use what we have in our local cache)
    if [ -e "$metadataFile" ]; then
      mv $metadataFile $metadataFile.bck
    fi
    do_curl "$curlOptions" "$metadataUrl" "$metadataFile" "Artifact Metadata"
    if [ -z "$artifactClassifier" ]; then
      local xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(not(classifier))and(extension=\"$artifactPackaging\")]/value/text()"
    else
      local xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$artifactClassifier\")and(extension=\"$artifactPackaging\")]/value/text()"
    fi
    set +e
    if $DARWIN; then
      artifactTimestamp=`xpath $metadataFile $xpathQuery`
    fi 
    if $LINUX; then
      artifactTimestamp=`xpath -q -e $xpathQuery $metadataFile`
    fi
    set -e
    if [ -z "$artifactTimestamp" ] && [ -e "$metadataFile.bck" ]; then
      # We will restore the previous one to get its timestamp and redeploy it
      echo "[WARNING] Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv $metadataFile.bck $metadataFile
      if $DARWIN; then
        artifactTimestamp=`xpath $METADATA $XPATH_QUERY`
      fi 
      if $LINUX; then
        artifactTimestamp=`xpath -q -e $XPATH_QUERY $METADATA`
      fi
    fi
    if [ -z "$artifactTimestamp" ]; then
      echo "[ERROR] No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f $metadataFile.bck
    echo "[INFO] Latest timestamp : $artifactTimestamp"
    artifactDate=`expr "$artifactTimestamp" : '.*-\(.*\)-.*'`
  fi
  
  #
  # Compute the Download URL for the artifact
  #
  local filename=$artifactArtifactId-$artifactTimestamp  
  local name=$artifactGroupId:$artifactArtifactId:$artifactVersion
  if [ -n "$artifactClassifier" ]; then
    filename="$filename-$artifactClassifier"
    name="$name:$artifactClassifier"
  fi;
  filename="$filename.$artifactPackaging"
  name="$name:$artifactPackaging"  
  local artifactUrl="$baseUrl/$filename"
  local artifactFile="$downloadDirectory/$fileBaseName-$artifactTimestamp.$artifactPackaging"
  
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
  case "$artifactPackaging" in
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
      echo "[WARNING] No method to validate \"$artifactPackaging\" file type." 
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
  local artifactInfo="$downloadDirectory/$fileBaseName-$artifactTimestamp.info"
  echo "[INFO] Creating archive descriptor ..."
  cat << EOF > $artifactInfo
${prefix}_VERSION="$artifactVersion"
${prefix}_ARTIFACT_GROUPID="$artifactGroupId"
${prefix}_ARTIFACT_ARTIFACTID="$artifactArtifactId"
${prefix}_ARTIFACT_TIMESTAMP="$artifactTimestamp"
${prefix}_ARTIFACT_CLASSIFIER="$artifactClassifier"
${prefix}_ARTIFACT_PACKAGING="$artifactPackaging"
${prefix}_ARTIFACT_URL="$artifactUrl"
${prefix}_ARTIFACT_LOCAL_PATH="$artifactFile"
EOF
  echo "[INFO] Done."
  #Display the deployment descriptor
  echo "[INFO] ========================== Archive Descriptor ==========================="
  cat $artifactInfo
  echo "[INFO] ========================================================================="
  
  #
  # Create a symlink if it is a SNAPSHOT to the TIMESTAMPED version
  #
  if [[ "$artifactVersion" =~ .*-SNAPSHOT ]]; then
    ln -fs "$fileBaseName-$artifactTimestamp.$artifactPackaging" "$downloadDirectory/$fileBaseName-$artifactVersion.$artifactPackaging"
    ln -fs "$fileBaseName-$artifactTimestamp.info" "$downloadDirectory/$fileBaseName-$artifactVersion.info"
  fi 
}

#
# Function that downloads a dataset from storage.exoplatform.org
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
  local storageUsername="$1"; shift;
  local storagePassword="$1"; shift;
  local localPath="$1"; shift;
  local description="$1"; shift;
  
  # Credentials and options
  if [ -n "$storageUsername" ]; then
    local curlOptions="--fail --show-error --location-trusted -u $storageUsername:$storagePassword" # Repository credentials and options  
  else
    local curlOptions="--fail --show-error --location-trusted"
  fi;
  
  # Create the directory where we will download it
  local downloadDirectory=`dirname "$localPath"`
  mkdir -p $downloadDirectory

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