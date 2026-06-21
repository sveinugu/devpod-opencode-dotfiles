#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_worktree_lane_safety_policy: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"
senior="$repo_root/.config/opencode/agents/senior-implementer.md"

required_non_guarantee='wrong-yet-self-consistent sibling-lane dispatch is not always independently detectable when remaining intent signals are absent or ambiguous.'

grep -F '## Managed worktree lane safety (v1)' "$agents" >/dev/null || fail 'missing managed lane safety section heading in AGENTS.md'
grep -F 'For scoped work, actions are lane-scoped by default.' "$agents" >/dev/null || fail 'missing lane-scoped-by-default rule in AGENTS.md'
grep -F 'For scoped authoring work, Maestro must resolve or create the dedicated managed worktree before dispatch.' "$agents" >/dev/null || fail 'missing mandatory worktree-resolution-before-dispatch rule in AGENTS.md'
grep -F 'Hard-stop lane/worktree refusal conditions:' "$agents" >/dev/null || fail 'missing hard-stop refusal heading in AGENTS.md'
grep -F -- '- dispatching scoped authoring work from hub root' "$agents" >/dev/null || fail 'missing hub-root hard-stop condition in AGENTS.md'
grep -F -- '- dispatching scoped authoring work from `main` when that lane requires its dedicated worktree' "$agents" >/dev/null || fail 'missing main-checkout hard-stop condition in AGENTS.md'
grep -F -- '- dispatching two unrelated active lanes into one worktree' "$agents" >/dev/null || fail 'missing multi-lane hard-stop condition in AGENTS.md'
grep -F -- '- continuing a lane from a worktree bound to a different active lane' "$agents" >/dev/null || fail 'missing wrong-lane hard-stop condition in AGENTS.md'
grep -F -- '- attempting lane-sensitive repo operations without having resolved the target lane first' "$agents" >/dev/null || fail 'missing unresolved-lane hard-stop condition in AGENTS.md'
grep -F 'Subagents must independently verify delegated lane/worktree/branch coherence against local repo + registry evidence and all available intent signals before substantive work.' "$agents" >/dev/null || fail 'missing subagent independent verification requirement in AGENTS.md'

grep -F 'Available intent signals (ordered; use in this sequence):' "$agents" >/dev/null || fail 'missing available intent signals heading in AGENTS.md'
grep -F '1. validated resume/routing context for a lane-qualified work item;' "$agents" >/dev/null || fail 'missing ordered intent signal #1 in AGENTS.md'
grep -F '2. delegated artifact anchor(s);' "$agents" >/dev/null || fail 'missing ordered intent signal #2 in AGENTS.md'
grep -F '3. verbatim user request when it materially distinguishes sibling lanes;' "$agents" >/dev/null || fail 'missing ordered intent signal #3 in AGENTS.md'
grep -F '4. explicit user/delegator lane, branch, or worktree naming in the current turn.' "$agents" >/dev/null || fail 'missing ordered intent signal #4 in AGENTS.md'
grep -F 'Intended session model for scoped work: use one session per `(subagent type, lane-qualified work item)`.' "$agents" >/dev/null || fail 'missing lane-qualified scoped session model in AGENTS.md'
grep -F 'Sibling lanes under one parent artifact are different resume targets.' "$agents" >/dev/null || fail 'missing sibling-lane resume distinction in AGENTS.md'
grep -F 'When only the parent artifact matches multiple active lanes, Maestro must ask rather than guess.' "$agents" >/dev/null || fail 'missing ask-rather-than-guess parent-artifact ambiguity rule in AGENTS.md'

grep -F "$required_non_guarantee" "$agents" >/dev/null || fail 'missing exact non-guarantee sentence in AGENTS.md'
grep -F "$required_non_guarantee" "$0" >/dev/null || fail 'missing exact non-guarantee sentence in docs contract test'

grep -F 'Managed lane/worktree safety policy is canonical in `.config/opencode/AGENTS.md`.' "$maestro" >/dev/null || fail 'missing canonical-policy pointer in maestro.md'
grep -F 'Maestro must resolve lane-qualified routing and the target worktree before dispatching scoped authoring work.' "$maestro" >/dev/null || fail 'missing lane-qualified routing requirement in maestro.md'
grep -F 'If lane identity or worktree binding is ambiguous, Maestro must pause and ask rather than dispatch.' "$maestro" >/dev/null || fail 'missing ambiguity pause requirement in maestro.md'
grep -F 'Refuse dispatch when scoped authoring would proceed from hub root, from `main` for a dedicated lane, or from a worktree bound to another active lane.' "$maestro" >/dev/null || fail 'missing refusal-backed wrong-worktree rule in maestro.md'
grep -F 'For scoped resume/routing, Maestro must use one session per `(subagent type, lane-qualified work item)`.' "$maestro" >/dev/null || fail 'missing lane-qualified scoped session model in maestro.md'
grep -F 'Sibling lanes under one parent artifact are different resume targets, and when only the parent artifact matches multiple active lanes Maestro must ask rather than guess.' "$maestro" >/dev/null || fail 'missing sibling-lane resume ask-rather-than-guess rule in maestro.md'

grep -F 'Managed lane/worktree safety policy is canonical in `.config/opencode/AGENTS.md`.' "$senior" >/dev/null || fail 'missing canonical-policy pointer in senior-implementer.md'
grep -F 'Senior implementers must validate local lane/worktree/branch coherence before substantive work on scoped authoring tasks.' "$senior" >/dev/null || fail 'missing local coherence requirement in senior-implementer.md'
grep -F 'If delegated routing metadata conflicts with local worktree or lane evidence, senior implementers must refuse substantive work and push back.' "$senior" >/dev/null || fail 'missing pushback-on-mismatch rule in senior-implementer.md'
grep -F 'Do not blindly trust delegated session/routing metadata until local coherence checks pass.' "$senior" >/dev/null || fail 'missing no-blind-trust requirement in senior-implementer.md'

bare_hub_runbook="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"
lifecycle_runbook="$repo_root/docs/superpowers/runbooks/devspace-workspace-lifecycle.md"

grep -F 'creating a lane-safe worktree' "$bare_hub_runbook" >/dev/null || fail 'missing lane-safe worktree creation guidance in bare-hub runbook'
grep -F 'scoped authoring should not proceed from hub root or unrelated worktrees' "$bare_hub_runbook" >/dev/null || fail 'missing scoped-authoring guardrail guidance in bare-hub runbook'
grep -F 'bin/new-worktree' "$bare_hub_runbook" >/dev/null || fail 'missing managed creation command guidance in bare-hub runbook'
grep -F 'bin/retire-worktree' "$bare_hub_runbook" >/dev/null || fail 'missing managed retirement command guidance in bare-hub runbook'

grep -F '## Managed local retirement' "$bare_hub_runbook" >/dev/null || fail 'missing local managed retirement heading in bare-hub runbook'
grep -F 'remote branch deletion remains out of scope for v1' "$bare_hub_runbook" >/dev/null || fail 'missing explicit remote-branch non-goal wording in bare-hub runbook'

printf 'PASS test_managed_worktree_lane_safety_policy\n'
