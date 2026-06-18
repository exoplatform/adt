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

  usage: $0 <action> [ -n PRODUCT_NAME -v PRODUCT_VERSION [ -a ADDONS ] -d DATABASE_TYPE:VERSION -p PORT_PREFIX [ -i INSTANCE_ID ] ]

This script manages automated deployment of eXo/Meeds products for testing purpose.
Each instance is deployed as an isolated docker compose project.

Action
------
  deploy           Deploys (pull images + render configs + compose up) the server
  download-dataset Downloads the dataset required by the server
  dump-dataset     Dumps the instance data into a dataset archive
  import-dataset   Imports a v1 dataset tarball into the instance volumes
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
  web-server       Starts a local PHP web server to test the front-end (dev mode)

  Instance Settings
  =================

  -n PRODUCT_NAME           : The product you want to manage. Possible values are :
    meeds          Meeds.io                                  - Apache Tomcat bundle (Docker image)
    plfcom         eXo Platform Community Edition            - Apache Tomcat bundle (Docker image)
    plfent         eXo Platform Express/Enterprise Edition   - Apache Tomcat bundle (Docker image)

  -v PRODUCT_VERSION        : The version of the product. Can be either a release, a snapshot (the latest one)
                              or a continuous tag (e.g. 7.2.0-SNAPSHOT, latest, develop, alpine)

  -p PORT_PREFIX            : The prefix for management ports (when DEPLOYMENT_EXPOSE_MANAGEMENT_PORTS=true)

  -a ADDONS                 : The comma separated list of add-ons to deploy (ex: meeds-wallet:1.0.0,meeds-perk-store)

  -C ADDONS_CATALOG         : The add-on manager catalog url to use

  -d DATABASE_TYPE:VERSION  : The database type + his version separated with a : char. Possible values are :
    postgres:17
    mysql:8.4

  -i INSTANCE_ID            : Add an ID to the instance to be able to deploy several time the same version

  -l LABELS                 : Comma separated list of labels for the deployment

  examples
  =================

  # List deployed servers
  ./adt-dev.sh list

  # Deploy Meeds 7.2.0-SNAPSHOT on PostgreSQL 17
  ./adt-dev.sh deploy -n meeds -v 7.2.0-SNAPSHOT -d postgres:17

  # Deploy eXo Platform Enterprise 7.2.0 on MySQL 8.4
  ./adt-dev.sh deploy -n plfent -v 7.2.0 -d mysql:8.4

  # Undeploy all servers
  ./adt-dev.sh undeploy-all
EOF

}

# if no parameters : print help
if [ $# == 0 ]; then print_usage_dev; exit 1; fi

ACTION=$1
shift

# if 1st parameter start with "-" character : print help
if [ "${ACTION:0:1}" = "-" ]; then echo "The first parameter must be an ACTION"; print_usage_dev; exit 1; fi

while getopts "n:v:a:C:d:p:i:l:h" OPTION; do
  case $OPTION in
    n) export PRODUCT_NAME=$OPTARG;       echo "## NAME    = $OPTARG";;
    v) export PRODUCT_VERSION=$OPTARG;    echo "## VERSION = $OPTARG";;
    a) export DEPLOYMENT_ADDONS=$OPTARG;  echo "## ADDONS  = $OPTARG";;
    C) export DEPLOYMENT_ADDONS_CATALOG=$OPTARG;  echo "## ADDONS CATALOG  = $OPTARG";;
    d) export DEPLOYMENT_DB_TYPE=$(echo "${OPTARG}" | cut -f1 -d':'); echo "## DATABASE TYPE  = ${DEPLOYMENT_DB_TYPE}"
       # cut -s to avoid retrieve the database type instead an empty version when there is no ':' on the string
       export DEPLOYMENT_DATABASE_VERSION=$(echo "${OPTARG}" | cut -s -f2 -d':'); echo "## DATABASE VERSION  = ${DEPLOYMENT_DATABASE_VERSION}" ;;
    p) export DEPLOYMENT_PORT_PREFIX=$OPTARG;  echo "## PORT PREFIX  = $OPTARG";;
    i) export INSTANCE_ID=$OPTARG;  echo "## INSTANCE ID  = $OPTARG";;
    l) export DEPLOYMENT_LABELS=$OPTARG;  echo "## LABELS  = $OPTARG";;
    h) print_usage_dev; exit 1;;
    *) echo "Wrong parameter !!"; print_usage_dev; exit 1;;
  esac
done

${SCRIPT_DIR}/adt.sh $ACTION

exit 0
