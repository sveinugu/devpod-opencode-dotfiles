# Maestro Delegation Packet Prevention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Maestro-side pre-dispatch prevention for malformed or interpretive `Delegation Packet` dispatches, with canonical policy wording, matching Maestro operational guidance, and docs-only drift checks.

**Architecture:** The canonical rule lives in `.config/opencode/AGENTS.md` under `# Delegation & Sessions (canonical)`. `.config/opencode/agents/maestro.md` mirrors only Maestro-specific operational behavior and points back to the canonical chapter for schema. Verification stays docs-only and TDD-driven: update or add failing shell contract checks first, then make the minimal policy/prompt edits needed to pass.

**Tech Stack:** Markdown policy docs, agent prompt markdown, bash + ripgrep (`rg`) doc-contract tests, git.

---

## Inputs / binding artifacts

- Binding spec: `docs/superpowers/specs/2026-06-12-maestro-delegation-packet-prevention-design.md`
- Existing canonical packet design to preserve: `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`
- Existing canonical policy surface: `.config/opencode/AGENTS.md` → `# Delegation & Sessions (canonical)`

## Scope

### In scope

1. Add Maestro-side prevention language to the canonical delegation chapter:
   - pre-dispatch prohibition
   - explicit pre-dispatch checks
   - refusal-before-launch behavior
   - trivial vs non-trivial preview gate
2. Reorder the anti-scatter checklist so validation is a precondition to Task launch rather than a post-dispatch review.
3. Update `.config/opencode/agents/maestro.md` so Maestro operational rules mirror the prevention policy without redefining packet schema.
4. Refresh docs-only contract coverage so prevention semantics are verified and stale contradictory expectations are resolved.

### Out of scope

- Redesigning the closed `Delegation Packet` schema
- Changing the settled subagent stop-rule behavior
- Runtime/plugin enforcement, packet-builder APIs, or audit logging
- Requiring preview for trivial packets
- Broad prompt/template cleanup unrelated to this prevention slice

## Constraints / policy guardrails

- Keep the packet schema closed and unchanged.
- Preserve the current subagent stop-rule unchanged.
- Prefer one canonical source of truth; Maestro prompt text should point to AGENTS rather than restating the schema.
- If a stale doc-contract test is retired or consolidated, replace it with equivalent or stronger coverage in the same slice.

---

## File map (expected)

**Primary canonical policy**
- Modify: `.config/opencode/AGENTS.md`

**Maestro operational surface**
- Modify: `.config/opencode/agents/maestro.md`

**Verification / drift guardrails**
- Modify: `tests/docs/test_delegation_packet_policy_contract.sh`
- Modify or delete: `tests/docs/test_maestro_intent_preservation_policy.sh`

**Conditional only if direct drift is found during implementation**
- Modify: `docs/superpowers/templates/subagent-handoff-templates.md`

---

## Acceptance criteria (verifiable)

1. `.config/opencode/AGENTS.md` gives Maestro an explicit must-not-dispatch rule for malformed packets before Task launch.
2. The canonical chapter defines the Maestro pre-dispatch checks called for by the spec, including:
   - allowed-fields-only discipline
   - verbatim quoting contract checks
   - `Warnings:` discipline
   - artifact-path discipline
   - packet/Annex boundary discipline
3. The canonical chapter defines required refusal-before-launch behavior, including no Task call, no fake handoff wording, no fabricated session metadata, and seeking correction from the human when needed.
4. The canonical chapter defines the trivial vs non-trivial preview gate and includes the umbrella rule: `If Maestro had to choose, compress, or explain, preview is mandatory.`
5. The canonical chapter makes full-message quoting the Maestro-side default when a single full user message is sufficient.
6. The canonical chapter states that partial-message quoting automatically makes the packet non-trivial and therefore preview-gated.
7. The anti-scatter checklist is reordered so validation happens before Task launch and session metadata appears only after successful launch.
8. `.config/opencode/agents/maestro.md` mirrors the operational rules to validate before launch, refuse malformed packets instead of silently fixing them, and preview non-trivial packets, while still treating AGENTS as canonical.
9. The current subagent stop-rule remains substantively unchanged.
10. The policy text explicitly defers runtime/plugin enforcement in this slice.
11. Docs-only contract tests pass after the documentation update and no active contradictory packet-policy test remains.

---

## Risks and trade-offs

