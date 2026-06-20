# Repo Documentation + Refactor Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the evidence-backed governing audit artifact for repository documentation gaps and clean-code hotspots, including the required inventories, prioritized follow-on slices, and sequencing rationale, without implementing the follow-on slices themselves.

**Architecture:** Treat the audit itself as the product. Lock its required output shape with one failing doc-contract test first, then build the audit from direct repository evidence: current files, current runbooks, current agent guidance, and existing characterization/contract tests for key scripts and workflows. Keep the result in one persistent markdown audit record so later planners can start from audited evidence instead of rediscovery.

**Tech Stack:** Markdown audit artifact, shell doc-contract test, existing Bash characterization/contract tests under `tests/docs/`, `tests/install/`, and `tests/devspace/`, plus direct repository inspection of docs and shell command surfaces.

---

## Inputs and authority

- Binding spec: `docs/superpowers/specs/2026-06-20-repo-documentation-and-refactor-audit-design.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Required audit outputs from the spec:
  1. surface inventory
  2. documentation gap inventory
  3. clean-code hotspot inventory
  4. prioritized follow-on slices
  5. sequencing rationale
- Primary evidence surfaces for this audit:
  - entry and orientation:
    - `README.md`
    - `devspace.yaml`
    - `install.sh`
  - operational and runbook surfaces:
    - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
    - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
    - `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
  - developer command and workflow surfaces:
    - `bin/clone-repo`
    - `bin/new-worktree`
    - `bin/dre`
    - `bin/dwt`
    - `bin/retire-worktree`
    - `scripts/lib/hub-repo-core.sh`
    - `scripts/lib/worktree-env.sh`
    - `scripts/lib/managed-lane-registry.sh`
    - `scripts/lib/managed-worktree-cleanup.sh`
    - `scripts/lib/resolve-install-target.sh`
    - `scripts/lib/resolve-managed-repo-root.sh`
    - `scripts/lib/write-managed-repo-env.sh`
    - `scripts/lib/read-install-env.sh`
    - `scripts/lib/validate_install_source_tree.sh`
    - `scripts/lib/validate_hub_repo_root.sh`
  - agent-facing guidance and orientation surfaces:
    - `.config/opencode/AGENTS.md`
    - `docs/superpowers/templates/subagent-handoff-templates.md`
    - `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`
  - explicit narrowing based on `ls -R docs/superpowers/`:
    - include only `docs/superpowers/templates/subagent-handoff-templates.md` and `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md` as non-runbook orientation/indexing docs
    - exclude `docs/superpowers/explorations/2026-05-23-devpod-alternatives.md` because it is an exploration artifact, not a current orientation/indexing surface
    - exclude `docs/superpowers/review-records/2026-05-19-pragmatic-superpowers-review.md` because it is a historical review snapshot, not a current orientation/indexing surface
    - exclude `docs/superpowers/specs/*.md` and `docs/superpowers/plans/*.md` other than the binding audit spec because they are slice-specific authority/history artifacts rather than general onboarding/indexing docs
