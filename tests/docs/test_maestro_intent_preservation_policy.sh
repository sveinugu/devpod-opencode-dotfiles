#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"

rg -n '^## Intent-preserving delegation packet$' "$agents" >/dev/null
rg -n 'Artifact path:' "$agents" >/dev/null
rg -n 'Active slice:' "$agents" >/dev/null
rg -n 'Verbatim user context:' "$agents" >/dev/null
rg -n 'Deliverables:' "$agents" >/dev/null
rg -n 'Non-deliverables:' "$agents" >/dev/null
rg -n 'Provenance:' "$agents" >/dev/null
rg -n 'No silent extra deliverables' "$agents" >/dev/null
rg -n 'prefer lossless routing over reinterpretation' "$agents" >/dev/null

printf 'PASS test_maestro_intent_preservation_policy\n'
