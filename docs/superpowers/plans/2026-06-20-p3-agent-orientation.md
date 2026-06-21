# P3 Docs Navigation: Agent Orientation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a short, additive “Agent start here” overlay near the top of `.config/opencode/AGENTS.md` so Maestro, implementers, reviewers, and newcomers can reach the right canonical sections faster without changing policy meaning or breaking any existing contract anchors.

**Architecture:** Treat the new copy as a navigation overlay, not a policy rewrite. First prove the current AGENTS-related doc-contract tests are green, then insert one compact role-based routing section near the top of `AGENTS.md`, rerun the existing policy tests, and review the diff to confirm the change stayed additive. If the DG-10 baseline is clean and the user explicitly wants more newcomer help, a tiny DG-11 vocabulary bridge may be added afterward as a separate optional addendum.

**Tech Stack:** Markdown only in `.config/opencode/AGENTS.md`, existing Bash doc-contract tests under `tests/docs/`, and `git diff` for additive-change review.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved slice: `P3 Slice 5 — Docs navigation: agent orientation`
- Primary audited gaps for this slice:
  - `DG-10` — add a role-based “start here” orientation overlay
  - `DG-11` — optional glossary/vocabulary bridge only after a clean DG-10 baseline and explicit user approval
- Reference plan format: `docs/superpowers/plans/2026-06-20-p1-docs-orientation.md`
- Primary surface to modify:
  - `.config/opencode/AGENTS.md`
- Supporting references to route readers toward, but not modify in this slice:
  - `docs/superpowers/templates/subagent-handoff-templates.md`
  - `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`
- Existing regression guards that must stay green:
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_maestro_intent_preservation_policy.sh`
  - `tests/docs/test_multi_question_interaction_policy.sh`
  - `tests/docs/test_managed_worktree_lane_safety_policy.sh`
  - `tests/docs/test_clean_code_policy_contract.sh`

## Scope

### In scope

- Add one short orientation section near the top of `.config/opencode/AGENTS.md`.
- Route four reader roles explicitly: Maestro, implementer, reviewer, newcomer.
- Keep all existing policy text, existing heading names, and doc-contract-tested anchor strings intact.
- Point newcomers toward the existing handoff template doc and the existing packet-inventory review record as supporting context only.
- Reuse existing tests as regression guards; add no new test file for this slice.
- Document DG-11 as an optional follow-up addendum, not part of the default implementation path.

### Out of scope

- No policy rewrites.
- No renaming, deleting, or reordering of existing canonical governance headings.
- No changes to `.config/opencode/agents/maestro.md`.
- No edits to `docs/superpowers/templates/subagent-handoff-templates.md`.
- No edits to `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`.
- No new doc-contract test for the orientation overlay.
- No runtime/plugin enforcement changes.
- No default DG-11 glossary work unless the DG-10 baseline is already green and the user asks for it.

## Proposed file map

- Modify: `.config/opencode/AGENTS.md` — add one additive role-based orientation overlay near the top of the file.
- Verify only:
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_maestro_intent_preservation_policy.sh`
  - `tests/docs/test_multi_question_interaction_policy.sh`
  - `tests/docs/test_managed_worktree_lane_safety_policy.sh`
  - `tests/docs/test_clean_code_policy_contract.sh`

---

## Task 1: Prove the current AGENTS policy baseline is green before editing

**Files:**
- Verify only: `.config/opencode/AGENTS.md`

- [ ] **Step 1: Run the existing AGENTS-related docs contract tests before making any edits**

Run:

```bash
bash tests/docs/test_delegation_packet_policy_contract.sh
bash tests/docs/test_maestro_intent_preservation_policy.sh
bash tests/docs/test_multi_question_interaction_policy.sh
bash tests/docs/test_managed_worktree_lane_safety_policy.sh
bash tests/docs/test_clean_code_policy_contract.sh
```

Expected: PASS for all five commands.

- [ ] **Step 2: Stop if the baseline is already red**

