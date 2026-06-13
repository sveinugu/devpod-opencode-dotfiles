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
rg -n 'Preview any non-trivial packet with a separate preview wrapper that shows the exact outgoing dispatch content and explicitly asks for `ok / edit / cancel`\.' "$maestro" >/dev/null
rg -n '`ok` approves only the exact previewed content and is valid only as the direct response to that explicit preview prompt\.' "$maestro" >/dev/null
rg -n '`edit` invalidates the pending approval and requires rebuild → revalidate → re-preview → fresh `ok`\.' "$maestro" >/dev/null
rg -n '`cancel` terminates the active preview/dispatch attempt and requires a completely new preview cycle before any later dispatch of that work\.' "$maestro" >/dev/null
rg -n 'If any non-trivial payload changes after preview, revalidate it, re-preview the exact updated dispatch content, and obtain a fresh `ok` before launch\.' "$maestro" >/dev/null
rg -n 'Refuse launch if the outgoing dispatch differs from the approved preview\.' "$maestro" >/dev/null
rg -n 'Router-owned metadata \(`Session:`, `Resume:`, `Owner:`, `Authority:`\) is exempt from the preview requirement because those fields are launch-generated and populated only after Task returns\.' "$agents" >/dev/null
rg -n 'If Maestro had to choose, compress, or explain, preview is mandatory\.' "$maestro" >/dev/null
rg -n 'Runtime/plugin enforcement is deferred in this slice; follow the policy manually until a later automation layer exists\.' "$maestro" >/dev/null
rg -n 'Delegation Packet \+ Annex rules are defined in `\.config/opencode/AGENTS\.md` → “Delegation & Sessions \(canonical\)”\.' "$maestro" >/dev/null
rg -n 'The valid control responses are `ok`, `edit`, and `cancel`\.' "$agents" >/dev/null
rg -n '`ok` is valid only as the direct response to the preview prompt that explicitly offered `ok / edit / cancel`\.' "$agents" >/dev/null
rg -n 'After preview approval, Maestro must not regenerate the outgoing dispatch from memory, from a summary, or from an internal restatement\.' "$agents" >/dev/null
rg -n 'For non-trivial delegation, the outgoing dispatch must be textually identical to the approved previewed content, except for allowed launch-generated router metadata when those values were not yet available during preview\.' "$agents" >/dev/null
rg -n 'If the outgoing dispatch differs from the approved preview, Maestro must refuse launch before Task/subagent launch\.' "$agents" >/dev/null
rg -n '`Warnings:` remains limited to short factual flags only\.' "$agents" >/dev/null
rg -n '`Warnings:` must not contain implied action, task extraction, implementation steering, disguised instructions, or expanded interpretations of a user `ok`\.' "$agents" >/dev/null
rg -n 'Maestro-side prevention for new scoped delegation' "$agents" >/dev/null
rg -n 'Do not silently spawn a new session' "$agents" >/dev/null
rg -n 'route the message to that session immediately and verbatim' "$agents" >/dev/null
rg -n 'Preserve resume tokens verbatim\. Do not rewrite, normalize, shorten, or absorb them\.' "$agents" >/dev/null
rg -n 'When the user says "switch", "continue", or something similarly resumptive, first check whether they most likely mean an existing relevant session before spawning a new one\.' "$maestro" >/dev/null
rg -n 'If a valid `\$<task_id>` token is present, route the message to that session immediately and verbatim\.' "$maestro" >/dev/null

printf 'PASS test_maestro_intent_preservation_policy\n'
