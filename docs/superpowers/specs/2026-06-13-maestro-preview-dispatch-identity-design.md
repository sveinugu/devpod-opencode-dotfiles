# Maestro Preview/Dispatch Identity Contract (Policy Design)

Date: 2026-06-13  
Status: Proposed (direction approved by user; written spec pending review)

## Problem

The current delegation policy already defines a closed `Delegation Packet` schema, Maestro-side pre-dispatch checks, non-trivial preview gating, and a non-authoritative Annex.

However, a critical failure mode remains: Maestro can show one preview to the user, receive approval, and then dispatch materially different content to the subagent. In practice this appears as:

- preview text that contains interpretive or operational material outside the allowed packet/Annex structure
- a user approval reply being rewritten rather than quoted verbatim
- a new synthesized dispatch message being generated after approval
- free-form implementation instructions being appended outside the packet block

This breaks the point of preview approval. The user is not actually approving the dispatched payload; they are approving an earlier draft while Maestro silently turns that approval into authorization for a different message.

The core defect is therefore not merely “extra instructions were added.” The deeper defect is **post-approval payload drift**.

## Scope

This design is a policy-only follow-on to the existing Delegation Packet prevention work.

It tightens the delegation contract for **non-trivial Maestro → subagent dispatches** by defining what preview approval means, when `ok` is valid, and how exact previewed content relates to the final dispatched payload.

This slice does **not** implement runtime enforcement, plugins, packet-builder APIs, or logging infrastructure.

Relevant implementation surfaces for the follow-on include the canonical policy in `.config/opencode/AGENTS.md`, Maestro-operational guidance in `.config/opencode/agents/maestro.md`, and the local handoff template surface at `docs/superpowers/templates/subagent-handoff-templates.md` when that template contains wording or examples that would otherwise drift from the canonical contract.

## Goals

- Make non-trivial preview approval bind the exact outgoing payload rather than a later reinterpretation.
- Prevent Maestro from converting a user `ok` into authorization for inferred tasks, operational summaries, or rewritten instructions.
- Preserve the existing closed packet schema and Annex authority model.
- Keep the policy precise enough for later mechanical enforcement.
- Minimize user friction by using short explicit preview responses: `ok`, `edit`, `cancel`.

## Non-goals

- Do not add new Delegation Packet fields.
- Do not weaken or redesign the existing Annex rules.
- Do not require preview for trivial packets.
- Do not implement runtime validators, audit logging, or packet-freezing code in this slice.
- Do not reopen the already-settled question of whether the packet schema should remain closed.

## Diagnosis

### 1. Preview approval is currently underspecified

The policy requires preview for non-trivial packets, but it does not yet fully define the semantic meaning of the approval response. Without that narrow definition, Maestro can reinterpret `approve`/`yes`/`ok` as approval for a broader inferred operational plan.

### 2. The previewed payload is not treated as frozen

Current policy is strong about packet shape, but weaker about packet identity across the preview → launch boundary. That leaves room for Maestro to preview one message, then regenerate a “cleaner” or “more actionable” dispatch from memory.

### 3. Helpful orchestration prose can still escape after the packet

Even when packet validation is conceptually present, a weak Maestro may append a free-form “Please implement…” block after the packet. This effectively bypasses the closed schema and annex boundary rules in practice.

### 4. Short approval replies are convenient but need a narrow contract

The user prefers `ok` because it is fast to type. That is ergonomically correct, but it requires a precise rule so casual conversational `ok` messages do not accidentally authorize dispatch.

## Chosen Policy Direction

Keep the existing Delegation Packet and Annex structure, but tighten the preview/approval boundary into an identity contract:

- a non-trivial preview presents the exact outgoing dispatch content before launch
- a user reply of `ok` means only “dispatch this exact previewed content”
- after `ok`, Maestro must send that exact content, not a regenerated version
- if anything changes after preview, Maestro must revalidate, re-preview, and obtain a fresh `ok`

This turns preview from an advisory human-check step into a narrow protocol gate.

## Policy Changes

### 1. Preview wrapper structure is distinct from dispatch structure

The preview message for a non-trivial packet is **not** itself a dispatch message.

It has two layers:

