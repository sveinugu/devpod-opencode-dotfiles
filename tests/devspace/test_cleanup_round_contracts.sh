#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_cleanup_round_contracts: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"

require_helper="$repo_root/scripts/lib/require-non-empty.sh"
new_worktree_flow="$repo_root/scripts/lib/new-worktree-flow.sh"
retire_worktree_flow="$repo_root/scripts/lib/retire-worktree-flow.sh"
metadata_helper="$repo_root/scripts/lib/managed-repo-metadata.sh"
default_checkout_helper="$repo_root/scripts/lib/resolve-managed-default-checkout.sh"
clone_repo_script="$repo_root/bin/clone-repo"
cleanup_entrypoint="$repo_root/scripts/lib/managed-worktree-cleanup.sh"
cleanup_resolve="$repo_root/scripts/lib/managed-worktree-cleanup-resolve.sh"
cleanup_risk="$repo_root/scripts/lib/managed-worktree-cleanup-risk.sh"
cleanup_mutation="$repo_root/scripts/lib/managed-worktree-cleanup-mutation.sh"
materialize_helper="$repo_root/scripts/lib/install/materialize.sh"
parse_args_helper="$repo_root/scripts/lib/install/parse-args.sh"

[ -f "$require_helper" ] || fail 'scripts/lib/require-non-empty.sh not found'
[ -f "$parse_args_helper" ] || fail 'scripts/lib/install/parse-args.sh not found'

for helper in "$new_worktree_flow" "$retire_worktree_flow" "$metadata_helper" "$default_checkout_helper"; do
  [ -f "$helper" ] || fail "missing helper: $helper"
  grep -F 'require-non-empty.sh' "$helper" >/dev/null || fail "helper should source shared require-non-empty helper: $helper"
done

if grep -F 'new_worktree_require_non_empty()' "$new_worktree_flow" >/dev/null; then
  fail 'new-worktree-flow should not define local require_non_empty helper'
fi

if grep -F 'retire_worktree_require_non_empty()' "$retire_worktree_flow" >/dev/null; then
  fail 'retire-worktree-flow should not define local require_non_empty helper'
fi

if grep -F 'metadata_require_non_empty()' "$metadata_helper" >/dev/null; then
  fail 'managed-repo-metadata should not define local require_non_empty helper'
fi

if grep -F 'resolve_managed_default_checkout_require_non_empty()' "$default_checkout_helper" >/dev/null; then
  fail 'resolve-managed-default-checkout should not define local require_non_empty helper'
fi

repo_name_guard_count="$(grep -F "require_non_empty 'resolve_managed_default_checkout' 'repo_name' \"\$repo_name\"" "$default_checkout_helper" | wc -l | tr -d ' ')"
[ "$repo_name_guard_count" = '1' ] || fail 'resolve-managed-default-checkout should not duplicate resolve_managed_default_checkout require_non_empty guards'

if grep -F 'HUB_REPO_RESOLVED_BRANCH' "$clone_repo_script" >/dev/null; then
  fail 'clone-repo should not depend on HUB_REPO_RESOLVED_BRANCH side effect'
fi

if grep -F 'if [ "$assume_yes" = true ] && [ "$dry_run" = true ]; then' "$materialize_helper" >/dev/null; then
  fail 'materialize helper should not include vestigial assume_yes+dry_run no-op block'
fi

if grep -F '[-y|--yes]' "$parse_args_helper" >/dev/null; then
  fail 'install parse-args usage should not advertise removed -y|--yes flag in v1'
fi

if grep -F 'assume_yes=' "$parse_args_helper" >/dev/null; then
  fail 'install parse-args should not define vestigial assume_yes variable in v1'
fi

if grep -F -- '-y|--yes)' "$parse_args_helper" >/dev/null; then
  fail 'install parse-args should not accept removed -y|--yes flag in v1'
fi

for helper in "$cleanup_resolve" "$cleanup_risk" "$cleanup_mutation"; do
  [ -f "$helper" ] || fail "missing cleanup split helper: $helper"
done

grep -F 'managed-worktree-cleanup-resolve.sh' "$cleanup_entrypoint" >/dev/null || fail 'cleanup entrypoint should source resolve helper'
grep -F 'managed-worktree-cleanup-risk.sh' "$cleanup_entrypoint" >/dev/null || fail 'cleanup entrypoint should source risk helper'
grep -F 'managed-worktree-cleanup-mutation.sh' "$cleanup_entrypoint" >/dev/null || fail 'cleanup entrypoint should source mutation helper'

printf 'PASS test_cleanup_round_contracts\n'
