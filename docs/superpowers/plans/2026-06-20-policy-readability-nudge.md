# Policy Readability Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one short "Policy readability and documentation expectations" section to `.config/opencode/AGENTS.md` that reinforces cross-reference upkeep, documented-path maintenance, and doc-contract-test awareness without widening scope beyond this AGENTS-only policy nudge.

**Architecture:** Keep the slice doc-only and AGENTS-only. Because the approved scope forbids touching any file outside `.config/opencode/AGENTS.md`, use the existing `tests/docs/` contract suites as the tests-first baseline and regression guard rather than creating or editing tests; if the wording change would require a contract-test update, stop and reopen scope instead of silently widening it.

**Tech Stack:** Markdown policy docs, existing Bash doc-contract tests under `tests/docs/`, Git.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved slice: `Item 6 — Small guidance nudge for docs/readability expectations` (audit lines 185-191)
- Primary implementation target: `.config/opencode/AGENTS.md`
- Hard scope limit from user:
  - add one concise section only;
  - keep it to 5-10 sentences;
  - do not create new enforcement machinery, new anchors, or broad policy rewrites;
  - do not touch any file outside `.config/opencode/AGENTS.md`.
- Existing AGENTS-related regression guards to use as baseline and post-edit checks:
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_maestro_intent_preservation_policy.sh`
  - `tests/docs/test_multi_question_interaction_policy.sh`
  - `tests/docs/test_clean_code_policy_contract.sh`
  - `tests/docs/test_managed_worktree_lane_safety_policy.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`

## Scope

### In scope

- Add a short `Policy readability and documentation expectations` section to `.config/opencode/AGENTS.md`.
- State that agents must keep policy/doc cross-references current when editing referenced files.
- State that agents must update runbook and spec file paths when refactoring documented surfaces.
- State that `tests/docs/` doc-contract tests are the enforcement mechanism and that policy wording changes should trigger a check for corresponding contract-test updates.
- Verify that the change stays additive and does not break current AGENTS policy contracts.

### Out of scope

- No edits to any file outside `.config/opencode/AGENTS.md`, including `tests/docs/`.
- No new doc-contract tests, no runtime enforcement, and no new doc-contract target anchors or marker text.
- No broad policy restructuring, heading renames, or canonical-text rewrites.
- No updates to historical plans, specs, runbooks, templates, or agent files.
- A new section heading such as `## Policy readability and documentation expectations` is allowed in this slice; the restriction above is about adding new anchor markers that doc-contract tests would need to target.

## File map

