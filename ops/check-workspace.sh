#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  printf 'usage: check-workspace.sh\n' >&2
  exit 2
fi

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
home_dir="${HUB_HOME_DIR:-/home/vscode}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
read_install_env_script="$script_dir/../scripts/lib/read-install-env.sh"

failures=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '[PASS] %s\n' "$label"
  else
    printf '[FAIL] %s\n' "$label"
    failures=$((failures + 1))
  fi
}

check "workspace Deployment exists" test "${HUB_CHECK_DEPLOYMENT:-no}" = "yes"
check "workspace PVC exists" test "${HUB_CHECK_PVC:-no}" = "yes"
check "workspace pod is reachable" test -n "${HUB_CHECK_POD:-}"

check "top-level .bare is a valid bare Git directory" git --git-dir="$workspace_root/.bare" rev-parse --is-bare-repository
check "top-level main exists and is attached" sh -lc "[ -d '$workspace_root/main' ] && git --git-dir='$workspace_root/.bare' worktree list --porcelain | grep -F 'worktree $workspace_root/main' >/dev/null"

check "managed directory work/ exists" test -d "$workspace_root/work"
check "managed directory repos/ exists" test -d "$workspace_root/repos"
check "managed directory state/ exists" test -d "$workspace_root/state"
check "managed directory tmp/ exists" test -d "$workspace_root/tmp"

check "canonical top-level state path exists" test -d "$workspace_root/state/hub/main"
check "canonical top-level tmp path exists" test -d "$workspace_root/tmp/hub/main"

check_symlink_points_to_top_level_worktree() {
  local rel="$1"
  local link_path="$home_dir/$rel"

  [ -L "$link_path" ] || return 1
  local target
  target="$(readlink "$link_path")"

  case "$target" in
    "$workspace_root/main"/*|"$workspace_root/work"/*)
      ;;
    *)
      return 1
      ;;
  esac

  local target_parent
  target_parent="$(dirname "$target")"
  [ -d "$target_parent" ] && [ -e "$target" ]
}

check "/home/vscode .zshrc symlink points to existing top-level worktree" check_symlink_points_to_top_level_worktree ".zshrc"
check "/home/vscode .zprofile symlink points to existing top-level worktree" check_symlink_points_to_top_level_worktree ".zprofile"
check "/home/vscode .config/opencode symlink points to existing top-level worktree" check_symlink_points_to_top_level_worktree ".config/opencode"

install_env="$workspace_root/state/hub/etc/install.env"
if [ -f "$install_env" ]; then
  install_branch=''
  install_dir=''
  if [ -x "$read_install_env_script" ]; then
    eval "$(bash "$read_install_env_script" "$install_env")"
  fi
  install_branch="${HUB_INSTALL_BRANCH:-}"
  install_dir="${HUB_INSTALL_BRANCH_DIR:-}"
  printf '[PASS] installed-branch state from install.env: HUB_INSTALL_BRANCH=%s HUB_INSTALL_BRANCH_DIR=%s\n' "$install_branch" "$install_dir"
else
  printf '[INFO] installed-branch state from install.env: unavailable\n'
fi

if [ "$failures" -eq 0 ]; then
  printf 'doctor: all required checks passed\n'
  exit 0
fi

printf 'doctor: %s required check(s) failed\n' "$failures"
exit 1
