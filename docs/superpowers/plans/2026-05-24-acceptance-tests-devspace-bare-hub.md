# Acceptance Tests For DevSpace Bare-Hub Workspace

Date: 2026-05-24  
Status: Proposed  
Target spec: `docs/superpowers/specs/2026-05-23-devspace-bare-hub-workspace-design.md`

> Human-readable acceptance checklist for validating the DevSpace bare-hub workspace design. Phase 1 items define the expected initial implementation acceptance tests. Phase 2 items are deferred and should not block the first implementation slice.

---

## How to use this checklist

- Treat each item as a user-visible acceptance test.
- Prefer validating through real commands and observable filesystem state.
- Phase 1 items are in-scope for the first implementation plan.
- Phase 2 items are deferred acceptance tests for later backup/export work.

---

## Phase 1 — Core workspace lifecycle

### A. Workspace creation and access

- [ ] From a normal local checkout of the dotfiles repo, the user can start the DevSpace-managed workspace runtime without DevPod.
- [ ] The workspace is deployed as one Kubernetes `Deployment` with one PVC.
- [ ] `/workspaces/dotfiles` and `/home/vscode` are both backed by that same PVC via separate subpaths, not nested mounts.
- [ ] The default interactive entry directory is `/workspaces/dotfiles/main`.
- [ ] DevSpace-managed SSH access is available when the workspace is started through DevSpace.
- [ ] No standalone workspace Service is required in v1 for normal use.

### B. Provisioning behavior

- [ ] `devspace run-pipeline provision` creates or starts the workspace pod if needed, then runs the provisioning logic in-pod.
- [ ] The DevSpace provision wrapper ensures the Deployment, PVC, and pod exist before running the in-pod provisioning script.
- [ ] The DevSpace provision wrapper does not require the user to pre-create or separately start the pod before invoking `devspace run-pipeline provision`.
- [ ] First-time provision creates the top-level workspace as a bare clone of the top-level dotfiles GitHub repo.
- [ ] V1 provision uses `origin/main` as the only supported bootstrap ref.
- [ ] `devspace run-pipeline provision` accepts optional `HUB_INSTALL_BRANCH=<branch>` to choose which top-level checkout supplies `install.sh`.
- [ ] Provision fails clearly if `origin/main` does not exist.
- [ ] Provision fails clearly if an existing top-level `main/` path is present but broken or detached.
- [ ] Successful provision attaches `/workspaces/dotfiles/main` from the top-level bare repo.
- [ ] If `HUB_INSTALL_BRANCH` names a non-`main` branch, provision ensures `/workspaces/dotfiles/work/<branch-name>` exists and runs that worktree's `install.sh`.
- [ ] Provision never retargets `/workspaces/dotfiles/main` away from the `main` branch.
- [ ] Successful provision creates `work/`, `repos/`, `state/`, and `tmp/` under `/workspaces/dotfiles`.
- [ ] Successful provision runs `install.sh` from the selected install checkout (`/workspaces/dotfiles/main` by default).

### C. Normal startup vs unprovisioned state

- [ ] `devspace dev` may create or start the Deployment/PVC/pod if needed.
- [ ] `devspace dev` performs preflight checks before opening normal interactive use.
- [ ] If the workspace is unprovisioned, `devspace dev` refuses normal interactive use instead of auto-bootstrapping silently.
- [ ] In the unprovisioned case, `devspace dev` instructs the user to run `devspace run-pipeline provision`.
- [ ] If appropriate, `devspace dev` creates or starts the workload before that preflight refusal is surfaced.

### D. Bare-hub layout and canonical paths

- [ ] The top-level hub root is administrative and not treated as the normal editable checkout.
- [ ] Editing the top-level repo happens in `/workspaces/dotfiles/main` or `/workspaces/dotfiles/work/<name>`.
- [ ] Canonical durable paths exist for the top-level repo:
  - [ ] `/workspaces/dotfiles/state/hub/main/`
  - [ ] `/workspaces/dotfiles/state/hub/work/<name>/`
- [ ] Canonical disposable paths exist for the top-level repo:
  - [ ] `/workspaces/dotfiles/tmp/hub/main/`
  - [ ] `/workspaces/dotfiles/tmp/hub/work/<name>/`
- [ ] Child repos use matching canonical durable/disposable paths under `state/repos/<repo>/...` and `tmp/repos/<repo>/...`.

### E. `/home/vscode` and install behavior

