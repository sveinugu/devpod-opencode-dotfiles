# Auto-CD After Create Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved interactive auto-navigation flow so successful `new-worktree` and `clone-repo` runs can land the user in the created checkout without violating Unix parent-shell boundaries.

**Architecture:** Keep path creation and authoritative destination resolution in the existing scripts, add one small machine-readable handoff for the created target path, and keep all `cd` decisions in `.config/shell/workspace-navigation.zsh`. Drive the slice with script-contract tests first, then shell-wrapper tests, and finish with minimal runbook updates plus a manual shell check-in for the interactive feel.

**Tech Stack:** Bash, Zsh shell functions, Git worktrees, existing shell contract tests under `tests/devspace/`, `tests/install/`, and `tests/docs/`.

---

## Inputs and authority

- Binding spec: `docs/superpowers/specs/2026-07-09-auto-cd-after-create-design.md` at commit `321112e`
- Editable repo root: `/workspaces/dotfiles/work/move-to-new-worktree-or-repo`
- Existing command surfaces:
  - `bin/new-worktree`
  - `bin/clone-repo`
  - `.config/shell/workspace-navigation.zsh`
- Existing tests to extend rather than replace:
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_public_repo_clone_behavior.sh`
  - `tests/install/test_workspace_navigation_shell.sh`
  - `tests/docs/test_bare_hub_guardrails.sh`

## Scope

### In scope

- interactive shell wrappers for `new-worktree` and `clone-repo`
- one shared machine-readable handoff from the scripts to the shell wrappers
- one shared opt-out environment variable for both wrappers
- focused regression coverage for script and shell layers
- minimal documentation updates for the new interactive behavior

### Out of scope

- no attempt to make the scripts themselves change the parent shell directory
- no per-command opt-out variables or new v1 CLI flags
- no changes to `dhub`, `dre`, `dwt`, or shell-startup auto-`cd`
- no brittle parsing of human-readable success text
- no broader refactor of unrelated navigation helpers

## File map

- Create: `scripts/lib/write-workspace-nav-target.sh` — best-effort helper for the optional machine-readable target-path handoff used by shell wrappers.
- Modify: `scripts/lib/new-worktree-flow.sh` — emit the created worktree path through the shared handoff helper while preserving current success output.
- Modify: `bin/clone-repo` — emit the created default-checkout path through the shared handoff helper while preserving current success output.
- Modify: `.config/shell/workspace-navigation.zsh` — add one shared wrapper runner plus thin `new-worktree` and `clone-repo` interactive wrappers.
- Modify: `tests/devspace/test_new_worktree.sh` — script-level contract coverage for `new-worktree` handoff behavior.
- Modify: `tests/devspace/test_public_repo_clone_behavior.sh` — script-level contract coverage for `clone-repo` handoff behavior.
- Modify: `tests/install/test_workspace_navigation_shell.sh` — shell-wrapper behavior coverage for auto-`cd`, opt-out, degraded handoff, and failure preservation.
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md` — document interactive wrapper behavior and the shared opt-out variable.
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` — point host-side readers at the updated in-pod wrapper behavior.
- Modify: `tests/docs/test_bare_hub_guardrails.sh` — pin the live-doc wording for the new wrapper behavior and opt-out variable.

---

## Task 1: Lock the script-to-shell handoff contract in failing tests

**Files:**
- Create: `scripts/lib/write-workspace-nav-target.sh`
- Modify: `scripts/lib/new-worktree-flow.sh`
- Modify: `bin/clone-repo`
- Modify: `tests/devspace/test_new_worktree.sh`
- Modify: `tests/devspace/test_public_repo_clone_behavior.sh`

- [ ] **Step 1: Write the failing script-level contract tests first**
  - Extend `tests/devspace/test_new_worktree.sh` so a run with `HUB_WORKSPACE_NAV_TARGET_FILE=<temp-file>` must write the created worktree path to that file.
  - Keep the existing success line assertion shape intact: the new handoff is additive and must not replace the current human-readable success output.
  - Extend `tests/devspace/test_public_repo_clone_behavior.sh` so a run with `HUB_WORKSPACE_NAV_TARGET_FILE=<temp-file>` must write the created default checkout path for the managed child repo.
  - Pin that the existing clone progress / success behavior still remains visible.

- [ ] **Step 2: Verify RED**
  - Run:

    ```bash
    bash tests/devspace/test_new_worktree.sh
    bash tests/devspace/test_public_repo_clone_behavior.sh
    ```

  - Expected: FAIL specifically on the new handoff-file assertions.

- [ ] **Step 3: Implement the additive handoff helper and wire it into both commands**
  - Add `scripts/lib/write-workspace-nav-target.sh` as the one helper that owns the `HUB_WORKSPACE_NAV_TARGET_FILE` contract.
  - `scripts/lib/new-worktree-flow.sh` should call the helper with the authoritative created worktree path.
  - `bin/clone-repo` should call the helper with the authoritative created default-checkout path.
  - Keep the handoff best-effort: a successful create operation must not be reclassified as failed just because the wrapper-side metadata file is missing or unusable.

- [ ] **Step 4: Verify GREEN for the script contract slice**
  - Re-run:

    ```bash
    bash tests/devspace/test_new_worktree.sh
    bash tests/devspace/test_public_repo_clone_behavior.sh
    ```

  - Expected: PASS.

- [ ] **Step 5: Mandatory refactor checkpoint**
  - Keep the target-file contract in one place.
  - Remove any duplicate env-var or file-writing logic introduced across `new-worktree` and `clone-repo`.
  - Re-run the two commands above after cleanup.

---

## Task 2: Add interactive wrappers and protect the shell behavior

**Files:**
- Modify: `.config/shell/workspace-navigation.zsh`
- Modify: `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Write the failing shell-wrapper tests first**
  - Extend `tests/install/test_workspace_navigation_shell.sh` with wrapper-backed scenarios for both `new-worktree` and `clone-repo`.
  - Pin these user-visible behaviors:
    - on success with opt-out unset, the wrapper forwards normal command output, prints the shared opt-out hint, prints `cd -> <target>`, and changes the current shell directory;
    - on success with `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1`, the wrapper forwards normal command output, prints the same hint, and stays in the original directory;
    - if the underlying command succeeds but the handoff file is missing, empty, or names a non-directory, the wrapper warns clearly and stays put;
    - if the underlying command fails, the wrapper preserves its output and exit status, prints no success hint, and does not change directories.

