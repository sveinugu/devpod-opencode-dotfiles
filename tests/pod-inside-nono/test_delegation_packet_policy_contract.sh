#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_delegation_packet_policy_contract'

policy="$repo_root/.config/opencode"
packet="$policy/skills/opencode-dispatch/SKILL.md"
template="$repo_root/docs/superpowers/templates/subagent-handoff-templates.md"
rg -qF 'opencode-dispatch' "$policy/AGENTS.md"
rg -qF 'opencode-dispatch' "$policy/agents/maestro.md"

# Keep the example usable with the actual packet and preview protocol.
for literal in 'Artifact path:' 'Worktree path:' 'Verbatim user request:' 'Warnings:' \
    'Annex (non-authoritative; not part of Delegation Packet)' 'Pointers:' \
    'Open questions:' 'Hypotheses:' 'confirm before relying' 'Evidence (verbatim, source:' \
    'ok / edit / cancel'; do
  for file in "$packet" "$template"; do
    grep -qF -- "$literal" "$file" || { echo "Missing $literal in $file" >&2; exit 1; }
  done
done
if rg -n '^(Instructions|Active slice|Deliverables|Non-deliverables|Provenance):' "$template" "$packet"; then
  echo 'Unexpected packet field' >&2
  exit 1
fi
rg -qF '> ---' "$packet"
rg -qF 'Any change requires fresh approval' "$packet"
rg -qF 'stop before launch' "$packet"
rg -qF 'Read every listed artifact' "$packet"

# Remote policy exceptions retain their checks at the new policy locations.
workflow="$policy/skills/delivery-workflow/SKILL.md"
rg -qF 'A general agent may perform named-specialist responsibilities when the human requests it, without a Maestro override.' "$policy/AGENTS.md"
rg -qF 'The human and agent may explicitly agree to waive pre-implementation approval checkpoints, including written or committed planning artifacts.' "$workflow"
rg -qF 'This agreement does not waive planning, workspace safety, TDD, refactoring, or verification.' "$workflow"
for file in "$policy/skills/opencode-sessions/SKILL.md" "$template"; do
  rg -qF 'Authority: the owning subagent owns this scope, subject to the general-agent exception and any human-approved Maestro override' "$file"
done
rg -qF 'including named-specialist responsibilities when the human requests it' "$policy/agents/general.md"

printf 'PASS test_delegation_packet_policy_contract\n'