- [ ] The top-level dotfiles repo is the only authority for `/home/vscode` config.
- [ ] Running `main/install.sh` points `/home/vscode` symlinks at the top-level `main` worktree.
- [ ] Running `install.sh` from a top-level feature worktree repoints `/home/vscode` symlinks to that worktree.
- [ ] Child repos under `repos/*` do not become authorities for `/home/vscode` config.
- [ ] `install.sh` publishes the active installed-branch state to `/workspaces/dotfiles/state/hub/etc/install.env`.
- [ ] `install.sh` hard-fails if caller-supplied `HUB_INSTALL_BRANCH` or `HUB_INSTALL_BRANCH_DIR` do not match the checkout it is actually running from.
- [ ] Each editable top-level checkout gets a generated `.envrc` plus `.envrc.local`, and generated `.envrc` sources `/workspaces/dotfiles/state/hub/etc/install.env` when present.
- [ ] Per-checkout cwd-sensitive environment uses `DYN_REPO_*` and `DYN_WORKTREE_*` names without changing `HOME`.
- [ ] `dhub` changes to the active install checkout from `$HUB_INSTALL_BRANCH_DIR` and prints the destination directory before changing into it.
- [ ] `dre <repo>` changes to `/workspaces/dotfiles/repos/<repo>` and refuses the top-level hub as a target.
- [ ] `dwt <name>` changes to `work/<name>` within the current managed repo context and refuses to run outside a managed repo context.
- [ ] Zsh tab completion exists for `dhub`, `dre`, and `dwt`.
- [ ] Invalid repo/worktree names print simple non-interactive `did you mean` hints.
- [ ] No compatibility `dd()` alias is shipped in v1.

### F. `doctor` behavior

- [ ] `devspace run-pipeline doctor` is a host-side command.
- [ ] `doctor` output is human-readable in v1.
- [ ] `doctor` returns exit code 0 when all required checks pass.
- [ ] `doctor` returns exit code 1 when one or more required checks fail.
- [ ] `doctor` returns exit code 2 on invalid CLI usage.
- [ ] `doctor` verifies at least these required checks:
  - [ ] workspace Deployment exists
  - [ ] workspace PVC exists
  - [ ] workspace pod is reachable
  - [ ] top-level `.bare` is a valid bare Git directory
  - [ ] top-level `main` exists and is attached
  - [ ] `work/`, `repos/`, `state/`, and `tmp/` exist
  - [ ] canonical top-level hub `state/` and `tmp/` paths exist
  - [ ] `/home/vscode` symlinks point to an existing top-level worktree
  - [ ] installed-branch state in `state/hub/etc/install.env` is reported when available

### G. `repair` behavior

- [ ] `devspace run-pipeline repair` is non-destructive.
- [ ] `repair` does not delete existing tracked files, untracked files, worktrees, or `/home/vscode` content.
- [ ] `repair` may recreate missing managed directories.
- [ ] `repair` may recreate missing canonical `state/` and `tmp/` subdirectories.
- [ ] `repair` may reattach or recreate top-level `main` only when the top-level bare repo is valid and recognizable.
- [ ] `repair` can honor optional `HUB_INSTALL_BRANCH=<branch>` and rerun that checkout's `install.sh` when appropriate.
- [ ] `repair` reruns `install.sh` from the selected install checkout without retargeting `/workspaces/dotfiles/main` away from `main`.
- [ ] `repair` can inspect existing installed-branch state via `state/hub/etc/install.env` before deciding what to restore.
- [ ] `repair` preserves an intentionally repointed non-`main` `/home/vscode` symlink target when that target still points to an existing top-level worktree.
- [ ] `repair` refuses rather than guessing when `.bare` is invalid, the top-level repo identity is ambiguous, or managed paths conflict by type.

### H. `destroy` behavior

- [ ] `devspace run-pipeline destroy` deletes the workspace Deployment/pod.
- [ ] `devspace run-pipeline destroy` deletes the workspace PVC.
- [ ] After `destroy`, a new `provision` behaves like a true first creation.
- [ ] `destroy` makes no preservation guarantees for uncommitted work, live session data, or `/home/vscode` content.

### I. Child repo onboarding

- [ ] V1 includes an in-pod child repo onboarding path.
- [ ] V1 child onboarding is exposed through an in-pod script or thin pipeline invocation.
- [ ] V1 child onboarding supports public repos only.
- [ ] Child onboarding uses a repo-derived default name for `repos/<name>`.
- [ ] V1 child onboarding refuses a user-supplied `--name` override.
- [ ] Child onboarding refuses on name/path collisions.
- [ ] Child onboarding detects the child repo's exact remote default branch name and keeps it without normalization.
- [ ] Child onboarding refuses if the child repo default branch cannot be determined or materialized.
- [ ] Successful child onboarding creates:
  - [ ] `repos/<name>/.bare`
  - [ ] `repos/<name>/<default-branch>`
  - [ ] `repos/<name>/work/`
  - [ ] matching canonical `state/` and `tmp/` paths for `<default-branch>`

