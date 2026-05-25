#!/usr/bin/env bash
set -euo pipefail

install_env="${1:-/workspaces/dotfiles/state/hub/etc/install.env}"

if [ ! -f "$install_env" ]; then
  exit 0
fi

extract_var() {
  local var_name="$1"
  sed -n "s/^export[[:space:]]\{1,\}${var_name}=//p; s/^${var_name}=//p" "$install_env" | head -n1
}

branch="$(extract_var HUB_INSTALL_BRANCH)"
branch_dir="$(extract_var HUB_INSTALL_BRANCH_DIR)"

if [ -n "$branch" ]; then
  printf 'HUB_INSTALL_BRANCH=%q\n' "$branch"
fi

if [ -n "$branch_dir" ]; then
  printf 'HUB_INSTALL_BRANCH_DIR=%q\n' "$branch_dir"
fi
