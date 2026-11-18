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

for role in brainstormer planner senior-implementer policy-implementer docs-writer code-reviewer docs-reviewer general; do
  test -s "$policy/agents/$role.md"
  rg -qF -- "\`$role\`" "$router" || { echo "Missing route to $role" >&2; exit 1; }
done
for skill in opencode-dispatch opencode-sessions maestro-override; do
  rg -qF -- "\`$skill\`" "$router"
  rg -qxF "name: $skill" "$policy/skills/$skill/SKILL.md"
done
for field in 'Session: <task_id>' 'Resume: $<task_id> <your reply>' 'Owner: <subagent>' 'Authority:'; do
  rg -qF -- "$field" "$sessions"
done
rg -qF 'remaining payload verbatim to that exact session' "$sessions"
rg -qF 'wait for explicit direction before retrying' "$sessions"
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
