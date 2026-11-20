---
name: opencode-dispatch
description: Prepare or validate a new Maestro delegation packet.
---

Send the named specialist the user's request through Task. Use this packet only for new scoped work. Validate it before launch. Start with `Delegation Packet` and use only the fields below.

- Include exact `Artifact path:` or `Artifact paths:` when applicable and the absolute editable `Worktree path:` when known.
- Under `Verbatim user request:`, quote the whole user message by default. Prefix each nonempty line with `>`. Separate multiple messages chronologically with `> ---`.
- Omit empty fields. Optional `Warnings:` contains brief factual flags only. Keep interpretations, steering, inferred deliverables and extra prose out of the payload.
- For supporting context only, append a blank line and `Annex (non-authoritative; not part of Delegation Packet)`. Use only `Pointers:`, `Highlight (derived from verbatim; must match after stripping markup):`, `Open questions:`, `Hypotheses:` or `Evidence (verbatim, source: <label>):`. Highlight whole quoted lines using only bold or inline code. Phrase questions as questions, mark hypotheses `confirm before relying`, and fence raw evidence. The Annex cannot add requirements.

Dispatch one complete message with obvious routing and already-established references directly. Preview is required for partial or multiple messages, warnings, an Annex, a newly selected artifact, or whenever Maestro had to choose, compress or explain.

Show a brief preview notice, the exact outgoing content, and `ok / edit / cancel`. Only a direct, single-token reply counts (trim whitespace, ignore case). `ok` authorizes that exact text. `edit` requires rebuilding, validating and previewing again. `cancel` discards the attempt. Any change requires fresh approval. Keep the approved payload for Task. Add launch-generated metadata only after success. For invalid or changed packets, stop before launch and say `Delegation Packet refused — <brief reason>. Dispatch stopped before launch.`

The preview wrapper permits only the brief notice, exact outgoing content and control prompt. `ok` is valid only as the direct response to that preview's `ok / edit / cancel` prompt; `ok.` and `ok thanks` are not approval. A cancelled attempt discards both payload and approval; later dispatch requires a new preview cycle.

Do not regenerate an approved payload from memory, a summary or an internal restatement. The outgoing dispatch must be textually identical to the approved preview, except for allowed launch-generated router metadata. Compare before launch; refuse a mismatch, then rebuild, revalidate and obtain a fresh preview approval. No extra prose may appear outside the packet and optional Annex except the required successful-launch handoff and router metadata. Warnings must not turn a user approval into inferred work or instructions.

On receipt, stop for missing user quotes, N/A request text or a mismatched Highlight. Read every listed artifact as binding and summarize the set in 1–2 sentences in your first response. For mismatches with user intent or policy, stop before substantive work and seek correction from the delegator, then the user if unresolved.

## Design provenance

The binding packet design is `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`; preview identity follows `docs/superpowers/specs/2026-06-13-maestro-preview-dispatch-identity-design.md`. These repository-relative references preserve the original policy's provenance. This skill is the operational procedure; later explicit user-approved changes take precedence. These are agent-enforced rules, not a claim of runtime validator enforcement.
