# DevSpace Model Credential Phasing Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Phase 1 of the model-credential phasing design by moving direct provider-key sourcing to Kubernetes Secrets referenced by the workspace Deployment, documenting the create/rotate/verify flow, and removing repo-managed or PVC-backed provider-key dependencies.

**Architecture:** Treat this slice as an operational-hardening change across three surfaces: Kubernetes manifests, DevSpace/operator documentation, and verification tests. Keep Phase 1 intentionally narrow: standardize the secret naming/key contract, inject provider credentials into the workspace container through required `secretKeyRef` environment variables, document the truthful security boundary and operator flow, and leave all broker/gateway work for Phase 2.

**Tech Stack:** Kubernetes YAML manifests, DevSpace configuration/docs, Markdown runbooks/spec-linked plan docs, and existing Bash-based docs/devspace contract tests under `tests/docs/` and `tests/devspace/`.

---

## Inputs and authority

- Binding design: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- Editable repo root: `/workspaces/dotfiles/work/devspace-model-credential-phasing`
- Phase boundary: this plan covers **Phase 1 only** from the umbrella design
- Primary implementation surfaces:
  - `k8s/devspace-bare-hub/workspace-deployment.yaml`
  - `devspace.yaml`
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Existing verification surfaces to extend rather than bypass:
  - `tests/devspace/test_workspace_manifest_contract.sh`
  - `tests/devspace/test_devspace_command_surface.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`

## Spec review cycle outcome

- The binding spec is internally consistent for a Phase 1-only plan: it clearly separates operational hardening from the later trust-boundary correction.
- The main planning-sensitive ambiguity left open is the **exact initial provider set**. The plan below keeps the contract provider-agnostic and requires one explicit user check-in before implementation hardens any default provider list.
- No spec change is required to begin Phase 1 planning.

## Scope

### In scope

- Define the Phase 1 provider secret naming convention and required secret key contract.
- Update the workspace Deployment manifest so configured providers are consumed through required `secretKeyRef` environment variables.
- Document the operator flow for creating, rotating, redeploying/restarting, and verifying provider secrets outside git.
- Remove any direct provider-key dependency on repo-managed files, shell startup files, and PVC-backed workspace files.
- Add or extend verification so the manifest contract, runbook wording, and fail-fast behavior are all reviewable without implementation guesswork.

### Out of scope

- No Phase 2 broker/model-gateway work.
- No workspace-to-broker endpoint or auth contract changes.
- No claim that Phase 1 prevents workspace-local access to raw provider credentials.
- No introduction of a broader secret-management platform beyond Kubernetes Secrets.
- No provider-specific application logic beyond the naming/key contract needed for direct workspace injection.

## Acceptance criteria

Phase 1 is complete when all of the following are true:

1. The repo defines one documented secret naming pattern for direct provider access in Phase 1: `opencode-provider-<provider>`.
2. The documented required key inside each secret matches the provider environment variable name expected in the workspace (for example `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`).
3. `k8s/devspace-bare-hub/workspace-deployment.yaml` references only secret names and key names for provider credentials and does not embed any provider credential values.
4. The workspace container consumes configured provider credentials via required `secretKeyRef` environment variables.
5. The plan implementation removes any documented or actual dependency on repo-managed files, shell startup files, or PVC-backed ad hoc files as sources of provider keys, including any provider-key sourcing from `state/hub/etc/install.env`; ordinary install-branch metadata references to `install.env` remain valid.
6. The runbook documentation explains how to create the secrets outside git, rotate them, restart or redeploy the workspace so new values are picked up, and verify that provider access still works.
7. The runbooks state truthfully that Phase 1 removes secrets from normal files but does **not** prevent code running inside the workspace from reading or using those credentials.
8. Missing or misnamed required secret references fail in a clear Kubernetes-level way consistent with a required `secretKeyRef` misconfiguration.
9. Verification coverage exists for the manifest contract and the updated documentation wording, and that coverage is reviewable by a docs reviewer without requiring implementation code examples inside this plan.
10. No Phase 2 broker requirements or follow-on work are pulled into this implementation slice.

## Proposed file map

### Manifest and config surfaces

- Modify: `k8s/devspace-bare-hub/workspace-deployment.yaml` — add provider credential environment entries backed by required `secretKeyRef` references; keep values out of the manifest.
- Modify: `devspace.yaml` — update comments or operator-facing guidance only if needed to point readers to the new secret-backed workflow; do not add Phase 2 behavior.

### Documentation surfaces

- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` — host/operator lifecycle guidance for create, rotate, restart/redeploy, and verification flow.
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md` — in-pod truth-in-advertising guidance about where credentials now come from and what Phase 1 does not protect against.
- Optional if the implementing agent finds it necessary for clarity: add one focused Phase 1 runbook under `docs/superpowers/runbooks/` rather than overloading unrelated docs. If this is needed, pause at the documentation-structure check-in first.

