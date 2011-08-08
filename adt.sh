#!/bin/bash -eu                                                                                                                                                                                                                         -e

# Load server config from /etc/default/adt
[ -e /etc/default/adt ] && source /etc/default/adt

# Load local config from $HOME/.adtrc
[ -e $HOME/.adtrc ] && source $HOME/.adtrc

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="${0%/*}"

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
# Initializes the script and various variables
#
initialize()
{
  # if the script was started from the base directory, then the
  # expansion returns a period
  if test "$SCRIPT_DIR" == "." ; then
    SCRIPT_DIR="$PWD"
  # if the script was not called with an absolute path, then we need to add the
  # current working directory to the relative path of the script
  elif test "${SCRIPT_DIR:0:1}" != "/" ; then
    SCRIPT_DIR="$PWD/$SCRIPT_DIR"
  fi

  # ADT_DATA is the working area for ADT script
  if [ ! $ADT_DATA ]; then 
    echo "[ERROR] ADT_DATA environment variable not set !"
    echo "[ERROR] You can define it in \$HOME/.adtrc"
    exit 1;
  fi

  # Convert to an absolute path
  pushd $ADT_DATA > /dev/null
  ADT_DATA=`pwd -P`
  popd > /dev/null

  ETC_DIR=$SCRIPT_DIR/etc

  echo "[INFO] ADT_DATA = $ADT_DATA"

  # Create ADT_DATA if required
  mkdir -p $ADT_DATA

  TMP_DIR=$ADT_DATA/tmp
  DL_DIR=$ADT_DATA/downloads
  SRV_DIR=$ADT_DATA/servers
  CONF_DIR=$ADT_DATA/conf
  APACHE_CONF_DIR=$ADT_DATA/conf/apache
  ADT_CONF_DIR=$ADT_DATA/conf/adt

  PRODUCT_NAME=""
  PRODUCT_VERSION=""

  DEPLOYMENT_DATE=""
  DEPLOYMENT_DIR=""
  DEPLOYMENT_URL=""
  DEPLOYMENT_LOG_URL=""
  DEPLOYMENT_LOG_PATH=""
  DEPLOYMENT_JMX_URL=""
  DEPLOYMENT_PID_FILE=""
  # These variables can be loaded from the env or $HOME/.adtrc
  set +u
  [ -z $DEPLOYMENT_SHUTDOWN_PORT ] && DEPLOYMENT_SHUTDOWN_PORT=8005
  [ -z $DEPLOYMENT_HTTP_PORT ] && DEPLOYMENT_HTTP_PORT=8080
  [ -z $DEPLOYMENT_AJP_PORT ] && DEPLOYMENT_AJP_PORT=8009
  [ -z $DEPLOYMENT_RMI_REG_PORT ] && DEPLOYMENT_RMI_REG_PORT=10001
  [ -z $DEPLOYMENT_RMI_SRV_PORT ] && DEPLOYMENT_RMI_SRV_PORT=10002
  set -u
  
  ARTIFACT_GROUPID=""
  ARTIFACT_ARTIFACTID=""
  ARTIFACT_TIMESTAMP=""
  ARTIFACT_DATE=""
  ARTIFACT_CLASSIFIER=""
  ARTIFACT_PACKAGING=""
  ARTIFACT_REPO_URL=""
  ARTIFACT_DL_URL=""
  # These variables can be loaded from the env or $HOME/.adtrc
  set +u
  [ -z $ARTIFACT_REPO_GROUP ] && ARTIFACT_REPO_GROUP="public"
  set -u
  
  # These variables can be loaded from the env or $HOME/.adtrc
  set +u
  [ -z $REPO_CREDENTIALS ] && REPO_CREDENTIALS=""
  [ -z $MYSQL_CREDENTIALS ] && MYSQL_CREDENTIALS=""  
  set -u
  
  CURR_DATE=`date "+%Y%m%d.%H%M%S"`
  KEEP_DB=false  
  SERVER_SCRIPT="/bin/gatein.sh"

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
}

#
# Usage message
#
print_usage()
{ 
cat << EOF

usage: $0 action [product] [version] [options]

This script manages automated deployment of eXo products

ACTION :
  deploy       Deploys (Download+Configure) the server
  start        Starts the server
  start-all    Starts all deployed servers
  stop         Stops the server
  stop-all     Stops all deployed servers
  restart      Restarts the server
  restart-all  Restarts all deployed servers
  undeploy     Undeploys (deletes) the server
  undeploy-all Undeploys (deletes) all deployed servers
  list         Lists all deployed servers
  
PRODUCT (for deploy, start, stop, restart, undeploy actions) :
  gatein       eXo GateIn
  webos        eXo WebOS
  social       eXo Social
  ecms         eXo Content
  ks           eXo Knowledge
  cs           eXo Collaboration
  platform     eXo Platform

VERSION (for deploy, start, stop, restart, undeploy actions) :
  version of the product

GLOBAL OPTIONS :
  -h           Show this message  

DEPLOY OPTIONS [ environment variable to use to set a default value ] :
  -A <value>   AJP Port (default: 8009) [ \$DEPLOYMENT_AJP_PORT ]
  -H <value>   HTTP Port (default: 8080) [ \$DEPLOYMENT_HTTP_PORT ]
  -S <value>   SHUTDOWN Port (default: 8005) [ \$DEPLOYMENT_SHUTDOWN_PORT ]
  -R <value>   RMI Registry Port for JMX (default: 10001) [ \$DEPLOYMENT_RMI_REG_PORT ]
  -V <value>   RMI Server Port for JMX (default: 10002) [ \$DEPLOYMENT_RMI_SRV_PORT ]
  -g <value>   Repository group where to download the artifact from. Values : public | staging | private (default: public) [ \$ARTIFACT_REPO_GROUP ]
  -r <value>   user credentials in "username:password" format to download the server package (default: none) [ \$REPO_CREDENTIALS ]
  -k           Keep the current database content. By default the deployment process drops the database if it already exists.

DEPLOY/UNDEPLOY OPTIONS [ environment variable to use to set a default value ] :
  -m <value>   user credentials in "username:password" format to manage the database server (default: none) [ \$MYSQL_CREDENTIALS ]  

EOF

}

