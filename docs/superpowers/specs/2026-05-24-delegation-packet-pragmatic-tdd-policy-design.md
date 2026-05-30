> **Historical — superseded by the approved design.** See `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md` for the current binding spec.
> This earlier spec is retained for context/history.

# Delegation Packet And Pragmatic TDD Policy Design

Date: 2026-05-24  
Status: Proposed

## Executive Summary

This design revises the current subagent delegation policy to better fit a pragmatic-programming-style TDD workflow with strong implementers. The main change is to replace the current `Execution Handoff` concept with a narrower `Delegation Packet`: a minimal, non-interpretive Maestro-to-subagent routing wrapper. Its job is to preserve exact references and user intent, not to restate, expand, or reinterpret the task.

The design also shifts planning policy upward in abstraction. Approved plans and specs should define goals, tests, constraints, known risks, and explicit `User Check-in` markers, but should not prescribe detailed implementation steps unless explicitly requested. Implementers are expected to work directly with the user through iterative pragmatic TDD, using tests as the primary collaboration and interface-design tool.

Finally, the design simplifies session-metadata ownership. Routing metadata such as `Session:` and `Resume:` is treated as router-owned and should be emitted by Maestro, not by ordinary subagents. This reduces boilerplate, aligns message requirements with what agents can actually know, and strengthens direct user-to-subagent communication through strict verbatim `$ses_<task-id>` routing.

## Goals

- Make Maestro-mediated delegation lossless and non-interpretive.
- Preserve the user as the primary source of truth for delegated work.
- Honor explicit user routing requests even when they bypass the default delegation workflow.
- Support pragmatic TDD with iterative user feedback and strong implementer discretion.
- Keep plans/specs at the right level: goals, tests, constraints, risks, and user check-ins.
- Prevent avoidable rework by requiring pauses before hard-to-reverse choices.
- Simplify message rules by assigning session metadata to the router layer.

## Non-Goals

- Do not remove the ability for Maestro to flag ambiguities, discrepancies, or missing formalities.
- Do not require acceptance-test documents to carry process-control markers.
- Do not force all handoff-like messages to use the same packet structure.
- Do not turn plans/specs into implementation scripts.
- Do not prevent implementers from proposing solutions that diverge from plan details.
- Do not allow Maestro to silently override an explicit user routing choice by substituting a different subagent or workflow.

## Core Problems To Solve

### Maestro reinterpretation drift

The existing policy shape encourages Maestro to summarize and reformulate tasks during delegation. In practice this makes Maestro a second planner and a competing source of truth, even when an approved artifact and a direct user instruction already exist.

### User routing intent being overridden by workflow defaults

The current skill- and subagent-oriented workflow can cause Maestro to redirect work to the nominally “correct” specialist even when the user explicitly asked to route the request elsewhere. This is especially harmful when the user is intentionally choosing a less formal or less process-heavy interaction mode.

### Overdesigned planning for low-powered implementers

The current process leans toward planner-authored execution detail intended to compensate for weaker implementers. With stronger implementers, this becomes counterproductive: plans become overdesigned, planners start effectively writing the implementation, and the human is pulled into constant correction of mediated summaries instead of collaborating directly on tests, interfaces, and feature boundaries.

### Excessive routing boilerplate on subagents

The current metadata rules require ordinary subagents to emit `Session:` and `Resume:` information they often do not actually know unless Maestro passed it down. This creates unnecessary boilerplate and makes the policy less truthful than it should be.

## Chosen Policy Direction

### 1. Replace `Execution Handoff` with `Delegation Packet`

`Delegation Packet` replaces `Execution Handoff` as the canonical Maestro-to-subagent delegation structure.

`Delegation Packet` is a transport envelope, not a reinterpretation step. Its purpose is to preserve exact references and user intent while allowing only narrowly-scoped non-authoritative warnings.

### 2. Use `Delegation Packet` only for Maestro → subagent scoped delegation

The packet should be used when Maestro is dispatching scoped work to a subagent. It should not be forced onto every other handoff-like message.

This means:

- Maestro → subagent new scoped work: use `Delegation Packet`
- Maestro → existing session resume: no packet unless this is effectively a new scoped delegation
- Subagent → user pause/question: no packet
- Subagent → Maestro completion: no packet

### 3. `Delegation Packet` contents are strictly limited

Allowed packet fields:

