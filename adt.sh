#!/bin/bash -eu                                                                                                                                                                                                                         -e

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="${0%/*}"

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
    exit 1;
  fi

  # Convert to an absolute path
  pushd $ADT_DATA > /dev/null
  ADT_DATA=`pwd -P`
  popd > /dev/null

  echo "[INFO] ADT_DATA = $ADT_DATA"

  # Create ADT_DATA if required
  mkdir -p $ADT_DATA

  TMP_DIR=$ADT_DATA/tmp
  DL_DIR=$ADT_DATA/downloads
  SRV_DIR=$ADT_DATA/servers
  CONF_DIR=$ADT_DATA/conf
  APACHE_CONF_DIR=$ADT_DATA/conf/apache
  ADT_CONF_DIR=$ADT_DATA/conf/adt

  DEPLOYMENT_SHUTDOWN_PORT=8005
  DEPLOYMENT_HTTP_PORT=8080
  DEPLOYMENT_AJP_PORT=8009
  
  CREDENTIALS=""

  CURR_DATE=`date "+%Y%m%d.%H%M%S"`

  # OS specific support.  $var _must_ be set to either true or false.
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
  deploy     Deploys (Download+Configure) the server
  start      Starts the server
  stop       Stops the server
  restart    Restarts the server
  undeploy   Undeploys (Delete) the server
  list       Lists all deployed servers
  
PRODUCT (for deploy, start, stop, restart, undeploy actions) :
  social     eXo Social
  ecms       eXo Content
  ks         eXo Knowledge
  cs         eXo Collaboration
  platform   eXo Platform

VERSION (for deploy, start, stop, restart, undeploy actions) :
  version of the product

GLOBAL OPTIONS :
  -h         Show this message  

DEPLOY OPTIONS :
  -A         AJP Port
  -H         HTTP Port
  -S         SHUTDOWN Port 
  -u         user credentials (value in "username:password" format) to download the server package (default: none)

EOF
}

#
# Decode command line parameters
#
do_init()
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
            ;;
          ecms)
            ARTIFACT_GROUPID="org.exoplatform.ecms"
            ARTIFACT_ARTIFACTID="exo-ecms-delivery-wcm-assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            ;;
          social)
            ARTIFACT_GROUPID="org.exoplatform.social"
            ARTIFACT_ARTIFACTID="exo.social.packaging.pkg"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            ;;
          ks)
            ARTIFACT_GROUPID="org.exoplatform.ks"
            ARTIFACT_ARTIFACTID="exo.ks.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            ;;
          cs)
            ARTIFACT_GROUPID="org.exoplatform.cs"
            ARTIFACT_ARTIFACTID="exo.cs.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            ;;
          plf)
            ARTIFACT_GROUPID="org.exoplatform.platform"
            ARTIFACT_ARTIFACTID="exo.platform.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
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
    while getopts "hA:H:S:u:" OPTION
    do
         case $OPTION in
             h)
                 print_usage
                 exit
                 ;;
             H)
                 if ["$ACTION" == "deploy"]; then
                   DEPLOYMENT_HTTP_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             A)
                 if ["$ACTION" == "deploy"]; then
                   DEPLOYMENT_AJP_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             S)
                 if ["$ACTION" == "deploy"]; then
                   DEPLOYMENT_SHUTDOWN_PORT=$OPTARG
                 else
                   echo "[WARNING] Useless option \"$OPTION\" for action \"$ACTION\"" 
                   print_usage
                   exit 1                 
                 fi
                 ;;
             u)
                 if ["$ACTION" == "deploy"]; then
                   CREDENTIALS=$OPTARG
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
  # Credentials and repository options
  if [ -n $CREDENTIALS ]; then
    local repository=private
    local credentials="--user $CREDENTIALS --location-trusted"
  fi;
  if [ -z $CREDENTIALS ]; then
    local repository=public
    local credentials="--location"
  fi;
  # By default the timestamp is the version (for a release)
  ARTIFACT_TIMESTAMP=$PRODUCT_VERSION
  # base url where to download from
  local url="http://repository.exoplatform.org/$repository/${ARTIFACT_GROUPID//.//}/$ARTIFACT_ARTIFACTID/$PRODUCT_VERSION"

  # For a SNAPSHOT we will ne to manually compute the TIMESTAMP of the SNAPSHOT
  if [[ "$PRODUCT_VERSION" =~ .*-SNAPSHOT ]]
  then
    echo "[INFO] Downloading metadata ..."
    curl $credentials "$url/maven-metadata.xml" > $DL_DIR/$PRODUCT_NAME-$PRODUCT_VERSION-maven-metadata.xml
    if [ "$?" -ne "0" ]; then
      echo "Sorry, cannot download artifact metadata"
      exit 1
    fi
    echo "[INFO] Metadata downloaded"
    local QUERY="/metadata/versioning/snapshotVersions/snapshotVersion[(classifier=\"$ARTIFACT_CLASSIFIER\")and(extension=\"$ARTIFACT_PACKAGING\")]/value/text()"
    local FILENAME=$DL_DIR/$PRODUCT_NAME-$PRODUCT_VERSION-maven-metadata.xml
    if $DARWIN; then
      ARTIFACT_TIMESTAMP=`xpath $FILENAME $QUERY`
    fi 
    if $LINUX; then
      ARTIFACT_TIMESTAMP=`xpath -q -e $QUERY $FILENAME`
    fi
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
  ARTIFACT_URL=$url/$filename
  if [ -e $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING ]; then
    echo "[WARNING] $name was already downloaded. Skip server download !"
  else
    echo "[INFO] Downloading server ..."
    echo "[INFO] Archive          : $name "
    echo "[INFO] Repository       : $repository "
    echo "[INFO] Url              : $ARTIFACT_URL "
    curl $credentials "$ARTIFACT_URL" > $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
    if [ "$?" -ne "0" ]; then
      echo "Sorry, cannot download $name"
      exit 1
    fi
    echo "[INFO] Server downloaded"
  fi
}