#
# Decode command line parameters
#
do_process_cl_params()
{   
    # no action ? provide help
    if [ $# -lt 1 ]; then
      echo ""
      echo "[ERROR] No action defined !"
      print_usage
      exit 1;
    fi
    
    # If help is asked
    if [ $1 == "-h" ]; then
      print_usage
      exit    
    fi

    # Action to do
    ACTION=$1
    shift    
    
    #
    # validate additional parameters
    case "$ACTION" in
      deploy|start|stop|restart|undeploy)
        if [ $# -lt 2 ]; then
          echo ""
          echo "[ERROR] product and version parameters are mandatory for action \"$ACTION\" !"
          print_usage
        exit 1;
        fi
        # Product
        PRODUCT_NAME=$1
        shift
        # Validate product and load artifact details
        case "$PRODUCT_NAME" in
          gatein)
            ARTIFACT_GROUPID="org.exoplatform.portal"
            ARTIFACT_ARTIFACTID="exo.portal.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            GATEIN_CONF_PATH="gatein/conf/configuration.properties"
            ;;
          webos)
            ARTIFACT_GROUPID="org.exoplatform.webos"
            ARTIFACT_ARTIFACTID="exo.webos.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            SERVER_SCRIPT="/bin/eXo.sh"
            GATEIN_CONF_PATH="gatein/conf/configuration.properties"
            ;;
          ecms)
            ARTIFACT_GROUPID="org.exoplatform.ecms"
            ARTIFACT_ARTIFACTID="exo-ecms-delivery-wcm-assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            GATEIN_CONF_PATH="gatein/conf/configuration.properties"
            ;;
          social)
            ARTIFACT_GROUPID="org.exoplatform.social"
            ARTIFACT_ARTIFACTID="exo.social.packaging.pkg"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            GATEIN_CONF_PATH="gatein/conf/portal/socialdemo/socialdemo.properties"
            ;;
          ks)
            ARTIFACT_GROUPID="org.exoplatform.ks"
            ARTIFACT_ARTIFACTID="exo.ks.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            GATEIN_CONF_PATH="gatein/conf/portal/ksdemo/ksdemo.properties"
            ;;
          cs)
            ARTIFACT_GROUPID="org.exoplatform.cs"
            ARTIFACT_ARTIFACTID="exo.cs.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            GATEIN_CONF_PATH="gatein/conf/configuration.properties"
            ;;
          plf)
            ARTIFACT_GROUPID="org.exoplatform.platform"
            ARTIFACT_ARTIFACTID="exo.platform.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            GATEIN_CONF_PATH="gatein/conf/configuration.properties"
            ;;
          ?)
            echo "[ERROR] Invalid product \"$PRODUCT_NAME\"" 
            print_usage
            exit 1
            ;;
        esac        
        # Version
        PRODUCT_VERSION=$1
        shift        
        # $PRODUCT_BRANCH is computed from $PRODUCT_VERSION and is equal to the version up to the latest dot
        # and with x added. ex : 3.5.0-M4-SNAPSHOT => 3.5.x, 1.1.6-SNAPSHOT => 1.1.x
        PRODUCT_BRANCH=`expr "$PRODUCT_VERSION" : '\(.*\)\..*'`".x"
        # Build a database name without dot, minus ... 
        DEPLOYMENT_DATABASE_NAME="${PRODUCT_NAME}_${PRODUCT_VERSION}"
        DEPLOYMENT_DATABASE_NAME="${DEPLOYMENT_DATABASE_NAME//./_}"
        DEPLOYMENT_DATABASE_NAME="${DEPLOYMENT_DATABASE_NAME//-/_}"
        # Build a database user without dot, minus ... (using the branch because limited to 16 characters)
        DEPLOYMENT_DATABASE_USER="${PRODUCT_NAME}_${PRODUCT_BRANCH}"
        DEPLOYMENT_DATABASE_USER="${DEPLOYMENT_DATABASE_USER//./_}"
        DEPLOYMENT_DATABASE_USER="${DEPLOYMENT_DATABASE_USER//-/_}"        
        ;;
      list)
        # Nothing to do
        ;;
      ?)
        echo "[ERROR] Invalid action \"$ACTION\"" 
        print_usage
        exit 1
        ;;
    esac    

    # Additional options
    while getopts "hkA:H:S:R:V:g:r:m:" OPTION
    do
         case $OPTION in
             h)
                 print_usage
                 exit
                 ;;
             k)
                 if [[ "$ACTION" == "deploy" ]]; then
                   KEEP_DB=true
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             H)
                 if [[ "$ACTION" == "deploy" ]]; then
                   DEPLOYMENT_HTTP_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             A)
                 if [[ "$ACTION" == "deploy" ]]; then
                   DEPLOYMENT_AJP_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             S)
                 if [[ "$ACTION" == "deploy" ]]; then
                   DEPLOYMENT_SHUTDOWN_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             R)
                 if [[ "$ACTION" == "deploy" ]]; then
                   DEPLOYMENT_RMI_REG_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             V)
                 if [[ "$ACTION" == "deploy" ]]; then
                   DEPLOYMENT_RMI_SRV_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             g)
                 if [[ "$ACTION" == "deploy" ]]; then
                   ARTIFACT_REPO_GROUP=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             r)
                 if [[ "$ACTION" == "deploy" ]]; then
                   REPO_CREDENTIALS=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             m)
                 if [[ ("$ACTION" == "deploy") ||  ("$ACTION" == "undeploy") ]]; then
                   MYSQL_CREDENTIALS=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             ?)
                 print_usage
                 echo "[ERROR] Invalid option \"$OPTARG\"" 
                 exit 1
                 ;;
         esac
    done

    if [[ (("$ACTION" == "deploy") || ("$ACTION" == "undeploy")) && -z $MYSQL_CREDENTIALS ]]; then
      echo "[ERROR] DB Credentials aren't set !"
      echo "[ERROR] Use the -m command line option or set the environment variable MYSQL_CREDENTIALS"
      print_usage
      exit 1;
    fi

    # skip getopt parms
    shift $((OPTIND-1))

}

