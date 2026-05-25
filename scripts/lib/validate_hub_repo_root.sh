#!/usr/bin/env bash
set -euo pipefail

checkout_dir="${1:?usage: validate_hub_repo_root.sh CHECKOUT_DIR}"
if [ ! -e "$checkout_dir" ]; then
  printf 'refused: checkout path does not exist\n' >&2
  exit 1
fi
if ! checkout_dir="$(readlink -f "$checkout_dir")"; then
  printf 'refused: checkout path could not be resolved\n' >&2
  exit 1
fi
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