#
# Function that unpacks the app server archive
#
do_unpack_server() 
{
  rm -rf $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
  echo "[INFO] Unpacking server ..."
  mkdir -p $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
  case $ARTIFACT_PACKAGING in
    zip)
      unzip $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING -d $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
      ;;
    tar.gz)
      cd $TMP_DIR/$PRODUCT_NAME-$PRODUCT_VERSION
      tar -xzvf $DL_DIR/$PRODUCT_NAME-$ARTIFACT_TIMESTAMP.$ARTIFACT_PACKAGING
      cd -
      ;;
    *)
      echo "[ERROR] Invalid packaging \"$ARTIFACT_PACKAGING\""
      print_usage
      exit 1
      ;;
  esac
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
  echo "[INFO] Server unpacked"
}

#
# Function that configure the server for ours needs
#
do_patch_server()
{
  sed -i -e "s|8005|${DEPLOYMENT_SHUTDOWN_PORT}|g" $DEPLOYMENT_DIR/conf/server.xml
  sed -i -e "s|8080|${DEPLOYMENT_HTTP_PORT}|g" $DEPLOYMENT_DIR/conf/server.xml
  sed -i -e "s|8009|${DEPLOYMENT_AJP_PORT}|g" $DEPLOYMENT_DIR/conf/server.xml
}

do_create_apache_vhost()
{
mkdir -p $APACHE_CONF_DIR
cat << EOF > $APACHE_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
<VirtualHost *:80>
    Include /home/swfcommons/etc/apache2/includes/default.conf
    ServerName  $PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org

    ErrorLog        \${APACHE_LOG_DIR}/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org-error.log
    LogLevel        warn
    CustomLog       \${APACHE_LOG_DIR}/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org-access.log combined  
    
    Alias /logs/ "$DEPLOYMENT_DIR/logs/"
    <Directory "$DEPLOYMENT_DIR/logs/">
        Options Indexes MultiViews
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>
    
    #
    # Compression via GZIP
    #
    SetOutputFilter DEFLATE
    SetInputFilter DEFLATE
    DeflateFilterNote Input instream
    DeflateFilterNote Output outstream
    DeflateFilterNote Ratio ratio
    # Higher Compression 9 - Medium 5
    DeflateCompressionLevel 5

    ProxyRequests           Off
    ProxyPreserveHost       On
    ProxyPass               /exo-static/   !
    ProxyPass               /logs/         !
    ProxyPass               /icons/        !
    ProxyPass               /       ajp://localhost:$DEPLOYMENT_AJP_PORT/ acquire=1000 retry=30
    ProxyPassReverse        /       ajp://localhost:$DEPLOYMENT_AJP_PORT/
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
# Reload Apache to activate the new config
if $LINUX; then
  sudo /usr/sbin/service apache2 reload
fi
DEPLOYMENT_URL=http://$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
DEPLOYMENT_LOG_URL=http://$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org/logs/catalina.out
}

