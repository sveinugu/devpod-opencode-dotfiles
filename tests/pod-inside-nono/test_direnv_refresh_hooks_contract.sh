#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_direnv_refresh_hooks_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_direnv_refresh_hooks_contract'

provision_script="$repo_root/scripts/provision-workspace.sh"
repair_script="$repo_root/bin/repair-workspace"
helper_script="$repo_root/scripts/lib/refresh-managed-direnv-trust.sh"

[ -f "$provision_script" ] || fail "scripts/provision-workspace.sh not found"
[ -f "$repair_script" ] || fail "bin/repair-workspace not found"
[ -f "$helper_script" ] || fail "scripts/lib/refresh-managed-direnv-trust.sh not found"

grep -F 'source "$script_dir/lib/refresh-managed-direnv-trust.sh"' "$provision_script" >/dev/null || fail "provision-workspace.sh should source shared direnv trust refresh helper"
grep -F 'refresh_managed_direnv_trust "$install_dir" "$workspace_root" provision' "$provision_script" >/dev/null || fail "provision-workspace.sh should refresh managed direnv trust after install"

grep -F 'source "$script_dir/../scripts/lib/refresh-managed-direnv-trust.sh"' "$repair_script" >/dev/null || fail "repair-workspace should source shared direnv trust refresh helper"
grep -F 'refresh_managed_direnv_trust "$install_dir" "$workspace_root" repair' "$repair_script" >/dev/null || fail "repair-workspace should refresh managed direnv trust before completion"

grep -F 'allow-direnv-managed-worktrees' "$helper_script" >/dev/null || fail "helper should invoke allow-direnv-managed-worktrees"
grep -F ' --allow' "$helper_script" >/dev/null || fail "helper should run allow-direnv-managed-worktrees --allow"
grep -F 'warning:' "$helper_script" >/dev/null || fail "helper should warn instead of failing hard when trust refresh cannot run"
grep -F 'return 0' "$helper_script" >/dev/null || fail "helper should continue without failing lifecycle scripts"

printf 'PASS test_direnv_refresh_hooks_contract\n'
