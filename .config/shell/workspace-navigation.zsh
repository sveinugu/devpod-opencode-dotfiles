# Workspace Navigation Package
#
# Bundles interactive workspace navigation behavior for DevSpace bare-hub use:
# - quiet direnv output while keeping explicit exports
# - direnv zsh hook
# - dhub is the install-root navigation helper
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

workspace_navigation_load_install_env() {
  [ -n "${HUB_INSTALL_BRANCH_DIR:-}" ] && return 0

  local install_env="${WORKSPACE_NAV_INSTALL_ENV_FILE:-/workspaces/dotfiles/state/hub/etc/install.env}"
  if [ -f "$install_env" ]; then
    # shellcheck disable=SC1090
    . "$install_env"
  fi
}

workspace_navigation_on_chpwd() {
  workspace_navigation_load_install_env
  workspace_navigation_add_branch_bin_to_path
}

workspace_navigation_on_chpwd

if whence -w add-zsh-hook >/dev/null 2>&1; then
  add-zsh-hook chpwd workspace_navigation_on_chpwd
fi

dhub() {
  local target
  local hub_dir="${HUB_INSTALL_BRANCH_DIR:-/workspaces/dotfiles/main}"
  local libexec_dir="${WORKSPACE_NAV_LIBEXEC_DIR:-$hub_dir/scripts/lib}"
  local resolver="$libexec_dir/resolve-install-target.sh"
  if ! target="$(HUB_INSTALL_ENV_FILE="${HUB_INSTALL_ENV_FILE:-/workspaces/dotfiles/state/hub/etc/install.env}" bash "$resolver")"; then
    return 1
  fi
  printf 'cd -> %s\n' "$target"
  cd "$target"
}

dre() {
  local target
  if ! target="$(command dre "$@")"; then
    return 1
  fi
  printf 'cd -> %s\n' "$target"
  cd "$target"
}

dwt() {
  local target
  if ! target="$(command dwt "$@")"; then
    return 1
  fi
  printf 'cd -> %s\n' "$target"
  cd "$target"
}

_workspace_nav_complete_dhub() {
  return 0
}

_workspace_nav_compadd_with_prefix() {
  local completion_prefix="${PREFIX:-}"
  local -a candidates
  local -a matching_candidates
  candidates=("$@")
  matching_candidates=()

  local candidate
  for candidate in "$candidates[@]"; do
    if [[ -z "$completion_prefix" || "$candidate" == "$completion_prefix"* ]]; then
      matching_candidates+=("$candidate")
    fi
  done

  if (( ${#matching_candidates[@]} > 0 )); then
    compadd -Q -U -S '' -- "$matching_candidates[@]"
  fi
}

_workspace_nav_complete_repos() {
  if [[ -n "${CURRENT:-}" ]] && (( CURRENT != 2 )); then
    return 1
  fi

  local workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
  local repos_root="$workspace_root/repos"
  local -a repos
  repos=()

  if [ -d "$repos_root" ]; then
    local dir
    for dir in "$repos_root"/*(/N); do
      [ -d "$dir/.bare" ] || continue
      repos+=("${dir:t}")
    done
  fi

  _workspace_nav_compadd_with_prefix "$repos[@]"

  # If completion still behaves like an older loaded definition,
  # re-source this file (or open a new shell) to refresh the function.
}

_workspace_nav_complete_dwt() {
  if [[ -n "${CURRENT:-}" ]] && (( CURRENT != 2 )); then
    return 1
  fi

  local workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
  local hub_dir="${HUB_INSTALL_BRANCH_DIR:-/workspaces/dotfiles/main}"
  local resolver="${WORKSPACE_NAV_REPO_ROOT_RESOLVER:-$hub_dir/scripts/lib/resolve-managed-repo-root.sh}"
  local repo_root=''
  if ! repo_root="$(HUB_WORKSPACE_ROOT="$workspace_root" bash "$resolver" "$PWD" 2>/dev/null)"; then
    return 0
  fi

  local default_branch=''
  if [ "$repo_root" = "$workspace_root" ]; then
    default_branch='main'
  else
    local repo_name="${repo_root#"$workspace_root/repos/"}"
    local repo_env="$workspace_root/state/repos/$repo_name/etc/repo.env"
    if [ -f "$repo_env" ]; then
      # shellcheck disable=SC1090
      . "$repo_env"
      default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
    fi
  fi

  [ -d "$repo_root/work" ] || return 0

  local -a worktree_names
  worktree_names=()

  local dir
  for dir in "$repo_root/work"/**/*(N/); do
    [ -e "$dir/.git" ] || continue
    worktree_names+=("${dir#"$repo_root/work/"}")
  done

  if [ -n "$default_branch" ]; then
    _workspace_nav_compadd_with_prefix "$default_branch"
  fi

  _workspace_nav_compadd_with_prefix "$worktree_names[@]"

  # If completion still behaves like older path-based logic in an existing shell,
  # re-source this file (or open a new shell) to refresh the loaded function.
}

if whence -w compdef >/dev/null 2>&1; then
  compdef _workspace_nav_complete_dhub dhub
  compdef _workspace_nav_complete_repos dre
  compdef _workspace_nav_complete_dwt dwt
fi

workspace_navigation_auto_cd() {
  [[ -o interactive ]] || return 0

  if [ "${HUB_WORKSPACE_NAV_AUTO_CD_DONE:-0}" = "1" ]; then
    return 0
  fi

  if [ "${SHLVL:-1}" -gt 1 ]; then
    return 0
  fi

  workspace_navigation_load_install_env

  local target="${HUB_INSTALL_BRANCH_DIR:-/workspaces/dotfiles/main}"
  if [ ! -d "$target" ] || [ "$PWD" = "$target" ]; then
    return 0
  fi

  export HUB_WORKSPACE_NAV_AUTO_CD_DONE=1
  cd "$target"
  workspace_navigation_add_branch_bin_to_path
}

workspace_navigation_auto_cd