- Existing tests expected to supply characterization evidence before any new test is considered:
  - `tests/bootstrap/test_setup_host_bare_hub.sh`
  - `tests/bootstrap/test_verify_host_bare_hub.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`
  - `tests/docs/test_clean_code_policy_contract.sh`
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_multi_question_interaction_policy.sh`
  - `tests/devspace/test_devspace_command_surface.sh`
  - `tests/devspace/test_devspace_doctor.sh`
  - `tests/devspace/test_workspace_provision.sh`
  - `tests/devspace/test_workspace_repair.sh`
  - `tests/install/test_install_validate_source.sh`
  - `tests/install/test_install_local_source_contract.sh`
  - `tests/install/test_workspace_navigation_shell.sh`
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/devspace/test_public_repo_clone_behavior.sh`
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_retire_worktree.sh`

## Scope

### In scope

- Create the persistent audit artifact for the approved audit/spec.
- Lock the audit artifact structure with a doc-contract test.
- Use current repository evidence to validate or reject the spec's initial hypotheses.
- Use existing characterization/contract tests as evidence for script behavior and workflow contracts.
- Recommend follow-on slices, including a narrowly scoped supporting policy nudge only if the audit evidence justifies it.

### Out of scope

- Do not implement any follow-on documentation slice.
- Do not refactor `install.sh`, `bin/new-worktree`, or any other hotspot in this slice.
- Do not open a broad policy rewrite or policy-only workstream.
- Do not invent intended workflows that are not supported by current repository files or tests.
- Do not add speculative new tests unless an audit conclusion would otherwise depend on unprotected behavior.

## Proposed file map

- Create: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` — the persistent audit artifact containing all required outputs.
- Create: `tests/docs/test_repo_documentation_refactor_audit.sh` — doc-contract test that locks the audit artifact structure and required headings.
- Review only:
  - `README.md`
  - `devspace.yaml`
  - `install.sh`
  - `.config/opencode/AGENTS.md`
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
  - `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
  - `docs/superpowers/templates/subagent-handoff-templates.md`
  - `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`
  - `docs/superpowers/specs/2026-06-20-repo-documentation-and-refactor-audit-design.md`
  - Exclude with justification: `docs/superpowers/explorations/2026-05-23-devpod-alternatives.md` — exploration artifact, not a current orientation/indexing surface
  - Exclude with justification: `docs/superpowers/review-records/2026-05-19-pragmatic-superpowers-review.md` — historical review snapshot, not a current orientation/indexing surface
  - Exclude with justification: `docs/superpowers/plans/*.md` and other `docs/superpowers/specs/*.md` — slice-specific authority/history artifacts, not general orientation/indexing docs for this audit
  - `bin/clone-repo`
  - `bin/new-worktree`
  - `bin/dre`
  - `bin/dwt`
  - `bin/retire-worktree`
  - `scripts/lib/hub-repo-core.sh`
  - `scripts/lib/worktree-env.sh`
  - `scripts/lib/managed-lane-registry.sh`
  - `scripts/lib/managed-worktree-cleanup.sh`
  - `scripts/lib/resolve-install-target.sh`
  - `scripts/lib/resolve-managed-repo-root.sh`
  - `scripts/lib/write-managed-repo-env.sh`
  - `scripts/lib/read-install-env.sh`
  - `scripts/lib/validate_install_source_tree.sh`
  - `scripts/lib/validate_hub_repo_root.sh`

---

## Task 1: Lock the audit artifact contract with a failing docs test

**Files:**
- Create: `tests/docs/test_repo_documentation_refactor_audit.sh`
- Create: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`

- [ ] **Step 1: Write the failing doc-contract test first**
  - Assert that `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` contains these exact top-level sections:
    - `## Surface inventory`
    - `## Documentation gap inventory`
    - `## Clean-code hotspot inventory`
    - `## Prioritized follow-on slices`
    - `## Sequencing rationale`
  - Assert that the audit includes one section each for:
    - `### Entry and orientation surfaces`
    - `### Operational and runbook surfaces`
    - `### Developer command and workflow surfaces`
    - `### Agent-facing guidance and orientation surfaces`
  - Assert that each surface section contains the per-surface template labels from the spec:
    - `Current role`
    - `Primary audiences`
    - `Current assets`
    - `Documentation gaps`
    - `Readability/refactor hotspots`
    - `Risk of change`
    - `Recommended slice type`
  - Assert that the priority model appears in the artifact:
    - `P1 — foundation blockers`
    - `P2 — important structural improvements`
    - `P3 — opportunistic cleanups`
    - `Supporting policy nudge`

- [ ] **Step 2: Verify RED**
  - Run:

    ```bash
    bash tests/docs/test_repo_documentation_refactor_audit.sh
    ```

  - Expected: FAIL because the audit artifact does not exist yet or lacks the required sections.

- [ ] **Step 3: Keep the contract test structural, not prescriptive**
  - Lock only the required headings, surface coverage, and priority vocabulary.
  - Do not freeze exact prose, rankings, or line-by-line conclusions in the test.

- [ ] **Step 4: Commit the red test slice**
  - Suggested commit: `test(docs): lock repo documentation audit contract`

---

## Task 2: Gather entry-point and operational surface evidence

**Files:**
- Review only: `README.md`
- Review only: `devspace.yaml`
- Review only: `install.sh`
- Review only: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Review only: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Review only: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`

- [ ] **Step 1: Inspect the thin entry surfaces first**
  - Read `README.md` and `devspace.yaml`.
  - Capture evidence about onboarding clarity, command discoverability, and whether the repo's first-contact story matches the richer downstream docs.

- [ ] **Step 2: Inspect the top-level install/orientation surface**
  - Read `install.sh`.
  - Capture evidence about mixed responsibilities, user messaging density, and how much hidden workflow knowledge this entry point requires.

- [ ] **Step 3: Inspect the current live runbooks**
  - Read `docs/superpowers/runbooks/devspace-bare-hub-usage.md` and `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`.
  - Capture evidence about discoverability, overlap, cross-linking, and whether these runbooks already carry content missing from the top-level entry points.

- [ ] **Step 4: Inspect the host/bootstrap runbook**
  - Read `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`.
  - Capture evidence about host-vs-pod workflow clarity and whether it creates additional navigation burden for users and developers.

- [ ] **Step 5: Capture one size snapshot for these surfaces**
  - Run:

    ```bash
    wc -l README.md devspace.yaml install.sh docs/superpowers/runbooks/devspace-bare-hub-usage.md docs/superpowers/runbooks/devspace-workspace-lifecycle.md docs/superpowers/runbooks/host-bare-hub-bootstrap.md
    ```

- [ ] **Step 6: Run the host/bootstrap characterization suites**
  - Run:

    ```bash
    bash tests/bootstrap/test_setup_host_bare_hub.sh
    bash tests/bootstrap/test_verify_host_bare_hub.sh
    ```

  - Use their assertions as evidence for host bootstrap expectations and documented host layout behavior.

- [ ] **Step 7: Run the live operational surface suites**
  - Run:

    ```bash
    bash tests/devspace/test_devspace_command_surface.sh
    bash tests/devspace/test_devspace_doctor.sh
    bash tests/devspace/test_workspace_provision.sh
    bash tests/devspace/test_workspace_repair.sh
    ```

  - Use the output as evidence for how much the repo already protects provision/repair/doctor workflows with contract tests.

---

## Task 3: Gather workflow and agent-orientation evidence

**Files:**
- Review only: `.config/opencode/AGENTS.md`
- Review only: `docs/superpowers/templates/subagent-handoff-templates.md`
- Review only: `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`
- Review only for scope validation: `docs/superpowers/review-records/2026-05-19-pragmatic-superpowers-review.md`
- Review only for authority boundary: `docs/superpowers/specs/2026-06-20-repo-documentation-and-refactor-audit-design.md`
- Review only: `bin/clone-repo`
- Review only: `bin/new-worktree`
- Review only: `bin/dre`
- Review only: `bin/dwt`
- Review only: `bin/retire-worktree`
- Review only: `scripts/lib/hub-repo-core.sh`
- Review only: `scripts/lib/worktree-env.sh`
- Review only: `scripts/lib/managed-lane-registry.sh`
- Review only: `scripts/lib/managed-worktree-cleanup.sh`
- Review only: `scripts/lib/resolve-install-target.sh`
- Review only: `scripts/lib/resolve-managed-repo-root.sh`
- Review only: `scripts/lib/write-managed-repo-env.sh`
- Review only: `scripts/lib/read-install-env.sh`
- Review only: `scripts/lib/validate_install_source_tree.sh`
- Review only: `scripts/lib/validate_hub_repo_root.sh`

- [ ] **Step 1: Inspect the canonical agent-orientation surface**
  - Read `.config/opencode/AGENTS.md`.
  - Capture evidence about policy density, orientation burden, and whether readers get enough indexing help before the detailed rules begin.

- [ ] **Step 2: Inspect adjacent agent-orientation docs under `docs/superpowers/`**
  - Use `ls -R docs/superpowers/` to confirm that the only non-runbook docs treated as active orientation/indexing aids in this slice are:
    - `docs/superpowers/templates/subagent-handoff-templates.md`
    - `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`
  - Read those two files and record whether they help orientation or instead require prior policy knowledge to navigate effectively.

- [ ] **Step 3: Verify the narrowing against one excluded review artifact**
  - Read `docs/superpowers/review-records/2026-05-19-pragmatic-superpowers-review.md`.
  - Record why it stays out of the orientation-doc review: historical review context, not an active indexing/onboarding surface.

- [ ] **Step 4: Confirm the authority-vs-orientation boundary for specs/plans**
  - Re-read `docs/superpowers/specs/2026-06-20-repo-documentation-and-refactor-audit-design.md`.
  - Record why the active spec is binding authority for this plan but not part of the broader orientation-doc audit inventory.

- [ ] **Step 5: Inspect command entry points for workflow complexity**
  - Read `bin/clone-repo`, `bin/new-worktree`, `bin/dre`, `bin/dwt`, and `bin/retire-worktree`.
  - Capture evidence about orchestration density, mixed abstraction levels, and how much workflow behavior is explained only indirectly through tests.

- [ ] **Step 6: Inspect supporting helper surfaces behind the command layer**
  - Read `scripts/lib/hub-repo-core.sh`, `scripts/lib/worktree-env.sh`, `scripts/lib/managed-lane-registry.sh`, `scripts/lib/managed-worktree-cleanup.sh`, `scripts/lib/resolve-install-target.sh`, `scripts/lib/resolve-managed-repo-root.sh`, `scripts/lib/write-managed-repo-env.sh`, `scripts/lib/read-install-env.sh`, and `scripts/lib/validate_install_source_tree.sh`, and `scripts/lib/validate_hub_repo_root.sh`.
  - Record which helpers are good local style exemplars and which ones still add documentation or readability burden.

- [ ] **Step 7: Capture one size snapshot for the command/helper surfaces**
  - Run:

    ```bash
    wc -l .config/opencode/AGENTS.md bin/clone-repo bin/new-worktree bin/dre bin/dwt bin/retire-worktree scripts/lib/hub-repo-core.sh scripts/lib/worktree-env.sh scripts/lib/managed-lane-registry.sh scripts/lib/managed-worktree-cleanup.sh scripts/lib/resolve-install-target.sh scripts/lib/resolve-managed-repo-root.sh scripts/lib/write-managed-repo-env.sh scripts/lib/read-install-env.sh scripts/lib/validate_install_source_tree.sh scripts/lib/validate_hub_repo_root.sh
    ```

- [ ] **Step 8: Run the live docs/policy contract suites in two small groups**
  - Run:

    ```bash
    bash tests/docs/test_bare_hub_guardrails.sh
    bash tests/docs/test_clean_code_policy_contract.sh
    ```

- [ ] **Step 9: Run the remaining docs/policy contract suites**
  - Run:

    ```bash
    bash tests/docs/test_delegation_packet_policy_contract.sh
    bash tests/docs/test_multi_question_interaction_policy.sh
    ```

- [ ] **Step 10: Run the install/navigation characterization suites**
  - Run:

    ```bash
    bash tests/install/test_install_validate_source.sh
    bash tests/install/test_install_local_source_contract.sh
    bash tests/install/test_workspace_navigation_shell.sh
    ```

- [ ] **Step 11: Run the first workflow-command characterization group**
  - Run:

    ```bash
    bash tests/devspace/test_workspace_navigation_commands.sh
    bash tests/devspace/test_public_repo_clone_behavior.sh
    bash tests/devspace/test_new_worktree.sh
    ```

- [ ] **Step 12: Run the second workflow-command characterization group**
  - Run:

    ```bash
    bash tests/devspace/test_managed_lane_registry.sh
    bash tests/devspace/test_retire_worktree.sh
    ```

  - Use the test output as characterization evidence for install behavior, navigation behavior, and worktree workflow complexity.

- [ ] **Step 13: Validate the spec's initial hypotheses explicitly**
  - For each initial likely finding in the spec, mark it as `validated`, `partially validated`, or `rejected` based on direct file/test evidence.
  - Cover at minimum:
    - thin `README.md` onboarding
    - stronger-but-buried runbook content
    - `install.sh` as a high-leverage readability hotspot
    - `bin/new-worktree` as a next workflow hotspot
    - smaller focused helpers as examples of preferred local style

- [ ] **Step 14: Do not widen the test surface casually**
  - If one critical audit conclusion still depends on behavior that none of the existing suites cover, stop and open a focused plan update before adding new characterization tests.
  - Do not add opportunistic tests just to satisfy process theater.

---

## Task 4: Draft the minimum audit artifact and verify GREEN early

**Files:**
- Create: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`

- [ ] **Step 1: Write the minimum viable artifact skeleton**
  - Create all required top-level sections and all four required surface subsections.
  - Add brief evidence-backed content under every required per-surface label so the artifact is structurally complete, even before the fuller inventories are expanded.

- [ ] **Step 2: Add minimum viable inventory rows**
  - Add at least one evidence-backed row to `## Documentation gap inventory` and `## Clean-code hotspot inventory`.
  - Add a small provisional list under `## Prioritized follow-on slices` plus one short paragraph under `## Sequencing rationale` so the contract test can pass on real content, not empty headings.

- [ ] **Step 3: Verify GREEN on the minimum artifact immediately**
  - Run:

    ```bash
    bash tests/docs/test_repo_documentation_refactor_audit.sh
    ```

  - Expected: PASS.

---

## Task 5: Expand the audit inventories from the gathered evidence

**Files:**
- Modify: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`

- [ ] **Step 1: Expand the surface inventory for entry and operational surfaces**
  - Fill out the `Current role`, `Primary audiences`, `Current assets`, `Documentation gaps`, `Readability/refactor hotspots`, `Risk of change`, and `Recommended slice type` fields for:
    - entry and orientation surfaces
    - operational and runbook surfaces

- [ ] **Step 2: Expand the surface inventory for workflow and agent-orientation surfaces**
  - Fill out the same per-surface fields for:
    - developer command and workflow surfaces
    - agent-facing guidance and orientation surfaces

- [ ] **Step 3: Expand the documentation gap inventory**
  - Create `## Documentation gap inventory` as a table.
  - Include columns for:
    - gap ID
    - surface
    - affected audiences
    - current evidence
    - likely fix type
    - priority bucket
  - Keep the gap wording tied to evidence such as missing orientation, weak framing, weak cross-links, or discoverability problems.

- [ ] **Step 4: Expand the clean-code hotspot inventory**
  - Create `## Clean-code hotspot inventory` as a table.
  - Include columns for:
    - hotspot ID
    - surface/files
    - observed symptoms
    - supporting evidence
    - likely refactor shape
    - risk of change
  - Focus on naming, function size, mixed abstraction levels, orchestration density, and duplication pressure.
  - Keep hotspots at slice-planning level; do not turn this into a line-by-line refactor spec.

- [ ] **Step 5: Keep policy subordinate**
  - If the audit includes a policy-related finding, place it behind the relevant documentation/refactor evidence and label it as a supporting policy nudge.
  - Exclude any policy-only cleanup that is not directly enabling better documentation or safer refactoring.

---

## Task 6: Derive prioritized follow-on slices and sequencing rationale

**Files:**
- Modify: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`

- [ ] **Step 1: Rank findings using the approved prioritization model**
  - Use the four factors from the spec for every P1/P2/P3 decision:
    - audience impact
    - task-blocking severity
    - change leverage
    - implementation safety
  - Make the ranking visible enough that a later planner can reconstruct why each slice landed where it did.

- [ ] **Step 2: Write the prioritized follow-on slices section**
  - Create `## Prioritized follow-on slices`.
  - Produce a small roadmap of 4-6 slices, each with:
    - slice name
    - primary surfaces/files
    - slice type (`doc-only`, `refactor-only`, `combined`, or `supporting policy nudge`)
    - why it belongs in its priority bucket
    - what it intentionally leaves for later
  - Expect the first-pass candidates to be close to the spec's model unless the evidence clearly changes the order.

- [ ] **Step 3: Write the sequencing rationale**
  - Create `## Sequencing rationale`.
  - Explain why the chosen order best reduces confusion and change risk.
  - Default to documentation/orientation improvements before hotspot refactors unless the audit evidence proves a code hotspot is blocking everything else.

- [ ] **Step 4: Add the required user decision point**
  - End the audit artifact with a clear next-step note that the user should choose which approved follow-on slice to plan first.
  - Keep this aligned with User Check-in 2 from the governing spec.

---

## Task 7: Verify the audit artifact, refactor the writeup, and commit the final green slice

**Files:**
- Review only: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Review only: `tests/docs/test_repo_documentation_refactor_audit.sh`

- [ ] **Step 1: Re-run the audit contract after the fuller writeup**
  - Run:

    ```bash
    bash tests/docs/test_repo_documentation_refactor_audit.sh
    ```

  - Expected: PASS.

- [ ] **Step 2: Re-run the focused host/operational evidence suites**
  - Run the same bootstrap and operational commands from Task 2 so the final audit is backed by fresh results, not stale memory.

- [ ] **Step 3: Re-run the focused workflow and docs evidence suites**
  - Run the same docs/install/workflow commands from Task 3 so the final audit is backed by fresh results, not stale memory.

- [ ] **Step 4: Re-read the governing spec and map every required output to the final artifact**
  - Confirm the final audit answers these questions without guesswork:
    - what the biggest documentation gaps are
    - what the biggest readability/refactor hotspots are
    - which issues affect users/operators, developers, and agents
    - what the first, second, and later follow-on slices should be
    - which policy changes stay out of scope and which small enabling nudges are still allowed

- [ ] **Step 5: Mandatory refactor checkpoint for the artifact itself**
  - Simplify tables, headings, and phrasing if the audit became repetitive or harder to scan.
  - Keep the meaning unchanged and rerun `bash tests/docs/test_repo_documentation_refactor_audit.sh` after cleanup.

- [ ] **Step 6: Commit the final green audit slice after refactoring**
  - Suggested commit: `docs(audit): add repo documentation and refactor inventory`

- [ ] **Step 7: Final handoff note**
  - Report the audit artifact path, the test path, the focused evidence suites run, and the recommended first follow-on slice candidate.
  - State clearly that no follow-on documentation/refactor implementation was performed in this slice.

---

## Final verification checklist

- [ ] `bash tests/docs/test_repo_documentation_refactor_audit.sh`
- [ ] `bash tests/bootstrap/test_setup_host_bare_hub.sh`
- [ ] `bash tests/bootstrap/test_verify_host_bare_hub.sh`
- [ ] `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] `bash tests/docs/test_clean_code_policy_contract.sh`
- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_multi_question_interaction_policy.sh`
- [ ] `bash tests/devspace/test_devspace_command_surface.sh`
- [ ] `bash tests/devspace/test_devspace_doctor.sh`
- [ ] `bash tests/devspace/test_workspace_provision.sh`
- [ ] `bash tests/devspace/test_workspace_repair.sh`
- [ ] `bash tests/install/test_install_validate_source.sh`
- [ ] `bash tests/install/test_install_local_source_contract.sh`
- [ ] `bash tests/install/test_workspace_navigation_shell.sh`
- [ ] `bash tests/devspace/test_workspace_navigation_commands.sh`
- [ ] `bash tests/devspace/test_public_repo_clone_behavior.sh`
- [ ] `bash tests/devspace/test_new_worktree.sh`
- [ ] `bash tests/devspace/test_managed_lane_registry.sh`
- [ ] `bash tests/devspace/test_retire_worktree.sh`
- [ ] Re-read `docs/superpowers/specs/2026-06-20-repo-documentation-and-refactor-audit-design.md` and confirm all five required audit outputs are present in the final artifact.
- [ ] Confirm every follow-on slice in the audit is evidence-backed and scoped as doc-only, refactor-only, combined, or a narrowly justified supporting policy nudge.
- [ ] Confirm the audit artifact does not drift into follow-on implementation detail.

## Notes for the implementing agent

- The audit document is the deliverable; treat it like a product surface, not scratch notes.
- Prefer citing existing tests as characterization evidence over adding new tests.
- If a claim cannot be supported by direct file evidence or existing tests, say so explicitly instead of guessing.
- Keep the roadmap small and reversible; the next slice should be easy for the user to approve or reorder.
