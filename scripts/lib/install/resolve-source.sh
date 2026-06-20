#!/usr/bin/env bash
set -euo pipefail

install_detect_branch() {
  local current_branch=''

  if [ "$source_root" = "$workspace_root/main" ]; then
    printf 'main\n'
  elif [ "${source_root#"$workspace_root/work/"}" != "$source_root" ]; then
    printf '%s\n' "${source_root#"$workspace_root/work/"}"
  else
    if current_branch="$(git -C "$source_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
      :
    fi
    if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
      printf '%s\n' "$current_branch"
    else
      printf 'main\n'
    fi
  fi
}

install_resolve_source_context() {
  workspace_root="${WORKSPACE_ROOT:-/workspaces/dotfiles}"
  home_dir="${HOME:?HOME must be set}"
  validator="$source_root/scripts/lib/validate_install_source_tree.sh"

  install_branch="$(install_detect_branch)"
  install_branch_dir="$source_root"
  install_env_dir="$workspace_root/state/hub/etc"
  install_env_file="$install_env_dir/install.env"
  zsh_custom="${ZSH_CUSTOM:-$home_dir/.oh-my-zsh/custom}"
  oh_my_zsh_dir="$home_dir/.oh-my-zsh"
}
