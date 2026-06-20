# Multi-question Interaction Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update repository interaction policy so subagents batch related clarification questions by default and frame user choices informatively, without weakening exact-token prompt reliability.

**Architecture:** Keep the slice confined to the canonical policy source in `.config/opencode/AGENTS.md` and protect it with a focused doc-contract shell test under `tests/docs/`. Drive the change with doc-level TDD: lock the approved wording and anti-regression anchors in a failing test first, then make the minimal policy edit, rerun focused regressions, and finish with a user wording check plus the required opencode restart note.

**Tech Stack:** Markdown policy docs, Bash doc-contract tests using `rg`/`grep`, Git.

---

## Inputs and authority

- Design spec: `docs/superpowers/specs/2026-06-20-multi-question-interaction-design.md` at commit `27e508f`. The file still says `Status: Proposed (direction approved; awaiting user review)`, but the user has already approved it in chat; that approval plus this plan are the active authority for this slice.
- Editable repo root: `/workspaces/dotfiles/work/policy_multiple_questions`
- Implementation target: `.config/opencode/AGENTS.md` in this worktree. The user referenced `/workspaces/dotfiles/main/.config/opencode/AGENTS.md`; this worktree copy is the editable branch-local source that will become the main copy once merged.
- Historical approved artifacts such as `docs/superpowers/plans/2026-05-22-subagent-session-communication-policy.md` may still quote the retired one-question wording. Do not rewrite historical plan/spec artifacts in this slice unless the user explicitly asks.

## Scope

### In scope

- Replace the recommended first subagent message so it no longer promises one-question-at-a-time interaction.
- Replace the one-question-per-message rule with the approved batching-default policy, including the five-question cap, no-filler rule, pending-question disclosure, and protocol-sensitive exemption.
- Add the explicit repository-policy override note so local batching policy wins over skill-level one-question guidance.
- Expand the question-framing guidance so user-choice prompts include brief background, trade-offs, recommendation, and reasoning, and forbid loaded/rhetorical framing.
- Add doc-contract coverage that pins the approved policy and the removal of the retired wording.

### Out of scope

- No edits to external packaged skills or runtime/plugin enforcement.
- No change to Maestro's separate routing-only one-question rule.
- No rewrite of historical plan/spec artifacts just because they quote the superseded wording.
- No broader conversation-policy redesign beyond the exact approved `AGENTS.md` slice.

## File map

- Create: `tests/docs/test_multi_question_interaction_policy.sh` — focused doc-contract test for the new batching and choice-framing policy.
- Modify: `.config/opencode/AGENTS.md` — canonical subagent interaction policy text.

---

## Task 1: Lock the approved interaction policy in a failing doc-contract test

**Files:**
- Create: `tests/docs/test_multi_question_interaction_policy.sh`
- Test: `tests/docs/test_multi_question_interaction_policy.sh`

- [ ] **Step 1: Write the failing doc-contract test**
  - Point the test at `.config/opencode/AGENTS.md` only.
  - Assert the new required anchors from the approved spec:
    - first subagent message allows one or more related questions;
    - batching is the default for ordinary clarifying/discovery exchanges;
    - at most five questions per message;
    - no filler questions when only one meaningful question exists;
    - disclose when more questions are pending and give a rough remaining-count or remaining-rounds estimate;
    - exact-token / protocol-sensitive prompts may remain isolated;
    - repository-policy override over skill-level one-question guidance;
    - choice prompts require background, trade-offs, recommendation, brief why, then the actual question or batch;
    - loaded or rhetorical choice framing is forbidden.
  - Assert the retired wording is absent:
    - `I will ask one question at a time`
    - `Ask one clarifying question per message`

- [ ] **Step 2: Keep the test narrowly scoped to live policy text**
  - Do not scan historical approved plan/spec files that intentionally preserve older wording as historical record.
  - Follow the existing doc-contract style used in `tests/docs/`: simple shell helpers plus fixed-string or regex anchor checks.

- [ ] **Step 3: Verify RED**
  - Run: `bash tests/docs/test_multi_question_interaction_policy.sh`
  - Expected: FAIL because `.config/opencode/AGENTS.md` still contains the retired one-question language and lacks the new batching/choice-framing anchors.

- [ ] **Step 4: Commit the red test slice**
  - Run:

    ```bash
    git add tests/docs/test_multi_question_interaction_policy.sh
    git commit -m "test(policy): lock multi-question interaction contract"
    ```

---

## Task 2: Apply the minimal `AGENTS.md` policy edit and bring the new contract green

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Test: `tests/docs/test_multi_question_interaction_policy.sh`

