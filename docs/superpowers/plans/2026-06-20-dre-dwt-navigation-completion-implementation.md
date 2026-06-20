# dre/dwt Navigation + Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align `dre` and `dwt` with the user-approved default-checkout and completion UX direction without widening scope beyond the approved navigation slice.

**Architecture:** Keep resolver behavior in `bin/` path-resolver scripts, keep completion behavior command-local inside `.config/shell/workspace-navigation.zsh`, and extract child-repo metadata writing into one internal helper so runtime behavior and repair hints share one source of truth. Drive the slice with contract-level shell tests first, then finish with a mandatory real-shell user check-in for interactive completion feel.

**Tech Stack:** Bash, Zsh completion, Git bare repos/worktrees, existing shell contract tests under `tests/devspace/`, `tests/install/`, and `tests/docs/`.

---

## Inputs and authority

- Design spec: `docs/superpowers/specs/2026-06-20-dre-dwt-navigation-completion-design.md` at commit `299f418` (the file still says `Status: Proposed`; user approval exists in chat and this plan keeps wording aligned to that state)
- Editable repo root: `/workspaces/dotfiles/main`
- Historical plans/runbooks may contain older `dre` wording; for this slice, the user-approved direction in the spec above plus this plan are the active authority.

## Scope

### In scope

- Make `dre <repo>` resolve the child repo default checkout from `repo.env`.
- Add one internal metadata-writer helper and reuse it from `bin/clone-repo`.
- Improve `dre`/`dwt` completion behavior with command-scoped tuning only.
- Make `dwt` completion offer full slash-containing worktree names directly.
- Update live user-facing runbooks to match the new `dre` contract.
- Add or strengthen contract tests that protect the new behavior.

### Out of scope

- No new public repair command.
- No global `.zshrc` or Oh My Zsh completion redesign.
- No unrelated navigation changes to `dhub`, top-level bootstrap rules, or alias policy.
- Do not rewrite historical approved plan/spec artifacts unless the human explicitly asks; update current user-facing docs/tests instead.

## File map

- Create: `scripts/lib/write-managed-repo-env.sh` — internal helper that validates child bare repo metadata inputs and writes `state/repos/<repo>/etc/repo.env`.
- Modify: `bin/clone-repo` — replace inline `repo.env` writing with the helper.
- Modify: `bin/dre` — resolve `DYN_REPO_DEFAULT_DIR` and surface repair guidance when metadata is missing or invalid.
- Modify: `bin/dwt` — keep runtime contract aligned for slash-containing worktree names and useful no-match hints.
- Modify: `.config/shell/workspace-navigation.zsh` — command-local completion candidate generation and refinement behavior for `dre`/`dwt`.
- Modify: `tests/devspace/test_workspace_navigation_commands.sh` — resolver contract tests for new `dre` behavior and metadata failure hints.
- Modify: `tests/devspace/test_public_repo_clone_behavior.sh` — regression coverage that child onboarding still writes correct metadata through the helper.
- Modify: `tests/install/test_workspace_navigation_shell.sh` — shell-wrapper and completion-behavior coverage for full worktree names and updated `dre` destination.
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md` — update `dre` wording and navigation notes.
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` — update `dre` wording and navigation notes.
- Modify: `tests/docs/test_bare_hub_guardrails.sh` — pin the updated live-doc wording if needed.

---

## Task 1: Lock the child metadata writer and `dre` runtime contract

