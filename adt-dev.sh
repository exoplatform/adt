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

This script manages automated deployment of eXo Platform and Meeds (7.0 and later) for testing purpose.
Every instance is a docker compose project: application, database, search and nginx containers on their own network.

Action
------
  deploy           Deploys (pulls the images and configures) the server
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
  build-web        Builds the adt-web front-end binary
  deploy-web       Builds adt-web and restarts its service
  web-server       Builds and starts adt-web in the foreground to test the front-end. It automatically activates the development mode.

  Instance Settings
  =================

  -n PRODUCT_NAME           : The product you want to manage. Possible values are :
    meeds          Meeds.io                                - image meedsio/meeds
    plfcom         eXo Platform Community Edition          - image exoplatform/exo-community
    plfent         eXo Platform Enterprise Edition         - image exoplatform/exo-enterprise
  Only versions 7.0 and later are supported.

  -v PRODUCT_VERSION        : The version of the product, also the tag of the image. Can be a release (X.Y.Z), a snapshot (X.Y.x-SNAPSHOT), or a build chosen in the registry using -MLT (latest) / -MBL (before latest) / -GA (latest GA release only, no milestone/RC/CP/build suffix) with optional Z wildcard for the patch version (e.g. 7.2.0-MLT, 7.2.Z-MLT or 7.2.Z-GA)

  -p PORT_PREFIX            : The prefix of the port of the instance: its nginx is published on 127.0.0.1:<prefix>01. Must be unique for all deployments on a server (ex: 200)

  -a ADDONS                 : The comma separated list of add-ons to deploy (ex: exo-agenda:1.0.0,meeds-poll:1.0.x-SNAPSHOT)

  -C ADDONS_CATALOG         : The add-on manager catalog url to use

  -d DATABASE_TYPE:VERSION  : The database type + his version separated with a : char (the version is optional except for MariaDB). Possible values are :
    HSQLDB
    MYSQL:8.4 / DOCKER_MYSQL:8.4
    POSTGRES:17 / DOCKER_POSTGRES:17
    MARIADB:11.4 / DOCKER_MARIADB:11.4

  -i INSTANCE_ID            : Add an ID to the instance to be able to deploy several time the same version

  -l LABELS                 : Comma separated list of labels for the deployment. Known values are :
    company         All the company deployement like Tribe / Blog / Website / Buy page / ...
    translation     Translation deployment
    doc             Documentation deployment
    fb              Feature Branch deployment
    maintenance     Maintenance deployment
    sales           eXo Sales deployment for each Sales Team guy
    sales-demo      Demo for lead evaluation requested by eXo Sales Team

  examples
  =================

  # List deployed servers
  ./adt-dev.sh list

  # Deploy Meeds 7.3 (latest milestone) on MySQL
  ./adt-dev.sh deploy -n meeds -v 7.3.0-MLT -p 200 -d MYSQL

  # Deploy eXo Platform Community 7.2 (latest GA release) on PostgreSQL 17
  ./adt-dev.sh deploy -n plfcom -v 7.2.Z-GA -p 201 -d POSTGRES:17

  # Undeploy it
  ./adt-dev.sh undeploy -n plfcom -v 7.2.Z-GA
EOF

}
#print_header_dev
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