- **Preview friction:** If the non-trivial gate is written too broadly, users may experience unnecessary approval loops.
- **Policy drift:** AGENTS and `maestro.md` can diverge unless tests assert the new prevention anchors.
- **Duplicate/stale verification surfaces:** Older tests may still encode superseded packet expectations and must be updated or retired carefully.
- **Warnings loophole:** `Warnings:` remains the easiest place for “helpful” interpretation to sneak back in; verification should keep this surface explicit.

---

## Task 1: Refresh docs-only verification and resolve stale drift checks

**Files:**
- Modify: `tests/docs/test_delegation_packet_policy_contract.sh`
- Modify or delete: `tests/docs/test_maestro_intent_preservation_policy.sh`
- Modify only if needed: `docs/superpowers/templates/subagent-handoff-templates.md`

- [ ] Start from failing docs-only verification for the new prevention anchors.
- [ ] Update the canonical contract test so it checks pre-dispatch prohibition, refusal-before-launch semantics, preview gating for non-trivial packets, full-message quoting default, partial-message quoting escalation, explicit runtime/plugin deferral, and the reordered anti-scatter checklist.
- [ ] Rewrite, retire, or consolidate any stale packet-policy doc test that still asserts superseded expectations, while keeping at least equivalent regression coverage.
- [ ] If test coverage reveals direct template drift in this slice, update the local handoff template doc minimally.
- [ ] **User Check-in:** if a historical test is removed rather than rewritten, confirm the replacement coverage before finalizing.

---

## Task 2: Update the canonical prevention policy in AGENTS.md

**Files:**
- Modify: `.config/opencode/AGENTS.md`

- [ ] Add a Maestro-side prevention subsection inside `# Delegation & Sessions (canonical)` based on the binding spec.
- [ ] Reorder the anti-scatter checklist so packet assembly and validation occur before Task launch.
- [ ] Add the spec-required full-message quoting default, partial-message quoting => non-trivial/preview-gated rule, and refusal wording that seeks correction from the human when needed.
- [ ] Preserve existing packet schema, Annex rules, resume-token rules, and subagent stop-rules except where the binding spec explicitly adds Maestro-side prevention wording.
- [ ] **User Check-in:** review the canonical wording before secondary surfaces and tests are finalized.

---

## Task 3: Mirror Maestro-only operational behavior in `maestro.md`

**Files:**
- Modify: `.config/opencode/agents/maestro.md`

- [ ] Add Maestro-operational language that mirrors the canonical prevention rule without becoming a second schema source.
- [ ] Make the prompt explicitly say Maestro must validate before Task launch, refuse malformed packets instead of silently correcting them, and preview non-trivial packets before dispatch.
- [ ] Mirror the full-message quoting default and the partial-message => preview-gated escalation as operational rules, while still pointing back to AGENTS for the actual schema.
- [ ] Keep packet schema details centralized in AGENTS via pointer-style wording.

---

## Task 4: Final verification and implementation handoff

**Files:**
- Review only: `.config/opencode/AGENTS.md`
- Review only: `.config/opencode/agents/maestro.md`
- Review only: `tests/docs/test_delegation_packet_policy_contract.sh`
- Review only: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] Run `bash tests/docs/test_delegation_packet_policy_contract.sh`.
- [ ] If `tests/docs/test_maestro_intent_preservation_policy.sh` survives Task 1, run `bash tests/docs/test_maestro_intent_preservation_policy.sh`.
- [ ] Run any other remaining docs tests touched by this slice.
- [ ] Re-read the binding spec and confirm each acceptance criterion maps to evidence in AGENTS, `maestro.md`, or the doc-contract tests.
- [ ] Review the final diff for policy drift, duplicate schema wording, and accidental scope expansion.

---

## Final verification checklist

- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `git diff -- .config/opencode/AGENTS.md .config/opencode/agents/maestro.md tests/docs/test_delegation_packet_policy_contract.sh tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] Confirm the wording still preserves the current subagent stop-rule unchanged.
- [ ] Confirm the policy still defers runtime/plugin enforcement explicitly.

## Pragmatic Programmer diagnostic (target score ≥ 8/10)

- **DRY:** one canonical packet/prevention policy source in AGENTS; Maestro prompt mirrors operations only.
- **Orthogonality:** packet schema, Maestro prevention, and doc-contract verification stay separated but aligned.
- **Reversibility:** this slice is docs/tests only, preserving a clean path for later runtime enforcement once the wording is stable.
