#!/bin/bash -eu
# Unit tests of the properties an operator adds to the exo.properties of an instance (do_append_custom_properties). No docker.
# Usage: tests/properties_test.sh
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_compose.sh"
WORK=$(mktemp -d); trap 'rm -rf "${WORK}"' EXIT
failures=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures+1)); fi; }
fresh() { printf '# Rendered\na.b=1\n' > "${WORK}/p"; }

fresh; DEPLOYMENT_PROPERTIES="" DEPLOYMENT_PROPERTIES_FILE="" do_append_custom_properties "${WORK}/p"
check "nothing asked, nothing added" "# Rendered|a.b=1" "$(paste -sd'|' "${WORK}/p")"

fresh; DEPLOYMENT_PROPERTIES='exo.wallet.admin.key=s3cr3t\n\nx.y=2' DEPLOYMENT_PROPERTIES_FILE="" do_append_custom_properties "${WORK}/p"
check "lines with a written newline, no empty line" "# Rendered|a.b=1|# Added by DEPLOYMENT_PROPERTIES and DEPLOYMENT_PROPERTIES_FILE|exo.wallet.admin.key=s3cr3t|x.y=2" "$(paste -sd'|' "${WORK}/p")"

fresh; DEPLOYMENT_PROPERTIES=$'k1=v1\nk2=v2' DEPLOYMENT_PROPERTIES_FILE="" do_append_custom_properties "${WORK}/p"
check "lines with real newlines" "k1=v1|k2=v2" "$(tail -2 "${WORK}/p" | paste -sd'|')"

printf 'f.a=1\n\n  \nf.b=2\n' > "${WORK}/custom.properties"
fresh; DEPLOYMENT_PROPERTIES="a.b=2" DEPLOYMENT_PROPERTIES_FILE="${WORK}/custom.properties" do_append_custom_properties "${WORK}/p"
check "the file comes after the lines, empty lines dropped" "a.b=2|f.a=1|f.b=2" "$(tail -3 "${WORK}/p" | paste -sd'|')"

fresh; ( DEPLOYMENT_PROPERTIES="" DEPLOYMENT_PROPERTIES_FILE="${WORK}/nope" do_append_custom_properties "${WORK}/p" ) > /dev/null 2>&1 && r=ok || r=error
check "a missing file is an error" "error" "${r}"

[ ${failures} -eq 0 ] && echo "All tests passed" || { echo "${failures} failure(s)"; exit 1; }