- [ ] **Step 2: Verify RED**
  - Run:

    ```bash
    bash tests/install/test_workspace_navigation_shell.sh
    ```

  - Expected: FAIL on the new wrapper-behavior assertions.

- [ ] **Step 3: Implement one shared wrapper runner plus thin command wrappers**
  - In `.config/shell/workspace-navigation.zsh`, add one small helper that:
    - creates a temp file,
    - invokes `command new-worktree` or `command clone-repo` with `HUB_WORKSPACE_NAV_TARGET_FILE` set,
    - preserves stdout, stderr, and the underlying exit status,
    - validates the handoff path only after a successful create,
    - prints the shared opt-out hint on every successful wrapper-driven run,
    - either `cd`s to the target or stays put based on `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1`.
  - Keep `new-worktree()` and `clone-repo()` themselves thin and wrapper-only.
  - Do not move any parent-shell behavior back into the scripts.

- [ ] **Step 4: Verify GREEN for the wrapper slice**
  - Run:

    ```bash
    bash tests/install/test_workspace_navigation_shell.sh
    ```

  - Expected: PASS.

- [ ] **Step 5: Mandatory manual shell verification**
  - In a real interactive Zsh session, verify at least these workflows:
    - `new-worktree` lands in the new worktree by default;
    - `clone-repo` lands in the managed child repo default checkout by default;
    - `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1` leaves the shell in place for both commands;
    - degraded handoff behavior warns and preserves the already-created checkout instead of pretending creation failed.

- [ ] **Step 6: Mandatory refactor checkpoint**
  - Keep hint text, temp-file handling, and handoff validation centralized in the shared shell helper.
  - Re-run `bash tests/install/test_workspace_navigation_shell.sh` after cleanup.

**User Check-in:** after Task 2 reaches green, pause for human confirmation that the interactive hint text and auto-`cd` feel are acceptable before updating docs.

---

## Task 3: Update live runbooks and protect the wording

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write or tighten the failing doc-contract checks first**
  - Extend `tests/docs/test_bare_hub_guardrails.sh` so the live runbooks are required to mention the interactive wrapper behavior and the shared opt-out variable `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1`.
  - Keep the checks focused on current live runbooks only.

- [ ] **Step 2: Verify RED**
  - Run:

    ```bash
    bash tests/docs/test_bare_hub_guardrails.sh
    ```

  - Expected: FAIL until the runbooks describe the new wrapper behavior.

- [ ] **Step 3: Update the live docs minimally**
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`: document that interactive `new-worktree` / `clone-repo` runs auto-jump by default, that raw script usage remains valid, and that `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1` opts out for both commands.
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`: keep host-side guidance brief and point readers at the in-pod wrapper behavior without duplicating low-level details.

- [ ] **Step 4: Verify GREEN**
  - Run:

    ```bash
    bash tests/docs/test_bare_hub_guardrails.sh
    ```

  - Expected: PASS.

- [ ] **Step 5: Mandatory refactor checkpoint**
  - Keep the runbook wording pointer-based and non-duplicative.
  - Re-run `bash tests/docs/test_bare_hub_guardrails.sh` after cleanup.

---

## Final verification checklist

- [ ] Run the focused regression suite:
  - `bash tests/devspace/test_new_worktree.sh`
  - `bash tests/devspace/test_public_repo_clone_behavior.sh`
  - `bash tests/install/test_workspace_navigation_shell.sh`
  - `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] Re-read `docs/superpowers/specs/2026-07-09-auto-cd-after-create-design.md` and confirm each acceptance check is covered:
  - script-level target-file handoff for both commands;
  - wrapper auto-jump by default;
  - shared opt-out behavior;
  - degraded handoff warning without false create failure;
  - raw script usage remains valid;
  - underlying failure preserves output/status and does not `cd`.
- [ ] Confirm the implementation still keeps `cd` behavior in shell code only.
- [ ] Confirm the final handoff/hint contract is documented in the live runbooks.
- [ ] Present the completed slice to the human for manual testing in their normal shell workflow before calling the feature done.
