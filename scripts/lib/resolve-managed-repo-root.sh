#!/usr/bin/env bash
set -euo pipefail

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
cwd_path="${1:-${PWD:-$(pwd -P)}}"

if [ "$cwd_path" = "$workspace_root/main" ] || [[ "$cwd_path" == "$workspace_root/main/"* ]] || [[ "$cwd_path" == "$workspace_root/work/"* ]]; then
  printf '%s\n' "$workspace_root"
  exit 0
fi

if [[ "$cwd_path" == "$workspace_root/repos/"* ]]; then
  remainder="${cwd_path#"$workspace_root/repos/"}"
  repo_name="${remainder%%/*}"
  if [ -n "$repo_name" ] && [ "$repo_name" != "$remainder" ]; then
    printf '%s\n' "$workspace_root/repos/$repo_name"
    exit 0
  fi
fi

printf 'refused: checkout path is outside managed repo context\n' >&2
exit 1
