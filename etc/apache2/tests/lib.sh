#!/bin/bash
# Shared by the tests that run a private httpd.
#
# Fedora ships mod_unixd, mod_log_config... as loadable modules; Debian and Ubuntu build some of them in
# ("module unixd_module is built-in and can't be loaded"). The tests list the modules they need: this drops the
# LoadModule lines whose file does not exist, so the same test runs on both.
prune_modules() { # httpd.conf
  local conf="$1" line so keep=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^LoadModule[[:space:]]+[A-Za-z0-9_]+[[:space:]]+([^[:space:]]+)$ ]]; then
      so="${BASH_REMATCH[1]}"
      [ -e "$so" ] || continue
    fi
    keep+=("$line")
  done < "$conf"
  printf '%s\n' "${keep[@]}" > "$conf"
}
