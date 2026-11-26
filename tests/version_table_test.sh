#!/bin/bash
# configurable_env_var only sets a variable that is not set yet: a default set early in initialize_product_settings makes every later
# configurable_env_var of the same variable (the per-version table) dead code, and the instances keep the old version. That is how
# the Matrix image of 7.3 stayed on v1.118.0 although the table said v1.165.0.
#
# A version or image variable set with configurable_env_var must not appear twice at a deeper indentation with another value.
#
#   tests/version_table_test.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 - "$(dirname "$HERE")/_functions.sh" <<'PY'
import re, sys
seen = {}
pat = re.compile(r'^(\s*)configurable_env_var\s+"([A-Z0-9_]+)"\s+"([^"]*)"')
for n, line in enumerate(open(sys.argv[1]), 1):
    m = pat.match(line)
    if m and re.search(r'VERSION|IMAGE', m.group(2)):
        seen.setdefault(m.group(2), []).append((n, len(m.group(1)), m.group(3)))
bad = 0
for name, uses in sorted(seen.items()):
    first = uses[0]
    for n, indent, value in uses[1:]:
        if indent > first[1] and value != first[2]:
            print(f"FAIL: {name} is set to {first[2]!r} at line {first[0]} first: line {n} ({value!r}) can never apply")
            bad = 1
if bad:
    sys.exit(1)
print("version table: ok (no version or image default shadows a per-version value)")
PY