- [ ] **Step 1: Replace the recommended first subagent message**
  - Update the quoted first-message recommendation so it preserves direct subagent-to-user interaction and completion handoff, but no longer promises one-question-at-a-time behavior.
  - Keep the new wording aligned with the spec: the subagent may ask one or more related questions directly.

- [ ] **Step 2: Replace the retired one-question rule with the batching-default block**
  - Add the approved policy points in the `Subagent interaction rules` section:
    - batching preferred for ordinary clarifying/discovery exchanges;
    - five-question cap;
    - no filler questions;
    - pending-question disclosure with rough estimate;
    - exact-token/protocol-sensitive isolation exception.

- [ ] **Step 3: Add the explicit repository override and stronger choice-framing guidance**
  - Add the repository-policy override note that local batching rules beat skill-level one-question guidance unless a stricter protocol or routing rule in `AGENTS.md` applies.
  - Expand the direct/minimal guidance so choice prompts include brief background, trade-offs, recommendation, and a short why before the actual question, and explicitly forbid hiding the recommendation inside rhetorical or loaded framing.

- [ ] **Step 4: Verify GREEN on the new contract**
  - Run: `bash tests/docs/test_multi_question_interaction_policy.sh`
  - Expected: PASS.

- [ ] **Step 5: Mandatory refactor checkpoint**
  - Keep the policy edit surgical: touch only the first-message line and the nearby interaction-rule bullets needed for this slice.
  - If wording is duplicated or awkward, simplify it without changing the approved meaning.
  - Rerun: `bash tests/docs/test_multi_question_interaction_policy.sh`

- [ ] **Step 6: Commit the green policy slice**
  - Run:

    ```bash
    git add .config/opencode/AGENTS.md tests/docs/test_multi_question_interaction_policy.sh
    git commit -m "docs(policy): adopt multi-question interaction defaults"
    ```

**User Check-in:** after Task 2 reaches green, pause and ask the user to review the rendered `AGENTS.md` wording before declaring the implementation slice finished. The approved spec is clear, but this is still user-facing policy language.

---

## Task 3: Run focused regressions and prepare the handoff

**Files:**
- No new implementation files expected unless a regression test reveals a nearby live-policy drift that must be corrected.

- [ ] **Step 1: Run the focused doc-policy regression suite**
  - Run:

    ```bash
    bash tests/docs/test_multi_question_interaction_policy.sh
    bash tests/docs/test_delegation_packet_policy_contract.sh
    bash tests/docs/test_maestro_intent_preservation_policy.sh
    bash tests/docs/test_clean_code_policy_contract.sh
    bash tests/docs/test_bare_hub_guardrails.sh
    ```

  - Expected: all pass.

- [ ] **Step 2: Re-read the approved spec and map every acceptance criterion to the final policy text or test coverage**
  - Confirm each acceptance criterion from `docs/superpowers/specs/2026-06-20-multi-question-interaction-design.md` is visibly satisfied by the final `AGENTS.md` text and/or `tests/docs/test_multi_question_interaction_policy.sh`.

- [ ] **Step 3: Record the operational follow-up**
  - In the handoff/PR note, remind the user that opencode loads config-time instructions once at startup, so they should restart opencode after the change is merged/applied if they want the updated interaction policy to affect new sessions.

- [ ] **Step 4: Record the mandatory post-implementation reviews**
  - Include the pragmatic-programmer diagnostic score.
  - Include the clean-code review outcome.
  - If either review reveals material issues, append 1–3 remediation items.

---

## Final verification checklist

- [ ] `bash tests/docs/test_multi_question_interaction_policy.sh`
- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] `bash tests/docs/test_clean_code_policy_contract.sh`
- [ ] `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] Re-read `docs/superpowers/specs/2026-06-20-multi-question-interaction-design.md` and confirm these acceptance points are covered:
  1. the recommended first subagent message no longer promises one-question-at-a-time interaction;
  2. ordinary clarifying/discovery exchanges default to multi-question batching, capped at five;
  3. the policy forbids filler questions and requires pending-question disclosure with a rough estimate;
  4. exact-token/protocol-sensitive prompts may stay isolated;
  5. repository policy explicitly overrides one-question-at-a-time skill guidance for this repo;
  6. choice prompts require background, trade-offs, recommendation, and brief reasoning;
  7. rhetorical or loaded choice framing is explicitly forbidden.
- [ ] Verify the final handoff includes the opencode restart reminder and the required pragmatic-programmer + clean-code review notes.

## Notes for the implementing agent

- Follow strict TDD for each task: red → verify red → green → verify green → refactor → verify green.
- Keep this slice reversible and surgical: no new runtime logic, no skill-package edits, no broader prompt rewrites.
- Treat the new doc-contract test as the primary behavioral guardrail for the policy text.
