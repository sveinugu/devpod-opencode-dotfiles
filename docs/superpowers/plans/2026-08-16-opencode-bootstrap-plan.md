# OpenCode Bootstrap Harness Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move local skill and installer-managed bootstrap work onto the new repo-root `.agents/skills` + `skills-lock.json` + `harness-installs.jsonc` contract while keeping `install.sh` branch-aware and verification-first.

**Architecture:** Treat this as one contract-driven install/bootstrap slice. The tracer bullet is a set of shell contract tests that prove repo-root skill installation, manifest-driven installer refresh, generated-output ignore rules, cleanup of deprecated `.config/opencode/.agents/...` materialization, and the limited preparatory helper boundary. Implementation should keep ordinary OpenCode runtime plugin selection in `opencode.jsonc`, keep installer-managed outputs generated and git-ignored, and keep privileged work out of the skill/plugin regeneration path.

**Tech Stack:** Bash install/bootstrap scripts, JSONC manifest/config files, Dockerfile image setup, repo-tracked OpenCode config, repo-tracked local skills, Bash contract tests under `tests/pod-outside-nono/` and `tests/host/`, and Markdown plan/spec artifacts.

**Spec:** `docs/superpowers/specs/2026-08-16-orchestration-agent-bootstrap-design.md`

## Global Constraints

- Keep `install.sh` as a first-class branch-apply workflow for both in-pod and provision-driven runs.
- Project-local skills must materialize at top-level `.agents/skills/` with top-level `skills-lock.json` as the reconstruction authority.
- Ordinary npm OpenCode plugins remain authoritative in `.config/opencode/opencode.jsonc`.
- Installer-managed harness installs must be declared in top-level `harness-installs.jsonc` and refreshed by running `uninstall`, then `install`, then output verification.
- Generated installer outputs under `.config/opencode/plugins/` and `.config/opencode/commands/` must remain git-ignored rather than committed.
- No sudo is used for project-local skill installation or installer-managed output regeneration.
- Privileged work remains limited to cross-user home wiring and reusable secure-launch/helper infrastructure.
- Helper work in this slice stays preparatory: define the reusable `sudo` + `nono` boundary and its verification surface without turning it into the primary skill/plugin install path.

---

## Scope and ownership

### Named owners

| Area | Owner |
| --- | --- |
| Binding requirements (`Spec:`) | Planner |
| Shell/bootstrap implementation and contract tests | Implementer |
| Cleanup/conformance verification | Implementer |
| Maintenance-skill wording and operator-facing documentation clarity | Docs reviewer |
| `User Check-in` decisions | Human partner |
| Test-runner / CI-hook alignment in `tests/run.sh` | Implementer |

### Proposed file map

**Create**

- `harness-installs.jsonc`
- `scripts/lib/install/install-project-skills.sh`
- `scripts/lib/install/run-harness-installs.sh`
- `scripts/lib/run-with-sudo-nono.sh`
- `.agents/skills/harness-install-maintenance/SKILL.md`
- `tests/pod-outside-nono/test_project_local_skills_contract.sh`
- `tests/pod-outside-nono/test_harness_installs_contract.sh`
- `tests/pod-outside-nono/test_generated_output_ignore_contract.sh`
- `tests/pod-outside-nono/test_cleanup_conformance_contract.sh`
- `tests/host/test_dockerfile_opencode_helper_contract.sh`

**Modify**

- `install.sh`
- `scripts/lib/install/materialize.sh`
- `scripts/provision-workspace.sh`
- `.config/opencode/opencode.jsonc`
- `.config/opencode/package.json`
- `.config/opencode/package-lock.json`
- `.config/opencode/.gitignore`
- `.gitignore`
- `Dockerfile`
- `tests/run.sh`
- `tests/pod-outside-nono/test_install_local_source_contract.sh`
- `scripts/lib/launch-opencode-nono.sh` only if needed to point at the reusable helper surface without expanding slice scope
- `scripts/lib/opencode-wrapper.sh` only if the helper-preparation task needs a small wrapper seam to stay DRY
- `.config/opencode/agents/*.md` only if this slice introduces a new subagent prompt file

### TDD level

- Preferred test level: **contract/integration**.
- Write shell-driven failing tests first for each external behavior change.
- Use `install.sh --dry-run`, manifest fixtures, and observable file/command surfaces instead of low-level unit tests.
- Keep helper work verification-focused: prove boundary and installation path, not speculative future helper features.

## Acceptance test matrix

