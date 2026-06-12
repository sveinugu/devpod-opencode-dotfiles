# Maestro Delegation Packet Prevention (Policy-Only Design)

Date: 2026-06-12  
Status: Proposed (direction approved by user; written spec pending review)

## Problem

The current delegation policy defines a strong **subagent-side** stop-rule for malformed `Delegation Packet` messages, but it does not define an equally strong **Maestro-side prevention rule** before dispatch.

In practice, this allows a weak or eager Maestro to do the following before a subagent ever gets a chance to refuse:

- paraphrase the user instead of quoting them verbatim
- add forbidden packet fields such as `Instructions:` or `Summary:`
- smuggle inferred scope or deliverables into `Warnings:` or surrounding prose
- choose a subset of prior user messages without surfacing that judgment
- dispatch first and “verify” later

This makes the closed-schema packet policy real only on paper. The subagent stop-rule remains necessary, but it is too late to be the primary defense.

## Scope

This design is a **policy-only revamp** for **Maestro-side prevention**.

It intentionally does **not** change the settled subagent-side stop-rule (`stop → ask delegator → ask user`) and does **not** introduce runtime/plugin enforcement in this slice.

## Goals

- Make malformed `Delegation Packet` dispatches a policy violation at the Maestro layer, not merely a subagent cleanup problem.
- Define explicit **pre-dispatch gates** that must pass before Maestro may call Task / launch a subagent.
- Define explicit **refusal behavior** when the packet is malformed or interpretive.
- Preserve low-friction dispatch for trivial packets while forcing review of non-trivial, judgment-heavy packets.
- Create a policy shape that can later be automated without redesign.

## Non-goals

- Do not redesign the closed schema of `Delegation Packet`.
- Do not weaken or replace the existing subagent stop-rules.
- Do not implement runtime validators, packet-builder APIs, audit logging, or plugins in this slice.
- Do not require preview/approval for every trivial dispatch.

## Diagnosis

### 1. Enforcement is asymmetric

The canonical chapter gives subagents a concrete malformed-packet response, but Maestro mainly receives formatting and routing rules. The missing piece is a hard sentence that says: **if the packet fails validation, Maestro must not dispatch it**.

### 2. The current checklist verifies too late

The canonical anti-scatter checklist currently ends with verification after dispatch. That makes packet checking advisory. For prevention, validation must become a precondition to dispatch, not a retrospective review step.

### 3. “Helpful interpretation” still has an escape hatch

The current policy forbids extra fields and paraphrase, but it does not fully define what Maestro must do when packet assembly requires judgment. Without a preview/approval rule, Maestro can still choose, compress, and explain while technically appearing to follow the schema.

### 4. Packet assembly is under-specified

The policy clearly defines what a valid packet looks like, but is weaker on the process for producing one. In practice, Maestro needs a sequential pre-dispatch workflow: gather exact quotes, choose artifact path, decide whether the packet is trivial or interpretive, then either dispatch or stop.

## Chosen Policy Direction

Adopt a **strict Maestro pre-dispatch gate** while keeping user friction targeted.

- **Trivial packets** may dispatch without preview.
- **Non-trivial packets** require exact-packet preview and explicit user approval.
- **Malformed packets** must be refused before Task is called.

Umbrella rule:

> If Maestro had to choose, compress, or explain, preview is mandatory.

## Policy Changes

### 1. Add a Maestro pre-dispatch prohibition

The canonical chapter should explicitly state:

> Maestro MUST NOT call Task / launch a subagent for new scoped delegation until the `Delegation Packet` has passed the Maestro pre-dispatch checks defined below.

And:

> If the packet fails any pre-dispatch check, Maestro MUST refuse dispatch, MUST NOT emit the required handoff wording, MUST NOT fabricate session metadata, and MUST instead surface the failure and seek correction.

This is the missing Maestro-side equivalent of the existing subagent stop-rule.

### 2. Replace post-dispatch verification with pre-dispatch validation

The anti-scatter checklist should be reordered so validation happens before Task launch.

Recommended canonical sequence:

1. Identify target subagent and confirm this is new scoped delegation.
2. Collect exact `Artifact path:` / `Artifact paths:` if any.
3. Collect exact user message text for `Verbatim user request:`.
4. Assemble packet using allowed fields only.
5. Run Maestro pre-dispatch checks.
6. If packet is non-trivial, preview exact packet and obtain explicit approval.
7. Only then call Task / launch the subagent.
8. After successful launch, emit required handoff wording and validated session metadata.

This keeps verification as a gate, not a hope.

### 3. Define Maestro pre-dispatch checks explicitly

For policy purposes, Maestro must check all of the following before dispatch:

1. **Allowed fields only**
   - Packet contains only allowed packet fields.
   - No `Instructions:`, `Notes:`, `Summary:`, `Deliverables:`, `Preview:`, or other extra fields.

2. **Verbatim quoting contract satisfied**
   - `Verbatim user request:` contains one or more `>`-quoted user lines.
   - Multi-message quoting uses `> ---` only when required.
   - Quotes are verbatim user-authored text, not paraphrase.