1. a **preview wrapper** shown to the user before launch
2. the **exact previewed dispatch content** that will be sent if approved

The preview wrapper is not part of the outgoing dispatch payload.

The preview wrapper may contain only:

- a brief notice that preview is required because the packet is non-trivial
- the exact previewed dispatch content
- an explicit response prompt offering `ok / edit / cancel`

No other explanatory or operational prose is allowed in the preview wrapper.

This resolves the boundary difference between preview-time interaction and the stricter dispatch-time structure.

### 2. `ok` binds the exact preview only

For a non-trivial packet, Maestro must ask for a direct preview response using:

- `ok`
- `edit`
- `cancel`

When the user replies `ok`, that means only:

1. dispatch the exact previewed packet/Annex content
2. plus only allowed launch-generated router metadata if needed at launch time

`ok` does **not** authorize Maestro to:

- infer tasks
- restate the scope operationally
- add deliverables
- add implementation instructions
- rewrite the user’s response
- regenerate the payload in different words

### 3. Preview response tokens are exact control responses

The valid control responses are:

- `ok`
- `edit`
- `cancel`

Matching should be defined mechanically as:

- trim leading and trailing whitespace
- compare case-insensitively to exactly one token: `ok`, `edit`, or `cancel`

Examples that **do count**:

- `ok`
- `OK`
- ` edit `

Examples that **do not count**:

- `ok.`
- `ok thanks`
- `please edit`

Messages that do not match one of the exact control responses must not be treated as approval or cancellation tokens.

### 4. `ok` is valid only as the direct response to the preview prompt

To avoid accidental dispatch from casual conversational phrasing, `ok` counts as approval only when all of the following are true:

1. Maestro has just shown a non-trivial preview
2. Maestro has explicitly asked for `ok / edit / cancel`
3. `ok` is the user’s direct response to that preview prompt

Outside that exact interaction pattern, `ok` must not be treated as dispatch authorization.

### 5. `edit` and `cancel` semantics

When the user replies `edit`:

1. do not launch
2. invalidate any pending approval for the currently previewed payload
3. gather the requested change from the user
4. rebuild the candidate payload
5. revalidate it
6. show a fresh exact preview
7. require a fresh `ok` before launch

When the user replies `cancel`:

1. do not launch
2. terminate the current preview/dispatch attempt
3. discard the pending payload and approval state for that attempt
4. require a completely new preview cycle before any later dispatch of that work

`cancel` ends the active approval attempt; a later `ok` without a new preview must not revive the canceled dispatch.

### 6. No post-approval payload drift

After preview approval, Maestro must not regenerate the outgoing dispatch from memory, from a summary, or from an internal restatement.

The exact previewed dispatch content becomes the frozen outgoing payload.

If any content changes after preview — including packet lines, Annex lines, or any surrounding text — Maestro must:

1. revalidate the updated payload
2. re-preview the exact updated payload
3. obtain a fresh `ok` before launch

### 7. Preview/dispatch identity rule

For non-trivial delegation, the outgoing dispatch must be textually identical to the approved previewed content, except for allowed launch-generated router metadata when those values were not yet available during preview.

No other deltas are allowed.

In particular, the following are prohibited after approval unless re-previewed and re-approved:

- converting shorthand approval into an expanded task brief
- appending `Please implement...`
- appending `Tasks:` or `Deliverables:` blocks
- rewriting `Verbatim user request:` content
- adding new packet or Annex material

### 8. Refuse launch on preview/dispatch mismatch

If the outgoing dispatch differs from the approved preview, Maestro must refuse launch before Task/subagent launch.

Recommended refusal style:

`Delegation Packet refused — outgoing dispatch differs from approved preview. Dispatch stopped before launch.`

Required behavior:

1. do not call Task / launch the subagent
2. do not emit the required handoff wording
3. do not fabricate session metadata
4. show the corrected exact payload if continuing
5. require a fresh `ok` before launch

### 9. No free-form prose outside the allowed structure

For dispatch messages, outside the required handoff wording, packet block, and optional Annex block, no extra prose is allowed.

This explicitly forbids post-packet additions such as:

- `Please implement...`
- `Tasks:`
- `Deliverables:`
- operational summaries of what the user “really approved”