#
# Function that downloads the app server from nexus
# Because Nexus REST APIs don't use Maven 3 metadata to download the latest SNAPSHOT
# of a given GAVCE we need to manually get the timestamp using xpath
# see https://issues.sonatype.org/browse/NEXUS-4423
#
do_download_server() {
  # We can compute the artifact date only for SNAPSHOTs
  ARTIFACT_DATE=""
  # Where we will download it
  mkdir -p $DL_DIR
  # REPO_CREDENTIALS and repository options
  if [ -n $REPO_CREDENTIALS ]; then
    local curl_options="--location-trusted -u $REPO_CREDENTIALS"
  fi;
  if [ -z $REPO_CREDENTIALS ]; then
    local curl_options="--location-trusted"
  fi;
  # By default the timestamp is the version (for a release)
  ARTIFACT_TIMESTAMP=$PRODUCT_VERSION
  # base url where to download from
  local url="http://repository.exoplatform.org/${ARTIFACT_REPO_GROUP}/${ARTIFACT_GROUPID//.//}/$ARTIFACT_ARTIFACTID/$PRODUCT_VERSION"

  # For a SNAPSHOT we will need to manually compute the TIMESTAMP of the SNAPSHOT
  if [[ "$PRODUCT_VERSION" =~ .*-SNAPSHOT ]]; then
    local METADATA=$DL_DIR/$PRODUCT_NAME-$PRODUCT_VERSION-maven-metadata.xml
    # Backup lastest metadata to be able to use them if newest are wrong (don't have delivery)
    if [ -e $METADATA ]; then
      mv $METADATA $METADATA.bck
    fi
    echo "[INFO] Downloading metadata $url/maven-metadata.xml ..."
    set +e
    curl $curl_options "$url/maven-metadata.xml" > $DL_DIR/$PRODUCT_NAME-$PRODUCT_VERSION-maven-metadata.xml
    if [ "$?" -ne "0" ]; then
      echo "[ERROR] Sorry, cannot download artifact metadata"
      exit 1
    fi
    set -e
    echo "[INFO] Metadata downloaded"
    local XPATH_QUERY="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$ARTIFACT_CLASSIFIER\")and(extension=\"$ARTIFACT_PACKAGING\")]/value/text()"
    set +e
    if $DARWIN; then
      ARTIFACT_TIMESTAMP=`xpath $METADATA $XPATH_QUERY`
    fi 
    if $LINUX; then
      ARTIFACT_TIMESTAMP=`xpath -q -e $XPATH_QUERY $METADATA`
    fi
    set -e
    if [ -z $ARTIFACT_TIMESTAMP ] && [ -e $METADATA.bck ]; then
      # We will restore the previous one to get its timestamp and redeploy it
      echo "[WARNING] Current metadata invalid (no more package in the repository ?). Reinstalling previous downloaded version."
      mv $METADATA.bck $METADATA
      if $DARWIN; then
        ARTIFACT_TIMESTAMP=`xpath $METADATA $XPATH_QUERY`
      fi 
      if $LINUX; then
        ARTIFACT_TIMESTAMP=`xpath -q -e $XPATH_QUERY $METADATA`
      fi
    fi
    if [ -z $ARTIFACT_TIMESTAMP ]; then
      echo "[ERROR] No package available in the remote repository and no previous version available locally."
      exit 1;
    fi
    rm -f $METADATA.bck
    echo "[INFO] Latest timestamp : $ARTIFACT_TIMESTAMP"
    ARTIFACT_DATE=`expr "$ARTIFACT_TIMESTAMP" : '.*-\(.*\)-.*'`
  fi
  local filename=$ARTIFACT_ARTIFACTID-$ARTIFACT_TIMESTAMP  
  local name=$ARTIFACT_GROUPID:$ARTIFACT_ARTIFACTID:$PRODUCT_VERSION
  if [ -n $ARTIFACT_CLASSIFIER ]; then
    filename="$filename-$ARTIFACT_CLASSIFIER"
    name="$name:$ARTIFACT_CLASSIFIER"
  fi;
  filename="$filename.$ARTIFACT_PACKAGING"
  name="$name:$ARTIFACT_PACKAGING"  
  ARTIFACT_REPO_URL=$url/$filename
  if [ -e $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING ]; then
    echo "[WARNING] $name was already downloaded. Skip server download !"
  else
    echo "[INFO] Downloading server ..."
    echo "[INFO] Archive          : $name "
    echo "[INFO] Repository       : $repository "
    echo "[INFO] Url              : $ARTIFACT_REPO_URL "
    set +e
    curl $curl_options "$ARTIFACT_REPO_URL" > $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
    if [ "$?" -ne "0" ]; then
      echo "[ERROR] Sorry, cannot download $name"
      exit 1
    fi
    set -e
    echo "[INFO] Server downloaded"
  fi
  ARTIFACT_DL_URL="http://acceptance.exoplatform.org/downloads/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING"
}

