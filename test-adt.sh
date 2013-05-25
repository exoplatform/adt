#!/bin/bash -eu

function test-adt() {
  export PRODUCT_NAME=$1
  export PRODUCT_VERSION=$2
  ./adt.sh deploy
  ./adt.sh start
  open -g http://localhost:8001
  sleep 30
  ./adt.sh stop
}

test-adt exogtn   3.2.4-PLF
test-adt plf      3.0.10
test-adt plf      3.5.7-SNAPSHOT
test-adt plfcom   4.0.0
test-adt plfent   4.0.0
test-adt docs     4.0.x-SNAPSHOT
test-adt plfcom   4.0.x-SNAPSHOT
test-adt plfent   4.0.x-SNAPSHOT

./adt.sh list
./adt.sh undeploy-all
