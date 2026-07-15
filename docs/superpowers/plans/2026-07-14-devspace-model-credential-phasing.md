# DevSpace Direct-Provider Hardening with nono Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the repo-supported secure OpenCode path for this DevSpace workspace by proving `nono` is suitable in-pod, keeping supported provider credentials out of agent bash scope, and making wrapped `opencode` the normal command surface.

**Architecture:** Treat this as one end-to-end hardening slice, not a Phase 1/Phase 2 split. The slice is organized around contract tests and operator-visible behavior: a blocking `nono` verification matrix gates the work, Kubernetes remains the credential source of truth, repo-owned `nono` + OpenCode runtime contracts define the supported providers, and a PATH-resolved wrapper makes the secure launch path the default. Documentation and verification evidence are first-class outputs because the security boundary must stay reviewable and truthful.

**Tech Stack:** Kubernetes manifests, DevSpace lifecycle config, shell install/bootstrap surfaces, repo-tracked OpenCode configuration, repo-tracked `nono` runtime/profile assets, Bash-based contract/integration tests under `tests/devspace/` and `tests/docs/`, and Markdown runbooks/spec-linked plan docs.

---

## Inputs and authority

- Binding design: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- Editable repo root: `/workspaces/dotfiles/work/devspace-model-credential-phasing`
- Current runtime/install surfaces already in use:
  - `Dockerfile`
  - `devspace.yaml`
  - `k8s/devspace-bare-hub/workspace-deployment.yaml`
  - `.zshrc`
  - `.config/shell/workspace-navigation.zsh`
  - `scripts/provision-workspace.sh`
  - `scripts/lib/install/materialize.sh`
  - `.config/opencode/opencode.jsonc`
- Existing verification surfaces to extend instead of bypassing:
  - `tests/devspace/test_workspace_manifest_contract.sh`
  - `tests/devspace/test_devspace_command_surface.sh`
  - `tests/devspace/test_workspace_preinstalled_tools_contract.sh`
  - `tests/docs/test_p2_runbook_consolidation.sh` when runbook anchors move

## Spec review cycle outcome

- The spec is implementation-ready for planning and intentionally keeps the work high-level: it defines the blocking gate, supported-provider contract, forbidden fallback routes, launch contract, and operator workflow expectations.
- The most planning-sensitive open points are operational rather than architectural: the exact Kubernetes secret delivery surface before sandboxing, the exact repo layout for new `nono`/OpenCode runtime assets, and any auxiliary endpoints that must remain allowed for wrapped OpenCode usability.
- Those points should be resolved during implementation behind explicit `User Check-in` markers rather than silently fixed in advance here.

## Scope

### In scope

- Lock the **blocking `nono` verification matrix** as the hard gate for the secure path.
- Define the **Kubernetes secret management contract** so real credentials stay outside ordinary interactive shell scope while remaining operator-managed.
- Add a **repo-specific `nono` runtime contract** covering profile minimization, credential routes, network policy, and fail-closed expectations.
- Add an **OpenCode configuration contract** for the supported provider set, including UiO provider templates and repo-tracked model policy.
- Make wrapped `opencode` the **default PATH-resolved launch surface** with raw OpenCode reachable only by explicit absolute path.
- Document the **operator workflow** for enablement, secret rotation, regeneration, restart/redeploy, and verification.
- Leave behind reviewable **acceptance verification evidence** for all blocking rows and any advisory rows exercised.

### Out of scope

- No fallback secure-path variant that reintroduces plain provider env vars into interactive shell scope.
- No broker/model-gateway platform or separate generalized credential broker.
- No support for providers that cannot satisfy the `nono` proxy-injection route.
- No claim that the design proves absolute isolation; the documented boundary must remain pragmatic and truthful.
- No requirement to support manual raw OpenCode use through repo guarantees.

## Acceptance criteria

This plan is complete only when all of the following are true:

1. All **blocking** rows in the spec’s `nono` verification matrix have fresh passing evidence; any advisory rows exercised are recorded explicitly.
2. The repo-supported secure path uses **only** `nono` proxy credential injection for supported providers.
3. The supported provider set is exactly:
   - `gpt-uio-yellow`
   - `gpt-uio-red`
   - `openai`
   - `anthropic` (API only)
   - `github-copilot`
