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
- [ ] First-time provision creates the top-level workspace as a bare clone of the top-level dotfiles GitHub repo.
- [ ] V1 provision uses `origin/main` as the only supported bootstrap ref.
- [ ] Provision fails clearly if `origin/main` does not exist.
- [ ] Provision fails clearly if an existing top-level `main/` path is present but broken or detached.
- [ ] Successful provision attaches `/workspaces/dotfiles/main` from the top-level bare repo.
- [ ] Successful provision creates `work/`, `repos/`, `state/`, and `tmp/` under `/workspaces/dotfiles`.
- [ ] Successful provision runs `main/install.sh`.

### C. Normal startup vs unprovisioned state

- [ ] `devspace dev` may create or start the Deployment/PVC/pod if needed.
- [ ] If the workspace is unprovisioned, `devspace dev` refuses normal interactive use instead of auto-bootstrapping silently.
- [ ] In the unprovisioned case, `devspace dev` instructs the user to run `devspace run-pipeline provision`.

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

### G. `repair` behavior

- [ ] `devspace run-pipeline repair` is non-destructive.
- [ ] `repair` does not delete existing tracked files, untracked files, worktrees, or `/home/vscode` content.
- [ ] `repair` may recreate missing managed directories.
- [ ] `repair` may recreate missing canonical `state/` and `tmp/` subdirectories.
- [ ] `repair` may reattach or recreate top-level `main` only when the top-level bare repo is valid and recognizable.
- [ ] `repair` reruns `main/install.sh` to restore default top-level `main` symlinks when appropriate.
- [ ] `repair` preserves an intentionally repointed non-`main` `/home/vscode` symlink target when that target still points to an existing top-level worktree.
- [ ] `repair` refuses rather than guessing when `.bare` is invalid, the top-level repo identity is ambiguous, or managed paths conflict by type.

### H. `destroy` behavior

- [ ] `devspace run-pipeline destroy` deletes the workspace Deployment/pod.
- [ ] `devspace run-pipeline destroy` deletes the workspace PVC.
- [ ] After `destroy`, a new `provision` behaves like a true first creation.
- [ ] `destroy` makes no preservation guarantees for uncommitted work, live session data, or `/home/vscode` content.

### I. Child repo onboarding

- [ ] V1 includes an in-pod child repo onboarding path.
- [ ] V1 child onboarding supports public repos only.
- [ ] Child onboarding uses a repo-derived default name for `repos/<name>`.
- [ ] Child onboarding refuses on name/path collisions.
- [ ] Child onboarding uses `origin/main` as the only supported source ref in v1.
- [ ] Child onboarding refuses if `origin/main` is absent.
- [ ] Successful child onboarding creates:
  - [ ] `repos/<name>/.bare`
  - [ ] `repos/<name>/main`
  - [ ] `repos/<name>/work/`
  - [ ] matching canonical `state/` and `tmp/` paths

---

## Phase 2 — Deferred backup/export acceptance tests

> These items are deferred. They should remain visible in planning, but they do not block phase-1 implementation acceptance.

### J. Periodic staging

- [ ] A Kubernetes CronJob runs in-pod staging on its alternating half-hour cadence.
- [ ] A manual one-shot staging trigger exists and uses the same staging script as the CronJob.
- [ ] Staging writes human-readable logs.
- [ ] Staging records persistent status under the workspace `state/` tree.
- [ ] Staging failures do not break ordinary workspace use.

### K. Backup command and host pull

- [ ] A host-side scheduled backup runs on the alternating half-hour cadence between staging runs.
- [ ] Phase-2 command surface includes `devspace run-pipeline staging`.
- [ ] Phase-2 command surface includes `devspace run-pipeline backup`.
- [ ] `backup` performs host-side pull plus `restic`.
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

---

## Exit criteria for the first implementation slice

The first implementation slice is acceptable when all non-deferred Phase 1 checklist items above have clear passing evidence and no phase-1 item remains ambiguous.
