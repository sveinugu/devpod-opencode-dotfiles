#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_worktree_refactor_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
new_worktree_script="$repo_root/bin/new-worktree"
retire_script="$repo_root/bin/retire-worktree"
new_worktree_flow="$repo_root/scripts/lib/new-worktree-flow.sh"
retire_flow="$repo_root/scripts/lib/retire-worktree-flow.sh"
hub_core="$repo_root/scripts/lib/hub-repo-core.sh"
hub_source="$repo_root/scripts/lib/hub-repo-core-source.sh"
hub_bootstrap="$repo_root/scripts/lib/hub-repo-core-bootstrap.sh"
hub_upstream="$repo_root/scripts/lib/hub-repo-core-upstream.sh"
cleanup_helper="$repo_root/scripts/lib/managed-worktree-cleanup.sh"
default_checkout_helper="$repo_root/scripts/lib/resolve-managed-default-checkout.sh"

[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'
[ -f "$retire_script" ] || fail 'bin/retire-worktree not found'
[ -f "$new_worktree_flow" ] || fail 'scripts/lib/new-worktree-flow.sh not found'
[ -f "$retire_flow" ] || fail 'scripts/lib/retire-worktree-flow.sh not found'
[ -f "$hub_core" ] || fail 'scripts/lib/hub-repo-core.sh not found'
[ -f "$hub_source" ] || fail 'scripts/lib/hub-repo-core-source.sh not found'
[ -f "$hub_bootstrap" ] || fail 'scripts/lib/hub-repo-core-bootstrap.sh not found'
[ -f "$hub_upstream" ] || fail 'scripts/lib/hub-repo-core-upstream.sh not found'
[ -f "$cleanup_helper" ] || fail 'scripts/lib/managed-worktree-cleanup.sh not found'
[ -f "$default_checkout_helper" ] || fail 'scripts/lib/resolve-managed-default-checkout.sh not found'

grep -F 'source "$script_dir/../scripts/lib/new-worktree-flow.sh"' "$new_worktree_script" >/dev/null || fail 'new-worktree should source new-worktree-flow.sh'
grep -F 'new_worktree_parse_cli "$@"' "$new_worktree_script" >/dev/null || fail 'new-worktree should parse CLI through a phase helper'
grep -F 'new_worktree_resolve_repo_context "$workspace_root" "$script_dir"' "$new_worktree_script" >/dev/null || fail 'new-worktree should pass explicit workspace/script context to repo-resolution helper'
grep -F 'new_worktree_create_or_attach_branch_worktree' "$new_worktree_script" >/dev/null || fail 'new-worktree should create/attach the worktree through a phase helper'
grep -F 'new_worktree_prepare_checkout_sidecars "$workspace_root" "$script_dir"' "$new_worktree_script" >/dev/null || fail 'new-worktree should pass explicit workspace/script context to sidecar helper'
grep -F 'new_worktree_record_lane_binding "$workspace_root"' "$new_worktree_script" >/dev/null || fail 'new-worktree should pass explicit workspace context to lane-binding helper'

grep -F 'source "$script_dir/../scripts/lib/retire-worktree-flow.sh"' "$retire_script" >/dev/null || fail 'retire-worktree should source retire-worktree-flow.sh'
grep -F 'retire_worktree_parse_cli "$@"' "$retire_script" >/dev/null || fail 'retire-worktree should parse CLI through a phase helper'
grep -F 'retire_worktree_resolve_target_record "$workspace_root"' "$retire_script" >/dev/null || fail 'retire-worktree should pass explicit workspace context to target-resolution helper'
grep -F 'retire_worktree_print_target_summary' "$retire_script" >/dev/null || fail 'retire-worktree should print target summary through a phase helper'
grep -F 'retire_worktree_assess_risk_and_maybe_refuse "$workspace_root"' "$retire_script" >/dev/null || fail 'retire-worktree should pass explicit workspace context to risk helper'
grep -F 'retire_worktree_execute' "$retire_script" >/dev/null || fail 'retire-worktree should execute cleanup through a phase helper'

grep -F 'source "$_HRC_SCRIPT_DIR/hub-repo-core-source.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-source.sh through private script-dir variable'
grep -F 'source "$_HRC_SCRIPT_DIR/hub-repo-core-bootstrap.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-bootstrap.sh through private script-dir variable'
grep -F 'source "$_HRC_SCRIPT_DIR/hub-repo-core-upstream.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-upstream.sh through private script-dir variable'
if grep -F 'script_dir=' "$hub_core" >/dev/null; then
  fail 'hub-repo-core should not assign caller script_dir'
fi
if grep -F 'BASH_SOURCE[1]' "$hub_core" >/dev/null; then
  fail 'hub-repo-core should not restore caller script_dir via BASH_SOURCE[1]'
fi

grep -F 'resolve_managed_default_checkout_require_helpers() {' "$default_checkout_helper" >/dev/null || fail 'resolve-managed-default-checkout should define an explicit helper-loading contract'
grep -F 'resolve_managed_default_checkout requires managed-repo-metadata helpers' "$default_checkout_helper" >/dev/null || fail 'resolve-managed-default-checkout should fail clearly when metadata helpers are unavailable'

grep -F 'local workspace_root="${1:?workspace_root required}"' "$cleanup_helper" >/dev/null || fail 'managed-worktree-cleanup retry renderer should require workspace_root explicitly'
grep -F 'local absolute_path=' "$cleanup_helper" >/dev/null || fail 'managed-worktree-cleanup should localize absolute_path scratch variables'
if grep -F '${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}' "$cleanup_helper" >/dev/null; then
  fail 'managed-worktree-cleanup should not depend on implicit HUB_WORKSPACE_ROOT globals'
fi

printf 'PASS test_worktree_refactor_layout\n'
