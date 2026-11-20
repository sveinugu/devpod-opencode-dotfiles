#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_maestro_intent_preservation_policy'

policy="$repo_root/.config/opencode"
router="$policy/agents/maestro.md"
sessions="$policy/skills/opencode-sessions/SKILL.md"
override="$policy/skills/maestro-override/SKILL.md"

for role in brainstormer planner senior-implementer policy-implementer docs-writer code-reviewer docs-reviewer-gpt docs-reviewer-claude general; do
  test -s "$policy/agents/$role.md"
  rg -qF -- "\`$role\`" "$router" || { echo "Missing route to $role" >&2; exit 1; }
done
test ! -e "$policy/agents/docs-reviewer.md" || { echo 'Obsolete docs-reviewer agent still present' >&2; exit 1; }
rg -qF 'opposite model family from the author' "$router" || { echo 'Missing opposite-family review routing' >&2; exit 1; }
for skill in opencode-dispatch opencode-sessions maestro-override; do
  rg -qF -- "\`$skill\`" "$router"
  rg -qxF "name: $skill" "$policy/skills/$skill/SKILL.md"
done
for field in 'Session: <task_id>' 'Resume: $<task_id> <your reply>' 'Owner: <subagent>' 'Authority:'; do
  rg -qF -- "$field" "$sessions"
done
rg -qF 'remaining payload verbatim to that exact session' "$sessions"
rg -qF 'wait for explicit direction before retrying' "$sessions"
for rule in 'Before every new launch, check for an existing session of the same role covering overlapping work.' \
    'Completion does not discard the session: route follow-up questions, review revisions and adjustments to the existing owner even after it reports finished.' \
    'Do not launch a second same-role session for overlapping work without explicit user direction.' \
    'Recovery may restore routing context but must not reconstruct user intent from a paraphrase; ask if interpretation is needed.'; do
  rg -qF -- "$rule" "$sessions" || { echo "Missing continuity rule: $rule" >&2; exit 1; }
done
for rule in 'When a specialist-owned skill says “you”, it means the owning specialist, not Maestro.' \
    'Monitor delegated TDD and intervene when implementers violate it.' \
    'Before advancing or declaring completion, verify that subagents actually performed verification and that plans follow specs and implementations follow plans.'; do
  rg -qF -- "$rule" "$router" || { echo "Missing supervision rule: $rule" >&2; exit 1; }
done
workflow="$policy/skills/delivery-workflow/SKILL.md"
for rule in 'Maestro, senior-implementer and junior-implementer must not use `executing-plans`; policy-implementer uses it for policy and document plans.' \
    '| Maestro | `subagent-driven-development`, `dispatching-parallel-agents`, `using-git-worktrees`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review` |' \
    '| senior-implementer | `subagent-driven-development`, `dispatching-parallel-agents`, `using-git-worktrees`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review`, `systematic-debugging`, `test-driven-development` |' \
    '| junior-implementer | `test-driven-development`, `receiving-code-review`, `systematic-debugging` (only for assigned debugging) |' \
    '| policy-implementer | `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`, `receiving-code-review`, `test-driven-development` |' \
    '| brainstormer | `brainstorming`, `receiving-code-review` |' \
    '| planner | `writing-plans`, `writing-skills`, `test-driven-development`, `receiving-code-review` |' \
    '| docs-writer | `receiving-code-review` |' \
    '| code-reviewer, docs-reviewer-gpt, docs-reviewer-claude | `requesting-code-review`, `test-driven-development` |'; do
  rg -qF -- "$rule" "$workflow" || { echo "Missing skill assignment: $rule" >&2; exit 1; }
done
rg -qF 'Ensure delegated juniors follow TDD and perform verification before accepting their work.' "$policy/agents/senior-implementer.md"
rg -qF 'Keep policy and documentation cross-references current when changing their targets.' "$policy/AGENTS.md"
rg -qF 'Run the relevant document-contract tests in their required execution context when changing policy; report checks that could not run.' "$policy/AGENTS.md"
rg -qF 'One human message, `maestro-override: <short scope>`, authorizes that scope immediately.' "$override"
rg -qF 'No confirmation message is needed.' "$override"
rg -qF 'at most 120 characters' "$override"
rg -qF 'Refused — outside override scope:' "$override"
rg -qF 'Override completed — exiting override mode.' "$override"
if rg -n 'maestro-override-confirm|two-message|two-step|two consecutive human messages|Override requested, please confirm' \
    "$policy/AGENTS.md" "$policy/agents" "$policy/skills" "$repo_root/CLAUDE.md"; then
  echo 'Obsolete Maestro confirmation requirement in active policy' >&2
  exit 1
fi

printf 'PASS test_maestro_intent_preservation_policy\n'
