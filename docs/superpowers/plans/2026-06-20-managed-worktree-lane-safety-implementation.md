# Managed Worktree Lane Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved managed-worktree lane-safety slice so scoped authoring work gets dedicated lane bindings, wrong-lane situations become refusal-backed, and managed local cleanup becomes safe and auditable across both hub and child repos.

**Architecture:** Keep the v1 scope anchored in policy docs, shell helpers, and shell/doc-contract tests rather than runtime/plugin enforcement. Add one registry-backed lane-binding layer on top of the existing branch-keyed `state/` / `tmp/` layout, extend managed worktree creation to record lane metadata, and add one managed cleanup command that proves or surfaces loss before deleting a worktree/local branch.

**Tech Stack:** Markdown policy/runbook docs, Bash commands/helpers, git worktrees, shell integration tests under `tests/devspace/`, doc-contract shell tests under `tests/docs/`.

---

## Inputs and authority

- Binding spec: `docs/superpowers/specs/2026-06-20-managed-worktree-lane-safety-design.md`
- Editable repo root: `/workspaces/dotfiles/main`
- Existing worktree command surface: `bin/new-worktree`, `bin/dwt`, `bin/dre`, `scripts/lib/worktree-env.sh`
- Existing guardrails/tests to extend rather than bypass:
  - `tests/devspace/test_new_worktree.sh`
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`
- Reviewer feedback that is now part of this plan’s scope:
  1. add a small ordered list of available intent signals so Maestro/subagent wording stays behaviorally aligned;
  2. mirror the non-guarantee language for wrong-yet-self-consistent sibling-lane dispatch exactly in doc-contract tests.

## Scope

### In scope

- refusal-backed lane/worktree policy updates in canonical agent docs;
- a registry-backed lane-binding layer that preserves the current branch-keyed `state/` / `tmp/` layout;
- managed worktree creation that records lane identity separately from branch/worktree paths;
- a managed cleanup command for non-default worktrees and local branches, including `--dry-run`, `--force`, and stateless `--force-token`;
- runbook updates and regression tests for both hub and child repos.

### Out of scope

- remote branch deletion;
- OpenCode runtime/plugin enforcement;
- redesigning the Delegation Packet schema;
- broad session-routing changes beyond lane-qualified work-item identity and refusal wording already approved in the spec.

## Reviewer-driven plan refinements to preserve during implementation

- The policy/test slice must introduce and pin a short ordered list of available intent signals. Recommended order for the policy text:
  1. validated resume/routing context for a lane-qualified work item;
  2. delegated artifact anchor(s);
  3. verbatim user request when it materially distinguishes sibling lanes;
  4. explicit user/delegator lane, branch, or worktree naming in the current turn.
- The exact non-guarantee sentence from the spec must be mirrored verbatim in docs tests:

  ```text
  wrong-yet-self-consistent sibling-lane dispatch is not always independently detectable when remaining intent signals are absent or ambiguous.
  ```

## Proposed file map

### Policy and runbook surfaces

- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`

### Commands and helpers

- Modify: `bin/new-worktree`
- Create: `bin/retire-worktree`
- Create: `scripts/lib/managed-lane-registry.sh`
- Create: `scripts/lib/managed-worktree-cleanup.sh`

### Tests

- Create: `tests/docs/test_managed_worktree_lane_safety_policy.sh`
- Modify: `tests/docs/test_delegation_packet_policy_contract.sh`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`
- Modify: `tests/devspace/test_new_worktree.sh`
- Create: `tests/devspace/test_managed_lane_registry.sh`
- Create: `tests/devspace/test_retire_worktree.sh`

---

## Task 1: Lock the approved lane-safety policy in failing docs tests

**Files:**
- Create: `tests/docs/test_managed_worktree_lane_safety_policy.sh`
- Modify: `tests/docs/test_delegation_packet_policy_contract.sh`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write the failing doc-contract coverage first**
  - Assert that `.config/opencode/AGENTS.md` defines lane-scoped-by-default behavior, mandatory worktree resolution before dispatch, hard-stop wrong-worktree conditions, and subagent independent verification.
  - Assert that `maestro.md` and `senior-implementer.md` mirror only the operational/refusal wording relevant to their roles.
  - Assert that the ordered available-intent-signals list is present in canonical policy wording.
  - Assert that the exact non-guarantee sentence appears verbatim in the canonical policy and in the docs test itself.
  - Assert that the runbooks mention both managed creation (`bin/new-worktree`) and managed retirement (`bin/retire-worktree`).

- [ ] **Step 2: Verify RED**
  - Run:

    ```bash
    bash tests/docs/test_managed_worktree_lane_safety_policy.sh
    ```

  - Expected: FAIL because the lane-safety wording, ordered intent-signal list, and retirement-command references do not exist yet.

- [ ] **Step 3: Keep the doc tests narrow and live-surface focused**
  - Test current policy surfaces and live runbooks only.
  - Do not rewrite historical approved plan/spec artifacts just because older text lacks the new wording.

- [ ] **Step 4: Commit the red test slice**
  - Suggested commit: `test(policy): lock managed worktree lane safety contract`

---

## Task 2: Bring the policy surfaces green with refusal-backed lane wording

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`