Preview messages follow the distinct preview-wrapper rule above; dispatch messages must follow the stricter handoff + packet + optional Annex structure.

### 10. Keep `Warnings:` narrow and factual

`Warnings:` remains limited to short factual flags only.

It must not contain:

- implied action
- task extraction
- implementation steering
- disguised instructions
- expanded interpretations of a user `ok`

This closes the most likely loophole for reintroducing post-approval interpretation inside an allowed field.

## Required Policy Edits

### `.config/opencode/AGENTS.md`

Add a follow-on subsection in `# Delegation & Sessions (canonical)` that defines:

- the `ok / edit / cancel` preview-response contract
- the rule that `ok` binds only the exact previewed content
- the no-post-approval-payload-drift rule
- the preview/dispatch identity rule
- refusal-before-launch behavior when previewed and outgoing payloads differ
- the explicit prohibition on free-form prose outside handoff wording + packet + optional Annex

The canonical wording should keep the existing closed schema and Annex model intact.

### `.config/opencode/agents/maestro.md`

Add Maestro-operational wording that mirrors the identity contract without redefining the packet schema. The prompt should explicitly say that Maestro must:

- ask for `ok / edit / cancel` on non-trivial previews
- treat `ok` as approval for the exact preview only
- treat `edit` as invalidating pending approval and requiring rebuild → revalidate → re-preview
- treat `cancel` as terminating the current preview/dispatch attempt
- refuse launch if the outgoing dispatch differs from the approved preview
- re-preview any changed non-trivial payload before launch

### `docs/superpowers/templates/subagent-handoff-templates.md`

Review the local handoff-template surface and update it if it contains wording or examples that would conflict with the preview/dispatch identity contract.

If the template does not contain relevant preview-time or dispatch-identity wording, it may remain unchanged, but the implementation follow-on should verify that explicitly rather than ignoring the surface.

### Docs-only contract tests

Update or add docs-contract checks so policy drift becomes visible when:

- preview responses are described inconsistently
- preview/dispatch identity rules disappear
- refusal-on-mismatch wording disappears
- extra-prose prohibitions disappear
- template examples contradict the preview/dispatch identity contract

## Acceptance Criteria

This design is satisfied when the resulting policy update does all of the following:

1. Defines that for non-trivial packet previews, `ok` means only “dispatch this exact previewed content.”
2. States that any change after preview requires revalidation, re-preview, and a fresh `ok`.
3. States that Maestro must refuse launch if the outgoing dispatch differs from the approved preview.
4. Explicitly forbids free-form prose outside the required handoff wording, packet block, and optional Annex block.
5. Keeps `Warnings:` limited to brief factual flags and forbids implied actions or task steering there.
6. Preserves the existing closed packet schema and Annex authority model.
7. Makes the rules precise enough that later validation/tooling can enforce them mechanically.
8. Defines operational semantics for `edit` and `cancel` that both prevent launch and require a fresh preview cycle before later dispatch.
9. Defines exact control-token matching tightly enough to distinguish `ok` from `ok thanks` or `ok.`.
10. Either updates the local handoff-template surface or explicitly verifies that it does not contradict the new contract.

## Risks

### Casual `ok` messages being misread as approval

If the policy is vague, a weak Maestro could treat any nearby `ok` as dispatch approval.

Mitigation: `ok` is valid only as the direct response to an explicit non-trivial preview prompt that offered `ok / edit / cancel`.

### Policy drift between canonical chapter and Maestro prompt

If AGENTS and `maestro.md` diverge, Maestro may regress into post-approval reinterpretation.

Mitigation: keep AGENTS canonical, keep `maestro.md` operational only, and cover the new anchors in docs-contract tests.

### Ritual preview without real identity checking

Preview can become empty ceremony if the dispatch is still regenerated after approval.

Mitigation: make payload identity, refusal-on-mismatch, and re-preview-on-change explicit policy requirements.

## Recommendation

Approve this as the next policy-design slice after Maestro-side prevention.

Implementation should remain docs/tests only in the immediate follow-on: update the canonical delegation chapter, update `maestro.md` to mirror only Maestro-operational rules, and add docs-contract checks for preview/dispatch identity before any runtime enforcement work.
