#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_worktree_lane_safety_policy: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_managed_worktree_lane_safety_policy'

policy="$repo_root/.config/opencode"
lanes="$policy/skills/managed-worktrees/SKILL.md"
rg -qF 'managed-worktrees' "$policy/AGENTS.md" || fail 'missing managed hub skill trigger'
for rule in 'dedicated checkout before dispatching' 'validated lane-qualified session' \
    'independently check the local checkout, branch and lane registry' \
    'on main for a dedicated lane' 'unrelated active lanes' 'Ask if ambiguous'; do
  rg -qF -- "$rule" "$lanes" || fail "missing managed worktree rule: $rule"
done

bare_hub_runbook="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"
lifecycle_runbook="$repo_root/docs/superpowers/runbooks/devspace-workspace-lifecycle.md"

grep -F 'creating a lane-safe worktree' "$bare_hub_runbook" >/dev/null || fail 'missing lane-safe worktree creation guidance in bare-hub runbook'
grep -F 'scoped authoring should not proceed from hub root or unrelated worktrees' "$bare_hub_runbook" >/dev/null || fail 'missing scoped-authoring guardrail guidance in bare-hub runbook'
grep -F 'bin/new-worktree' "$bare_hub_runbook" >/dev/null || fail 'missing managed creation command guidance in bare-hub runbook'
grep -F 'bin/retire-worktree' "$bare_hub_runbook" >/dev/null || fail 'missing managed retirement command guidance in bare-hub runbook'

grep -F '## Managed local retirement' "$bare_hub_runbook" >/dev/null || fail 'missing local managed retirement heading in bare-hub runbook'
grep -F 'remote branch deletion remains out of scope for v1' "$bare_hub_runbook" >/dev/null || fail 'missing explicit remote-branch non-goal wording in bare-hub runbook'

printf 'PASS test_managed_worktree_lane_safety_policy\n'