- [ ] **Step 1: Update the canonical policy first**
  - Add the approved lane-scoped-by-default rules, mandatory worktree resolution before dispatch, hard-stop conditions, and subagent pushback contract.
  - Add the short ordered list of available intent signals in the same order locked by Task 1.
  - Mirror the exact non-guarantee sentence from the spec verbatim.

- [ ] **Step 2: Mirror only operational role-specific behavior downstream**
  - `maestro.md`: lane-qualified routing/worktree-resolution responsibility, ambiguity prompting, and refusal-before-dispatch wording.
  - `senior-implementer.md`: local coherence checks, wrong-worktree refusal expectation, and no blind trust of delegated routing metadata.
  - Keep `AGENTS.md` as the only canonical policy source.

- [ ] **Step 3: Verify GREEN on the docs contract**
  - Run:

    ```bash
    bash tests/docs/test_managed_worktree_lane_safety_policy.sh
    bash tests/docs/test_delegation_packet_policy_contract.sh
    bash tests/docs/test_bare_hub_guardrails.sh
    ```

  - Expected: PASS.

- [ ] **Step 4: Mandatory refactor checkpoint**
  - Keep wording surgical and non-duplicative.
  - If the same rule appears in multiple places, reduce the downstream copy to pointer-style operational wording.
  - Rerun the three doc-policy tests after cleanup.

- [ ] **Step 5: User Check-in**
  - Pause for user review of the rendered lane-selection, refusal, and non-guarantee wording before moving into command/helper changes.

- [ ] **Step 6: Commit the green policy slice**
  - Suggested commit: `docs(policy): add managed worktree lane safety rules`

---

## Task 3: Add registry-backed lane bindings to managed worktree creation

**Files:**
- Create: `scripts/lib/managed-lane-registry.sh`
- Modify: `bin/new-worktree`
- Modify: `tests/devspace/test_new_worktree.sh`
- Create: `tests/devspace/test_managed_lane_registry.sh`

- [ ] **Step 1: Write the failing shell tests first**
  - Extend `tests/devspace/test_new_worktree.sh` so new hub and child worktrees must also create lane metadata, not just branch/worktree directories.
  - Add `tests/devspace/test_managed_lane_registry.sh` for registry behavior:
    - one registry per managed repo context;
    - per-worktree reverse lookup metadata;
    - lane ID stored separately from branch/worktree path;
    - sibling lanes under one parent artifact remain distinct bindings;
    - status begins as `active`.

- [ ] **Step 2: Choose and lock one concrete v1 metadata layout**
  - Preserve the branch-keyed directories under `state/` and `tmp/`.
  - Add one central registry per repo context plus one per-worktree pointer file. A simple v1 shape is acceptable if it is easy to inspect in shell tests.
  - Ensure the tests treat lane ID as a registry-level identity, not a synonym for branch name, even if the initial default is branch-derived.

- [ ] **Step 3: Verify RED**
  - Run:

    ```bash
    bash tests/devspace/test_new_worktree.sh
    bash tests/devspace/test_managed_lane_registry.sh
    ```

  - Expected: FAIL until lane-registry helpers and `bin/new-worktree` recording behavior exist.

- [ ] **Step 4: Implement the minimal registry + creation path**
  - `bin/new-worktree` should continue creating the branch/worktree/env files as before.
  - After creation, it should record the lane binding and reverse lookup metadata for hub and child repos.
  - Keep the implementation compatible with existing managed repo metadata such as `repo.env` and `worktree-env.sh`.

- [ ] **Step 5: Verify GREEN**
  - Rerun the two tests above and confirm both pass.

- [ ] **Step 6: Mandatory refactor checkpoint**
  - Keep registry parsing/writing logic isolated in the new helper.
  - Remove duplication between hub and child repo handling only where the knowledge truly matches.
  - Rerun both tests after refactoring.

- [ ] **Step 7: Commit the registry slice**
  - Suggested commit: `feat(worktree): record managed lane bindings`

**User Check-in:** if the implementation needs a user-visible lane-ID override on `bin/new-worktree`, pause and confirm the CLI shape before hardening it.

---

## Task 4: Add safe managed retirement for non-default worktrees and local branches

**Files:**
- Create: `bin/retire-worktree`
- Create: `scripts/lib/managed-worktree-cleanup.sh`
- Create: `tests/devspace/test_retire_worktree.sh`

- [ ] **Step 1: Write the failing cleanup tests first**
  - Cover both hub and child repos.
  - Cover target resolution by lane ID or branch name.
  - Cover non-overridable structural refusals:
    - default checkout target;
    - unmanaged path/branch;
    - ambiguous target;
    - still-attached branch/worktree mismatch.
  - Cover loss-reporting refusals:
    - tracked modifications with patch output;
    - untracked text content output;
    - binary-file evidence;
    - local-only commits with commit list + patch;
    - missing/unusable upstream proof.
  - Cover `--dry-run`, `--force`, and stale-token rejection after state changes.

