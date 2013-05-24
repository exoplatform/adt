#!/bin/bash -eu

#Activate aliases usage in scripts
shopt -s expand_aliases

# ####################################
# Generic bash functions library
# ####################################

# OS specific support. $var _must_ be set to either true or false.
CYGWIN=false
LINUX=false;
OS400=false
DARWIN=false
case "`uname`" in
  CYGWIN*) CYGWIN=true ;;
  Linux*) LINUX=true ;;
  OS400*) OS400=true ;;
  Darwin*) DARWIN=true ;;
esac

# System dependent settings
if $LINUX; then
  TAR_BZIP2_COMPRESS_PRG=--use-compress-prog=pbzip2
  NICE_CMD="nice -n 20 ionice -c2 -n7"
else
  TAR_BZIP2_COMPRESS_PRG=
  NICE_CMD="nice -n 20"
fi

# Various command aliases
if $LINUX; then
  alias display_time='/usr/bin/time -f "[INFO] Return code : %x\n[INFO] Time report (sec) : \t%e real,\t%U user,\t%S system"'
else
  alias display_time='/usr/bin/time'
fi

# Converts $1 in upper case
toupper() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Converts $1 in lower case
tolower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}


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
  if (${ADT_DEBUG}); then
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
  if (${ADT_DEBUG}); then
    echo "[DEBUG] $PARAM_NAME=$PARAM_VALUE"
  fi
  set -u
}

#
# Replace in file $1 the value $2 by $3
#
replace_in_file() {
  mv $1 $1.orig
  sed "s|$2|$3|g" $1.orig > $1
  rm $1.orig
}

#
# find_file <VAR> <PATH1> ..  <PATHx>
# test all paths and the path of the latest one existing in parameters is set as VAR
#
find_file() {
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

#
# Replace in file $1 all environment variables (${XXX}) and push the result in $2
#
evaluate_file_content() {
  local _file_in=$1
  local _file_out=$2
  awk '{while(match($0,"[$]{[^}]*}")) {var=substr($0,RSTART+2,RLENGTH -3);gsub("[$]{"var"}",ENVIRON[var])}}1' < $_file_in > $_file_out
  # escape any single quote
  if $LINUX; then
    replace_in_file $_file_out "'" "\\\'"
  else
    replace_in_file $_file_out "\'" "\\\'"
  fi
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
  local _curlOptions="$1";
  shift;
  local _url="$1";
  shift;
  local _filePath="$1";
  shift;
  local _description="$1";
  shift;

  echo "[INFO] Downloading $_description from $_url ..."
  set +e
  curl $_curlOptions "$_url" > $_filePath
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, cannot download $_description"
    rm -f $_filePath # Remove potential corrupted file
    exit 1
  fi
  set -e
  echo "[INFO] $_description downloaded"
  echo "[INFO] Local path : $_filePath"
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
  mkdir -p $_downloadDirectory

  #
  # For a SNAPSHOT we will need to manually compute its TIMESTAMP from maven metadata
  #
  if [[ "$_artifactVersion" =~ .*-SNAPSHOT ]]; then
    local _metadataFile="$_downloadDirectory/$_fileBaseName-$_artifactVersion-maven-metadata.xml"
    local _metadataUrl="$_baseUrl/maven-metadata.xml"
    # Backup lastest metadata to be able to use them if newest are wrong
    # (were removed from nexus for example thus we can use what we have in our local cache)
    if [ -e "$_metadataFile" ]; then
      mv $_metadataFile $_metadataFile.bck
    fi
    do_curl "$_curlOptions" "$_metadataUrl" "$_metadataFile" "Artifact Metadata"
    local _xpathQuery="";
    if [ -z "$_artifactClassifier" ]; then
      _xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(not(classifier))and(extension=\"$_artifactPackaging\")]/value/text()"
    else
      _xpathQuery="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$_artifactClassifier\")and(extension=\"$_artifactPackaging\")]/value/text()"
    fi
    set +e
    if $DARWIN; then
      _artifactTimestamp=`xpath $_metadataFile $_xpathQuery`
    fi
    if $LINUX; then
      _artifactTimestamp=`xpath -q -e $_xpathQuery $_metadataFile`
    fi
    set -e
    if [ -z "$_artifactTimestamp" ] && [ -e "$_metadataFile.bck" ]; then
      # We will restore the previous one to get its timestamp and redeploy it
      echo "[WARNING] Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv $_metadataFile.bck $_metadataFile
      if $DARWIN; then
        _artifactTimestamp=`xpath $_metadataFile $_xpathQuery`
      fi
      if $LINUX; then
        _artifactTimestamp=`xpath -q -e $_xpathQuery $_metadataFile`
      fi
    fi
    if [ -z "$_artifactTimestamp" ]; then
      echo "[ERROR] No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f $_metadataFile.bck
    echo "[INFO] Latest timestamp : $_artifactTimestamp"
    _artifactDate=`expr "$_artifactTimestamp" : '.*-\(.*\)-.*'`
  fi

  #
  # Compute the Download URL for the artifact
  #
  local _filename=$_artifactArtifactId-$_artifactTimestamp
  local _name=$_artifactGroupId:$_artifactArtifactId:$_artifactVersion
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
  if [ ! -e "$_sha1File" ]; then
    do_curl "$_curlOptions" "$_sha1Url" "$_sha1File" "Artifact SHA1"
  fi

  #
  # Download the artifact
  #
  if [ -e "$_artifactFile" ]; then
    echo "[INFO] $_name was already downloaded. Skip artifact download !"
  else
    do_curl "$_curlOptions" "$_artifactUrl" "$_artifactFile" "Artifact $_name"
  fi

  #
  # Validate download integrity
  #
  echo "[INFO] Validating download integrity ..."
  # Read the SHA1 from Maven
  read -r mavenSha1 < $_sha1File || true
  echo "$mavenSha1  $_artifactFile" > $_sha1File.tmp
  set +e
  shasum -c $_sha1File.tmp
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $_name download integrity failed"
    rm -f $_artifactFile
    rm -f $_sha1File
    rm -f $_sha1File.tmp
    exit 1
  fi
  set -e
  rm -f $_sha1File.tmp
  echo "[INFO] Download integrity validated."

  #
  # Validate archive integrity
  #
  echo "[INFO] Validating archive integrity ..."
  set +e
  case "$_artifactPackaging" in
    zip)
      zip -T $_artifactFile
    ;;
    jar | war | ear)
      jar -tf $_artifactFile > /dev/null
    ;;
    tar.gz | tgz)
      gzip -t $_artifactFile
    ;;
    *)
      echo "[WARNING] No method to validate \"$_artifactPackaging\" file type."
    ;;
  esac
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $_name archive integrity failed. Local copy is deleted."
    rm -f $_artifactFile
    rm -f $mavenSha1
    exit 1
  fi
  set -e
  echo "[INFO] Archive integrity validated."

  #
  # Create an info file with all details about the artifact
  #
  local _artifactInfo="$_downloadDirectory/$_fileBaseName-$_artifactTimestamp.info"
  echo "[INFO] Creating archive descriptor ..."
  cat << EOF > $_artifactInfo
