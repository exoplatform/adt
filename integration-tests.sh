#!/bin/bash -e


# Load local config from $HOME/.adtrc
[ -e "$HOME/.adtrc" ] && source $HOME/.adtrc

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
# if the script was not called with an absolute path, then we need to add the
# current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

# Load shared functions
source "${SCRIPT_DIR}/_functions_core.sh"

env_var "ADT_DEV_MODE" true

function test-adt() {
  env_var "PRODUCT_NAME" $1
  env_var "PRODUCT_VERSION" $2
  env_var "DEPLOYMENT_PORT_PREFIX" $3
  echo_info "# #######################################################################"
  echo_info "#"
  echo_info "# Testing $PRODUCT_NAME $PRODUCT_VERSION"
  echo_info "#"
  echo_info "# #######################################################################"
  echo_info "#"
  echo_info "#"
  ./adt.sh deploy
  ./adt.sh start
  open -g http://localhost:${DEPLOYMENT_PORT_PREFIX}01
  sleep 30
  ./adt.sh stop
}

test-adt clouddash 1.0.0-SNAPSHOT     408

./adt.sh list
./adt.sh web-server &
open -g http://${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT}
fg

exit


if [ -z "${REPOSITORY_USERNAME+xxx}" -o -z "${REPOSITORY_PASSWORD+xxx}"  ]; then
  echo_warn "Credentials not set !!!"
  echo_warn "You cannot test private distributions"
  echo_warn "Create a file ~/.adtrc"
  echo_warn "Put it in these 2 lines :"
  echo_warn "REPOSITORY_USERNAME=xxxxx"
  echo_warn "REPOSITORY_PASSWORD=yyyyy"
  echo_warn "Where xxxxx/yyyyy are your LDAP credentials"
else
  # PLF Enterprise Edition - Tomcat
  test-adt plfent    4.0.0             402
  test-adt plfent    4.0.x-SNAPSHOT    403

  # PLF Enterprise Edition - JBossEAP
  test-adt plfenteap 4.0.x-SNAPSHOT    404
fi

# PLF Community Edition - Tomcat
test-adt plfcom    4.0.0             400
test-adt plfcom    4.0.x-SNAPSHOT    401


# PLF Documentations - Tomcat
test-adt docs      4.0.x-SNAPSHOT    405

# PLF Standard Edition - Tomcat
test-adt plf       3.0.9             310
test-adt plf       3.0.10            310
test-adt plf       3.0.11-SNAPSHOT   311

#TBD test-adt plf       3.5.0-GA          350
#KO(PermGen error) test-adt plf       3.5.1             351
test-adt plf       3.5.2             352
test-adt plf       3.5.3             353
test-adt plf       3.5.4             354
test-adt plf       3.5.5             355
test-adt plf       3.5.6             356
test-adt plf       3.5.7-SNAPSHOT    357

# Gatein - eXo Edition - Tomcat
#TBD test-adt exogtn   3.2.0-PLF          320
#TBD test-adt exogtn   3.2.1-PLF          321
#TBD test-adt exogtn   3.2.2-PLF          322
#TBD test-adt exogtn   3.2.3-PLF          323
#TBD test-adt exogtn   3.2.4-PLF          324
#TBD test-adt exogtn   3.2.5-PLF          325
#TBD test-adt exogtn   3.2.6-PLF          326
test-adt exogtn   3.2.7-PLF          327
test-adt exogtn   3.2.8-PLF-SNAPSHOT 328

./adt.sh list

./adt.sh web-server &
open -g http://${ACCEPTANCE_HOST}:${ACCEPTANCE_PORT}
fg