- `Artifact path:` or `Artifact paths:` when applicable, using exact path strings
- `Verbatim user request:` as a quoted block
- `Warnings:` only when non-empty
- router-owned metadata such as `Session:`, `Resume:`, `Owner:`, and `Authority:`

Forbidden packet content:

- interpretative summaries
- inferred deliverables
- inferred scope
- implementation steering beyond the approved artifact
- “helpful corrections” to user wording

### 4. `Warnings:` are allowed but non-authoritative

`Warnings:` is the only allowed Maestro-added context field inside the packet, and it is explicitly non-authoritative.

Allowed warning categories:

- ambiguity
- discrepancy with approved artifact
- missing formalities
- routing/admin facts

`Warnings:` must never override the artifact or the user’s verbatim request.

### 5. Maestro must ask instead of infer

If delegation would require interpretation, Maestro must ask the user instead of inferring or summarizing.

This applies both when an approved artifact exists and when delegation is artifact-free. Better one extra routing question than silent reinterpretation.

### 6. `$ses_<task-id>` routing is strict verbatim pass-through

When a user message begins with `$ses_<task-id>`, the content after the token is routed to the owning subagent verbatim and unchanged.

The subagent-facing payload begins immediately after the token and extends verbatim to the end of the user message.

Maestro may optionally emit a separate routing notice to the chat UI, but must not prepend, append, normalize, or otherwise contaminate the subagent-facing payload.

### 7. Explicit user routing requests override default routing policy

When the user explicitly requests a particular subagent or explicitly requests that work stay with the currently engaged general agent, Maestro must honor that routing choice even if default policy would otherwise prefer a different specialist workflow.

This override applies to routing choice, not to content authority. Once routed, the receiving agent still remains bound by the applicable approved artifact, user instructions, and repository policy for the scoped work.

Maestro may ask at most one routing/formality question if needed to identify the intended target, but must not redirect the work to a different subagent on the grounds that the different subagent would be more specialized or more policy-typical.

Example:

- If the user explicitly asks to discuss a policy clarification with the general agent rather than the brainstormer or planner, Maestro must honor that request.
- If the user explicitly routes to an existing `$ses_<task-id>` session, Maestro must route there verbatim even if another subagent would normally own that type of work.

## Planning And Implementation Policy

### 1. Approved artifact is enough to start

If a plan, spec, acceptance-test document, or similar approved artifact already defines the task at the right level, Maestro must not require a separate execution or implementation plan by default.

The approved artifact is the task reference. `Delegation Packet` only routes to it.

For policy, documentation, and similarly bounded process changes, an approved spec may serve directly as the implementation authority when it already defines the work at the correct level. In those cases, Maestro may route directly from the approved spec to the implementing subagent without demanding a separate planner-authored implementation plan.

### 2. Planner artifacts should stay high-level

Plans and specs should define:

- goals
- tests / acceptance criteria
- constraints
- known risks
- `User Check-in` markers

Plans and specs should not prescribe detailed implementation steps unless the user explicitly asks for that level of detail.

Acceptance-test documents should remain behavioral and should not carry `User Check-in` markers.

### 3. Implementers should use pragmatic TDD with direct user feedback

Implementers should work directly with the user through a pragmatic TDD process.

Tests are the primary basis for refining:

- interface shape
- feature boundaries
- behavior

The approved artifact guides the work, but is not a line-by-line execution script.

### 4. Divergence from plan detail is allowed with explicit surfacing

Implementers may propose solutions that diverge from details implied by a plan or spec. That is acceptable when the divergence is surfaced explicitly and reviewed before it hardens into costly downstream work.

Tests and direct user feedback take precedence over stale implementation detail in a plan, subject to explicit review where required.

### 5. Pause before hard-to-reverse choices

Implementers may explore freely, but must pause before cementing hard-to-reverse choices.

This is especially important for:

- interfaces
- test semantics
- architecture boundaries
- other choices likely to cause significant rework if changed later

If ownership is unclear, the implementer should ask before doing dependent work that would lock the choice in.

### 6. `User Check-in` markers are mandatory pause points

Plans and specs may contain `User Check-in` markers. These are normative, not advisory.

Each `User Check-in` should include a short reason, for example:

`User Check-in: confirm interface boundary before dependent work`

Even when no explicit marker exists, the fallback policy remains: pause before hard-to-reverse choices if ownership is unclear.

## Session Metadata Ownership

### 1. Session metadata is router-owned