| Acceptance test | Level | Exact command | Expected outcome |
| --- | --- | --- | --- |
| Install source + repo-root skill invocation contract | Contract | `bash tests/pod-outside-nono/test_install_local_source_contract.sh` | exits `0`; dry-run output proves repo/worktree-root execution and no fallback to repo-backed `.config/opencode/.agents/...` installs |
| Project-local skills contract | Contract | `bash tests/pod-outside-nono/test_project_local_skills_contract.sh` | exits `0`; proves `.agents/skills/` and `skills-lock.json` are the canonical local skill surfaces |
| Harness-installs manifest contract | Contract | `bash tests/pod-outside-nono/test_harness_installs_contract.sh` | exits `0`; proves each manifest entry runs `uninstall` then `install` from the declared `workingDirectory` and verifies outputs |
| Generated-output ignore contract | Contract | `bash tests/pod-outside-nono/test_generated_output_ignore_contract.sh` | exits `0`; proves installer-managed outputs are generated and git-ignored |
| Cleanup/conformance contract | Contract | `bash tests/pod-outside-nono/test_cleanup_conformance_contract.sh` | exits `0`; proves deprecated `.config/opencode/.agents/...`-style materialization is no longer canonical |
| Dockerfile helper contract | Contract | `bash tests/host/test_dockerfile_opencode_helper_contract.sh` | exits `0`; proves `/usr/local/libexec/dotfiles-run-helper` is staged as preparatory helper infrastructure distinct from skill/plugin regeneration |

### CI hooks / regression commands

- `bash tests/run.sh pod-outside-nono` → expected `Summary: ... failed=0` after the new pod-outside-nono tests are added to the runner.
- `bash tests/run.sh host` → expected `Summary: ... failed=0` after the new host helper-contract test is added to the runner.

### User Check-in anchors

- **User Check-in 1:** before broadening `harness-installs.jsonc` beyond `name`, `workingDirectory`, `install`, `uninstall`, and `outputs`.
- **User Check-in 2:** before turning the preparatory `run-with-sudo-nono.sh` helper into anything more than a reusable boundary/helper seam.
- **User Check-in 3:** before introducing any new subagent prompt file that would require the new skill-path pointers.
- **Final User Check-in:** present the authority split, generated-output policy, cleanup result, and helper scope before calling the slice complete.

---

## Task 1: Lock the tracer-bullet contract tests first

**Intent:** Make the new install model observable before changing production scripts.

**Files:**

- Create: `tests/pod-outside-nono/test_project_local_skills_contract.sh`
- Create: `tests/pod-outside-nono/test_harness_installs_contract.sh`
- Create: `tests/pod-outside-nono/test_generated_output_ignore_contract.sh`
- Create: `tests/pod-outside-nono/test_cleanup_conformance_contract.sh`
- Create: `tests/host/test_dockerfile_opencode_helper_contract.sh`
- Modify: `tests/pod-outside-nono/test_install_local_source_contract.sh`

- [ ] Write failing contract tests for repo-root `skills experimental_install`, repo-root `.agents/skills/`, top-level `skills-lock.json`, and manifest-driven installer refresh.
- [ ] Extend `test_install_local_source_contract.sh` so its dry-run expectations stop accepting `.config/opencode`-scoped `skills add` commands and instead expect repo-root skill reconstruction plus installer-helper invocation.
- [ ] Write failing ignore/conformance tests that define stale surfaces exactly as the spec does: deprecated `.config/opencode/.agents/...`, `.config/opencode/skills/`, `.config/opencode/skills-lock.json`, and undeclared generated plugin/command outputs.
- [ ] Write the failing host-side helper contract test that checks for `/usr/local/libexec/dotfiles-run-helper` as preparatory infrastructure only.
- [ ] Run the new red slice:
  - `bash tests/pod-outside-nono/test_install_local_source_contract.sh`
  - `bash tests/pod-outside-nono/test_project_local_skills_contract.sh`
  - `bash tests/pod-outside-nono/test_harness_installs_contract.sh`
  - `bash tests/pod-outside-nono/test_generated_output_ignore_contract.sh`
  - `bash tests/pod-outside-nono/test_cleanup_conformance_contract.sh`
  - `bash tests/host/test_dockerfile_opencode_helper_contract.sh`
- [ ] Verify the expected RED state: current install flow still uses `.config/opencode`-scoped `skills add`, there is no `harness-installs.jsonc`, and the reusable helper surface is not yet aligned.
- [ ] Commit the red tracer-bullet test slice.

**Review gate:** if any failing test needs requirements not present in the spec, stop and resolve via `User Check-in 1` instead of inventing extra manifest fields or helper behavior.

---

## Task 2: Add the repo-root project-skill and harness-install authority surfaces

**Intent:** Introduce the canonical repo-root artifacts that the new install flow will consume.

**Files:**

- Create: `harness-installs.jsonc`
- Create: `scripts/lib/install/install-project-skills.sh`
- Create: `scripts/lib/install/run-harness-installs.sh`
- Modify only if directly needed for fixtures/authority clarity: `.config/opencode/opencode.jsonc`

