#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"
fail=0

check() {
    local label="$1"
    local pattern="$2"
    local file="$3"
    if rg -n "$pattern" "$file" >/dev/null 2>&1; then
        printf '  ✓ %s\n' "$label"
    else
        printf '  ✗ %s (not found in %s)\n' "$label" "$file"
        fail=1
    fi
}

printf 'Checking maestro.md mirrors canonical policy...\n'
check 'pre-dispatch validation pointer' \
    'Before Task launch for new scoped delegation, validate the packet against the canonical pre-dispatch checks in AGENTS\.' "$maestro"
check 'refuse interpretive packets' \
    'Refuse malformed or interpretive packets instead of silently correcting them\.' "$maestro"
check 'stop before launch on validation failure' \
    'If validation fails, stop before launch, do not emit the handoff wording, and do not emit `Session:` / `Resume:` metadata for a launch that did not occur\.' "$maestro"
check 'refusal wording format' \
    'Use refusal wording equivalent to: `Delegation Packet refused — <brief reason>\. Dispatch stopped before launch\.`' "$maestro"
check 'full message default' \
    'If a single full user message is sufficient, quote that whole message by default\.' "$maestro"
check 'partial quote is non-trivial' \
    'If quoting only part of a user message is necessary, treat the packet as non-trivial and preview-gated\.' "$maestro"
check 'non-trivial preview wrapper' \
    'Preview any non-trivial packet with a separate preview wrapper that shows the exact outgoing dispatch content and explicitly asks for `ok / edit / cancel`\.' "$maestro"
check 'ok binds exact preview' \
    '`ok` approves only the exact previewed content and is valid only as the direct response to that explicit preview prompt\.' "$maestro"
check 'edit semantics' \
    '`edit` invalidates the pending approval and requires rebuild → revalidate → re-preview → fresh `ok`\.' "$maestro"
check 'cancel semantics' \
    '`cancel` terminates the active preview/dispatch attempt and requires a completely new preview cycle before any later dispatch of that work\.' "$maestro"
check 'changed payload re-preview' \
    'If any non-trivial payload changes after preview, revalidate it, re-preview the exact updated dispatch content, and obtain a fresh `ok` before launch\.' "$maestro"
check 'refuse launch on mismatch' \
    'Refuse launch if the outgoing dispatch differs from the approved preview\.' "$maestro"
check 'preview-mandatory when choosing' \
    'If Maestro had to choose, compress, or explain, preview is mandatory\.' "$maestro"
check 'runtime enforcement deferred' \
    'Runtime/plugin enforcement is deferred in this slice; follow the policy manually until a later automation layer exists\.' "$maestro"
check 'packet + annex pointer to AGENTS' \
    'Delegation Packet \+ Annex rules are defined in `\.config/opencode/AGENTS\.md` → “Delegation & Sessions \(canonical\)”\.' "$maestro"
check 'resume token routing' \
    'If a valid `\$<task_id>` token is present, route the message to that session immediately and verbatim\.' "$maestro"
check 'switch/continue session check' \
    'When the user says "switch", "continue", or something similarly resumptive, first check whether they most likely mean an existing relevant session before spawning a new one\.' "$maestro"

printf 'Checking AGENTS.md canonical policy has identity contract...\n'
check 'router metadata exempt from preview' \
    'Router-owned metadata \(`Session:`, `Resume:`, `Owner:`, `Authority:`\) is exempt from the preview requirement because those fields are launch-generated and populated only after Task returns\.' "$agents"
check 'ok/edit/cancel defined' \
    'The valid control responses are `ok`, `edit`, and `cancel`\.' "$agents"
check 'ok direct response only' \
    '`ok` is valid only as the direct response to the preview prompt that explicitly offered `ok / edit / cancel`\.' "$agents"
check 'no post-approval regeneration' \
    'After preview approval, Maestro must not regenerate the outgoing dispatch from memory, from a summary, or from an internal restatement\.' "$agents"
check 'outgoing textually identical' \
    'For non-trivial delegation, the outgoing dispatch must be textually identical to the approved previewed content, except for allowed launch-generated router metadata when those values were not yet available during preview\.' "$agents"
check 'refuse launch on mismatch' \
    'If the outgoing dispatch differs from the approved preview, Maestro must refuse launch before Task/subagent launch\.' "$agents"
check 'Warnings factual only' \
    '`Warnings:` remains limited to short factual flags only\.' "$agents"
check 'Warnings no steering' \
    '`Warnings:` must not contain implied action, task extraction, implementation steering, disguised instructions, or expanded interpretations of a user `ok`\.' "$agents"
check 'Maestro-side prevention' \
    'Maestro-side prevention for new scoped delegation' "$agents"
check 'no silent spawn' \
    'Do not silently spawn a new session' "$agents"
check 'verbatim routing' \
    'route the message to that session immediately and verbatim' "$agents"
check 'resume token preservation' \
    'Preserve resume tokens verbatim\. Do not rewrite, normalize, shorten, or absorb them\.' "$agents"

if [ "$fail" -eq 0 ]; then
    printf '\nPASS test_maestro_intent_preservation_policy\n'
else
    printf '\nFAIL test_maestro_intent_preservation_policy — some anchors were missing\n'
    exit 1
fi
