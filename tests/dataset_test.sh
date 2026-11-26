#!/bin/bash -eu
# Unit tests of the reading of the datasets (_functions_dataset.sh): the archive formats of ADT and of the former ADT, and the
# symbolic links that zstd ignores when given as a file. Needs zstd and bzip2; no docker.
# Usage: tests/dataset_test.sh
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/_functions_core.sh"
source "${SCRIPT_DIR}/_functions_dataset.sh"

WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT
failures=0
check() { # $1 description $2 expected $3 actual
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; failures=$((failures+1)); fi
}

mkdir -p "${WORK}/src/exo/files" "${WORK}/src/search" "${WORK}/src/codec" "${WORK}/ds" "${WORK}/real"
echo data > "${WORK}/src/exo/files/a"; echo idx > "${WORK}/src/search/i"; echo key > "${WORK}/src/codec/codeckey.txt"; echo "select 1;" > "${WORK}/src/backup.sql"
tar -C "${WORK}/src" -cf - exo search codec backup.sql | zstd -q -o "${WORK}/real/new.tar.zst"
tar -C "${WORK}/src" -cf - exo search codec backup.sql | bzip2 > "${WORK}/real/old.tar.bz2"
ln -s "${WORK}/real/new.tar.zst" "${WORK}/ds/linked.tar.zst"

members() { do_dataset_cat "$1" | tar -tf - | cut -d/ -f1 | sort -u | tr '\n' ' '; }
check "a zst dataset"                         "backup.sql codec exo search " "$(members "${WORK}/real/new.tar.zst")"
check "a dataset of the former ADT (bz2)"     "backup.sql codec exo search " "$(members "${WORK}/real/old.tar.bz2")"
check "a symbolic link to a zst dataset"      "backup.sql codec exo search " "$(members "${WORK}/ds/linked.tar.zst")"
check "the sql of a dataset"                  "select 1;" "$(do_dataset_cat "${WORK}/real/new.tar.zst" | tar -xOf - backup.sql)"

DS_DIR="${WORK}/ds"
DS_FILENAME=linked;  check "the dataset to restore is found"            "${WORK}/ds/linked.tar.zst" "$(do_get_dataset_file)"
cp "${WORK}/real/old.tar.bz2" "${WORK}/ds/legacy.tar.bz2"
DS_FILENAME=legacy;  check "the former format is found when it is alone" "${WORK}/ds/legacy.tar.bz2" "$(do_get_dataset_file)"
cp "${WORK}/real/new.tar.zst" "${WORK}/ds/legacy.tar.zst"
check "the new format wins"                   "${WORK}/ds/legacy.tar.zst" "$(do_get_dataset_file)"
DS_FILENAME=none;    do_get_dataset_file > /dev/null && check "a missing dataset is an error" "error" "found" || check "a missing dataset is an error" "error" "error"

[ ${failures} -eq 0 ] && echo "All tests passed" || { echo "${failures} failure(s)"; exit 1; }