3. **Warnings discipline**
   - `Warnings:` is omitted when empty.
   - If present, entries are brief factual flags only.
   - `Warnings:` must not contain imperatives, inferred deliverables, or implementation steering.

4. **Artifact-path discipline**
   - Any artifact path is exact.
   - If the selected artifact is newly introduced or not clearly established, the packet is non-trivial and must go through preview.

5. **Packet/Annex boundary discipline**
   - No free-form text outside the required handoff wording line, packet block, and optional Annex block.
   - Annex, if present, uses only approved headings.

### 4. Define Maestro refusal behavior

If any pre-dispatch check fails, Maestro must stop before dispatch and do all of the following:

1. Say that the `Delegation Packet` is refused.
2. Name the failure category briefly (for example: forbidden field, missing verbatim quotes, interpretive warning, ambiguous artifact selection).
3. Do **not** call Task.
4. Do **not** emit subagent handoff wording.
5. Do **not** emit `Session:` / `Resume:` metadata for a launch that did not occur.
6. Ask for correction from the human when needed.

Recommended exact refusal style:

> `Delegation Packet refused — <brief reason>. Dispatch stopped before launch.`

The exact wording can vary in implementation, but the policy must require this behavior.

### 5. Distinguish trivial vs non-trivial packets

The policy should explicitly define when preview is required.

#### Trivial packet

A packet is trivial only if all of the following are true:

- one full user message is quoted verbatim
- no `Warnings:`
- no Annex
- artifact path is already clear
- Maestro did not need to choose, compress, or explain

Trivial packets may dispatch without user preview after passing the pre-dispatch checks.

#### Non-trivial packet

A packet is non-trivial if any of the following are true:

1. `Warnings:` is non-empty
2. any Annex is present
3. `Verbatim user request:` includes multiple user messages
4. Maestro quotes only part of a user message instead of the full message
5. Maestro selects or introduces an `Artifact path:` that was not already clearly established
6. Maestro resolves ambiguity from context rather than routing from one obvious user message

For non-trivial packets, Maestro must show the **exact outgoing packet** and require explicit user approval before dispatch.

### 6. Make “full-message quoting” the default

The canonical policy already prefers quoting the entire relevant user message. This design strengthens that preference into a Maestro-side default:

- If a single full user message is sufficient, Maestro should quote that whole message.
- Partial-message quoting is allowed only when necessary.
- Partial-message quoting automatically makes the packet non-trivial and therefore preview-gated.

This reduces accidental “compression by excerpting.”

### 7. Keep resume-token routing separate

This design does not change the rule that explicit `$<task_id>` resume messages route verbatim and are not new `Delegation Packet` dispatches.

The prevention policy applies to **new scoped delegation**, not ordinary session resume.

## Required Policy Edits

### `.config/opencode/AGENTS.md`

Add a new Maestro-side prevention subsection inside the canonical chapter that defines:

- the pre-dispatch prohibition
- the pre-dispatch checks
- the refusal behavior
- the trivial vs non-trivial preview gate
- the reordered anti-scatter checklist

### `.config/opencode/agents/maestro.md`

Add Maestro-operational language that mirrors the canonical rule without redefining the packet schema. The Maestro prompt should explicitly say that it must:

- validate the packet before Task launch
- refuse malformed packets instead of “fixing them silently”
- preview any non-trivial packet before dispatch

## Future Automation Hook (deferred)

This policy should be written so a later runtime validator can implement it directly, but no runtime/plugin work is part of this slice.

In particular, later automation should be able to enforce:

- pass/fail pre-dispatch validation
- preview gating for non-trivial packets
- refusal-before-launch semantics

That future work is intentionally deferred until the policy wording is stable.

## Acceptance Criteria

This design is satisfied when the resulting policy update does all of the following:

1. Gives Maestro an explicit **must-not-dispatch** rule for malformed packets.
2. Moves packet verification from an after-dispatch check to a pre-dispatch gate.
3. Defines required Maestro refusal behavior when validation fails.
4. Defines a clear trivial vs non-trivial preview rule.
5. Makes “if Maestro had to choose, compress, or explain, preview is mandatory” part of the policy.
6. Preserves the current subagent stop-rule unchanged.
7. Defers runtime/plugin enforcement explicitly rather than half-specifying it.

## Risks

### Too much preview friction

If preview is required too often, users will treat it as ritual. That is why preview is tied to judgment-heavy packets, not every packet.

### Policy drift between canonical chapter and Maestro prompt

If AGENTS.md and `maestro.md` diverge, Maestro will regress. The implementation slice should therefore update both surfaces together and keep `maestro.md` as a pointer plus Maestro-only operational rules.

### Continued “helpful” misuse of `Warnings:`

This remains the highest-risk loophole. The implementation slice should make the warnings discipline text sharp and testable in docs drift checks.

## Recommendation

Approve this as the follow-on design for the existing Delegation Packet canonical policy, then implement it as a documentation/policy update before any runtime/plugin enforcement work.
