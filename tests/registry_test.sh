#!/bin/bash -eu
# Unit tests of the image tag resolution (_functions_registry.sh), on a canned list of tags.
# Usage: tests/registry_test.sh
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_registry.sh"

TAGS='7.3.x-SNAPSHOT
7.3.x-devx-SNAPSHOT
7.2.x-SNAPSHOT
sha256-8eee282ab66516cddaf0b1b3fe533e0c0f604e20741f9a43adc6cf658770d694.sig
latest
develop
nightly-exo
7.2.1
7.2.2-RC01
7.2.2
7.2.3-CP1
7.3.0-M9_0
7.3.0-M15_0
7.3.0-M16_0
7.3.0-M16_1
7.3.0-20261020_0
7.3.0-20261020_1
7.3.0-20261022_0
7.3.10-M1_0
7.3.1-M2_0
7.10.0-M1_0'

failures=0
check() { # $1 description $2 expected $3 actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures+1)); fi
}
pick() { image_tag_pick "$1" "${2:-false}" <<< "${TAGS}" || echo "none"; }
rebuild() { image_tag_rebuild "$1" <<< "${TAGS}"; }

check "MLT of a milestone line"           "7.3.0-M16_1"      "$(pick 7.3.0-MLT)"
check "MBL is the build before the latest" "7.3.0-M16_0"     "$(pick 7.3.0-MBL)"
check "MLT with wildcard takes the highest line" "7.3.10-M1_0" "$(pick 7.3.Z-MLT)"
check "7.1 wildcard does not match 7.10"  "none"             "$(pick 7.1.Z-MLT)"
check "GA of 7.2 skips RC and CP"         "7.2.2"            "$(pick 7.2.Z-GA)"
check "GA without release"                "none"             "$(pick 7.3.0-GA)"
check "MLT of 7.2 takes the CP"           "7.2.3-CP1"        "$(pick 7.2.Z-MLT)"
check "continuous MLT takes the date tag" "7.3.0-20261022_0" "$(pick 7.3.0-MLT true)"
check "continuous MBL"                    "7.3.0-20261020_1" "$(pick 7.3.0-MBL true)"
check "continuous is ignored for GA"      "7.2.2"            "$(pick 7.2.Z-GA true)"
check "middle token of 7.3.Z-meed-MLT"    "7.3.10-M1_0"      "$(pick 7.3.Z-meed-MLT)"
check "7.3.1 does not match 7.3.10"       "7.3.1-M2_0"       "$(pick 7.3.1-MLT)"
check "rebuild of a milestone"            "7.3.0-M16_1"      "$(rebuild 7.3.0-M16)"
check "release without rebuild"           "7.2.2"            "$(rebuild 7.2.2)"
check "unknown version is the literal"    "7.9.9"            "$(rebuild 7.9.9)"
check "7.3.1-M2 is not 7.3.10-M2"         "7.3.1-M2_0"       "$(rebuild 7.3.1-M2)"

[ ${failures} -eq 0 ] && echo "All tests passed" || { echo "${failures} failure(s)"; exit 1; }
