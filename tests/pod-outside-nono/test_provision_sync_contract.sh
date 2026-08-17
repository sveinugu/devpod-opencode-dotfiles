#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_provision_sync_contract'

script="$repo_root/scripts/provision-workspace.sh"

fail() {
  printf 'FAIL test_provision_sync_contract: %s\n' "$1" >&2
  exit 1
}

[ -f "$script" ] || fail 'scripts/provision-workspace.sh not found'

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_provision_sync_contract')"
tmpdir="$(context_make_test_tmpdir "$temp_root" 'test_provision_sync_contract')"
trap 'rm -rf "$tmpdir"' EXIT

make_source_repo_with_main() {
  local path="$1"
  mkdir -p "$path"
  git init "$path" >/dev/null 2>&1
  (
    cd "$path"
    git config user.name 'Test User'
    git config user.email 'test@example.com'
    git branch -M main
cat > install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cat "$script_dir/INSTALL_VERSION" > "$HOME/.install-version"
EOF
    chmod +x install.sh
    printf 'main-v1\n' > INSTALL_VERSION
    git add install.sh INSTALL_VERSION
    git commit -m 'fixture main v1' >/dev/null 2>&1
  )
}

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
source_repo="$tmpdir/source"

make_source_repo_with_main "$source_repo"
mkdir -p "$workspace_root" "$home_dir"

run_provision() {
  local branch="$1"
  local label="$2"

  HUB_WORKSPACE_ROOT="$workspace_root" \
  HUB_PROVISION_SOURCE="$source_repo" \
  HUB_INSTALL_BRANCH="$branch" \
  HUB_PYENV_INSTALL_COMMAND=":" \
  HOME="$home_dir" \
  bash "$script" >"$tmpdir/$label.out"
}

run_provision 'main' 'provision-main-initial'
[ "$(cat "$home_dir/.install-version")" = 'main-v1' ] || fail 'initial main provision should run main tip install.sh'

(
  cd "$source_repo"
  printf 'main-sync\n' > MAIN_SYNC_MARKER
  printf 'main-v2\n' > INSTALL_VERSION
  git add MAIN_SYNC_MARKER INSTALL_VERSION
  git commit -m 'update main for provision sync' >/dev/null 2>&1
)

run_provision 'main' 'provision-main-followup'
[ -f "$workspace_root/main/MAIN_SYNC_MARKER" ] || fail 'follow-up main provision should fast-forward existing main worktree'
[ "$(cat "$home_dir/.install-version")" = 'main-v2' ] || fail 'follow-up main provision should run updated main install.sh'

(
  cd "$source_repo"
  git checkout -b feature/provision-sync >/dev/null 2>&1
  printf 'feature-v1\n' > INSTALL_VERSION
  printf 'feature-v1\n' > FEATURE_SYNC_MARKER
  git add INSTALL_VERSION FEATURE_SYNC_MARKER
  git commit -m 'create feature branch for provision sync' >/dev/null 2>&1
)

run_provision 'feature/provision-sync' 'provision-feature-initial'
[ -f "$workspace_root/work/feature/provision-sync/FEATURE_SYNC_MARKER" ] || fail 'initial feature provision should create install worktree from branch tip'
[ "$(cat "$home_dir/.install-version")" = 'feature-v1' ] || fail 'initial feature provision should run feature tip install.sh'

(
  cd "$source_repo"
  git checkout feature/provision-sync >/dev/null 2>&1
  printf 'feature-v2\n' > INSTALL_VERSION
  printf 'feature-v2\n' > FEATURE_SYNC_MARKER_UPDATE
  git add INSTALL_VERSION FEATURE_SYNC_MARKER_UPDATE
  git commit -m 'update feature branch for provision sync' >/dev/null 2>&1
)

run_provision 'feature/provision-sync' 'provision-feature-followup'
[ -f "$workspace_root/work/feature/provision-sync/FEATURE_SYNC_MARKER_UPDATE" ] || fail 'follow-up feature provision should fast-forward existing install worktree'
[ "$(cat "$home_dir/.install-version")" = 'feature-v2' ] || fail 'follow-up feature provision should run updated feature install.sh'

printf 'PASS test_provision_sync_contract\n'