4. Unsupported providers are excluded rather than partially supported.
5. Real provider credentials do not appear in ordinary agent bash scope, shell startup files, repo files, or supported-provider `auth.json` surfaces.
6. Kubernetes remains the source of credential material, but credential visibility before sandboxing is confined to the approved non-interactive launch path.
7. UiO yellow/red remain separate providers with separate credential identities and repo-tracked full current model lists.
8. Standard providers use repo-owned integration/auth contracts plus repo-owned model allowlists, not full mirrored upstream catalogs.
9. `opencode` resolves by PATH to the wrapped secure launcher, and verification includes `command -v opencode` plus `type -a opencode` evidence showing the wrapped entry before the raw binary.
10. The operator workflow has one observable source of truth for provider enablement: a single host-local enablement manifest referenced by the runbooks.
11. Generated runtime configuration matches that host-local enablement manifest exactly, and verification output matches it exactly as well.
12. No tracked repo file contains secret values.
13. If `nono` fails the suitability gate in this pod, the secure-path design is rejected rather than silently downgraded.
14. The privilege-separation + escalation-blocking add-on is implemented with passing contract evidence and dedicated security review sign-off.
15. For the supported path, escalation from agent runtime to owner/operator/root via `sudo`, user-switch attempts, and shell-escape bypass paths is blocked.

Direction lock for this slice:

- Two-user split is mandatory for this plan slice.
- Single-user wrapper-only fallback is out of scope for this plan.

## Proposed file map

### Runtime and launch surfaces

- Modify: `Dockerfile` — ensure the workspace image/runtime can supply `nono` in a way consistent with the approved secure path.
- Modify: `scripts/provision-workspace.sh` — keep workspace bootstrap aligned with any required secure-path runtime installation or verification prerequisites.
- Modify: `scripts/lib/install/materialize.sh` — keep install-time symlinked/runtime surfaces aligned with the secure launch path.
- Create: `.config/opencode/bin/opencode` — PATH-resolved secure wrapper that becomes the default `opencode` entrypoint.
- Review and modify only as needed: `.zshrc` and `.config/shell/workspace-navigation.zsh` — only if launch-path verification or PATH ordering needs documentation or small supporting adjustments.

### Runtime contract surfaces

- Create one repo-tracked `nono` profile/config surface under the repo (exact path chosen during implementation, with a check-in before introducing a new top-level subdirectory).
- Modify or extend `.config/opencode/` surfaces so supported-provider contract, UiO provider templates, and standard-provider allowlists are repo-tracked and reviewable.
- Modify: `k8s/devspace-bare-hub/workspace-deployment.yaml` and related deployment/config surfaces only as needed to support the approved pre-sandbox secret delivery contract without exposing credentials to ordinary interactive shell scope.

### Documentation surfaces

- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Optional with check-in: add one focused secure-path runbook under `docs/superpowers/runbooks/` if overloading the two current runbooks would reduce clarity.

### Verification surfaces

- Prefer create: one focused DevSpace contract/integration test for the `nono` suitability matrix.
- Prefer create: one focused contract test for the secure `opencode` launch wrapper and PATH precedence.
- Prefer create: one focused contract test for the provider/runtime configuration rules.
- Extend existing tests only where overlap is direct:
  - `tests/devspace/test_workspace_manifest_contract.sh`
  - `tests/devspace/test_devspace_command_surface.sh`
  - `tests/devspace/test_workspace_preinstalled_tools_contract.sh`
  - relevant `tests/docs/` runbook-anchor tests if documentation anchors move

---

## Task 1: Lock the blocking `nono` matrix as the tracer-bullet test surface

**Intent:** Make the hard gate executable and reviewable before changing runtime behavior.

**Files:**
- Create: focused `tests/devspace/` contract/integration tests for the blocking matrix
- Extend only directly overlapping existing tests

- [ ] Write failing contract/integration tests first for each blocking matrix row: in-pod runtime, kernel enforcement, fail-closed behavior, network control, proxy secrecy, OpenCode usability, UiO routing, and provider-specific verification.
- [ ] Ensure the tests distinguish blocking rows from advisory rows so the hard gate stays explicit.
- [ ] Use dummy credentials for early red/green cycles wherever the spec requires them.
- [ ] Verify RED on the new matrix-focused tests before runtime/config changes begin.
- [ ] Commit the red tracer-bullet test slice.

**Verification target:** the first red slice should fail because the repo does not yet define the reviewed `nono` runtime contract or the secure wrapped launch path.

**Review cycle:** request docs-review of the matrix wording and evidence expectations before implementation continues. Reviewers should assess contract truthfulness and completeness, not demand embedded code or shell snippets in this plan.

---

## Task 2: Define the Kubernetes secret-management boundary for the secure path

