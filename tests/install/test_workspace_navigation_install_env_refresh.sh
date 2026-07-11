#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_install_env_refresh: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
nav_script="$repo_root/.config/shell/workspace-navigation.zsh"

[ -f "$nav_script" ] || fail "workspace-navigation.zsh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
stale_branch="main"
stale_dir="$workspace_root/main"
fresh_branch="feature-refresh"
fresh_dir="$workspace_root/work/$fresh_branch"
install_env="$workspace_root/state/hub/etc/install.env"

mkdir -p "$stale_dir" "$fresh_dir" "$(dirname "$install_env")"

cat > "$install_env" <<EOF
export HUB_INSTALL_BRANCH=$fresh_branch
export HUB_INSTALL_BRANCH_DIR=$fresh_dir
EOF

refresh_out="$({
  HUB_INSTALL_BRANCH="$stale_branch" \
  HUB_INSTALL_BRANCH_DIR="$stale_dir" \
  WORKSPACE_NAV_INSTALL_ENV_FILE="$install_env" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    workspace_navigation_on_chpwd
    printf "branch=%s\n" "$HUB_INSTALL_BRANCH"
    printf "dir=%s\n" "$HUB_INSTALL_BRANCH_DIR"
  '
} 2>&1)"

printf '%s\n' "$refresh_out" | grep -Fx "branch=$fresh_branch" >/dev/null || fail "workspace navigation should refresh stale HUB_INSTALL_BRANCH from install.env"
printf '%s\n' "$refresh_out" | grep -Fx "dir=$fresh_dir" >/dev/null || fail "workspace navigation should refresh stale HUB_INSTALL_BRANCH_DIR from install.env"

printf 'PASS test_workspace_navigation_install_env_refresh\n'