do_create_deployment_descriptor()
{
  mkdir -p $ADT_CONF_DIR
  cat << EOF > $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
PRODUCT_NAME=$PRODUCT_NAME
PRODUCT_VERSION=$PRODUCT_VERSION
DEPLOYMENT_DATE=$CURR_DATE
DEPLOYMENT_DIR=$DEPLOYMENT_DIR
DEPLOYMENT_URL=$DEPLOYMENT_URL
DEPLOYMENT_LOG_URL=$DEPLOYMENT_LOG_URL
DEPLOYMENT_SHUTDOWN_PORT=$DEPLOYMENT_SHUTDOWN_PORT
DEPLOYMENT_HTTP_PORT=$DEPLOYMENT_HTTP_PORT
DEPLOYMENT_AJP_PORT=$DEPLOYMENT_AJP_PORT
DEPLOYMENT_PID_FILE=$DEPLOYMENT_PID_FILE
ARTIFACT_GROUPID=$ARTIFACT_GROUPID
ARTIFACT_ARTIFACTID=$ARTIFACT_ARTIFACTID
ARTIFACT_TIMESTAMP=$ARTIFACT_TIMESTAMP
ARTIFACT_DATE=$ARTIFACT_DATE
ARTIFACT_CLASSIFIER=$ARTIFACT_CLASSIFIER
ARTIFACT_PACKAGING=$ARTIFACT_PACKAGING
ARTIFACT_URL=$ARTIFACT_URL
EOF
  #Display the deployment descriptor
  echo "[INFO] ========================= Deployment Descriptor ========================="
  cat $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  echo "[INFO] ========================================================================="
}

do_load_deployment_descriptor()
{
  if [ ! -e $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org ]; then
    echo "[ERROR] $PRODUCT_NAME $PRODUCT_VERSION isn't deployed !"
    echo "[ERROR] You need to deploy it first."
    exit 1    
  fi
  source $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  #Display the deployment descriptor
  echo "[INFO] ========================= Deployment Descriptor ========================="
  cat $ADT_CONF_DIR/$PRODUCT_NAME-$PRODUCT_VERSION.acceptance.exoplatform.org
  echo "[INFO] ========================================================================="  
}

#
# Function that deploys (Download+configure) the app server
#
do_deploy()
{
  echo "[INFO] Deploying server ..."
  do_download_server
  do_unpack_server
  do_patch_server
  do_create_apache_vhost
  do_create_deployment_descriptor
  echo "[INFO] Server deployed"
}

#
# Function that starts the app server
#
do_start()
{
  echo "[INFO] Starting server ..."
  chmod 755 $DEPLOYMENT_DIR/bin/*.sh
  export CATALINA_HOME=$DEPLOYMENT_DIR
  export CATALINA_PID=$DEPLOYMENT_PID_FILE
  ${CATALINA_HOME}/bin/gatein.sh start
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
    if [ -e $DEPLOYMENT_DIR/logs/catalina.out ]; then
      if grep -q "Server startup in" $DEPLOYMENT_DIR/logs/catalina.out; then
        kill $tailPID
        wait $tailPID 2>/dev/null
        break
      fi    
    fi    
  done
  set -e
  echo "[INFO] Server started"
  echo "[INFO] URL  : $DEPLOYMENT_URL"
  echo "[INFO] Logs : $DEPLOYMENT_LOG_URL"
}

#
# Function that stops the app server
#
do_stop()
{
  if [ -e $DEPLOYMENT_DIR ]; then
    echo "[INFO] Stopping server ..."
    export CATALINA_HOME=$DEPLOYMENT_DIR
    export CATALINA_PID=$DEPLOYMENT_PID_FILE
    ${CATALINA_HOME}/bin/gatein.sh stop 60 -force || true
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
  echo "[INFO] Undeploying server ..."
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
  echo "[INFO] Server undeployed"
}

#
# Function that lists all deployed servers
#
do_list()
{
  echo "[INFO] Deployed servers : "
  printf "%-10s %-20s\n" "Product" "Version"
  printf "%-10s %-20s\n" "=======" "======="  
  for f in $ADT_CONF_DIR/*
  do
    source $f
    printf "%-10s %-20s %-5s\n" $PRODUCT_NAME $PRODUCT_VERSION
  done  
}

initialize

do_init $@

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
  *)
    echo "[ERROR] Invalid action \"$ACTION\"" 
    print_usage
    exit 1
    ;;
esac

exit 0