**Files:**
- Create: `scripts/lib/write-managed-repo-env.sh`
- Modify: `bin/clone-repo`
- Modify: `bin/dre`
- Modify: `tests/devspace/test_workspace_navigation_commands.sh`
- Modify: `tests/devspace/test_public_repo_clone_behavior.sh`
- Modify: `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Write failing contract tests for the approved `dre` destination**
  - Extend `tests/devspace/test_workspace_navigation_commands.sh` so `dre alpha` expects `$workspace_root/repos/alpha/master`, not `$workspace_root/repos/alpha`.
  - Extend `tests/install/test_workspace_navigation_shell.sh` so the `dre` shell wrapper expects to `cd` into the child default checkout path, not the child hub root.

- [ ] **Step 2: Write failing contract tests for missing/invalid child metadata guidance**
  - Add a `dre` failure case where the child bare repo exists but `state/repos/<repo>/etc/repo.env` is missing or invalid.
  - Assert exit status stays non-zero and stderr includes both the refusal reason and a repair hint that references the internal helper path `scripts/lib/write-managed-repo-env.sh` for that repo.

- [ ] **Step 3: Write a failing regression test for the helper-owned metadata contract**
  - Extend `tests/devspace/test_public_repo_clone_behavior.sh` before introducing the helper so child onboarding is already required to prove the metadata contract that the helper will own.
  - Pin these behaviors explicitly:
    - `state/repos/<repo>/etc/repo.env` contains `export DYN_REPO_DEFAULT_BRANCH=<detected-branch>`;
    - `state/repos/<repo>/etc/repo.env` contains `export DYN_REPO_DEFAULT_DIR=<workspace-root>/repos/<repo>/<detected-branch>`;
    - the matching canonical directories under `state/repos/<repo>/<detected-branch>`, `tmp/repos/<repo>/<detected-branch>`, and `state/repos/<repo>/etc/` exist after onboarding.

- [ ] **Step 4: Verify RED**
  - Run: `bash tests/devspace/test_workspace_navigation_commands.sh`
  - Run: `bash tests/install/test_workspace_navigation_shell.sh`
  - Run: `bash tests/devspace/test_public_repo_clone_behavior.sh`
  - Expected: the suites fail specifically on the new `dre` path / metadata-hint assertions and the new onboarding metadata-contract assertions.

- [ ] **Step 5: Implement the internal metadata writer and wire it into onboarding**
  - Add `scripts/lib/write-managed-repo-env.sh` as the only helper that writes `DYN_REPO_DEFAULT_BRANCH` and `DYN_REPO_DEFAULT_DIR` for managed child repos.
  - Update `bin/clone-repo` to call the helper instead of writing `repo.env` inline.
  - Keep the helper internal-only; do not add a new public `bin/` command in this slice.

- [ ] **Step 6: Implement the `dre` runtime contract**
  - Update `bin/dre` so success prints `DYN_REPO_DEFAULT_DIR` from `repo.env`.
  - Preserve existing top-level refusal behavior and unknown-repo hint behavior.
  - For missing/invalid metadata, fail clearly and include the helper-based repair hint without guessing a fallback path.

- [ ] **Step 7: Verify GREEN for the runtime slice**
  - Run: `bash tests/devspace/test_workspace_navigation_commands.sh`
  - Run: `bash tests/install/test_workspace_navigation_shell.sh`
  - Run: `bash tests/devspace/test_public_repo_clone_behavior.sh`
  - Expected: all pass.

- [ ] **Step 8: Refactor checkpoint**
  - Remove any new duplication around child metadata validation or error text introduced by this slice.
  - Keep behavior unchanged; rerun the three commands above after any cleanup.

**User Check-in:** after Task 1 reaches green, pause for approval on the new `dre` runtime target, metadata-failure wording, and helper-owned child metadata contract before starting Task 2.

---

## Task 2: Make `dwt` completion offer full worktree names directly

**Files:**
- Modify: `.config/shell/workspace-navigation.zsh`
- Modify: `bin/dwt`
- Modify: `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Write failing completion tests for slash-containing worktree names**
  - Extend `tests/install/test_workspace_navigation_shell.sh` so `_workspace_nav_complete_dwt` is validated through captured completion candidates, not only through `_path_files` behavior.
  - Assert the completion candidates include `spec/limit-peek-elements-design` as one direct candidate.
  - Remove or replace any test expectation that requires `_workspace_nav_complete_dwt` to rely on `_path_files -W "$repo_root/work" -/`.

- [ ] **Step 2: Write failing no-match hint coverage for nested worktree names if needed**
  - If `bin/dwt` currently loses useful suggestions for slash-containing names, add a failing contract assertion that unknown nested names still get meaningful `did you mean` output using repo-relative worktree names.
  - Keep this test only if it protects user-visible behavior; do not add low-value internal-only tests.

- [ ] **Step 3: Verify RED**
  - Run: `bash tests/install/test_workspace_navigation_shell.sh`
  - Expected: failure on the direct full-name completion assertions.

- [ ] **Step 4: Implement direct worktree candidate generation**
  - Update `.config/shell/workspace-navigation.zsh` so `dwt` completion enumerates managed worktree names relative to `work/`, preserving embedded slashes as part of a single candidate.
  - Preserve the repo default-branch alias completion alongside worktree-name completion.
  - Keep the behavior command-scoped; do not change unrelated global completion defaults.

- [ ] **Step 5: Align runtime hints if the red tests required it**
  - Update `bin/dwt` only as needed so slash-containing worktree names remain consistent between runtime lookup and user-facing hinting.

- [ ] **Step 6: Verify GREEN for the completion-candidate slice**
  - Run: `bash tests/install/test_workspace_navigation_shell.sh`
  - Expected: pass, including the interactive transcript coverage for `dwt spec/lim<TAB>`.

