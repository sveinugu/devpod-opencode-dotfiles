#!/usr/bin/env bash
set -euo pipefail

workspace_nav_target_usage() {
  printf 'usage: write-workspace-nav-target.sh <created-target-path>\n' >&2
}

if [ "$#" -ne 1 ]; then
  workspace_nav_target_usage
  exit 2
fi

target_path="$1"
target_file="${HUB_WORKSPACE_NAV_TARGET_FILE:-}"

if [ -z "$target_file" ]; then
  exit 0
fi

if [ -z "$target_path" ]; then
  exit 0
fi

target_parent="$(dirname "$target_file")"
if [ ! -d "$target_parent" ]; then
  exit 0
fi

printf '%s\n' "$target_path" >"$target_file" || true
