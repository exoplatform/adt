#!/bin/bash -eu                                                                                                                                                                                                                         -e

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
  DEPLOYMENT_JMX_URL=""
  DEPLOYMENT_SHUTDOWN_PORT=8005
  DEPLOYMENT_HTTP_PORT=8080
  DEPLOYMENT_AJP_PORT=8009
  DEPLOYMENT_RMI_REG_PORT=10001
  DEPLOYMENT_RMI_SRV_PORT=10002
  DEPLOYMENT_PID_FILE=""
  
  ARTIFACT_GROUPID=""
  ARTIFACT_ARTIFACTID=""
  ARTIFACT_TIMESTAMP=""
  ARTIFACT_DATE=""
  ARTIFACT_CLASSIFIER=""
  ARTIFACT_PACKAGING=""
  ARTIFACT_URL=""
  
  CREDENTIALS=""

  CURR_DATE=`date "+%Y%m%d.%H%M%S"`
  
  SERVER_SCRIPT="/bin/gatein.sh"

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
  gatein     eXo GateIn
  webos      eXo WebOS
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
  -R         RMI Registry Port for JMX
  -V         RMI Server Port for JMX
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
          webos)
            ARTIFACT_GROUPID="org.exoplatform.webos"
            ARTIFACT_ARTIFACTID="exo.webos.packaging.assembly"
            ARTIFACT_CLASSIFIER="tomcat"
            ARTIFACT_PACKAGING="zip"
            SERVER_SCRIPT="/bin/eXo.sh"
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
        # $PRODUCT_BRANCH is computed from $PRODUCT_VERSION and is equal to the version up to the latest dot
        # and with x added. ex : 3.5.0-M4-SNAPSHOT => 3.5.x, 1.1.6-SNAPSHOT => 1.1.x
        PRODUCT_BRANCH=`expr "$PRODUCT_VERSION" : '\(.*\)\..*'`".x"
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
    while getopts "hA:H:S:R:V:u:" OPTION
    do
         case $OPTION in
             h)
                 print_usage
                 exit
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
             u)
                 if [[ "$ACTION" == "deploy" ]]; then
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
    local repository=staging
    local credentials="--location-trusted -u $CREDENTIALS"
  fi;
  if [ -z $CREDENTIALS ]; then
    local repository=public
    local credentials="--location-trusted"
  fi;
  # By default the timestamp is the version (for a release)
  ARTIFACT_TIMESTAMP=$PRODUCT_VERSION
  # base url where to download from
  local url="http://repository.exoplatform.org/$repository/${ARTIFACT_GROUPID//.//}/$ARTIFACT_ARTIFACTID/$PRODUCT_VERSION"

  # For a SNAPSHOT we will ne to manually compute the TIMESTAMP of the SNAPSHOT
  if [[ "$PRODUCT_VERSION" =~ .*-SNAPSHOT ]]    
  then
    echo "[INFO] Downloading metadata $url/maven-metadata.xml ..."
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
  echo "[INFO] Server unpacked"
}

#
# Function that configure the server for ours needs
#
do_patch_server()
{
  # Install jmx jar
  JMX_JAR_URL="http://archive.apache.org/dist/tomcat/tomcat-6/v6.0.32/bin/extras/catalina-jmx-remote.jar"
  echo "[INFO] Downloading and installing JMX remote lib ..."
  curl ${JMX_JAR_URL} > ${DEPLOYMENT_DIR}/lib/catalina-jmx-remote.jar
  if [ ! -e ${DEPLOYMENT_DIR}/lib/catalina-jmx-remote.jar ]; then
    echo "[ERROR] !!! Sorry, cannot download ${JMX_JAR_URL}"
    exit 1
  fi
  echo "[INFO] Done."

  # Reconfigure server.xml
  # First we need to find which patch to apply
  # We'll try to find it in the directory $ETC_DIR/tomcat6/ and we'll select it in this order :
  # $PRODUCT_NAME-$PRODUCT_VERSION-server.xml.patch
  # $PRODUCT_NAME-$PRODUCT_BRANCH-server.xml.patch
  # server.xml.patch
  #
  
  local patch="$ETC_DIR/tomcat6/server.xml.patch"
  [ -e $ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_VERSION-server.xml.patch ] && patch="$ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_VERSION-server.xml.patch"
  [ -e $ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_BRANCH-server.xml.patch ] && patch="$ETC_DIR/tomcat6/$PRODUCT_NAME-$PRODUCT_BRANCH-server.xml.patch"
  echo "[INFO] Applying on server.xml the patch $patch ..."
  # Prepare the patch
  cp $patch $DEPLOYMENT_DIR/conf/server.xml.patch
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml.patch "@SHUTDOWN_PORT@" "${DEPLOYMENT_SHUTDOWN_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml.patch "@HTTP_PORT@" "${DEPLOYMENT_HTTP_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml.patch "@AJP_PORT@" "${DEPLOYMENT_AJP_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml.patch "@JMX_RMI_REGISTRY_PORT@" "${DEPLOYMENT_RMI_REG_PORT}"
  replace_in_file $DEPLOYMENT_DIR/conf/server.xml.patch "@JMX_RMI_SERVER_PORT@" "${DEPLOYMENT_RMI_SRV_PORT}"
  # Ensure the server.xml doesn't have some windows end line characters
  # '\015' is Ctrl+V Ctrl+M = ^M
  cp $DEPLOYMENT_DIR/conf/server.xml $DEPLOYMENT_DIR/conf/server.xml.orig
  tr -d '\015' < $DEPLOYMENT_DIR/conf/server.xml.orig > $DEPLOYMENT_DIR/conf/server.xml  
  patch -l -p0 $DEPLOYMENT_DIR/conf/server.xml < $DEPLOYMENT_DIR/conf/server.xml.patch  
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
    # Compression using GZIP
    #
    # Insert filter
    SetOutputFilter DEFLATE
    SetInputFilter DEFLATE
    DeflateFilterNote Input instream
    DeflateFilterNote Output outstream
    DeflateFilterNote Ratio ratio
    # Higher Compression 9 - Medium 5
    DeflateCompressionLevel 5

    # Netscape 4.x has some problems...
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    # Netscape 4.06-4.08 have some more problems
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    # MSIE masquerades as Netscape, but it is fine
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html
    
    # Don't compress images
    SetEnvIfNoCase Request_URI "\.(?:gif|jpe?g|png)\$" no-gzip dont-vary
    # Make sure proxies don't deliver the wrong content
    Header append Vary User-Agent env=!dont-vary
    
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
PRODUCT_BRANCH=$PRODUCT_BRANCH
DEPLOYMENT_DATE=$CURR_DATE
DEPLOYMENT_DIR=$DEPLOYMENT_DIR
DEPLOYMENT_URL=$DEPLOYMENT_URL
DEPLOYMENT_LOG_URL=$DEPLOYMENT_LOG_URL
DEPLOYMENT_JMX_URL=$DEPLOYMENT_JMX_URL
DEPLOYMENT_SHUTDOWN_PORT=$DEPLOYMENT_SHUTDOWN_PORT
DEPLOYMENT_HTTP_PORT=$DEPLOYMENT_HTTP_PORT
DEPLOYMENT_AJP_PORT=$DEPLOYMENT_AJP_PORT
DEPLOYMENT_PID_FILE=$DEPLOYMENT_PID_FILE
DEPLOYMENT_RMI_REG_PORT=$DEPLOYMENT_RMI_REG_PORT
DEPLOYMENT_RMI_SRV_PORT=$DEPLOYMENT_RMI_SRV_PORT
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
    echo "[INFO] Stopping server ..."
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
