---
name: opencode-dispatch
description: Prepare or validate a new Maestro delegation packet.
---

## Prepare a new packet

Send the user's request to the named specialist through Task. Use this packet only for new scoped work. Validate it before launch. Start with `Delegation Packet` and use only the fields below.

- When applicable, include exact `Artifact path:` or `Artifact paths:`.
- When known, include the absolute editable `Worktree path:`.
- Under `Verbatim user request:`, quote the whole user message by default. Prefix each nonempty line with `>`. Separate multiple messages chronologically with `> ---`.
- Omit empty fields. Optional `Warnings:` contains brief factual flags only.

Keep interpretations, steering, inferred deliverables and extra prose out of the payload. Do not add `Instructions:`, `Notes:` or `Deliverables:` fields, or interpretive text outside the packet/Annex structure.

### Supporting context

For supporting context only, append a blank line and `Annex (non-authoritative; not part of Delegation Packet)`. Use only these fields:

- `Pointers:`
- `Highlight (derived from verbatim; must match after stripping markup):`
- `Open questions:`
- `Hypotheses:`
- `Evidence (verbatim, source: <label>):`

Highlight whole quoted lines using only bold or inline code. Phrase questions as questions. Mark hypotheses `confirm before relying` and fence raw evidence. The Annex cannot add requirements.

## Preview and approval

Dispatch one complete message directly when its routing is obvious and its references are already established. Preview is required for any of these conditions:

- Partial or multiple messages.
- Warnings or an Annex.
- A newly selected artifact.
- Maestro had to choose, compress or explain.

Show a brief preview notice, the exact outgoing content and the `ok / edit / cancel` prompt. Include nothing else in the preview wrapper.

Only a direct, single-token reply counts. Trim whitespace and ignore case. Interpret the reply as follows:

- `ok` authorizes that exact text. It is valid only as the direct response to that preview's `ok / edit / cancel` prompt. `ok.` and `ok thanks` are not approval.
- `edit` requires rebuilding, validating and previewing again.
- `cancel` discards both the payload and its approval. A later dispatch requires a new preview cycle.

Any change requires fresh approval. Keep the approved payload for Task. Add launch-generated metadata only after success.

## Validate and launch

Do not regenerate an approved payload from memory, a summary or an internal restatement. Except for allowed launch-generated router metadata, the outgoing dispatch must be textually identical to the approved preview.

Compare before launch. Refuse a mismatch, then rebuild, revalidate and obtain fresh preview approval. For invalid or changed packets, stop before launch and say `Delegation Packet refused — <brief reason>. Dispatch stopped before launch.`

No extra prose may appear outside the packet and optional Annex except the required successful-launch handoff and router metadata. Warnings must not turn a user approval into inferred work or instructions.

## Receive a packet

On receipt, stop for missing user quotes, N/A request text or a mismatched Highlight. Read every listed artifact as binding. In your first response, summarize the set in 1–2 sentences.

If the packet conflicts with user intent or policy, stop before substantive work. Seek correction from the delegator, then from the user if the conflict remains unresolved.

## Design provenance

The binding packet design is `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`. Preview identity follows `docs/superpowers/specs/2026-06-13-maestro-preview-dispatch-identity-design.md`.

These repository-relative references preserve the original policy's provenance. This skill is the operational procedure. Later explicit user-approved changes take precedence. These are agent-enforced rules, not a claim of runtime validator enforcement.