- [ ] Add `harness-installs.jsonc` at repo root with the initial installer-managed entry for `@bybrawe/opencode-loop`, including exact `workingDirectory`, `install`, `uninstall`, and `outputs` values.
- [ ] Add `install-project-skills.sh` as the repo-root skill reconstruction seam that runs `npx -y skills experimental_install` from the worktree root against the committed top-level `skills-lock.json`.
- [ ] Add `run-harness-installs.sh` as the manifest processor that runs each entry's `uninstall`, then `install`, then output verification from the declared `workingDirectory`, with no sudo.
- [ ] Keep ordinary npm runtime plugin authority in `.config/opencode/opencode.jsonc`; do not duplicate that authority into the new manifest.
- [ ] Run the focused GREEN checks for the new authority surfaces:
  - `bash tests/pod-outside-nono/test_project_local_skills_contract.sh`
  - `bash tests/pod-outside-nono/test_harness_installs_contract.sh`
- [ ] Perform the mandatory refactor checkpoint on the new helper scripts so manifest parsing, path resolution, and output verification stay orthogonal.
- [ ] Commit the authority-surface slice.

**User Check-in:** if implementation pressure suggests adding extra manifest fields, pause and confirm before broadening the schema.

---

## Task 3: Rewire `install.sh` and install-time authority flow

**Intent:** Make the branch-aware installer consume the new repo-root surfaces without changing the approved authority split.

**Files:**

- Modify: `install.sh`
- Modify: `scripts/lib/install/materialize.sh`
- Modify: `scripts/provision-workspace.sh`
- Modify: `tests/pod-outside-nono/test_install_local_source_contract.sh`

- [ ] Update the install/materialize flow so project-local skills are reconstructed from repo root via `npx -y skills experimental_install` rather than `.config/opencode`-scoped `skills add` commands.
- [ ] Call the harness-install helper from the install flow after local skill reconstruction so installer-managed outputs are refreshed by manifest contract.
- [ ] Preserve current branch-aware source resolution, hub-root refusal, cross-user `.config/opencode` symlink wiring, and provision-driven install entrypoints.
- [ ] Keep installer-managed regeneration on the unprivileged path; do not move it behind sudo or the reusable helper.
- [ ] Run the focused GREEN checks:
  - `bash tests/pod-outside-nono/test_install_local_source_contract.sh`
  - `bash tests/pod-outside-nono/test_project_local_skills_contract.sh`
  - `bash tests/pod-outside-nono/test_harness_installs_contract.sh`
- [ ] Perform the mandatory refactor checkpoint to keep install-source resolution separate from skill reconstruction and manifest-driven regeneration.
- [ ] Commit the branch-aware install-flow slice.

**Review gate:** if the install flow cannot stay branch-aware while running from repo root, stop and resolve that contradiction before touching unrelated surfaces.

---

## Task 4: Align plugin authority, ignore rules, and preparatory helper scope

**Intent:** Keep plugin authority single-sourced, generated outputs ignored, and helper work explicitly preparatory.

**Files:**

- Modify: `.config/opencode/package.json`
- Modify: `.config/opencode/package-lock.json`
- Modify: `.config/opencode/.gitignore`
- Modify: `.gitignore`
- Modify: `Dockerfile`
- Create: `scripts/lib/run-with-sudo-nono.sh`
- Create: `.agents/skills/harness-install-maintenance/SKILL.md`
- Modify only if necessary for DRY helper reuse: `scripts/lib/launch-opencode-nono.sh`, `scripts/lib/opencode-wrapper.sh`

- [ ] Make `.config/opencode/package.json` and `.config/opencode/package-lock.json` explicit secondary repo-local dependency surfaces rather than a second runtime plugin authority.
- [ ] Update ignore rules so generated installer-managed outputs under `.config/opencode/plugins/` and `.config/opencode/commands/` are ignored, while the new top-level authority files remain committed.
- [ ] Add the maintenance skill at `.agents/skills/harness-install-maintenance/SKILL.md` so future humans/agents can reconstruct the install model and are pointed back to `.config/opencode/AGENTS.md` for policy/contract expectations.
- [ ] Add the preparatory reusable helper surface and Dockerfile staging only to the extent needed to satisfy the helper contract; keep skill/plugin regeneration outside that helper path.
- [ ] Run the focused GREEN checks:
  - `bash tests/pod-outside-nono/test_generated_output_ignore_contract.sh`
  - `bash tests/host/test_dockerfile_opencode_helper_contract.sh`
- [ ] Perform the mandatory refactor checkpoint to keep runtime-plugin authority, generated-output policy, and preparatory helper scope clearly separated.
- [ ] Commit the authority/ignore/helper slice.

**User Check-in:** before expanding helper behavior beyond the preparatory boundary described in the spec.

---

## Task 5: Cleanup and conformance as a separate reviewable slice

