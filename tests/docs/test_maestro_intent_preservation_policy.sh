#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"

rg -n '^## Delegation Packet$' "$agents" >/dev/null
rg -n 'Allowed packet fields:' "$agents" >/dev/null
rg -n 'Verbatim user request:' "$agents" >/dev/null
rg -n 'Warnings:' "$agents" >/dev/null
rg -n 'Forbidden packet content:' "$agents" >/dev/null
rg -n 'Instructions:' "$agents" >/dev/null
rg -n 'Summary:' "$agents" >/dev/null
rg -n 'Deliverables:' "$agents" >/dev/null
rg -n 'Provenance:' "$agents" >/dev/null
rg -n 'Active slice:' "$agents" >/dev/null
rg -n 'Preview:' "$agents" >/dev/null
rg -n 'closed schema' "$agents" >/dev/null
rg -n 'If delegation would require interpretation, Maestro must ask the user instead of inferring' "$agents" >/dev/null
rg -n 'switch' "$agents" "$maestro" >/dev/null
rg -n 'continue' "$agents" "$maestro" >/dev/null
rg -n 'Do not silently spawn a new session' "$agents" >/dev/null
rg -n 'route the message to that session immediately and verbatim' "$agents" >/dev/null
rg -n 'Allowed packet fields are limited to' "$maestro" >/dev/null
rg -n 'Do not add interpretative summaries, inferred deliverables' "$maestro" >/dev/null
rg -n 'Preview:' "$maestro" >/dev/null

printf 'PASS test_maestro_intent_preservation_policy\n'