### Verification surfaces

- Prefer create: `tests/devspace/test_model_credential_phase1_contract.sh` — one focused Phase 1 contract test that locks:
  - required provider secret naming/key anchors,
  - `secretKeyRef`-based Deployment wiring,
  - truthful Phase 1 security-boundary wording,
  - create/rotate/verify operator-flow anchors.
- Extend existing tests only where the overlap is direct and keeps the slice smaller:
  - `tests/devspace/test_workspace_manifest_contract.sh`
  - `tests/devspace/test_devspace_command_surface.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`

---

## Task 1: Lock the Phase 1 contract with a failing reviewable test slice

**Intent:** Make the Phase 1 requirements mechanically reviewable before changing manifests or docs.

**Files:**
- Prefer create: `tests/devspace/test_model_credential_phase1_contract.sh`
- Extend only directly overlapping existing tests under `tests/docs/` and `tests/devspace/`

- [ ] Write a failing contract test first for the Phase 1 secret contract and runbook truthfulness.
- [ ] Assert the secret naming pattern, required key naming rule, `secretKeyRef`-based Deployment wiring, and fail-fast expectation anchored in the spec.
- [ ] Assert the runbooks describe create, rotate, restart/redeploy, and verify flow, and explicitly state that Phase 1 does not protect against workspace-local credential access.
- [ ] Verify RED by running only the new or extended contract tests.
- [ ] Commit the red test slice.

**Verification target:** the red test must fail because the current Deployment has no provider secret wiring and the current runbooks do not yet define the Phase 1 flow.

**Review cycle:** request docs-reviewer feedback on the red contract-test wording before manifest work begins, specifically asking whether the contract is Phase 1-only and free of hidden Phase 2 assumptions.

---

## Task 2: Add the Phase 1 provider secret contract to the workspace manifest

**Intent:** Make the workspace Deployment consume provider credentials only through Kubernetes Secrets and required environment-variable wiring.

**Files:**
- Modify: `k8s/devspace-bare-hub/workspace-deployment.yaml`
- Verify against: `tests/devspace/test_workspace_manifest_contract.sh` and the new Phase 1 contract test

- [ ] Add the approved provider secret naming and key contract to the manifest-level design in the narrowest form needed for Phase 1.
- [ ] Wire configured providers into the workspace container environment using required `secretKeyRef` entries.
- [ ] Keep the Deployment free of secret values, fallback file reads, or PVC-backed credential sources.
- [ ] Preserve the existing workspace shape outside the credential-wiring change.
- [ ] Verify GREEN on the manifest-focused tests.
- [ ] Perform the mandatory refactor checkpoint: keep the manifest readable, keep provider contract knowledge in one place, and avoid speculative abstraction for Phase 2.
- [ ] Commit the manifest slice.

**User Check-in:** before hardening a default provider list in the manifest, confirm which providers must be supported in the first Phase 1 slice if the answer is not already obvious from current usage.

**Review cycle:** request review focused on whether the manifest contract stays Phase 1-only, uses required secret references, and avoids reintroducing file-backed secrets through adjacent configuration.

---

## Task 3: Document the create, rotate, and verify operator flow

**Intent:** Give operators a truthful, end-to-end runbook for managing Phase 1 provider secrets without leaking them into git or PVC-backed files.

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Optional with check-in: one new focused Phase 1 runbook under `docs/superpowers/runbooks/`

- [ ] Document how to create each provider secret outside git using the approved naming and key contract.
- [ ] Document how to rotate a secret and what workspace restart/redeploy action is required for the new value to take effect.
- [ ] Document how to verify that the workspace still has working provider access after secret creation or rotation.
- [ ] State clearly that Phase 1 removes provider keys from normal files but does not make the workspace a trusted boundary for those credentials.
- [ ] Remove or rewrite any documentation that implies repo-managed files, shell startup files, ad hoc PVC-backed files, or provider-key sourcing from `install.env` are valid provider-key sources while preserving legitimate non-credential install-metadata references.
- [ ] Verify GREEN on the docs-focused contract tests.
- [ ] Perform the mandatory standalone refactor checkpoint: tighten the documentation wording, keep the Phase 1 credential contract authoritative and non-duplicative, and rerun the docs-focused contract tests after any cleanup.
- [ ] Commit the documentation slice.

**User Check-in:** if the implementing agent concludes that the existing runbooks would become overloaded, pause and confirm whether to add one dedicated Phase 1 credential runbook instead of expanding the two existing runbooks.

**Review cycle:** request docs-reviewer feedback specifically on truthfulness, operator clarity, and whether the documented flow can be followed without any unstated tribal knowledge.

---

## Task 4: Remove direct provider-key dependency on repo-managed or PVC-backed files

**Intent:** Ensure Phase 1 does not leave behind an alternate, contradictory credential path.

