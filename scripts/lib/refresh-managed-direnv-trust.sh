#!/usr/bin/env bash

refresh_managed_direnv_trust() {
  local install_dir="${1:-}"
  local workspace_root="${2:-/workspaces/dotfiles}"
  local phase_label="${3:-lifecycle}"
  local allow_helper=''

  if [ -z "$install_dir" ]; then
    printf 'warning: %s: skipped managed direnv trust refresh (missing install_dir)\n' "$phase_label" >&2
    return 0
  fi

  if [ ! -d "$install_dir" ]; then
    printf 'warning: %s: skipped managed direnv trust refresh (install dir missing at %s)\n' "$phase_label" "$install_dir" >&2
    return 0
  fi

  allow_helper="$install_dir/bin/allow-direnv-managed-worktrees"
  if [ ! -x "$allow_helper" ]; then
    printf 'warning: %s: skipped managed direnv trust refresh (helper not executable at %s)\n' "$phase_label" "$allow_helper" >&2
    return 0
  fi

  if ! (
    cd "$install_dir"
    HUB_WORKSPACE_ROOT="$workspace_root" "$allow_helper" --allow
  ); then
    printf 'warning: %s: managed direnv trust refresh failed; run "%s --allow" manually\n' "$phase_label" "$allow_helper" >&2
    return 0
  fi

  return 0
}