${_prefix}_VERSION="$_artifactVersion"
${_prefix}_ARTIFACT_GROUPID="$_artifactGroupId"
${_prefix}_ARTIFACT_ARTIFACTID="$_artifactArtifactId"
${_prefix}_ARTIFACT_TIMESTAMP="$_artifactTimestamp"
${_prefix}_ARTIFACT_DATE="$_artifactDate"
${_prefix}_ARTIFACT_CLASSIFIER="$_artifactClassifier"
${_prefix}_ARTIFACT_PACKAGING="$_artifactPackaging"
${_prefix}_ARTIFACT_URL="$_artifactUrl"
${_prefix}_ARTIFACT_LOCAL_PATH="$_artifactFile"
EOF

  echo "[INFO] Done."
  #Display the deployment descriptor
  echo "[INFO] ========================== Archive Descriptor ==========================="
  cat $_artifactInfo
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
  local _downloadDirectory="$1";
  shift;
  local _fileBaseName="$1";
  shift;
  local _artifactVersion="$1";
  shift;
  source "$_downloadDirectory/$_fileBaseName-$_artifactVersion.info"
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
  mkdir -p $_downloadDirectory

  #
  # Download the SHA1
  #
  local _sha1Url="${_fileURL}.sha1"
  local _sha1File="${_localPath}.sha1"
  if [ ! -e "$_sha1File" ]; then
    do_curl "$_curlOptions" "$_sha1Url" "$_sha1File" "File SHA1"
  fi

  #
  # Download the file
  #
  if [ -e "$_localPath" ]; then
    echo "[INFO] $_description was already downloaded. Skip file download !"
  else
    do_curl "$_curlOptions" "$_fileURL" "$_localPath" "$_description"
  fi

  #
  # Validate download integrity
  #
  echo "[INFO] Validating download integrity ..."
  set +e
  cd `dirname ${_localPath}`
  shasum -c $_sha1File
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $_description download integrity failed"
    rm -f $_localPath
    rm -f $_sha1File
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
  zip -T $_localPath
  if [ "$?" -ne "0" ]; then
    echo "[ERROR] Sorry, $_description archive integrity failed"
    rm -f $_localPath
    exit 1
  fi
  set -e
  echo "[INFO] Archive integrity validated."
}