- [ ] **Step 2: Verify RED**
  - Run:

    ```bash
    bash tests/devspace/test_retire_worktree.sh
    ```

  - Expected: FAIL because the cleanup command and helper do not exist yet.

- [ ] **Step 3: Implement the minimal cleanup command**
  - Resolve the target through the managed lane metadata first.
  - Refuse on structural invariants before considering `--force`.
  - For loss-related refusals, print evidence plus the exact retry command with the current `--force-token`.
  - On successful cleanup, remove the worktree, delete the local branch, and convert the active binding into a retired/tombstone record.

- [ ] **Step 4: Verify GREEN**
  - Rerun `bash tests/devspace/test_retire_worktree.sh` and confirm it passes.

- [ ] **Step 5: Mandatory refactor checkpoint**
  - Keep evidence generation and token computation inside the helper rather than spreading it across the CLI wrapper.
  - Rerun the cleanup test after any refactor.

- [ ] **Step 6: Commit the cleanup slice**
  - Suggested commit: `feat(worktree): add managed retirement command`

**User Check-in:** before widening the CLI surface beyond the approved spec, confirm any proposed naming or output-shape changes that would be hard to reverse.

---

## Task 5: Update runbooks and final doc coverage for the managed lane workflow

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`
- Modify: `tests/docs/test_managed_worktree_lane_safety_policy.sh`

- [ ] **Step 1: Write or extend failing doc assertions first if the runbook wording needs new anchors**
  - Lock examples for:
    - creating a lane-safe worktree;
    - understanding that scoped authoring should not proceed from hub root or unrelated worktrees;
    - retiring a managed worktree locally;
    - preserving the v1 non-goal that remote branch deletion is out of scope.

- [ ] **Step 2: Update the runbooks minimally**
  - Document the new managed retirement command and when to prefer it.
  - Keep the guidance consistent with the new refusal-backed policy language.

- [ ] **Step 3: Verify GREEN on the runbook/doc set**
  - Run:

    ```bash
    bash tests/docs/test_managed_worktree_lane_safety_policy.sh
    bash tests/docs/test_bare_hub_guardrails.sh
    ```

  - Expected: PASS.

- [ ] **Step 4: Commit the runbook slice**
  - Suggested commit: `docs(runbook): add managed lane workflow guidance`

---

## Task 6: Final verification, spec mapping, and handoff

**Files:**
- Review only: all files touched above

- [ ] **Step 1: Run the focused regression suite**
  - Run:

    ```bash
    bash tests/docs/test_managed_worktree_lane_safety_policy.sh
    bash tests/docs/test_delegation_packet_policy_contract.sh
    bash tests/docs/test_bare_hub_guardrails.sh
    bash tests/devspace/test_new_worktree.sh
    bash tests/devspace/test_managed_lane_registry.sh
    bash tests/devspace/test_retire_worktree.sh
    ```

- [ ] **Step 2: Re-read the spec and confirm each acceptance criterion is covered by policy text, command behavior, or tests**
  - Pay special attention to:
    - lane-qualified work-item identity from the start;
    - sibling-lane distinction;
    - independent subagent verification against available intent signals;
    - exact non-guarantee wording for ambiguous wrong-yet-self-consistent sibling-lane dispatch;
    - local-only cleanup with non-overridable structural checks.

- [ ] **Step 3: Record the required post-implementation reviews**
  - Append the pragmatic-programmer diagnostic score.
  - Append the clean-code review outcome.
  - If either is below the repo threshold, append 1–3 remediation items.

- [ ] **Step 4: Record the operational reminder**
  - Remind the user that opencode must be restarted after merged/applied policy/agent config changes for new sessions to pick them up.

---

## Final verification checklist

- [ ] `bash tests/docs/test_managed_worktree_lane_safety_policy.sh`
- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] `bash tests/devspace/test_new_worktree.sh`
- [ ] `bash tests/devspace/test_managed_lane_registry.sh`
- [ ] `bash tests/devspace/test_retire_worktree.sh`
- [ ] Re-read `docs/superpowers/specs/2026-06-20-managed-worktree-lane-safety-design.md` and confirm every acceptance criterion maps to final tests or user-visible behavior.
- [ ] Confirm the ordered available-intent-signals list is present and consistent across canonical/operational policy surfaces.
- [ ] Confirm the exact non-guarantee sentence is mirrored verbatim in the doc-contract tests.
- [ ] Confirm the final handoff includes the opencode restart reminder plus pragmatic-programmer and clean-code review outcomes.

## Notes for the implementing agent

- Follow strict TDD per task: red → verify red → green → verify green → refactor → verify green.
- Keep the branch-keyed `state/` / `tmp/` layout intact in v1; add lane metadata alongside it rather than replacing it.
- Prefer small shell helpers with inspectable text metadata over clever opaque state.
- Treat the policy/test wording as part of the product surface; do not silently paraphrase the locked non-guarantee sentence.
