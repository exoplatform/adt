#!/bin/bash
# Every workflow pins its actions to a commit (a moved tag of an action would run in jobs that hold a push-capable token) and
# declares the rights of its GITHUB_TOKEN.
#
#   tests/workflows_test.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
for f in "$ROOT"/.github/workflows/*.yml; do
  name="$(basename "$f")"
  while IFS= read -r l; do
    ref="${l##*uses:}"; ref="$(echo "$ref" | sed -E 's/#.*//; s/^[[:space:]]+|[[:space:]]+$//g')"
    case "$ref" in ./*|docker://*) continue;; esac
    [[ "$ref" =~ @[0-9a-f]{40}$ ]] || { echo "FAIL: $name: '$ref' is not pinned to a commit"; fail=1; }
  done < <(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:' "$f")
  grep -qE '^permissions:' "$f" || { echo "FAIL: $name has no top-level permissions block"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "workflows: ok" || { echo "workflows: FAILED"; exit 1; }