**Intent:** Remove deprecated materialization paths and prove the repo no longer depends on them.

**Files:**

- Modify or remove only deprecated/generated surfaces identified by the new tests
- Modify: `.gitignore`
- Modify: `.config/opencode/.gitignore`
- Modify: `tests/pod-outside-nono/test_cleanup_conformance_contract.sh`

- [ ] Remove or quarantine stale generated skill content under `.config/opencode/.agents/`, `.config/opencode/skills/`, and `.config/opencode/skills-lock.json` if present.
- [ ] Remove or quarantine generated plugin/command outputs that are not declared by the current `harness-installs.jsonc` manifest outputs.
- [ ] Keep the cleanup diff separate from the core install-flow refactor so reviewers can verify conformance independently.
- [ ] Run the focused GREEN checks:
  - `bash tests/pod-outside-nono/test_cleanup_conformance_contract.sh`
  - `bash tests/pod-outside-nono/test_generated_output_ignore_contract.sh`
- [ ] Perform the mandatory refactor checkpoint and verify there is one clear canonical surface for each concern.
- [ ] Commit the cleanup/conformance slice.

**Review gate:** if cleanup would remove repo content whose status is unclear, stop and ask rather than silently deleting potentially intentional tracked files.

---

## Task 6: Final verification, CI-hook alignment, and handoff

**Intent:** Finish with a clean verification story and no ambiguity about what future automation should run.

**Files:**

- Modify: `tests/run.sh`
- Review only the changed files from Tasks 1-5

- [ ] Add the new pod-outside-nono and host contract tests to `tests/run.sh` so the repo-level runner covers the slice automatically.
- [ ] Run the targeted acceptance suite:
  - `bash tests/pod-outside-nono/test_install_local_source_contract.sh`
  - `bash tests/pod-outside-nono/test_project_local_skills_contract.sh`
  - `bash tests/pod-outside-nono/test_harness_installs_contract.sh`
  - `bash tests/pod-outside-nono/test_generated_output_ignore_contract.sh`
  - `bash tests/pod-outside-nono/test_cleanup_conformance_contract.sh`
  - `bash tests/host/test_dockerfile_opencode_helper_contract.sh`
- [ ] Run the aggregate regression commands:
  - `bash tests/run.sh pod-outside-nono`
  - `bash tests/run.sh host`
- [ ] Re-read the binding spec and verify that each target artifact, verification expectation, and cleanup requirement maps to a changed surface or an explicit deferral consistent with the spec.
- [ ] Perform the mandatory final refactor checkpoint even if no further edits are needed.
- [ ] Request review focused on scope discipline, authority clarity, cleanup truthfulness, and whether helper work stayed preparatory.
- [ ] Present the final authority split, acceptance-test evidence, cleanup result, and helper boundary to the user for the final check-in.

**Final User Check-in:** confirm the top-level skill/install authority split, generated-output policy, and helper scope before declaring the slice complete.

---

## Risks and follow-up guards

| Risk | Owner | Mitigation |
| --- | --- | --- |
| Manifest/output drift leaves undeclared generated files behind | Implementer | Keep uninstall+install+output verification in the contract tests and fail cleanup/conformance when drift appears |
| `.config/opencode/package.json` becomes a second runtime plugin source of truth | Implementer + reviewer | Add explicit wording/tests that `opencode.jsonc` remains authoritative for ordinary npm plugins |
| Helper work expands into an unapproved privileged install path | Implementer + human partner | Enforce `User Check-in 2` before broadening helper behavior |
| Cleanup deletes intentional repo content | Implementer | Keep cleanup as its own slice and stop when file ownership/history is unclear |
| Touched install surfaces regress branch-aware behavior | Implementer | Keep `test_install_local_source_contract.sh` in every focused rerun and in the aggregate pod-outside-nono runner |

## Reviewer guidance

Review this plan against the binding spec, especially:

1. Does each task preserve the authority split between repo-root skills, `opencode.jsonc`, and `harness-installs.jsonc`?
2. Are the contract tests the primary deliverables rather than embedded production implementation detail?
3. Does the cleanup task stay separate and verification-focused?
4. Does the helper work remain preparatory instead of becoming the main install mechanism?
5. Are the `User Check-in` markers placed before schema/helper/path-expansion decisions?

## Pragmatic diagnostic

Score: **9/10**

Strong rows: DRY, orthogonality, tracer-bullet testing, design-by-contract, broken-window cleanup, reversibility.

Remaining gap:

- Estimation remains intentionally light; the plan is verification- and scope-oriented rather than schedule-prescriptive.

Remediation to reach 10/10:

1. Add rough per-task time ranges at implementation kickoff.
2. Keep the contract tests authoritative; do not let ad hoc shell checks replace them.
3. Reject any new authority surface unless it is explicitly approved by the user.