#
# Function that unpacks the app server archive
#
do_unpack_server() 
{
  rm -rf $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
  echo "[INFO] Unpacking server ..."
  mkdir -p $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
  set +e
  case $ARTIFACT_PACKAGING in
    zip)
      unzip $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING -d $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo "[WARNING] unpack of the server failed. We will try to download it a second time."
        rm $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
        do_download_server
        unzip $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING -d $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
        if [ "$?" -ne "0" ]; then
          echo "[ERROR] Unable to unpack the server."
          exit 1
        fi
      fi      
      ;;
    tar.gz)
      cd $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
      tar -xzvf $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
      if [ "$?" -ne "0" ]; then
        # If unpack fails we try to redownload the archive
        echo "[WARNING] unpack of the server failed. We will try to download it a second time."
        rm $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
        do_download_server
        tar -xzvf $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
        if [ "$?" -ne "0" ]; then
          echo "[ERROR] Unable to unpack the server."
          exit 1
        fi
      fi      
      cd -
      ;;
    *)
      echo "[ERROR] Invalid packaging \"$ARTIFACT_PACKAGING\""
      print_usage
      exit 1
      ;;
  esac
  set -e
  DEPLOYMENT_DIR=$SRV_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
  DEPLOYMENT_PID_FILE=$SRV_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.pid
  rm -rf $DEPLOYMENT_DIR
  mkdir -p $SRV_DIR
  if [ -d "$TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION/gatein/" ]; then
    cp -rf $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION $DEPLOYMENT_DIR
  else
    find $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION -maxdepth 1 -mindepth 1 -type d -exec cp -rf {} $DEPLOYMENT_DIR \;
  fi
  rm -rf $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
  DEPLOYMENT_LOG_PATH=$DEPLOYMENT_DIR/logs/catalina.out
  echo "[INFO] Server unpacked"
}