If any command fails before the orientation overlay is added, pause and ask the user whether that unrelated repair is now part of scope. Do not start this doc-only slice on a known-red AGENTS baseline.

---

## Task 2: Add the DG-10 role-based orientation overlay to `AGENTS.md`

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Test: `tests/docs/test_delegation_packet_policy_contract.sh`
- Test: `tests/docs/test_maestro_intent_preservation_policy.sh`
- Test: `tests/docs/test_multi_question_interaction_policy.sh`
- Test: `tests/docs/test_managed_worktree_lane_safety_policy.sh`
- Test: `tests/docs/test_clean_code_policy_contract.sh`

- [ ] **Step 1: Insert one new orientation section near the top of `AGENTS.md`**

Place the new section after the introductory setup paragraphs and before `# How the agent should relate to the supported skills` so it behaves as a reader-routing overlay rather than a rewrite of the canonical policy body.

Insert this exact section shape:

```markdown
## Agent start here

Use this section to choose a reading route. `AGENTS.md` remains the canonical policy source; the template and review-record paths below are supporting context only.

- **Maestro / delegator:** start with `# Subagent delegation`, then read `# Delegation & Sessions (canonical)`, `## Managed worktree lane safety (v1)`, and `## Simple Maestro override (human-only, two-message confirmation)`.
- **Implementer:** start with `## The Superpowered Pragmatic Programmers:`, then read `### On Test-driven development`, `### Refactor phase policy`, `## Planning and implementation policy`, and `## Managed worktree lane safety (v1)`.
- **Reviewer:** start with `## The Superpowered Pragmatic Programmers:`, then read `### PR reporting template policy`, `## Named-responsibility ownership`, and `## Subagent interaction rules`.
- **Newcomer / first-time agent contributor:** read `# Overview`, `## Intent and operational setup`, and `# Subagent delegation` first.

Supporting references:

- Packet construction example: `docs/superpowers/templates/subagent-handoff-templates.md`
- Historical packet review context: `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`
```

Preservation rules for this step:

- Keep the overlay short and scan-friendly.
- Do not edit any existing heading text referenced above.
- Do not restate policy details that already live in the destination sections.
- Do not turn the overlay into a second source of truth.

- [ ] **Step 2: Rerun the existing policy tests after the overlay is added**

Run:

```bash
bash tests/docs/test_delegation_packet_policy_contract.sh
bash tests/docs/test_maestro_intent_preservation_policy.sh
bash tests/docs/test_multi_question_interaction_policy.sh
bash tests/docs/test_managed_worktree_lane_safety_policy.sh
bash tests/docs/test_clean_code_policy_contract.sh
```

Expected: PASS for all five commands.

- [ ] **Step 3: Inspect the diff and confirm the change stayed additive**

Run:

```bash
git diff -- .config/opencode/AGENTS.md
```

Expected review outcome:

- one new orientation block near the top of the file
- no renamed existing headings
- no deleted or rewritten canonical contract text
- no accidental edits below the intended insertion zone except local spacing required by the new section

- [ ] **Step 4: Mandatory refactor checkpoint for wording only**

Review the new section for readability only:

- the first sentence should say this is a reading route, not new policy
- each role bullet should point to existing sections, not summarize them in depth
- the supporting references should stay clearly subordinate to `AGENTS.md`

If any wording changes are made during this checkpoint, rerun:

```bash
bash tests/docs/test_delegation_packet_policy_contract.sh
bash tests/docs/test_maestro_intent_preservation_policy.sh
bash tests/docs/test_multi_question_interaction_policy.sh
bash tests/docs/test_managed_worktree_lane_safety_policy.sh
bash tests/docs/test_clean_code_policy_contract.sh
git diff -- .config/opencode/AGENTS.md
```

- [ ] **Step 5: User Check-in**

Present the rendered `## Agent start here` section and ask whether the four reading routes are clear enough as the new default entry path, or whether the optional DG-11 vocabulary bridge is desired.