**Files:**
- Review and modify only the surfaces that actually carry provider-key assumptions
- Expected primary surfaces: manifest comments, runbooks, and any secret-related helper/config text discovered during implementation

- [ ] Search the repo for direct provider-key dependency on repo-managed files, shell startup files, provider-key sourcing from `state/hub/etc/install.env`, or PVC-backed workspace files.
- [ ] Remove or rewrite only the live references that would conflict with the Phase 1 contract.
- [ ] Keep the cleanup surgical; do not broaden into unrelated secret-management refactors or non-credential `install.env` metadata usage.
- [ ] Re-run the focused Phase 1 tests plus any touched existing tests.
- [ ] Perform the mandatory standalone refactor checkpoint: confirm the cleanup stayed credential-specific, preserve valid install-metadata references, and rerun the focused Phase 1 tests after any wording or scope cleanup.
- [ ] Commit the cleanup slice.

**Verification target:** there should be no remaining live documentation or manifest/config surface that instructs operators to place provider API keys in tracked repo files, shell startup files, provider-key fields in `install.env`, or PVC-backed ad hoc files.

**Review cycle:** request review focused on drift detection: ask whether any remaining file-based provider-key path still exists in live repo surfaces after the cleanup.

---

## Task 5: Final verification, review cycle, and handoff

**Intent:** Finish the Phase 1 slice with evidence, explicit review, and no accidental Phase 2 drift.

**Files:**
- Review only the changed manifest, runbooks, and tests from Tasks 1-4

- [ ] Re-run all Phase 1 verification commands from a clean working state.
- [ ] Confirm the changed-file list stays within the approved Phase 1 surfaces.
- [ ] Re-read the Phase 1 section of the binding spec and map each requirement to a changed file or verification surface.
- [ ] Perform the mandatory refactor checkpoint even if no further edits are needed.
- [ ] Request one final review cycle on the completed plan slice, asking reviewers to check Phase 1 scope discipline, reviewability, and truthful security-boundary wording.
- [ ] Present the changed files, verification evidence, and any follow-up items to the user.

**Final User Check-in:** before declaring the slice done, show the final secret contract summary, the documented operator flow, and the exact fail-fast expectation for missing required secrets.

---

## Verification plan

At minimum, the implementation should leave behind fresh evidence for:

- one manifest-focused verification command covering `workspace-deployment.yaml`
- one docs-focused verification command covering the Phase 1 runbook wording
- any existing DevSpace command-surface test that was touched indirectly by the documentation/config updates
- a final changed-files check such as `git diff --name-only` or equivalent review output

Suggested verification surfaces:

- `bash tests/devspace/test_workspace_manifest_contract.sh`
- `bash tests/devspace/test_model_credential_phase1_contract.sh` if the preferred focused contract file is added
- the new or extended Phase 1 contract tests under `tests/devspace/` and/or `tests/docs/`
- `bash tests/docs/test_bare_hub_guardrails.sh` if runbook wording is extended there
- `bash tests/devspace/test_devspace_command_surface.sh` if `devspace.yaml` guidance changes

## Risks and constraints

- **Provider-set ambiguity:** the spec leaves the exact initial provider set open. Do not silently hard-code a broader set than needed.
- **Truthfulness risk:** documentation must not imply that Kubernetes Secret injection makes the workspace unable to access the raw credentials.
- **Scope-creep risk:** broker endpoint, broker auth, egress policy, or model-gateway concerns belong to Phase 2, not this plan.
- **DRY risk:** keep the secret naming/key contract authoritative in one clear surface and have the other docs/tests point to that wording rather than restating it inconsistently.
- **Operational risk:** required `secretKeyRef` wiring is intentionally fail-fast; documentation must prepare operators for misconfiguration symptoms rather than treating them as runtime bugs.

## Reviewer guidance

This plan is intentionally high-level and docs-reviewable.

Review this plan against the binding spec, scope boundaries, file map, acceptance criteria, risks, and check-ins. Do **not** require embedded implementation code, YAML snippets, or shell examples for plan approval.

Reviewers should evaluate it by asking:

1. Does every planned change map to a Phase 1 requirement from the binding spec?
2. Are acceptance criteria verifiable without requiring implementation code examples inside the plan?
3. Does the plan stay out of Phase 2 broker work?
4. Are the User Check-ins placed before hard-to-reverse choices?
5. Does the review cycle ask for the right kind of feedback at the right time?

## Pragmatic diagnostic

Score: **8.5/10**

Strong rows: DRY, orthogonality, tracer-slice focus, design-by-contract, broken-window prevention, reversibility.

Remaining gap:

- **Estimation/range detail** is still light because the plan is intentionally artifact-first and review-oriented. During implementation kickoff, convert each task into a small time range before scheduling.

Remediation to reach 10/10:

1. Pick one minimal provider slice first if provider ambiguity remains.
2. Keep the manifest and docs contract tests as the authoritative tracer bullet for Phase 1.
3. Record task-level estimates before implementation begins.
