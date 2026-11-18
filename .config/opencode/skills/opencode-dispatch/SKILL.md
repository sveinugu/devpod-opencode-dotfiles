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

On receipt, stop for missing user quotes, N/A request text or a mismatched Highlight. Read every listed artifact as binding and summarize the set in 1–2 sentences in your first response. For mismatches with user intent or policy, stop before substantive work and seek correction from the delegator, then the user if unresolved.
