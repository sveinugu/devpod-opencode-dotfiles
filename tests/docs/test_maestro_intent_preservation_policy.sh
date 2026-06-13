#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"

rg -n 'Before Task launch for new scoped delegation, validate the packet against the canonical pre-dispatch checks in AGENTS\.' "$maestro" >/dev/null
rg -n 'Refuse malformed or interpretive packets instead of silently correcting them\.' "$maestro" >/dev/null
rg -n 'If validation fails, stop before launch, do not emit the handoff wording, and do not emit `Session:` / `Resume:` metadata for a launch that did not occur\.' "$maestro" >/dev/null
rg -n 'Use refusal wording equivalent to: `Delegation Packet refused — <brief reason>\. Dispatch stopped before launch\.`' "$maestro" >/dev/null
rg -n 'If a single full user message is sufficient, quote that whole message by default\.' "$maestro" >/dev/null
rg -n 'If quoting only part of a user message is necessary, treat the packet as non-trivial and preview-gated\.' "$maestro" >/dev/null
rg -n 'Preview any non-trivial packet before dispatch by showing the exact outgoing packet and obtaining explicit user approval\.' "$maestro" >/dev/null
rg -n 'If Maestro had to choose, compress, or explain, preview is mandatory\.' "$maestro" >/dev/null
rg -n 'Runtime/plugin enforcement is deferred in this slice; follow the policy manually until a later automation layer exists\.' "$maestro" >/dev/null
rg -n 'Delegation Packet \+ Annex rules are defined in `\.config/opencode/AGENTS\.md` → “Delegation & Sessions \(canonical\)”\.' "$maestro" >/dev/null
rg -n 'Maestro-side prevention for new scoped delegation' "$agents" >/dev/null
rg -n 'Do not silently spawn a new session' "$agents" >/dev/null
rg -n 'route the message to that session immediately and verbatim' "$agents" >/dev/null
rg -n 'Preserve resume tokens verbatim\. Do not rewrite, normalize, shorten, or absorb them\.' "$agents" >/dev/null
rg -n 'When the user says "switch", "continue", or something similarly resumptive, first check whether they most likely mean an existing relevant session before spawning a new one\.' "$maestro" >/dev/null
rg -n 'If a valid `\$<task_id>` token is present, route the message to that session immediately and verbatim\.' "$maestro" >/dev/null

printf 'PASS test_maestro_intent_preservation_policy\n'
