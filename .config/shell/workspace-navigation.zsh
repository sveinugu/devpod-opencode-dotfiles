# Workspace Navigation Package
#
# Bundles interactive workspace navigation behavior for DevSpace bare-hub use:
# - quiet direnv output while keeping explicit exports
# - direnv zsh hook
# - dd() helper to jump to current install checkout
# - one-time auto-cd on interactive shell startup

export DIRENV_LOG_FORMAT=''

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

workspace_navigation_add_branch_bin_to_path() {
  local branch_dir="${HUB_INSTALL_BRANCH_DIR:-}"
  [ -n "$branch_dir" ] || return 0

  local branch_bin="$branch_dir/bin"
  [ -d "$branch_bin" ] || return 0

  case ":$PATH:" in
    *":$branch_bin:"*)
      return 0
      ;;
  esac

  # Prepend branch bin so branch-scoped tooling takes precedence.
  export PATH="$branch_bin:$PATH"
}

workspace_navigation_add_branch_bin_to_path

dd() {
  local target="${HUB_INSTALL_BRANCH_DIR:-/workspaces/dotfiles/main}"
  printf 'cd -> %s\n' "$target"
  cd "$target"
}

workspace_navigation_auto_cd() {
  [[ -o interactive ]] || return 0

  if [ "${HUB_WORKSPACE_NAV_AUTO_CD_DONE:-0}" = "1" ]; then
    return 0
  fi

  if [ "${SHLVL:-1}" -gt 1 ]; then
    return 0
  fi

  local install_env="/workspaces/dotfiles/state/hub/etc/install.env"
  if [ -f "$install_env" ]; then
    # shellcheck disable=SC1090
    . "$install_env"
  fi

  local target="${HUB_INSTALL_BRANCH_DIR:-/workspaces/dotfiles/main}"
  if [ ! -d "$target" ] || [ "$PWD" = "$target" ]; then
    return 0
  fi

  export HUB_WORKSPACE_NAV_AUTO_CD_DONE=1
  cd "$target"
}

workspace_navigation_auto_cd
