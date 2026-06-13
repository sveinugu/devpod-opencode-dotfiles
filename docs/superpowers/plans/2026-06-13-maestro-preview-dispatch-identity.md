# Maestro Preview/Dispatch Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved preview/dispatch identity contract to the canonical delegation policy, Maestro guidance, handoff-template surface, and docs-contract tests without adding runtime enforcement.

**Architecture:** Keep `.config/opencode/AGENTS.md` as the single binding policy source for the preview/dispatch identity contract. Mirror only Maestro-operational behavior in `.config/opencode/agents/maestro.md`, verify or minimally align the local handoff template, and drive the slice with failing docs-contract tests first so drift is visible before the wording changes land.

**Tech Stack:** Markdown policy docs, Markdown agent prompt/template docs, bash + ripgrep docs-contract tests, git.

---

## Inputs / binding artifacts

- Binding spec: `docs/superpowers/specs/2026-06-13-maestro-preview-dispatch-identity-design.md`
- Existing canonical policy: `.config/opencode/AGENTS.md`
- Maestro operational surface: `.config/opencode/agents/maestro.md`
- Template surface: `docs/superpowers/templates/subagent-handoff-templates.md`
- Existing docs-contract tests:
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_maestro_intent_preservation_policy.sh`

## Scope

### In scope

1. Add the preview-response token contract (`ok / edit / cancel`) to the canonical delegation chapter.
2. Define exact-token matching, direct-response-only approval semantics, and `edit` / `cancel` behavior.
3. Define no-post-approval-payload-drift, preview/dispatch identity, and refusal-before-launch on mismatch.
4. Explicitly forbid free-form prose outside handoff wording + packet + optional Annex in dispatch messages.
5. Keep `Warnings:` narrow and factual.
6. Mirror the new operational rules in `maestro.md` without creating a second schema source.
7. Update or explicitly verify the handoff template surface.
8. Extend docs-contract tests so these rules fail loudly if they drift.

### Out of scope

- Runtime/plugin enforcement
- Packet-builder APIs or launch-state storage
- Changes to the closed `Delegation Packet` schema
- Changes to Annex authority beyond wording needed to preserve the current contract
- General prompt/template cleanup unrelated to preview/dispatch identity

---

## File map

**Canonical policy**
- Modify: `.config/opencode/AGENTS.md`

**Maestro operational guidance**
- Modify: `.config/opencode/agents/maestro.md`

**Template surface**
- Review and modify only if needed: `docs/superpowers/templates/subagent-handoff-templates.md`

**Docs-contract verification**
- Modify: `tests/docs/test_delegation_packet_policy_contract.sh`
- Modify or consolidate: `tests/docs/test_maestro_intent_preservation_policy.sh`

---

## TDD strategy

This slice should be implemented test-first at the docs-contract level.

### Primary failing test surface

- `tests/docs/test_delegation_packet_policy_contract.sh`

### Secondary verification surface

- `tests/docs/test_maestro_intent_preservation_policy.sh`

### Expected new/updated contract anchors

The failing test update should assert the presence of wording equivalent to:

```text
ok / edit / cancel
trim leading and trailing whitespace
compare case-insensitively to exactly one token
ok thanks
ok.
ok is valid only as the direct response to the preview prompt
edit
cancel
After preview approval, Maestro must not regenerate the outgoing dispatch
outgoing dispatch must be textually identical to the approved previewed content
outgoing dispatch differs from approved preview
No free-form prose outside the allowed structure
Please implement...
Tasks:
Deliverables:
Warnings: remains limited to short factual flags only
```

The plan does **not** require those exact phrases if the implementation chooses tighter wording, but the tests should cover each required behavior from the spec.

---

## Acceptance criteria (verifiable)

1. `.config/opencode/AGENTS.md` defines `ok / edit / cancel` as the preview control responses for non-trivial packets.
2. The canonical chapter defines exact control-token matching tightly enough that `ok` passes but `ok.` and `ok thanks` do not.
3. The canonical chapter states that `ok` means only “dispatch the exact previewed content,” not inferred work.
4. The canonical chapter states that `ok` is valid only as the direct response to a preview prompt that explicitly offered `ok / edit / cancel`.
5. The canonical chapter defines `edit` semantics as no launch + rebuild + revalidate + re-preview + fresh `ok`.
6. The canonical chapter defines `cancel` semantics as no launch + terminated attempt + discarded pending approval state.
7. The canonical chapter states that any content change after preview requires revalidation, re-preview, and a fresh `ok`.
8. The canonical chapter states that the outgoing dispatch must be textually identical to the approved previewed content, except for allowed launch-generated router metadata.
9. The canonical chapter states that Maestro must refuse launch if the outgoing dispatch differs from the approved preview.
10. The canonical chapter explicitly forbids free-form prose outside the required handoff wording, packet block, and optional Annex block in dispatch messages.
11. The canonical chapter keeps `Warnings:` limited to short factual flags and forbids implied action/task steering there.
12. `.config/opencode/agents/maestro.md` mirrors the operational rules above without redefining packet schema.
13. The handoff template either aligns with the contract or is explicitly verified as non-contradictory.
14. Docs-contract tests fail before the wording update and pass afterward.

---

## Task 1: Extend docs-contract tests first

**Files:**
- Modify: `tests/docs/test_delegation_packet_policy_contract.sh`
- Modify or consolidate: `tests/docs/test_maestro_intent_preservation_policy.sh`
- Review only: `docs/superpowers/templates/subagent-handoff-templates.md`

- [ ] Add failing assertions for the preview-response contract: `ok / edit / cancel`, exact-token matching, and direct-response-only approval.
- [ ] Add failing assertions for `edit` and `cancel` behavior.
- [ ] Add failing assertions for no-post-approval-payload-drift, preview/dispatch identity, refusal-on-mismatch, and no-extra-prose prohibitions.
- [ ] Add or update assertions that `Warnings:` remains factual-only and non-steering.
- [ ] Decide whether `tests/docs/test_maestro_intent_preservation_policy.sh` should remain as a focused Maestro mirror test or be consolidated into the broader contract test.
- [ ] If consolidation removes a historical test file, ensure the replacement coverage is equal or stronger in the same slice.
- [ ] **User Check-in:** if one docs-policy test is removed rather than rewritten, present the replacement coverage before finalizing.

### Test examples to drive this task

Example anchor checks that should fail before the doc edits and pass after:

```bash
rg -n 'ok / edit / cancel' "$agents" >/dev/null
rg -n 'trim leading and trailing whitespace' "$agents" >/dev/null
rg -n 'ok is valid only as the direct response to the preview prompt' "$agents" >/dev/null
rg -n 'outgoing dispatch must be textually identical to the approved previewed content' "$agents" >/dev/null
rg -n 'outgoing dispatch differs from approved preview' "$agents" >/dev/null
rg -n 'No free-form prose outside the allowed structure' "$agents" >/dev/null
```

---

## Task 2: Update the canonical policy in `AGENTS.md`

**Files:**
- Modify: `.config/opencode/AGENTS.md`

- [ ] Add a new canonical subsection for the preview wrapper vs dispatch structure.
- [ ] Add canonical wording for `ok / edit / cancel`, exact token matching, and direct-response-only approval.
- [ ] Add canonical wording for `edit` and `cancel` lifecycle behavior.
- [ ] Add canonical wording for no-post-approval-payload-drift and preview/dispatch identity.
- [ ] Add the mismatch refusal rule with the approved refusal wording.
- [ ] Add the explicit prohibition on free-form prose outside the allowed dispatch structure.
- [ ] Tighten `Warnings:` wording so it cannot be used as a loophole for implied tasks or steering.
- [ ] Preserve the closed packet schema, Annex model, router-metadata exception, and existing authority ordering.
- [ ] **User Check-in:** review the AGENTS wording before treating downstream mirrors/templates as final.

### Implementation note

This is the only binding policy surface. If a rule is normative, it belongs here first.

---

## Task 3: Mirror Maestro-only operational behavior in `maestro.md`

**Files:**
- Modify: `.config/opencode/agents/maestro.md`

- [ ] Add Maestro-operational wording that says non-trivial previews must explicitly ask for `ok / edit / cancel`.
- [ ] State that `ok` approves only the exact previewed content.
- [ ] State that `edit` invalidates pending approval and requires rebuild → revalidate → re-preview.
- [ ] State that `cancel` terminates the active preview/dispatch attempt.
- [ ] State that any changed non-trivial payload must be re-previewed before launch.
- [ ] State that Maestro must refuse launch if the outgoing dispatch differs from the approved preview.
- [ ] Keep schema details centralized in AGENTS by pointer-style wording rather than duplicating canonical packet rules.

---

## Task 4: Review and, only if needed, update the handoff template

**Files:**
- Review: `docs/superpowers/templates/subagent-handoff-templates.md`
- Modify only if needed: `docs/superpowers/templates/subagent-handoff-templates.md`

- [ ] Check whether the template contains preview wording, dispatch examples, or notes that conflict with the identity contract.
- [ ] If it is already compatible, leave the template unchanged and let tests document that explicit verification.
- [ ] If it conflicts, make the minimal edit needed to align it with the canonical policy.
- [ ] Avoid turning the template into a second normative policy source.

---

## Task 5: Final verification and handoff

**Files:**
- Review only: `.config/opencode/AGENTS.md`
- Review only: `.config/opencode/agents/maestro.md`
- Review only: `docs/superpowers/templates/subagent-handoff-templates.md`
- Review only: `tests/docs/test_delegation_packet_policy_contract.sh`
- Review only: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] Run `bash tests/docs/test_delegation_packet_policy_contract.sh`.
- [ ] Run `bash tests/docs/test_maestro_intent_preservation_policy.sh` if the file remains.
- [ ] Re-read the binding spec and map each acceptance criterion to AGENTS, `maestro.md`, template verification, or docs tests.
- [ ] Review the final diff for accidental schema changes, duplicate policy wording, or scope creep into runtime enforcement.
- [ ] Confirm the final slice stays docs/tests only.

---

## Final verification checklist

- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_maestro_intent_preservation_policy.sh` (if retained)
- [ ] `git diff -- .config/opencode/AGENTS.md .config/opencode/agents/maestro.md docs/superpowers/templates/subagent-handoff-templates.md tests/docs/test_delegation_packet_policy_contract.sh tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] Confirm no runtime/plugin enforcement work was introduced.
- [ ] Confirm the template surface is either updated minimally or explicitly verified as compatible.

## Pragmatic Programmer diagnostic (target score ≥ 8/10)

- **DRY:** AGENTS remains the canonical source; Maestro and templates only mirror or point.
- **Orthogonality:** policy wording, Maestro operations, template examples, and docs tests stay distinct but aligned.
- **Tracer bullet:** docs-contract tests provide the thin end-to-end slice for preview → policy → mirror consistency before any runtime automation.
- **Reversibility:** docs/tests-only scope keeps later runtime enforcement easy to add or revise.