**Intent:** Keep Kubernetes as the credential source of truth while preventing supported-provider credentials from becoming ordinary interactive shell state.

**Files:**
- Modify: `k8s/devspace-bare-hub/workspace-deployment.yaml`
- Modify any directly related lifecycle/bootstrap surface only if it is part of the approved pre-sandbox credential handoff

- [ ] Choose and implement one approved pre-sandbox credential delivery surface that matches the spec’s allowed boundary.
- [ ] Keep real credentials out of shell startup files, persistent user env setup, repo files, and supported-provider `auth.json` surfaces.
- [ ] Make the failure mode clear and fail-closed when the credential source, route, or wrapper prerequisites are missing or malformed.
- [ ] Verify GREEN on the secret-boundary contract tests and any manifest/lifecycle tests touched by the change.
- [ ] Perform the mandatory refactor checkpoint and keep the credential-boundary contract authoritative in one place.
- [ ] Commit the secret-boundary slice.

**User Check-in:** confirm the chosen Kubernetes delivery surface before implementation hardens it if multiple compliant options remain viable after the red test pass/fail evidence is understood.

**Review cycle:** request review focused on whether the design keeps supported-provider credentials out of ordinary interactive bash scope without inventing an unapproved fallback path.

---

## Task 2.5: Add owner/agent runtime identity separation hardening

**Intent:** Tighten the secret boundary by separating owner/operator credential-handoff identity from the non-sudo agent runtime identity, and verify blocked escalation paths under the wrapped secure path.

Owner/operator identity for this slice is the main sudo-capable workspace user: `vscode`.

**Files:**
- Modify: `k8s/devspace-bare-hub/workspace-deployment.yaml`
- Modify: `.config/opencode/bin/opencode`
- Modify: `scripts/lib/nono-secret-env.sh`
- Create or modify focused `tests/devspace/` contract checks for identity separation and `sudo` behavior

Sequencing note: Task 2.5 may complete identity and secret-boundary hardening before wrapper-path binding exists; if `.config/opencode/bin/opencode` is not present yet, finalize wrapper integration in Task 5.

- [ ] Add failing contract/integration tests first for owner-vs-agent identity behavior and secret-file read constraints.
- [ ] Ensure mounted provider-secret files are owner-controlled/read-restricted and are not directly readable by the everyday agent runtime user.
- [ ] Keep credential handoff in a non-interactive owner-controlled wrapper path that fails closed when prerequisites are missing.
- [ ] Verify `sudo` behavior under the wrapped secure path with explicit contract evidence that escalation is blocked for agent runtime.
- [ ] Verify blocked escalation evidence for user-switch attempts and shell-escape bypass attempts under the supported path.
- [ ] Verify GREEN on the new identity-separation/escalation-blocking contract tests plus directly touched manifest/runtime tests.
- [ ] Perform the mandatory refactor checkpoint and keep identity-boundary rules centralized and reviewable.
- [ ] Commit the identity-separation hardening slice.

**User Check-in:** if enforcing non-sudo agent runtime behavior requires a material container-user/ownership contract shift, pause and confirm the exact owner-vs-agent runtime model before broadening rollout.

**Review cycle:** request a security-focused review on identity separation, escalation-blocking evidence (`sudo`, user-switch, shell-escape bypass), and whether the resulting boundary claims remain truthful.

Docs Review Gate: do not begin Task 2.5 runtime implementation until the user approves this docs clarification.

---

## Task 3: Add the repo-specific `nono` runtime contract

**Intent:** Replace any dependence on the stock OpenCode profile with a repo-reviewed `nono` contract that expresses filesystem, network, and credential-routing rules.

**Files:**
- Create: repo-tracked `nono` profile/config surface
- Modify any bootstrap/runtime surface required to invoke that profile consistently

- [ ] Add the reviewed repo-specific `nono` profile/config surface with explicit credential routes for `openai`, `anthropic`, `github-copilot`, `gpt-uio-yellow`, and `gpt-uio-red`.
- [ ] Encode the default-deny child egress posture plus the minimal loopback and explicitly verified auxiliary endpoints needed for wrapped OpenCode operation.
- [ ] Prove fail-closed behavior when the profile, proxy, or credential-route setup is intentionally broken.
- [ ] Verify GREEN on the matrix rows covering kernel enforcement, fail-closed behavior, network control, proxy secrecy, and UiO routing.
- [ ] Perform the mandatory refactor checkpoint with least-privilege and DRY review in mind.
- [ ] Commit the `nono` runtime-contract slice.

