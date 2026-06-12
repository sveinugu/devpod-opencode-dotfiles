#!/usr/bin/env bash
set -euo pipefail

bare_dir="${1:?usage: ensure-bare-excludes.sh BARE_DIR}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
list_file="$script_dir/bare-excludes.list"

if [ ! -d "$bare_dir" ]; then
  printf 'refused: bare repository path is missing\n' >&2
  exit 1
fi

exclude_file="$bare_dir/info/exclude"
mkdir -p "$(dirname "$exclude_file")"

if [ ! -f "$list_file" ]; then
  printf 'refused: bare exclude list is missing\n' >&2
  exit 1
fi

cp "$list_file" "$exclude_file"
