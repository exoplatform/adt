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

  usage: $0 <action> [ -n PRODUCT_NAME -v PRODUCT_VERSION ]

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

  PRODUCT_NAME                      : The product you want to manage. Possible values are :
    gatein         GateIn Community edition                - Apache Tomcat bundle
    exogtn         GateIn eXo edition                      - Apache Tomcat bundle
    plf            eXo Platform Standard Edition           - Apache Tomcat bundle
    plfcom         eXo Platform Community Edition          - Apache Tomcat bundle
    plfent         eXo Platform Express/Enterprise Edition - Apache Tomcat bundle
    plfenteap      eXo Platform Express/Enterprise Edition - JBoss EAP bundle
    plftrial       eXo Platform Trial Edition              - Apache Tomcat bundle
    plfdemo        eXo Platform Demo Edition               - Apache Tomcat bundle
    addonchat      eXo Platform + eXo Addon Chat           - Apache Tomcat bundle
    compint        eXo Company Intranet                    - Apache Tomcat bundle
    community      eXo Community Website                   - Apache Tomcat bundle
    docs           eXo Platform Documentations Website     - Apache Tomcat bundle

  PRODUCT_VERSION                   : The version of the product. Can be either a release, a snapshot (the latest one) or a timestamped snapshot

EOF

}
#print_header_dev
# if no parameters : print help
if [ $# == 0 ]; then print_usage_dev; exit 1; fi

ACTION=$1
shift

# if 1st parameter start with "-" character : print help
if [ "${ACTION:0:1}" = "-" ]; then echo "The first parameter must be an ACTION"; print_usage_dev; exit 1; fi

while getopts "n:v:h" OPTION; do
  case $OPTION in
    n) export PRODUCT_NAME=$OPTARG;     echo "## NAME    = $OPTARG";;
    v) export PRODUCT_VERSION=$OPTARG;  echo "## VERSION = $OPTARG";;
    h) print_usage_dev; exit 1;;
    *) echo "Wrong parameter !!"; print_usage_dev; exit 1;;
  esac
done

${SCRIPT_DIR}/adt.sh $ACTION

exit 0
