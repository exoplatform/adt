#!/bin/bash -eu

export ACCEPTANCE_HOST=localhost
export ACCEPTANCE_PORT=8080

function test-adt() {
  export PRODUCT_NAME=$1
  export PRODUCT_VERSION=$2
  export DEPLOYMENT_PORT_PREFIX=$3
  ./adt.sh deploy
  ./adt.sh start
  open -g http://localhost:8001
  sleep 30
  ./adt.sh stop
}

# PLF Community Edition - Tomcat
test-adt plfcom    4.0.0             400
test-adt plfcom    4.0.x-SNAPSHOT    401

# PLF Enterprise Edition - Tomcat
test-adt plfent    4.0.0             402
test-adt plfent    4.0.x-SNAPSHOT    403

# PLF Enterprise Edition - JBossEAP
#KO test-adt plfenteap 4.0.x-SNAPSHOT    404

# PLF Documentations - Tomcat
test-adt docs      4.0.x-SNAPSHOT    405

# PLF Standard Edition - Tomcat
test-adt plf       3.0.9             310
test-adt plf       3.0.10            310
test-adt plf       3.0.11-SNAPSHOT   311

#TBD test-adt plf       3.5.0-GA          350
test-adt plf       3.5.1             351
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
open -g http://$ACCEPTANCE_HOST:$ACCEPTANCE_PORT
fg