**User Check-in:** if implementation reveals required auxiliary endpoints beyond loopback, pause and confirm the proposed allowlist before it becomes part of the supported contract.

**Review cycle:** request review focused on least privilege, route clarity, and whether the supported-provider network contract stays within the spec.

---

## Task 4: Add the OpenCode provider/runtime configuration contract

**Intent:** Make the supported-provider set explicit and reviewable from repo-owned configuration rather than ad hoc runtime state.

**Files:**
- Modify or extend `.config/opencode/` runtime/provider surfaces
- Create additional provider-contract assets only if they live under the chosen repo-tracked config location

- [ ] Add repo-tracked configuration for the exact supported provider set and exclude unsupported providers from the secure path.
- [ ] Keep that provider selection scoped to the repo-supported secure path only; do not redefine out-of-scope raw OpenCode use into a repo-enforced global allowlist.
- [ ] Keep UiO yellow/red as separate providers with separate routing identities and repo-tracked full current model lists.
- [ ] Keep standard-provider model policy as repo-tracked allowlists rather than full mirrored catalogs.
- [ ] Ensure the supported-provider auth contract stays consistent with the `nono` credential-route contract and does not make supported-provider `auth.json` authoritative.
- [ ] Verify GREEN on provider-specific auth/list/request smoke tests, including `GITHUB_TOKEN`-based evidence for GitHub Copilot.
- [ ] Perform the mandatory refactor checkpoint and keep model-policy ownership boundaries clear.
- [ ] Commit the provider/runtime contract slice.

**User Check-in:** if the current sanctioned model lists or allowlists are ambiguous, confirm the exact approved model inventory before the repo-owned policy is finalized.

**Review cycle:** request docs-review on contract clarity and policy ownership, again without requiring code examples inside the plan.

---

## Task 5: Make the wrapped `opencode` launcher the default PATH surface

**Intent:** Turn the secure path into the normal muscle-memory path for users and subprocesses.

**Files:**
- Create: `.config/opencode/bin/opencode`
- Modify only the install/bootstrap/path surfaces needed to make that wrapper the default resolved executable

- [ ] Add the secure wrapper so invoking `opencode` by name launches the reviewed `nono` path.
- [ ] Preserve raw OpenCode availability only by explicit absolute-path use, not as the first PATH-resolved result.
- [ ] Verify the contract with observable shell evidence such as `command -v opencode` and `type -a opencode`.
- [ ] Verify wrapped OpenCode usability for the normal workflow surface: smoke prompt, streaming response, file edit, and subagent call.
- [ ] Perform the mandatory refactor checkpoint and keep the launch contract simple, explicit, and script-friendly.
- [ ] Commit the secure-launch slice.

**User Check-in:** if making the wrapper default requires introducing a new persistent PATH surface beyond the already managed install surfaces, pause before broadening that contract.

**Review cycle:** request review focused on whether the wrapper is a real executable PATH entry and whether the repo avoids training users onto an insecure alternate everyday command.

---

## Task 6: Document the operator workflow and truthful boundary

**Intent:** Give the operator one coherent workflow for enablement, secret rotation, regeneration, redeploy/restart, and verification.

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Optional with check-in: one focused secure-path runbook

- [ ] Document one observable source of truth for provider enablement: a single host-local enablement manifest referenced by the runbooks.
- [ ] Document that both generated runtime configuration and verification output must match that host-local enablement manifest exactly.
- [ ] Document enable/rotate/redeploy/verify flow for the supported providers without ever instructing operators to place credentials in repo files, shell startup files, `.env` files, or supported-provider `auth.json`.
- [ ] State clearly what the secure path improves and what it does **not** guarantee.
- [ ] Explain the secure default launch behavior, the absolute-path raw escape hatch, and the evidence operators should gather when verification fails.
- [ ] Verify GREEN on docs/runbook contract tests.
- [ ] Perform the mandatory standalone refactor checkpoint and remove duplicated or contradictory wording.
- [ ] Commit the documentation slice.

**User Check-in:** if the two current runbooks become too overloaded, or if the implementing agent finds ambiguity/drift between the host-local enablement manifest, generated runtime config, and verification output, pause and confirm the contract before proceeding.

**Review cycle:** request docs-review focused on operator clarity, security-boundary truthfulness, and whether the workflow can be followed without unstated tribal knowledge.

---

## Task 7: Final acceptance verification and handoff

**Intent:** Finish with evidence that the secure path works and that the hard gate genuinely controlled the slice.