#
# Creates a database for the instance. Drops it if it already exists.
#
do_create_database()
{
  echo "[INFO] Creating MySQL database $DEPLOYMENT_DATABASE_NAME ..."
  SQL=""
  if( ! $KEEP_DB ); then
    SQL=$SQL"DROP DATABASE IF EXISTS $DEPLOYMENT_DATABASE_NAME;"
    echo "[INFO] Existing databases will be dropped !"
  fi;
  SQL=$SQL"CREATE DATABASE IF NOT EXISTS $DEPLOYMENT_DATABASE_NAME CHARACTER SET latin1 COLLATE latin1_bin;"
  SQL=$SQL"GRANT ALL ON $DEPLOYMENT_DATABASE_NAME.* TO '$DEPLOYMENT_DATABASE_USER'@'localhost' IDENTIFIED BY '$DEPLOYMENT_DATABASE_USER';"
  SQL=$SQL"FLUSH PRIVILEGES;"
  SQL=$SQL"SHOW DATABASES;"
  mysql -u ${MYSQL_CREDENTIALS%%:*} -p${MYSQL_CREDENTIALS##*:} -e "$SQL"
  echo "[INFO] Done."
}

#
# Drops the database used by the instance.
#
do_drop_database()
{
  echo "[INFO] Drops MySQL database $DEPLOYMENT_DATABASE_NAME ..."
  SQL=""
  SQL=$SQL"DROP DATABASE IF EXISTS $DEPLOYMENT_DATABASE_NAME;"  
  SQL=$SQL"SHOW DATABASES;"
  mysql -u ${MYSQL_CREDENTIALS%%:*} -p${MYSQL_CREDENTIALS##*:} -e "$SQL"
  echo "[INFO] Done."
}

#
# Function that configure the server for ours needs
#
do_patch_server()
{
  # Install jmx jar
  JMX_JAR_URL="http://archive.apache.org/dist/tomcat/tomcat-6/v6.0.32/bin/extras/catalina-jmx-remote.jar"
  echo "[INFO] Downloading and installing JMX remote lib ..."
  curl ${JMX_JAR_URL} > ${DEPLOYMENT_DIR}/lib/`basename $JMX_JAR_URL`
  if [ ! -e ${DEPLOYMENT_DIR}/lib/`basename $JMX_JAR_URL` ]; then
    echo "[ERROR] !!! Sorry, cannot download ${JMX_JAR_URL}"
    exit 1
  fi
  echo "[INFO] Done."

  MYSQL_JAR_URL="http://repository.exoplatform.org/public/mysql/mysql-connector-java/5.1.16/mysql-connector-java-5.1.16.jar"
  echo "[INFO] Download and install MySQL JDBC driver ..."
  curl ${MYSQL_JAR_URL} > ${DEPLOYMENT_DIR}/lib/`basename $MYSQL_JAR_URL`
  if [ ! -e ${DEPLOYMENT_DIR}/lib/`basename $MYSQL_JAR_URL` ]; then
    echo "[ERROR] !!! Sorry, cannot download ${MYSQL_JAR_URL}"
    exit 1
  fi
  echo "[INFO] Done."

  # Reconfigure server.xml
  
  # Ensure the server.xml doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp $DEPLOYMENT_DIR/conf/server.xml $DEPLOYMENT_DIR/conf/server.xml.orig
  tr -d '\015' < $DEPLOYMENT_DIR/conf/server.xml.orig > $DEPLOYMENT_DIR/conf/server.xml  

  # First we need to find which patch to apply
  # We'll try to find it in the directory $ETC_DIR/tomcat6/ and we'll select it in this order :
  # $PRODUCT_NAME-$PRODUCT_VERSION-server.xml.patch
  # $PRODUCT_NAME-$PRODUCT_BRANCH-server.xml.patch
  # $PRODUCT_NAME-server.xml.patch  
  # server.xml.patch
  #
  local server_patch="$ETC_DIR/tomcat6/server.xml.patch"
  [ -e $ETC_DIR/tomcat6/$PRODUCT_NAME-server.xml.patch ] && server_patch="$ETC_DIR/tomcat6/$PRODUCT_NAME-server.xml.patch"  
  [ -e $ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_BRANCH-server.xml.patch ] && server_patch="$ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_BRANCH-server.xml.patch"
  [ -e $ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_VERSION-server.xml.patch ] && server_patch="$ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_VERSION-server.xml.patch"
  # Prepare the patch
  cp $server_patch $DEPLOYMENT_DIR/conf/server.xml.patch
  echo "[INFO] Applying on server.xml the patch $server_patch ..."  
  cp $DEPLOYMENT_DIR/conf/server.xml $DEPLOYMENT_DIR/conf/server.xml.ori
  patch -l -p0 $DEPLOYMENT_DIR/conf/server.xml < $DEPLOYMENT_DIR/conf/server.xml.patch  
  cp $DEPLOYMENT_DIR/conf/server.xml $DEPLOYMENT_DIR/conf/server.xml.patched
  
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@SHUTDOWN_PORT@" "${DEPLOYMENT_SHUTDOWN_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@HTTP_PORT@" "${DEPLOYMENT_HTTP_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@AJP_PORT@" "${DEPLOYMENT_AJP_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@JMX_RMI_REGISTRY_PORT@" "${DEPLOYMENT_RMI_REG_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@JMX_RMI_SERVER_PORT@" "${DEPLOYMENT_RMI_SRV_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
  echo "[INFO] Done."

  # Reconfigure $GATEIN_CONF_PATH
  
  # Ensure the configuration.properties doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp $DEPLOYMENT_DIR/$GATEIN_CONF_PATH $DEPLOYMENT_DIR/$GATEIN_CONF_PATH.orig
  tr -d '\015' < $DEPLOYMENT_DIR/$GATEIN_CONF_PATH.orig > $DEPLOYMENT_DIR/$GATEIN_CONF_PATH  

  # First we need to find which patch to apply
  # We'll try to find it in the directory $ETC_DIR/gatein/ and we'll select it in this order :
  # $PRODUCT_NAME-$PRODUCT_VERSION-configuration.properties.patch
  # $PRODUCT_NAME-$PRODUCT_BRANCH-configuration.properties.patch
  # $PRODUCT_NAME-configuration.properties.patch
  # configuration.properties.patch
  #
  local gatein_patch="$ETC_DIR/gatein/configuration.properties.patch"
  [ -e $ETC_DIR/gatein/$PRODUCT_NAME-configuration.properties.patch ] && gatein_patch="$ETC_DIR/gatein/$PRODUCT_NAME-configuration.properties.patch"
  [ -e $ETC_DIR/gatein/$PRODUCT_NAME-$PRODUCT_BRANCH-configuration.properties.patch ] && gatein_patch="$ETC_DIR/gatein/$PRODUCT_NAME-$PRODUCT_BRANCH-configuration.properties.patch"
  [ -e $ETC_DIR/gatein/$PRODUCT_NAME-$PRODUCT_VERSION-configuration.properties.patch ] && gatein_patch="$ETC_DIR/gatein/$PRODUCT_NAME-$PRODUCT_VERSION-configuration.properties.patch"
  # Prepare the patch
  cp $gatein_patch $DEPLOYMENT_DIR/$GATEIN_CONF_PATH.patch
  echo "[INFO] Applying on $GATEIN_CONF_PATH the patch $gatein_patch ..."  
  cp $DEPLOYMENT_DIR/$GATEIN_CONF_PATH $DEPLOYMENT_DIR/$GATEIN_CONF_PATH.ori
  patch -l -p0 $DEPLOYMENT_DIR/$GATEIN_CONF_PATH < $DEPLOYMENT_DIR/$GATEIN_CONF_PATH.patch  
  cp $DEPLOYMENT_DIR/$GATEIN_CONF_PATH $DEPLOYMENT_DIR/$GATEIN_CONF_PATH.patched
  
  replace_in_file $DEPLOYMENT_DIR/$GATEIN_CONF_PATH "@DB_JCR_USR@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/$GATEIN_CONF_PATH "@DB_JCR_PWD@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/$GATEIN_CONF_PATH "@DB_JCR_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
  replace_in_file $DEPLOYMENT_DIR/$GATEIN_CONF_PATH "@DB_IDM_USR@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/$GATEIN_CONF_PATH "@DB_IDM_PWD@" "${DEPLOYMENT_DATABASE_USER}"
  replace_in_file $DEPLOYMENT_DIR/$GATEIN_CONF_PATH "@DB_IDM_NAME@" "${DEPLOYMENT_DATABASE_NAME}"
  echo "[INFO] Done."

  # JMX settings
  echo "[INFO] Creating JMX configuration files ..."  
  cat << EOF > $DEPLOYMENT_DIR/conf/jmxremote.access
acceptanceMonitor readonly
EOF
  cat << EOF > $DEPLOYMENT_DIR/conf/jmxremote.password
acceptanceMonitor monitorAcceptance!
EOF
  chmod 400 $DEPLOYMENT_DIR/conf/jmxremote.password
  echo "[INFO] Done."
  echo "[INFO] Opening firewall ports ..."
  # Open firewall ports
  if $LINUX; then
    sudo /usr/sbin/ufw allow ${DEPLOYMENT_RMI_REG_PORT}
    sudo /usr/sbin/ufw allow ${DEPLOYMENT_RMI_SRV_PORT}    
  fi  
  echo "[INFO] Done."
  DEPLOYMENT_JMX_URL="service:jmx:rmi://$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org:${DEPLOYMENT_RMI_SRV_PORT}/jndi/rmi://$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org:${DEPLOYMENT_RMI_REG_PORT}/jmxrmi"
}

do_create_apache_vhost()
{
mkdir -p $APACHE_CONF_DIR
cat << EOF > $APACHE_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
<VirtualHost *:80>
    ServerName  $PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org

    ErrorLog        \${ADT_DATA}/var/log/apache2/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org-error.log
    LogLevel        warn
    CustomLog       \${ADT_DATA}/var/log/apache2/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org-access.log combined  

    # Error pages    
    ErrorDocument 404 /404.html
    ErrorDocument 500 /500.html
    ErrorDocument 502 /502.html
    ErrorDocument 503 /503.html

    # don't loose time with IP address lookups
    HostnameLookups Off

    # needed for named virtual hosts
    UseCanonicalName Off

    # configures the footer on server-generated documents
    ServerSignature Off

    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>

    DocumentRoot ${ADT_HOME}/var/www/
    <Directory ${ADT_HOME}/var/www/>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride None
        Order allow,deny
        allow from all
    </Directory>

    Alias /icons/ "/usr/share/apache2/icons/"
    <Directory "/usr/share/apache2/icons">
        Options Indexes MultiViews
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>
        
    Alias /logs/ "$DEPLOYMENT_DIR/logs/"
    <Directory "$DEPLOYMENT_DIR/logs/">
        Options Indexes MultiViews
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    ProxyRequests           Off
    ProxyPreserveHost       On
    ProxyPass               /exo-static/   !
    ProxyPass               /logs/         !
    ProxyPass               /icons/        !
    ProxyPass               /       ajp://localhost:$DEPLOYMENT_AJP_PORT/ acquire=1000 retry=30
    ProxyPassReverse        /       ajp://localhost:$DEPLOYMENT_AJP_PORT/
    
    # No security for gadgets
    <ProxyMatch "^.*/(eXoGadgetServer|rest|.*Resources)/.*\$">
        Order allow,deny
        Allow from all
        Satisfy any
    </ProxyMatch>
    
    # Everything else is secured
    <Proxy *>
        Order deny,allow
        Allow from all

        AuthName "eXo Employees only"
        AuthType Basic
        AuthBasicProvider crowd

        CrowdAppName \${CROWD_ACCEPTANCE_APP_NAME}
        CrowdAppPassword \${CROWD_ACCEPTANCE_APP_PASSWORD}
        CrowdURL https://identity.exoplatform.org/

        # Activate SSO 
        CrowdAcceptSSO On
        CrowdCreateSSO On

        # Only exo-employees can access
        Require group exo-employees
    </Proxy>    
</VirtualHost>
EOF
DEPLOYMENT_URL=http://$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
DEPLOYMENT_LOG_URL=http://$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org/logs/catalina.out
}

do_log_rotate()
{
  cat << EOF > $TMP_DIR/logrotate-$PRODUCT_NAME-$PRODUCT_VERSION
${ADT_DATA}/var/log/apache2/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org-*.log {
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 www-data www-data
    sharedscripts
    postrotate
            sudo /usr/sbin/service apache2 reload > /dev/null
    endscript
}
EOF  
  if $LINUX; then
    logrotate -f $TMP_DIR/logrotate-$PRODUCT_NAME-$PRODUCT_VERSION
  fi
  rm $TMP_DIR/logrotate-$PRODUCT_NAME-$PRODUCT_VERSION  
}

do_create_deployment_descriptor()
{
  mkdir -p $ADT_CONF_DIR
  cat << EOF > $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
PRODUCT_NAME=$PRODUCT_NAME
PRODUCT_VERSION=$PRODUCT_VERSION
PRODUCT_BRANCH=$PRODUCT_BRANCH
DEPLOYMENT_DATE=$CURR_DATE
DEPLOYMENT_DIR=$DEPLOYMENT_DIR
DEPLOYMENT_URL=$DEPLOYMENT_URL
DEPLOYMENT_LOG_URL=$DEPLOYMENT_LOG_URL
DEPLOYMENT_LOG_PATH=$DEPLOYMENT_LOG_PATH
DEPLOYMENT_JMX_URL=$DEPLOYMENT_JMX_URL
DEPLOYMENT_SHUTDOWN_PORT=$DEPLOYMENT_SHUTDOWN_PORT
DEPLOYMENT_HTTP_PORT=$DEPLOYMENT_HTTP_PORT
DEPLOYMENT_AJP_PORT=$DEPLOYMENT_AJP_PORT
DEPLOYMENT_PID_FILE=$DEPLOYMENT_PID_FILE
DEPLOYMENT_RMI_REG_PORT=$DEPLOYMENT_RMI_REG_PORT
DEPLOYMENT_RMI_SRV_PORT=$DEPLOYMENT_RMI_SRV_PORT
DEPLOYMENT_DATABASE_NAME=$DEPLOYMENT_DATABASE_NAME
ARTIFACT_GROUPID=$ARTIFACT_GROUPID
ARTIFACT_ARTIFACTID=$ARTIFACT_ARTIFACTID
ARTIFACT_TIMESTAMP=$ARTIFACT_TIMESTAMP
ARTIFACT_DATE=$ARTIFACT_DATE
ARTIFACT_CLASSIFIER=$ARTIFACT_CLASSIFIER
ARTIFACT_PACKAGING=$ARTIFACT_PACKAGING
ARTIFACT_REPO_GROUP=$ARTIFACT_REPO_GROUP
ARTIFACT_REPO_URL=$ARTIFACT_REPO_URL
ARTIFACT_DL_URL=$ARTIFACT_DL_URL
EOF
  #Display the deployment descriptor
  echo "[INFO] ========================= Deployment Descriptor ========================="
  cat $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  echo "[INFO] ========================================================================="
}

do_load_deployment_descriptor()
{
  if [ ! -e $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org ]; then
    echo "[WARNING] $PRODUCT_NAME $PRODUCT_VERSION isn't deployed !"
    echo "[WARNING] You need to deploy it first."
  else
    source $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  fi
}

#
# Function that deploys (Download+configure) the app server
#
do_deploy()
{
  echo "[INFO] Deploying server $PRODUCT_NAME $PRODUCT_VERSION ..."
  do_download_server
  do_create_database
  do_unpack_server
  do_patch_server
  do_create_apache_vhost
  do_log_rotate
  do_create_deployment_descriptor
  echo "[INFO] Server deployed"
}

#
# Function that starts the app server
#
do_start()
{
  echo "[INFO] Starting server $PRODUCT_NAME $PRODUCT_VERSION ..."
  chmod 755 $DEPLOYMENT_DIR/bin/*.sh
  export CATALINA_HOME=$DEPLOYMENT_DIR
  export CATALINA_PID=$DEPLOYMENT_PID_FILE
  export JAVA_JRMP_OPTS="-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=true -Dcom.sun.management.jmxremote.password.file=$DEPLOYMENT_DIR/conf/jmxremote.password -Dcom.sun.management.jmxremote.access.file=$DEPLOYMENT_DIR/conf/jmxremote.access"
  export JAVA_OPTS="$JAVA_OPTS $JAVA_JRMP_OPTS"
  ${CATALINA_HOME}${SERVER_SCRIPT} start
  # Wait for logs availability
  while [ true ];
  do    
    if [ -e $DEPLOYMENT_DIR/logs/catalina.out ]; then
      break
    fi    
  done
  # Display logs
  tail -f $DEPLOYMENT_DIR/logs/catalina.out &
  local tailPID=$!
  # Check for the end of startup
  set +e
  while [ true ];
  do    
    if grep -q "Server startup in" $DEPLOYMENT_DIR/logs/catalina.out; then
      kill $tailPID
      wait $tailPID 2>/dev/null
      break
    fi    
  done
  set -e
  echo "[INFO] Server started"
  echo "[INFO] URL  : $DEPLOYMENT_URL"
  echo "[INFO] Logs : $DEPLOYMENT_LOG_URL"
  echo "[INFO] JMX  : $DEPLOYMENT_JMX_URL"
}

#
# Function that stops the app server
#
do_stop()
{
  if [ ! -z $DEPLOYMENT_DIR ] && [ -e $DEPLOYMENT_DIR ]; then
    echo "[INFO] Stopping server $PRODUCT_NAME $PRODUCT_VERSION ..."
    export CATALINA_HOME=$DEPLOYMENT_DIR
    export CATALINA_PID=$DEPLOYMENT_PID_FILE
    ${CATALINA_HOME}${SERVER_SCRIPT} stop 60 -force || true
    echo "[INFO] Server stopped"
  else
    echo "[WARNING] No server directory to stop it"
  fi
}

#
# Function that undeploys (delete) the app server
#
do_undeploy()
{
  # Stop the server
  do_stop
  do_drop_database
  echo "[INFO] Undeploying server $PRODUCT_NAME $PRODUCT_VERSION ..."
  # Delete the vhost
  rm $APACHE_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  # Reload Apache to deactivate the config  
  if $LINUX; then
    sudo /usr/sbin/service apache2 reload
  fi
  # Delete the deployment descriptor
  rm $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  # Delete the server
  rm -rf $DEPLOYMENT_DIR
  # Close firewall ports
  if $LINUX; then
    sudo /usr/sbin/ufw deny ${DEPLOYMENT_RMI_REG_PORT}
    sudo /usr/sbin/ufw deny ${DEPLOYMENT_RMI_SRV_PORT}    
  fi  
  echo "[INFO] Server undeployed"
}

#
# Function that lists all deployed servers
#
do_list()
{
  if [ "$(ls -A $ADT_CONF_DIR)" ]; then
    echo "[INFO] Deployed servers : "
    printf "%-10s %-20s\n" "Product" "Version"
    printf "%-10s %-20s\n" "=======" "======="  
    for f in $ADT_CONF_DIR/*
    do
      source $f
      printf "%-10s %-20s %-5s\n" $PRODUCT_NAME $PRODUCT_VERSION
    done  
  else
    echo "[INFO] No server deployed."
  fi  
}

#
# Function that starts all deployed servers
#
do_start_all()
{
  if [ "$(ls -A $ADT_CONF_DIR)" ]; then
    echo "[INFO] Starting all servers ..."
    for f in $ADT_CONF_DIR/*
    do
      source $f
      do_start
    done
    echo "[INFO] All servers started"  
  else
    echo "[INFO] No server deployed."
  fi  
}

#
# Function that restarts all deployed servers
#
do_restart_all()
{
  if [ "$(ls -A $ADT_CONF_DIR)" ]; then
    echo "[INFO] Restarting all servers ..."
    for f in $ADT_CONF_DIR/*
    do
      source $f
      do_stop
      do_start
    done
    echo "[INFO] All servers restarted"  
  else
    echo "[INFO] No server deployed."
  fi  
}

#
# Function that stops all deployed servers
#
do_stops_all()
{
  if [ "$(ls -A $ADT_CONF_DIR)" ]; then
    echo "[INFO] Stopping all servers ..."
    for f in $ADT_CONF_DIR/*
    do
      source $f
      do_stop
    done
    echo "[INFO] All servers stopped"  
  else
    echo "[INFO] No server deployed."
  fi  
}

#
# Function that undeploys all deployed servers
#
do_undeploy_all()
{
  if [ "$(ls -A $ADT_CONF_DIR)" ]; then
    echo "[INFO] Undeploying all servers ..."
    for f in $ADT_CONF_DIR/*
    do
      source $f
      do_undeploy
    done
    echo "[INFO] All servers undeployed"  
  else
    echo "[INFO] No server deployed."
  fi  
}

initialize

do_process_cl_params "$@"

case "$ACTION" in
  deploy)
    do_deploy
    ;;
  start)
    do_load_deployment_descriptor
    do_start
    ;;
  stop) 
    do_load_deployment_descriptor
    do_stop
    ;;
  restart)
    do_load_deployment_descriptor
    do_stop
    do_start
    ;;
  undeploy) 
    do_load_deployment_descriptor
    do_undeploy
    ;;
  list) 
    do_list
    ;;
  start-all) 
    do_start_all
    ;;
  stop-all) 
    do_stop_all
    ;;
  restart-all) 
    do_restart_all
    ;;
  undeploy-all) 
    do_undeploy_all
    ;;
  *)
    echo "[ERROR] Invalid action \"$ACTION\"" 
    print_usage
    exit 1
    ;;
esac

exit 0
