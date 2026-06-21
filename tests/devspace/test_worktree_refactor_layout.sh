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

[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'
[ -f "$retire_script" ] || fail 'bin/retire-worktree not found'
[ -f "$new_worktree_flow" ] || fail 'scripts/lib/new-worktree-flow.sh not found'
[ -f "$retire_flow" ] || fail 'scripts/lib/retire-worktree-flow.sh not found'
[ -f "$hub_core" ] || fail 'scripts/lib/hub-repo-core.sh not found'
[ -f "$hub_source" ] || fail 'scripts/lib/hub-repo-core-source.sh not found'
[ -f "$hub_bootstrap" ] || fail 'scripts/lib/hub-repo-core-bootstrap.sh not found'
[ -f "$hub_upstream" ] || fail 'scripts/lib/hub-repo-core-upstream.sh not found'

grep -F 'source "$script_dir/../scripts/lib/new-worktree-flow.sh"' "$new_worktree_script" >/dev/null || fail 'new-worktree should source new-worktree-flow.sh'
grep -F 'new_worktree_parse_cli "$@"' "$new_worktree_script" >/dev/null || fail 'new-worktree should parse CLI through a phase helper'
grep -F 'new_worktree_resolve_repo_context' "$new_worktree_script" >/dev/null || fail 'new-worktree should resolve repo context through a phase helper'
grep -F 'new_worktree_create_or_attach_branch_worktree' "$new_worktree_script" >/dev/null || fail 'new-worktree should create/attach the worktree through a phase helper'
grep -F 'new_worktree_prepare_checkout_sidecars' "$new_worktree_script" >/dev/null || fail 'new-worktree should prepare env/state sidecars through a phase helper'
grep -F 'new_worktree_record_lane_binding' "$new_worktree_script" >/dev/null || fail 'new-worktree should record lane bindings through a phase helper'

grep -F 'source "$script_dir/../scripts/lib/retire-worktree-flow.sh"' "$retire_script" >/dev/null || fail 'retire-worktree should source retire-worktree-flow.sh'
grep -F 'retire_worktree_parse_cli "$@"' "$retire_script" >/dev/null || fail 'retire-worktree should parse CLI through a phase helper'
grep -F 'retire_worktree_resolve_target_record' "$retire_script" >/dev/null || fail 'retire-worktree should resolve targets through a phase helper'
grep -F 'retire_worktree_print_target_summary' "$retire_script" >/dev/null || fail 'retire-worktree should print target summary through a phase helper'
grep -F 'retire_worktree_assess_risk_and_maybe_refuse' "$retire_script" >/dev/null || fail 'retire-worktree should assess risk through a phase helper'
grep -F 'retire_worktree_execute' "$retire_script" >/dev/null || fail 'retire-worktree should execute cleanup through a phase helper'

grep -F 'source "$script_dir/hub-repo-core-source.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-source.sh'
grep -F 'source "$script_dir/hub-repo-core-bootstrap.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-bootstrap.sh'
grep -F 'source "$script_dir/hub-repo-core-upstream.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-upstream.sh'

printf 'PASS test_worktree_refactor_layout\n'