# Backup the file passed as parameter
backup_logs() {
  if [ -d $1 ]; then
    # We need to backup existing logs if they already exist
    cd $1
    local _start_date=`date -u "+%Y%m%d-%H%M%S-UTC"`
    for file in $2
    do
      if [ -e $file ]; then
        echo "Archiving existing log file $file as archived-on-${_start_date}-$file   ..."
        mv $file archived-on-${_start_date}-$file
        echo "Done."
      fi
    done
    cd -
  fi
}

lowercase() {
  echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

# Get informations about system
loadSystemInfo() {
  OS=`lowercase \`uname\``
  OSSTR=""
  KERNEL=`uname -r`
  MACH=`uname -m`
  ARCH=""
  DIST=""
  PSEUDONAME=""
  REV=""
  DistroBasedOn=""

  if [ "${OS}" == "windowsnt" ]; then
    OS=windows
  elif [ "${OS}" == "darwin" ]; then
    OS=mac
  else
    OS=`uname`
    if [ "${OS}" = "SunOS" ]; then
      OS=Solaris
      ARCH=`uname -p`
      OSSTR="${OS}${REV}(${ARCH}`uname-v`)"
    elif [ "${OS}" = "AIX" ]; then
      OSSTR="${OS}`oslevel` (`oslevel-r`)"
    elif [ "${OS}" = "Linux" ]; then
      if [ -f /etc/redhat-release ]; then
        DistroBasedOn='RedHat'
        DIST=`cat /etc/redhat-release | sed s/\ release.*//`
        PSEUDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
        REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
      elif [ -f /etc/SuSE-release ]; then
        DistroBasedOn='SuSe'
        PSEUDONAME=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/VERSION.*//`
        REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
      elif [ -f /etc/mandrake-release ]; then
        DistroBasedOn='Mandrake'
        PSEUDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
        REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
      elif [ -f /etc/debian_version ]; then
        DistroBasedOn='Debian'
        DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F= '{ print $2 }'`
        PSEUDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F= '{ print $2 }'`
        REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F= '{ print $2 }'`
      fi
      if [ -f /etc/UnitedLinux-release ]; then
        DIST="${DIST}[`cat/etc/UnitedLinux-release|tr"\n"' '|seds/VERSION.*//`]"
      fi
      OS=`lowercase $OS`
      DistroBasedOn=`lowercase $DistroBasedOn`
      readonly OS
      readonly OSSTR
      readonly KERNEL
      readonly MACH
      readonly DIST
      readonly PSEUDONAME
      readonly REV
      readonly DistroBasedOn
    fi

  fi
  echo "========"
  if [ -n "${OS}" ]; then
    echo "[INFO] OS: ${OS}";
  fi
  if [ -n "${OSSTR}" ]; then
    echo "[INFO] OSSTR: ${OSSTR}";
  fi
  if [ -n "${DIST}" ]; then
    echo "[INFO] DIST: ${DIST}"
  fi
  if [ -n "${PSEUDONAME}" ]; then
    echo "[INFO] PSEUDONAME: ${PSEUDONAME}"
  fi
  if [ -n "${REV}" ]; then
    echo "[INFO] REV: ${REV}"
  fi
  if [ -n "${DistroBasedOn}" ]; then
    echo "[INFO] DistroBasedOn: ${DistroBasedOn}"
  fi
  if [ -n "${KERNEL}" ]; then
    echo "[INFO] KERNEL: ${KERNEL}"
  fi
  if [ -n "${MACH}" ]; then
    echo "[INFO] MACH: ${MACH}"
  fi
  if [ -n "${ARCH}" ]; then
    echo "[INFO] ARCH: ${ARCH}"
  fi
  echo "========"

}

# $1 : scheme : http, ..
# $2 : host
# $3 : port
# $4 : path
do_build_url() {
  if [ $# -lt 4 ]; then
    echo ""
    echo "[ERROR] No enough parameters for function do_build_url !"
    exit 1;
  fi

  #
  # Function parameters
  #
  local _scheme="$1";
  shift;
  local _host="$1";
  shift;
  local _port="$1";
  shift;
  local _path="$1";
  shift;

  local _result="${_scheme}://${_host}";
  if [ "$_port" == "80" ]; then
    _result="${_result}${_path}";
  else
    _result="${_result}:${_port}${_path}";
  fi

  echo $_result
}