### Additional phase-1 documentation and workflow guidance

- [ ] `docs/superpowers/runbooks/devspace-bare-hub-usage.md` explains the dev/testing/production workflow for policy changes: develop in a non-`main` worktree, test with `HUB_INSTALL_BRANCH=<branch>` during provision/repair, merge to `main` for staging/testing, then push `main` for production/default behavior.
- [ ] `docs/superpowers/runbooks/devspace-bare-hub-usage.md` and `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` document `bin/clone-repo`, `bin/new-worktree`, `dhub`, `dre`, `dwt`, `.envrc`, `.envrc.local`, `state/hub/etc/install.env`, and the no-implicit-fallback rule.
- [ ] Agent policy docs (`.config/opencode/AGENTS.md`, `.config/opencode/agents/maestro.md`, `.config/opencode/agents/senior-implementer.md`) tell agents to prefer `bin/clone-repo` and `bin/new-worktree` and to read `state/hub/etc/install.env`.
- [ ] Touched runbooks and agent-policy docs include a short "what changed for implementers" note whenever this retrofit changes command names, install-branch behavior, child default-branch handling, or required files to touch.

---

## Phase 2 — Deferred backup/export acceptance tests

> These items are deferred. They should remain visible in planning, but they do not block phase-1 implementation acceptance.

### J. Periodic staging

- [ ] The phase-2 staging CronJob is scheduled at minute 0 of every hour (`0 * * * *`).
- [ ] A manual one-shot staging trigger exists and uses the same staging script as the CronJob.
- [ ] Staging writes human-readable logs.
- [ ] Staging records persistent status under the workspace `state/` tree.
- [ ] Staging failures do not break ordinary workspace use.

### K. Backup command and host pull

- [ ] The phase-2 host-side scheduled backup is scheduled at minute 30 of every hour (`30 * * * *`).
- [ ] Phase-2 command surface includes `devspace run-pipeline staging`.
- [ ] Phase-2 command surface includes `devspace run-pipeline backup`.
- [ ] `backup` performs host-side pull plus `restic`.
- [ ] The repository provides an installable host-runner under `ops/host-backup/` that contains the default containerized cron runner (Containerfile, entrypoint.sh, and run-devspace-backup.sh).
- [ ] The default host-runner is the containerized cron runner; it must be invocable via `ops/host-backup/run-devspace-backup.sh --once --env-file <path>` and documented in the runbook.
- [ ] The repository documents a Linux systemd timer fallback that invokes the same `run-devspace-backup.sh` entrypoint for operators who prefer systemd.
- [ ] The host-runner must be testable by the host-side contract test `tests/opencode/test_host_backup_runner_contract.sh` which asserts scheduled invocation and successful host-pull+restic behavior.
- [ ] The host-side staging/pull destination is operator-configurable.
- [ ] Stale staging causes a warning, not a hard failure.
- [ ] Repeated stale staging still remains warning-only by default.
- [ ] Pull failure causes backup failure.
- [ ] `restic` failure causes backup failure.

### L. Backup visibility and recovery signal

- [ ] Host backup output reports whether staged data is fresh or stale.
- [ ] Kubernetes job logs and persistent workspace status are sufficient to debug staging failures.
- [ ] PVC snapshot/clone remains an explicitly deferred fast-recovery enhancement, not the primary backup path.
- [ ] Object-store export remains an explicitly deferred later extension, not the primary backup path.

### M. OpenCode session export deliverable

- [ ] OpenCode session export exists as a separately testable phase-2 deliverable.
- [ ] Exported session artifacts are written to the documented durable path under `state/opencode/exported_sessions/`.
- [ ] Export can be verified independently of host-side pull + `restic`.
- [ ] Export failure is reported distinctly from general backup failure.
- [ ] Exported session artifacts are readable as files after export.

### N. OpenCode session recovery deliverable

- [ ] OpenCode session recovery exists as a separately testable phase-2 deliverable.
- [ ] Previously exported session artifacts can be restored from backup storage into the documented export location.
- [ ] Recovery can be verified independently of full workspace rebuild.
- [ ] Recovery success is measured at minimum by restored readable export artifacts and a documented recovery workflow.
- [ ] Exact resumability as live OpenCode sessions is not required unless a later phase defines that behavior explicitly.

---

## Exit criteria for the first implementation slice

The first implementation slice is acceptable when all non-deferred Phase 1 checklist items above have clear passing evidence and no phase-1 item remains ambiguous.