**Files:**
- Review only the changed runtime/config/docs/tests surfaces from Tasks 1-6

- [ ] Re-run all blocking verification-matrix checks from a clean working state.
- [ ] Record any advisory-row outcomes that were exercised.
- [ ] Re-read the binding spec and map each acceptance criterion to a changed surface or test/evidence artifact.
- [ ] Perform the mandatory final refactor checkpoint even if no additional edits are needed.
- [ ] Request final review focused on secure-path integrity, scope discipline, and evidence quality.
- [ ] Present the changed surfaces, verification evidence, remaining advisory follow-ups, and any rejected provider/path findings to the user.

**Final User Check-in:** before declaring the slice done, show the final supported-provider set, the chosen pre-sandbox credential boundary, the PATH-resolution evidence for `opencode`, and the blocking-matrix results.

---

## Verification plan

At minimum, implementation should leave behind fresh evidence for:

- one focused verification command or test file covering the blocking `nono` suitability matrix
- one focused verification command or test file covering the secure `opencode` launch contract and PATH precedence
- one focused verification command or test file covering supported-provider configuration rules and model-policy boundaries
- one focused verification command or test file proving the single host-local enablement manifest is the source of truth and that both generated runtime configuration and verification output match it exactly
- one focused verification command or test file proving owner-vs-agent identity separation and escalation blocking (`sudo`, user-switch, and shell-escape bypass attempts) for the supported path
- the relevant existing manifest/bootstrap/runbook contract tests touched by the slice
- a final changed-files review plus explicit acceptance-criteria mapping

The preferred test level is **contract/integration**, not low-level unit tests, because the value of this slice is in the real runtime boundary and operator-visible behavior.

For this plan, “contract/integration” tests are intended to be **shell-driven boundary checks** that launch the real wrapped subprocesses and inspect observable behavior such as exit status, stdout/stderr, PATH resolution, file-access success/failure, network reachability, and secret-leak surfaces. They do **not** assume nested interactive OpenCode agent sessions except where no thinner smoke-check surface exists; if a subagent-call path cannot be exercised non-interactively, that portion should be treated as a thin smoke test or an explicit manual verification step rather than the main automated harness.

## Risks and constraints

- **Hard-gate risk:** if the `nono` suitability matrix fails, the correct outcome is rejection or redesign of this secure path, not a weakened fallback.
- **Boundary-truthfulness risk:** documentation and tests must not confuse “not in ordinary bash scope” with “unreachable by all workspace code.”
- **Kubernetes-surface ambiguity:** the spec allows a narrow pre-sandbox credential surface but does not pre-select the exact implementation shape; this needs an implementation-time check-in.
- **Network-policy risk:** wrapped OpenCode may require auxiliary endpoints beyond loopback; those must be explicitly discovered, justified, and approved.
- **Enablement-drift risk:** the host-local enablement manifest, generated runtime configuration, and verification output can drift unless one testable contract ties them together exactly.
- **DRY risk:** provider policy, model policy, route policy, and operator docs can easily drift if spread across too many surfaces; keep one authoritative contract per concern.
- **Scope-creep risk:** broker work, unsupported providers, and generalized secret-brokering ideas remain deferred even if implementation exposes them as attractive follow-ons.

## Reviewer guidance

This plan is intentionally high-level and reviewable without implementation code.

Review it against the binding spec, scope boundaries, task coverage, acceptance criteria, risks, test strategy, and `User Check-in` markers. **Do not require embedded implementation code, YAML snippets, shell snippets, or detailed step-by-step production instructions for plan approval.**

Reviewers should evaluate it by asking:

1. Does every planned task map back to a requirement in the binding spec?
2. Are the tests/verification surfaces the primary deliverables rather than embedded implementation details?
3. Does the plan preserve the hard-gate nature of the `nono` verification matrix?
4. Are the User Check-ins placed before hard-to-reverse boundary decisions?
5. Does the plan avoid hidden fallback routes and avoid broadening into broker work?

## Pragmatic diagnostic

Score: **9/10**

Strong rows: DRY, orthogonality, tracer-bullet focus, design-by-contract, broken-window prevention, reversibility.

Remaining gap:

- **Estimation/range detail** remains intentionally light because this plan is approval- and verification-oriented rather than schedule-prescriptive.

Remediation to reach 10/10:

1. Convert each task into a small time range during implementation kickoff.
2. Keep the blocking matrix tests as the authoritative tracer bullet throughout execution.
3. Reject any fallback route the moment it appears instead of carrying it as “temporary.”
