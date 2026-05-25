#!/usr/bin/env bash
set -euo pipefail

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"

if [ ! -d "$workspace_root/.bare" ] || [ ! -d "$workspace_root/main" ]; then
  printf 'workspace not provisioned; run devspace run-pipeline provision\n' >&2
  exit 1
fi

exit 0
