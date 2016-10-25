#!/bin/bash -eu

# #############################################################################
# Initialize
# #############################################################################                                              
SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "# ############################################################################## #"
echo "#                     Acceptance Development Mode                                #"
echo "# ############################################################################## #"

#
# Usage message
#
print_usage_dev() {
  cat << EOF

  usage: $0 <action> [ -n PRODUCT_NAME -v PRODUCT_VERSION [ -a ADDONS ] -d DATABASE_TYPE:VERSION -p PORT_PREFIX [ -c ] [ -i INSTANCE_ID ] ]

This script manages automated deployment of eXo products for testing purpose.

Action
------
  deploy           Deploys (Download+Configure) the server
  download-dataset Downloads the dataset required by the server
  start            Starts the server
  stop             Stops the server
  restart          Restarts the server
  undeploy         Undeploys (deletes) the server

  start-all        Starts all deployed servers
  stop-all         Stops all deployed servers
  restart-all      Restarts all deployed servers
  undeploy-all     Undeploys (deletes) all deployed servers
  list             Lists all deployed servers

  init             Initializes the environment
  update-repos     Update Git repositories used by the web front-end
  web-server       Starts a local PHP web server to test the front-end (requires PHP >= 5.4). It automatically activates the development mode.

  Instance Settings
  =================

  -n PRODUCT_NAME           : The product you want to manage. Possible values are :
    gatein         GateIn Community edition                - Apache Tomcat bundle
    exogtn         GateIn eXo edition                      - Apache Tomcat bundle
    plf            eXo Platform Standard Edition           - Apache Tomcat bundle
    plfcom         eXo Platform Community Edition          - Apache Tomcat bundle
    plfent         eXo Platform Express/Enterprise Edition - Apache Tomcat bundle
    plfenteap      eXo Platform Express/Enterprise Edition - JBoss EAP bundle
    plfsales       eXo Platform Enterprise Edition         - Apache Tomcat bundle for Sales
    plftrial       eXo Platform Trial Edition              - Apache Tomcat bundle
    plfdemo        eXo Platform Demo Edition               - Apache Tomcat bundle
    addonchat      eXo Platform + eXo Addon Chat           - Apache Tomcat bundle
    compint        eXo Company Intranet                    - Apache Tomcat bundle
    community      eXo Community Website                   - Apache Tomcat bundle
    docs           eXo Platform Documentations Website     - Apache Tomcat bundle

  -v PRODUCT_VERSION        : The version of the product. Can be either a release, a snapshot (the latest one) or a timestamped snapshot

  -p PORT_PREFIX            : The prefix for all the ports used. Must be unique for all deployments on a server (ex: 400)

  -a ADDONS                 : The comma separated list of add-ons to deploy (ex: exo-site-templates:1.0.0,exo-sdp-demo:1.0.x-SNAPSHOT)

  -d DATABASE_TYPE:VERSION  : The database type + his version separated with a : char. Possible values are :
    HSQLDB
    DOCKER_MYSQL:5.7 / DOCKER_MYSQL:5.6 / DOCKER_MYSQL:5.5
    DOCKER_POSTGRES:9.6 / DOCKER_POSTGRES:9.5 / DOCKER_POSTGRES:9.4
    DOCKER_ORACLE:12cR1_plf (pre initialized database)
    DOCKER_SQLSERVER:2014express

  -c                        : Configure mongodb for the Chat

  -i INSTANCE_ID            : Add an ID to the instance to be able to deploy several time the same version
EOF

}
#print_header_dev
# if no parameters : print help
if [ $# == 0 ]; then print_usage_dev; exit 1; fi

ACTION=$1
shift

# if 1st parameter start with "-" character : print help
if [ "${ACTION:0:1}" = "-" ]; then echo "The first parameter must be an ACTION"; print_usage_dev; exit 1; fi

while getopts "n:v:a:d:p:ci:h" OPTION; do
  case $OPTION in
    n) export PRODUCT_NAME=$OPTARG;       echo "## NAME    = $OPTARG";;
    v) export PRODUCT_VERSION=$OPTARG;    echo "## VERSION = $OPTARG";;
    a) export DEPLOYMENT_ADDONS=$OPTARG;  echo "## ADDONS  = $OPTARG";;
    d) export DEPLOYMENT_DATABASE_TYPE=$(echo "${OPTARG}" | sed 's/\([a-zA-Z0-9_\-]*\):[0-9\.]*/\1/'); echo "## DATABASE TYPE  = ${DEPLOYMENT_DATABASE_TYPE}"
       export DEPLOYMENT_DATABASE_VERSION=$(echo "${OPTARG}" | sed 's/[a-zA-Z0-9_\-]*:\([0-9\.]*\)/\1/'); echo "## DATABASE VERSION  = ${DEPLOYMENT_DATABASE_VERSION}" ;;
    p) export DEPLOYMENT_PORT_PREFIX=$OPTARG;  echo "## PORT PREFIX  = $OPTARG";;
    c) export DEPLOYMENT_CHAT_ENABLED=true; export DEPLOYMENT_CHAT_WEEMO_KEY=xxx ;;
    i) export INSTANCE_ID=$OPTARG;  echo "## INSTANCE ID  = $OPTARG";;
    h) print_usage_dev; exit 1;;
    *) echo "Wrong parameter !!"; print_usage_dev; exit 1;;
  esac
done

${SCRIPT_DIR}/adt.sh $ACTION

exit 0
