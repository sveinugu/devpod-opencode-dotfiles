#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_clean_code_policy_contract'

policy="$repo_root/.config/opencode"
workflow="$policy/skills/delivery-workflow/SKILL.md"
rg -qF 'delivery-workflow' "$policy/AGENTS.md"
for rule in 'All agents must load `pragmatic-programmer` and `karpathy-guidelines`, including for design and planning.' \
    'For coding, refactoring and code review, also load `clean-code`.' \
    'Within user instructions, repository policy and approved scope, skill precedence is `pragmatic-programmer` → `karpathy-guidelines` → `clean-code` → `obra/superpowers`.'; do
  rg -qF -- "$rule" "$policy/AGENTS.md" || { echo "Missing shared policy: $rule" >&2; exit 1; }
done
# Preserve the local overrides that make the upstream Superpowers workflow pragmatic.
for rule in 'TDD does not mean unit testing: tests must describe specific behavior and functionality meaningful to the human partner, at the level that best drives the current goal.' \
    'Prioritize tests of individual software subcomponents only when they are generally useful or particularly important to the architecture.' \
    'Avoid tests coupled to low-level implementation details that make behavior-preserving refactoring require extensive test rewrites.' \
    'Use tests as exploratory devices to pin down interfaces, functionality, architecture and design with the human partner before writing the implementation.' \
    'When considering new interfaces or architectures, prioritize discussion with the human partner around those tests unless the human says otherwise.' \
    'Tests are primary deliverables of plans and define behavior, interfaces and scope for discussion with the user.' \
    'Plans and specs must stay high-level and must not prescribe detailed implementation steps unless the user explicitly requests them, even when `writing-plans` says otherwise.' \
    'Repository policy and `pragmatic-programmer` govern test-level selection, tracer-bullet scope and design trade-offs.' \
    '`obra/superpowers` governs tests-first execution discipline.' \
    '`clean-code` governs refactor quality and may override conflicting Superpowers cleanup techniques or code-quality heuristics; `pragmatic-programmer` wins over `clean-code`.' \
    '`clean-code` must not override user instructions, repository policy, approved artifacts, the chosen test level or test protection of behavior.'; do
  rg -qF -- "$rule" "$workflow" || { echo "Missing pragmatic workflow policy: $rule" >&2; exit 1; }
done
for rule in 'red → verify red → green → verify green → refactor → verify green' \
    'cleanup or why none was needed' 'pragmatic-programmer diagnostic and clean-code review' \
    'score below 8' 'reasons for deferral' \
    'For every TDD slice, perform a standalone refactor checkpoint after reaching green, even when no changes seem necessary.' \
    'Review the changed slice and nearby connected code for naming, duplication, boundaries, readability and small behavior-preserving cleanups.' \
    'Record follow-up cleanup items and rerun the relevant tests after refactoring.' \
    'Pause for human approval before a refactor changes behavior or makes a hard-to-reverse architectural change outside the approved slice.' \
    'Wait until the user is content before dispatching automated review, unless the user has instructed otherwise.' \
    'Before marking a feature done, run the pragmatic-programmer diagnostic and clean-code review' \
    'For material clean-code issues, list 1–3 cleanup/remediation tasks or explicit reasons for deferral.'; do
  rg -qF -- "$rule" "$workflow" || { echo "Missing delivery rule: $rule" >&2; exit 1; }
done
rg -qF '.config/opencode/AGENTS.md' "$policy/PULL_REQUEST_TEMPLATE.md"
test ! -f "$repo_root/opencode.json"
test ! -f "$repo_root/opencode.jsonc"

printf 'PASS test_clean_code_policy_contract\n'