- [ ] **Step 7: Refactor checkpoint**
  - Keep candidate collection logic small and single-purpose.
  - Rerun `bash tests/install/test_workspace_navigation_shell.sh` after cleanup.

**User Check-in:** after Task 2 reaches green, pause for approval on the direct slash-containing `dwt` completion candidates before starting Task 3.

---

## Task 3: Tune `dre`/`dwt` completion refinement behavior without global churn

**Files:**
- Modify: `.config/shell/workspace-navigation.zsh`
- Modify: `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Add failing scripted checks for command-local completion semantics that are safe to automate**
  - Capture completion-function behavior that protects the approved UX goals:
    - typed prefixes are preserved on no-match,
    - refinement stays within the same token,
    - completion does not append separators/spaces that break continued typing.
  - Prefer helper-level or transcript-level assertions that are stable in CI; do not overfit to one exact global Zsh theme/plugin state.

- [ ] **Step 2: Verify RED**
  - Run: `bash tests/install/test_workspace_navigation_shell.sh`
  - Expected: failure tied to the new refinement-preservation assertions.

- [ ] **Step 3: Implement command-scoped completion tuning**
  - Adjust `.config/shell/workspace-navigation.zsh` with command-local completion styles / `compadd` behavior so `dre` and `dwt` honor the approved token-preservation behavior.
  - Prefer the smallest change that enables longest-unambiguous-prefix insertion plus re-openable ambiguous menus.
  - Do not redesign global completion behavior for the whole shell.

- [ ] **Step 4: Verify GREEN for scripted completion behavior**
  - Run: `bash tests/install/test_workspace_navigation_shell.sh`
  - Expected: pass for the new scripted checks.

- [ ] **Step 5: Mandatory manual verification and user check-in**
  - In a real interactive Zsh session, verify:
    - `dre <prefix><TAB>` expands by longest unambiguous prefix,
    - no-match keeps the typed token intact,
    - after selecting or partially completing, typing more characters and pressing `TAB` refines the same token,
    - backspace edits the token instead of only hiding the list.
  - **User Check-in:** pause here and ask the human to confirm the interactive completion feel is acceptable in their environment before calling the slice done.

- [ ] **Step 6: Refactor checkpoint**
  - If the command-local tuning is noisy or duplicated, simplify it without changing behavior.
  - Rerun `bash tests/install/test_workspace_navigation_shell.sh` after cleanup.

---

## Task 4: Update live documentation and protect it with doc contracts

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write or strengthen failing doc-contract checks**
  - If the runbooks are updated to say `dre <repo>` lands on the managed child default checkout, add or tighten `tests/docs/test_bare_hub_guardrails.sh` assertions so that wording drift is caught later.
  - Keep the checks focused on current live docs, not historical plan files.

- [ ] **Step 2: Verify RED**
  - Run: `bash tests/docs/test_bare_hub_guardrails.sh`
  - Expected: fail if the runbooks still describe the old `repos/<repo>` destination.

- [ ] **Step 3: Update runbooks to the approved contract**
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`: update the navigation bullets and behavior notes so `dre <repo>` clearly means the child repo default checkout.
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`: make the same contract change and keep the rest of the navigation guidance intact.

- [ ] **Step 4: Verify GREEN**
  - Run: `bash tests/docs/test_bare_hub_guardrails.sh`
  - Expected: pass.

---

## Final verification checklist

- [ ] Run the focused regression suite:
  - `bash tests/devspace/test_workspace_navigation_commands.sh`
  - `bash tests/devspace/test_public_repo_clone_behavior.sh`
  - `bash tests/install/test_workspace_navigation_shell.sh`
  - `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] Re-read `docs/superpowers/specs/2026-06-20-dre-dwt-navigation-completion-design.md` and confirm each acceptance criterion is covered:
  1. `dre` resolves `DYN_REPO_DEFAULT_DIR`.
  2. Missing/invalid metadata fails with repair guidance.
  3. `dwt` completion offers full slash-containing names.
  4. `dre`/`dwt` preserve typed prefixes and same-token refinement.
  5. Backspace/editing behavior has been manually checked with the user.
- [ ] Record the mandatory post-implementation checks in the handoff/PR note:
  - pragmatic-programmer diagnostic score,
  - clean-code review outcome,
  - any remediation items if either review finds material gaps.

## Notes for the implementing agent

- Follow strict TDD for each task: red → verify red → green → verify green → refactor → verify green.
- Keep tests at the contract/integration level already used in this repo unless a tiny helper truly needs narrower protection.
- Keep this slice reversible: no public repair command, no global completion rewrite, no behavior creep outside `dre`/`dwt` and their directly supporting helper/doc surfaces.
