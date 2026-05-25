#!/usr/bin/env bash
set -euo pipefail

checkout_dir="${1:?usage: validate_hub_repo_root.sh CHECKOUT_DIR}"
checkout_dir="$(readlink -f "$checkout_dir")"
workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"

case "$checkout_dir" in
  "$workspace_root/main"|"$workspace_root/main"/*|"$workspace_root/work"/*|"$workspace_root/repos"/*)
    ;;
  *)
    printf 'refused: checkout path is outside managed workspace root\n' >&2
    exit 1
    ;;
esac

printf 'ok: validated hub repo root path %s\n' "$checkout_dir"
