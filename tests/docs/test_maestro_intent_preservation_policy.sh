#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"
templates="$repo_root/docs/superpowers/templates/subagent-handoff-templates.md"

rg -n '^## Intent-preserving delegation packet$' "$agents" >/dev/null
rg -n 'Artifact path:' "$agents" >/dev/null
rg -n 'Active slice:' "$agents" >/dev/null
rg -n 'Verbatim user context:' "$agents" >/dev/null
rg -n 'Deliverables:' "$agents" >/dev/null
rg -n 'Non-deliverables:' "$agents" >/dev/null
rg -n 'Provenance:' "$agents" >/dev/null
rg -n 'No silent extra deliverables' "$agents" >/dev/null
rg -n 'prefer lossless routing over reinterpretation' "$agents" >/dev/null
rg -n 'Subagent restatement:' "$agents" "$templates" >/dev/null
rg -n 'Artifact path:' "$templates" >/dev/null
rg -n 'Active slice:' "$templates" >/dev/null
rg -n 'Verbatim user context:' "$templates" >/dev/null
rg -n 'Non-deliverables:' "$templates" >/dev/null
rg -n 'Prefer lossless routing over reinterpretation' "$maestro" >/dev/null
rg -n 'No silent extra deliverables' "$maestro" >/dev/null
rg -n 'Artifact path:' "$maestro" >/dev/null
rg -n 'Verbatim user context:' "$maestro" >/dev/null
rg -n 'Provenance:' "$maestro" >/dev/null
rg -n 'switch' "$agents" "$maestro" >/dev/null
rg -n 'continue' "$agents" "$maestro" >/dev/null
rg -n 'Do not silently spawn a new session' "$agents" "$maestro" >/dev/null
rg -n 'route the message to that session immediately and verbatim' "$agents" "$maestro" >/dev/null
rg -n 'Preview:' "$maestro" "$templates" >/dev/null
rg -n 'available on request before dispatch' "$maestro" "$templates" >/dev/null

printf 'PASS test_maestro_intent_preservation_policy\n'