Session and resume metadata are routing concerns and should be owned by Maestro or another delegating/router agent.

Ordinary subagents should not be required to emit `Session:` / `Resume:` metadata.

### 2. Remove ordinary-subagent resume-formatting requirements

The policy and ordinary subagent specs should remove mandatory resume-formatting sections and other message requirements that assume the subagent knows exact router metadata.

Exception: subagents that themselves delegate work, such as `senior-implementer`, inherit router obligations for the child session they create.

### 3. Maestro must surface metadata at orchestration boundaries

Maestro should print session metadata when:

- dispatching a subagent
- resuming an existing subagent session
- immediately after control is handed back from a subagent

This keeps routing visibility at the layer that actually owns and knows the routing state.

## Failed Resume And Recovery Alignment

### 1. Failed resume handling must preserve the same authority model

Any failed session-resume or manual-recovery policy should align with the same source-of-truth order and anti-interpretation rules as normal delegation.

That means recovery policy should preserve:

- strict `$ses_<task-id>` verbatim handling when the target session still exists
- router-owned session metadata
- direct user-to-subagent substantive interaction
- no Maestro-authored reinterpretation during recovery

### 2. Recovery may restore routing, not reinterpret intent

If a session cannot be resumed directly and requires manual or transcript-based rehydration, the recovery procedure should restore the routing context as faithfully as possible without turning Maestro into a summarizer of the intended task.

If recovery would require substantive interpretation, Maestro should ask the user rather than reconstructing intent from a paraphrase.

### 3. Recovery policy should be updated alongside delegation policy

Any repo policy sections covering failed resume recovery, manual rehydration, or expired-session handling should be reviewed and updated together with the delegation-packet policy so the system does not apply stricter non-interpretation rules to normal routing but looser reinterpretation rules to failure paths.

## Message Simplification

### Maestro → subagent dispatch

Use the full `Delegation Packet`.

### Maestro → existing session resume

Use a minimal routing wrapper only. If the user supplied `$ses_<task-id>`, the payload must be forwarded verbatim.

### Subagent → user pause / question

Ordinary subagents should send the direct question or update only. No router metadata block is required.

### Subagent → Maestro completion

Ordinary subagents should send short status-oriented completion messages such as:

- scoped work complete
- blocked on user input
- awaiting user review

These should preserve ownership boundaries without forcing rigid ceremony.

## Example `Delegation Packet`

```text
Delegation Packet
Artifact path: docs/superpowers/plans/2026-05-22-example.md
Verbatim user request:
> Implement the first approved slice with tests first.
Warnings:
- Possible discrepancy: the approved plan says CLI-only, while the latest user note may imply TUI interest.
Session: ses_abc123
Resume: $ses_abc123 <your reply>
Owner: implementer
Authority: only the owning subagent may perform implementer responsibilities unless a human-approved Maestro override is active
```

## Example strict `$ses_<task-id>` routing

User message:

```text
$ses_abc123 Stop after the first failing acceptance test and show me the interface sketch.
```

Subagent receives exactly:

```text
Stop after the first failing acceptance test and show me the interface sketch.
```

## Risks And Trade-Offs

- **Less Maestro smoothing:** weaker or careless Maestro behavior is constrained more tightly. This is intentional.
- **More direct questions to the user:** this increases interaction count but reduces misdelegation and rework.
- **Less planner detail:** some implementers may need more support, but strong implementers benefit from the freedom.
- **Policy split by message type:** the rules become more differentiated, but also more honest and easier to follow.
- **User-routed exceptions reduce automatic specialization:** this is intentional; explicit user routing is treated as a deliberate choice.

## Success Criteria

1. Maestro-to-subagent task starts use `Delegation Packet` instead of `Execution Handoff`.
2. Policy text forbids Maestro interpretations and interpretative summaries during delegation.
3. `$ses_<task-id>` routing is defined as verbatim pass-through.
4. Plans/specs are defined at the level of goals, tests, constraints, known risks, and `User Check-in`s rather than detailed execution steps.
5. Ordinary subagent resume-formatting requirements are removed from policy/spec text.
6. Maestro is required to surface session metadata at dispatch, resume, and handback boundaries.
7. Policy allows qualified approved specs to be delegated directly for implementation without requiring a separate implementation plan.
8. Failed session-resume recovery policy is aligned with the same non-interpretation and routing-authority rules.
9. Explicit user routing requests are honored even when they bypass default specialist routing.
