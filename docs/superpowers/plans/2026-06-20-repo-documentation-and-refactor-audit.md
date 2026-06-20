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
- Primary evidence surfaces named in the spec:
  - `README.md`
  - `install.sh`
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
  - `.config/opencode/AGENTS.md`
  - `bin/new-worktree`
  - `bin/dre`
  - `bin/dwt`
  - `scripts/lib/resolve-install-target.sh`
- Existing tests expected to supply characterization evidence before any new test is considered:
  - `tests/docs/test_bare_hub_guardrails.sh`
  - `tests/docs/test_clean_code_policy_contract.sh`
  - `tests/docs/test_delegation_packet_policy_contract.sh`
  - `tests/docs/test_multi_question_interaction_policy.sh`
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
  - `install.sh`
  - `.config/opencode/AGENTS.md`
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
  - `bin/new-worktree`
  - `bin/dre`
  - `bin/dwt`
  - `scripts/lib/resolve-install-target.sh`
  - `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md` as a formatting/reference example only, not as an authority source

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

## Task 2: Gather current repository evidence for the audit

**Files:**
- Review only: `README.md`
- Review only: `install.sh`
- Review only: `.config/opencode/AGENTS.md`
- Review only: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Review only: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Review only: `bin/new-worktree`
- Review only: `bin/dre`
- Review only: `bin/dwt`
- Review only: `scripts/lib/resolve-install-target.sh`

- [ ] **Step 1: Inspect the named audit surfaces directly**
  - Read the files listed above and capture evidence for the per-surface template inside the audit draft.
  - Record concrete facts such as file purpose, rough size/density, current entry-point quality, cross-linking quality, and obvious mixed-abstraction hotspots.
  - Use one quick size snapshot command to support readability claims instead of relying on impressions alone:

    ```bash
    wc -l README.md install.sh .config/opencode/AGENTS.md docs/superpowers/runbooks/devspace-bare-hub-usage.md docs/superpowers/runbooks/devspace-workspace-lifecycle.md bin/new-worktree bin/dre bin/dwt scripts/lib/resolve-install-target.sh
    ```

- [ ] **Step 2: Run the current docs/policy contract suites as evidence**
  - Run:

    ```bash
    bash tests/docs/test_bare_hub_guardrails.sh
    bash tests/docs/test_clean_code_policy_contract.sh
    bash tests/docs/test_delegation_packet_policy_contract.sh
    bash tests/docs/test_multi_question_interaction_policy.sh
    ```

  - Use their assertions as evidence for what the repository already treats as live user/agent-facing contract surface.

- [ ] **Step 3: Run the current install/workflow characterization suites as evidence**
  - Run:

    ```bash
    bash tests/install/test_install_validate_source.sh
    bash tests/install/test_install_local_source_contract.sh
    bash tests/install/test_workspace_navigation_shell.sh
    bash tests/devspace/test_workspace_navigation_commands.sh
    bash tests/devspace/test_public_repo_clone_behavior.sh
    bash tests/devspace/test_new_worktree.sh
    bash tests/devspace/test_managed_lane_registry.sh
    bash tests/devspace/test_retire_worktree.sh
    ```

  - Use the test output as characterization evidence for install/bootstrap behavior, navigation behavior, and worktree workflow complexity.

- [ ] **Step 4: Validate the spec's initial hypotheses explicitly**
  - For each initial likely finding in the spec, mark it as `validated`, `partially validated`, or `rejected` based on direct file/test evidence.
  - Cover at minimum:
    - thin `README.md` onboarding
    - stronger-but-buried runbook content
    - `install.sh` as a high-leverage readability hotspot
    - `bin/new-worktree` as a next workflow hotspot
    - smaller focused helpers as examples of preferred local style

- [ ] **Step 5: Do not widen the test surface casually**
  - If one critical audit conclusion still depends on behavior that none of the existing suites cover, stop and open a focused plan update before adding new characterization tests.
  - Do not add opportunistic tests just to satisfy process theater.

---

## Task 3: Draft the audit artifact from the gathered evidence

**Files:**
- Create: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`

- [ ] **Step 1: Write the surface inventory first**
  - Create `## Surface inventory` with one subsection per audited surface.
  - For each subsection, fill in the exact per-surface template fields from the spec.
  - Name concrete files in `Current assets` so later planners know where the evidence came from.

- [ ] **Step 2: Write the documentation gap inventory**
  - Create `## Documentation gap inventory` as a table.
  - Include columns for:
    - gap ID
    - surface
    - affected audiences
    - current evidence
    - likely fix type
    - priority bucket
  - Keep the gap wording tied to evidence such as missing orientation, weak framing, weak cross-links, or discoverability problems.

- [ ] **Step 3: Write the clean-code hotspot inventory**
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

- [ ] **Step 4: Keep policy subordinate**
  - If the audit includes a policy-related finding, place it behind the relevant documentation/refactor evidence and label it as a supporting policy nudge.
  - Exclude any policy-only cleanup that is not directly enabling better documentation or safer refactoring.

---

## Task 4: Derive prioritized follow-on slices and sequencing rationale

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

- [ ] **Step 5: Commit the green audit slice**
  - Suggested commit: `docs(audit): add repo documentation and refactor inventory`

---

## Task 5: Verify the audit artifact and hand off cleanly

**Files:**
- Review only: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Review only: `tests/docs/test_repo_documentation_refactor_audit.sh`

- [ ] **Step 1: Verify the audit contract goes green**
  - Run:

    ```bash
    bash tests/docs/test_repo_documentation_refactor_audit.sh
    ```

  - Expected: PASS.

- [ ] **Step 2: Re-run the focused evidence suites cited by the audit**
  - Run the same evidence commands from Task 2 so the final audit is backed by fresh results, not stale memory.

- [ ] **Step 3: Re-read the governing spec and map every required output to the final artifact**
  - Confirm the final audit answers these questions without guesswork:
    - what the biggest documentation gaps are
    - what the biggest readability/refactor hotspots are
    - which issues affect users/operators, developers, and agents
    - what the first, second, and later follow-on slices should be
    - which policy changes stay out of scope and which small enabling nudges are still allowed

- [ ] **Step 4: Mandatory refactor checkpoint for the artifact itself**
  - Simplify tables, headings, and phrasing if the audit became repetitive or harder to scan.
  - Keep the meaning unchanged and rerun `bash tests/docs/test_repo_documentation_refactor_audit.sh` after cleanup.

- [ ] **Step 5: Final handoff note**
  - Report the audit artifact path, the test path, the focused evidence suites run, and the recommended first follow-on slice candidate.
  - State clearly that no follow-on documentation/refactor implementation was performed in this slice.

---

## Final verification checklist

- [ ] `bash tests/docs/test_repo_documentation_refactor_audit.sh`
- [ ] `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] `bash tests/docs/test_clean_code_policy_contract.sh`
- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_multi_question_interaction_policy.sh`
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