- [ ] **Step 6: Commit the DG-10 baseline slice after approval**

```bash
git add .config/opencode/AGENTS.md
git commit -m "docs: add agent start-here overlay"
```

---

## Task 3: Optional DG-11 addendum — add a tiny vocabulary bridge only if requested

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Test: `tests/docs/test_delegation_packet_policy_contract.sh`
- Test: `tests/docs/test_maestro_intent_preservation_policy.sh`
- Test: `tests/docs/test_multi_question_interaction_policy.sh`
- Test: `tests/docs/test_managed_worktree_lane_safety_policy.sh`
- Test: `tests/docs/test_clean_code_policy_contract.sh`

- [ ] **Step 1: Only start this task if DG-10 is already green and the user explicitly asks for DG-11**

If the user is satisfied with the DG-10 overlay alone, skip this task entirely.

- [ ] **Step 2: Add one tiny vocabulary bridge directly under `## Agent start here`**

If requested, add this exact optional subsection below the role bullets and above `Supporting references:`:

```markdown
### Quick vocabulary bridge

- `Delegation Packet` — the closed-schema Maestro → subagent dispatch block.
- `Artifact path` — the binding requirements source named in a packet when one exists.
- `Session` / `Resume` — the exact `task_id` and `$<task_id> <reply>` routing token for continuing a subagent conversation.
- `Lane-qualified work item` — scoped work tied to a specific managed worktree lane.
- `Maestro override` — the human-only two-message authorization that temporarily lets Maestro perform subagent-owned work directly.
```

Keep this bridge short. Do not expand it into a glossary appendix or restate the full policy rules.

- [ ] **Step 3: Re-run the same regression tests**

Run:

```bash
bash tests/docs/test_delegation_packet_policy_contract.sh
bash tests/docs/test_maestro_intent_preservation_policy.sh
bash tests/docs/test_multi_question_interaction_policy.sh
bash tests/docs/test_managed_worktree_lane_safety_policy.sh
bash tests/docs/test_clean_code_policy_contract.sh
git diff -- .config/opencode/AGENTS.md
```

Expected: PASS for all five tests, with the diff still showing only additive orientation content near the top of the file.

- [ ] **Step 4: Commit the optional addendum**

```bash
git add .config/opencode/AGENTS.md
git commit -m "docs: add agent vocabulary bridge"
```

---

## Task 4: Final handoff and verification summary

**Files:**
- Review only: `.config/opencode/AGENTS.md`

- [ ] **Step 1: Report the final change surface**

State whether the finished slice changed only `.config/opencode/AGENTS.md`, or whether the optional DG-11 addendum was also applied within the same file.

- [ ] **Step 2: Report fresh verification evidence**

Include the exact test commands run and whether DG-11 was skipped or completed.

- [ ] **Step 3: Confirm the scope boundaries stayed intact**

Explicitly confirm:

- no existing canonical headings were renamed
- no existing contract-anchor text was edited
- no new doc-contract test file was introduced
- no template or review-record file was modified in this slice

---

## Final verification checklist

- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] `bash tests/docs/test_multi_question_interaction_policy.sh`
- [ ] `bash tests/docs/test_managed_worktree_lane_safety_policy.sh`
- [ ] `bash tests/docs/test_clean_code_policy_contract.sh`
- [ ] `git diff -- .config/opencode/AGENTS.md`
- [ ] Confirm the new overlay is near the top of `AGENTS.md` and reads as navigation, not policy replacement.
- [ ] Confirm all existing referenced headings remain spelled exactly as before.
- [ ] Confirm DG-11 remains skipped unless explicitly requested after DG-10 is green.

## Notes for the implementing agent

- Keep the work doc-only and surgical.
- Prefer explicit references to existing section headings over paraphrasing policy rules.
- If a wording tweak risks touching an existing tested anchor string, keep the simpler additive wording instead.
- The newcomer route should warm readers up without weakening the “AGENTS.md is canonical” hierarchy.
