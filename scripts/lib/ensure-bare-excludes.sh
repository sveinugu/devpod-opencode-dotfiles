#!/usr/bin/env bash
set -euo pipefail

bare_dir="${1:?usage: ensure-bare-excludes.sh BARE_DIR}"

if [ ! -d "$bare_dir" ]; then
  printf 'refused: bare repository path is missing\n' >&2
  exit 1
fi

exclude_file="$bare_dir/info/exclude"
mkdir -p "$(dirname "$exclude_file")"
touch "$exclude_file"

append_pattern_if_missing() {
  local pattern="$1"

  if grep -Fx -- "$pattern" "$exclude_file" >/dev/null 2>&1; then
    return 0
  fi

  printf '%s\n' "$pattern" >> "$exclude_file"
}

append_pattern_if_missing '.envrc'
append_pattern_if_missing '.envrc.local'
append_pattern_if_missing '.envrc.bak.*'
append_pattern_if_missing '.opencode/'