- Modify: `.config/opencode/AGENTS.md` — add one short readability/documentation expectations section.
- Verify only:
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_maestro_intent_preservation_policy.sh`
  - `tests/docs/test_multi_question_interaction_policy.sh`
  - `tests/docs/test_clean_code_policy_contract.sh`
  - `tests/docs/test_managed_worktree_lane_safety_policy.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`

---

## Task 1: Prove the current AGENTS baseline is green before editing

**Files:**
- Verify only: `.config/opencode/AGENTS.md`

- [ ] **Step 1: Run the existing AGENTS-focused doc-contract tests before making any edit**

  Run:

  ```bash
  bash tests/docs/test_delegation_packet_policy_contract.sh
  bash tests/docs/test_maestro_intent_preservation_policy.sh
  bash tests/docs/test_multi_question_interaction_policy.sh
  bash tests/docs/test_clean_code_policy_contract.sh
  bash tests/docs/test_managed_worktree_lane_safety_policy.sh
  bash tests/docs/test_bare_hub_guardrails.sh
  ```

  Expected: PASS for all six commands.

- [ ] **Step 2: Stop if the baseline is already red**

  If any command fails before the wording nudge is added, pause and ask the user whether that unrelated repair is now in scope. Do not start this AGENTS-only slice on a known-red baseline.

- [ ] **Step 3: Identify the insertion zone without disturbing canonical anchors**

  Read the nearby top-of-file orientation text and surrounding policy sections, then choose one additive insertion point that keeps existing tested headings, anchor phrases, and reading order intact. Prefer a location where the reminder reads as editor guidance rather than a second source of truth.

---

## Task 2: Add the minimal readability/documentation expectations section

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Test: `tests/docs/test_delegation_packet_policy_contract.sh`
- Test: `tests/docs/test_maestro_intent_preservation_policy.sh`
- Test: `tests/docs/test_multi_question_interaction_policy.sh`
- Test: `tests/docs/test_clean_code_policy_contract.sh`
- Test: `tests/docs/test_managed_worktree_lane_safety_policy.sh`
- Test: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Add one short section with only the approved reminders**

  Add a section titled `Policy readability and documentation expectations` to `.config/opencode/AGENTS.md`.

  Content constraints:

  - 5-10 short sentences total;
  - keep the section additive and concise;
  - include the three required reminders from the approved scope;
  - do not add new rules outside those reminders;
  - do not introduce new doc-contract target anchors or marker text, procedural machinery, or repeated policy summaries;
  - a new section heading for this nudge is allowed because existing contract tests match specific required text rather than forbidding unknown headings.

- [ ] **Step 2: Keep the wording subordinate to existing canonical policy**

  The new section should reinforce maintenance expectations for editors of documented surfaces, not restate delegation/TDD/session policy. Cross-reference current docs where useful, but avoid turning this section into a map of every related file.

- [ ] **Step 3: Verify GREEN on the existing AGENTS contracts**

  Run:

  ```bash
  bash tests/docs/test_delegation_packet_policy_contract.sh
  bash tests/docs/test_maestro_intent_preservation_policy.sh
  bash tests/docs/test_multi_question_interaction_policy.sh
  bash tests/docs/test_clean_code_policy_contract.sh
  bash tests/docs/test_managed_worktree_lane_safety_policy.sh
  bash tests/docs/test_bare_hub_guardrails.sh
  ```

  Expected: PASS for all six commands.

- [ ] **Step 4: Scope guard on test-updates**

  After the edit and regression run, explicitly check whether the new wording appears to require any `tests/docs/` updates. If yes, stop and ask the user for scope expansion instead of editing tests, because the approved slice forbids touching files outside `.config/opencode/AGENTS.md`.

- [ ] **Step 5: Mandatory refactor checkpoint for wording only**

  Review the added section for readability and duplication only:

  - remove any sentence that merely restates nearby policy text;
  - keep references current and exact;
  - keep the section short enough that it still reads as a nudge, not a policy rewrite.

  If wording changes are made during this checkpoint, rerun the six doc-contract commands above.

- [ ] **Step 6: User Check-in**

  Present the rendered new section to the user and ask for wording approval before calling the slice complete. This is user-facing policy text even though the change is small.

---

## Task 3: Final verification and handoff

**Files:**
- Modify: `.config/opencode/AGENTS.md`

- [ ] **Step 1: Rerun the focused regression suite once more after approval**

  Run:

  ```bash
  bash tests/docs/test_delegation_packet_policy_contract.sh
  bash tests/docs/test_maestro_intent_preservation_policy.sh
  bash tests/docs/test_multi_question_interaction_policy.sh
  bash tests/docs/test_clean_code_policy_contract.sh
  bash tests/docs/test_managed_worktree_lane_safety_policy.sh
  bash tests/docs/test_bare_hub_guardrails.sh
  ```

  Expected: PASS for all six commands.

- [ ] **Step 2: Re-read the audit slice and confirm no scope drift**

  Check audit lines 185-191 and confirm the final change stayed within all four boundaries:

  - AGENTS-only primary surface;
  - supporting policy nudge only;
  - no broad policy restructuring;
  - no new enforcement machinery.

- [ ] **Step 3: Record the operational note**

  In the final handoff, remind the user that opencode loads instruction/config-time files at startup, so they should restart opencode after the change is merged or applied if they want new sessions to pick up the updated AGENTS guidance.

- [ ] **Step 4: Record the mandatory post-implementation reviews**

  Include the pragmatic-programmer diagnostic score and the clean-code review outcome in the implementation handoff. If either review finds material issues, append 1-3 follow-up items.

---

## Final verification checklist

- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] `bash tests/docs/test_multi_question_interaction_policy.sh`
- [ ] `bash tests/docs/test_clean_code_policy_contract.sh`
- [ ] `bash tests/docs/test_managed_worktree_lane_safety_policy.sh`
- [ ] `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] Re-read `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` lines 185-191 and confirm the implementation remained a supporting policy nudge only.
- [ ] Confirm the new `Policy readability and documentation expectations` section is 5-10 sentences, AGENTS-only, and contains only the three approved reminders.
- [ ] Confirm the final handoff includes the opencode restart reminder plus the required pragmatic-programmer and clean-code review notes.

## Notes for the implementing agent

- This slice is intentionally small; keep every changed line directly traceable to the approved wording nudge.
- Because the user forbade edits outside `.config/opencode/AGENTS.md`, treat any needed test change as a stop-and-ask event, not an invitation to widen scope.
- Prefer additive placement and exact path maintenance over clever restructuring.
