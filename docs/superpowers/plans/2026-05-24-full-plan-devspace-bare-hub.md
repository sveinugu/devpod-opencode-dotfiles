# DevSpace Bare-Hub Workspace Full Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the DevPod-era bare-hub workflow with a DevSpace-managed, PVC-backed workspace while preserving the top-level dotfiles repo as the `/home/vscode` authority, adding DevSpace-managed SSH access, and carrying forward the approved phase-2 staging/backup model.

**Architecture:** Keep DevSpace thin and keep workspace behavior in repo-owned shell scripts. Phase 1 creates one `Deployment` plus one PVC, provisions the top-level bare hub in-pod from `origin/main`, preserves the top-level dotfiles repo as the only `/home/vscode` authority, and adds DevSpace-managed SSH plus `doctor` / `repair` / `destroy` / child-repo onboarding contracts. Phase 2 reuses the approved export/staging/host-pull backup contracts from the older bare-hub plan, adapting only the runtime wrappers from DevPod to DevSpace and adding the CronJob, a portable host-runner default, and freshness/status checks required by the new spec.

**Tech Stack:** Bash, Zsh-compatible shell usage, DevSpace, Kubernetes `Deployment`/PVC/CronJob manifests, Git bare repos + worktrees, `kubectl`, `python3`, `opencode`, `tar`, `restic`, GNU coreutils, util-linux `flock`, and an OCI-compatible host runner (`docker`/`podman`/colima-backed runtime) for scheduled host-side backup.

---

## Inputs and approval basis

- Primary design spec: `docs/superpowers/specs/2026-05-23-devspace-bare-hub-workspace-design.md` at commits `d069cf5` and `3455f13`.
- Acceptance checklist: `docs/superpowers/plans/2026-05-24-acceptance-tests-devspace-bare-hub.md` at commits `f1d2aff` and `2a17725`.
- Prior plan to reuse where still valid: `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`.
- This document replaces the older plan as the active implementation plan for this feature set, but the older plan remains in the repo for reference and verbatim reuse tracking.

## Purpose

Provide one approved implementation plan for the full DevSpace bare-hub workspace roadmap: phase 1 workspace lifecycle and phase 2 staging/backup. The plan keeps the good parts of the earlier bare-hub-manager work, removes the host-mounted DevPod assumptions that the new design superseded, and gives implementers one ordered path with explicit verification and rollback checkpoints.

## Scope

### In scope for phase 1

- Thin `devspace.yaml` command surface for `dev`, `provision`, `doctor`, `repair`, and `destroy`.
- One Kubernetes `Deployment` and one PVC with two subPath mounts: `/workspaces/dotfiles` and `/home/vscode`.
- DevSpace-managed SSH access using the built-in DevSpace SSH connection instead of a standalone Kubernetes Service.
- In-pod top-level bare-hub provision from the public dotfiles repo using `origin/main` only.
- Local-source `install.sh` behavior and top-level-only `/home/vscode` authority.
- Human-readable, host-side `doctor`; non-destructive `repair`; destructive `destroy`.
- Public child-repo onboarding under `repos/*` using the same bare-hub conventions.

### In scope for phase 2

- OpenCode export into `state/opencode/exported_sessions/`.
- Durable-state staging with busy-file preservation and atomic promotion.
- One staging script used both by a Kubernetes CronJob and by a manual DevSpace pipeline.
- Host-side pull plus `restic` backup flow, with freshness/staleness reporting.
- A user-controlled scheduled host runner, with a small containerized cron runner as the recommended default and a Linux-only systemd alternative documented as fallback.
- Recovery of exported sessions from the staged/backup artifacts.

## Goals

- Match every non-deferred acceptance item in `2026-05-24-acceptance-tests-devspace-bare-hub.md`.
- Preserve the bare-hub/worktree model and canonical `state/` / `tmp/` mapping.
- Reuse the earlier plan verbatim wherever the new design still agrees with it.
- Keep scripts small, explicit, and shell-friendly.
- Keep rollback simple: non-destructive `repair`, destructive `destroy`, and additive phase-2 backup scripts.

## Non-goals

- No broker or GitHub App integration.
- No private-repo onboarding in v1.
- No Helm packaging in v1.
- No DevSpace file sync as the durability model.
- No image-seeded source snapshot replacing Git bootstrap.
- No destructive in-place `reset` command in v1.
- No direnv/per-worktree environment automation in this first plan; that older idea is deferred unless a later approved spec brings it back.

---

## Decisions locked by this plan

1. **Manifest layout:** use plain manifests under `k8s/devspace-bare-hub/`, not Helm.
2. **PVC mount model:** one PVC mounted twice with `subPath` entries, once at `/workspaces/dotfiles` and once at `/home/vscode`.
3. **Top-level provision source:** in-pod `git clone --bare` from the top-level dotfiles repo, with `origin/main` as the only supported bootstrap ref in v1.
4. **DevSpace role:** wrappers only; the repo-owned scripts remain authoritative for provision/doctor/repair/add-repo/staging/backup logic.
5. **Shared helper boundary:** extract only the duplicated repo-hub creation logic into `scripts/lib/hub-repo-core.sh`; keep top-level orchestration and child-repo orchestration separate.
6. **Phase sequencing:** finish all phase-1 acceptance items before starting phase-2 CronJob/backup work.
7. **DevSpace SSH shape:** use DevSpace's built-in `ssh` dev connection (`ssh.enabled: true`, `ssh.useInclude: true`) so DevSpace generates keys under `~/.devspace/ssh/`, writes the local SSH alias, and reaches the container through a loopback-only port-forward/tunnel instead of a Kubernetes Service.
8. **Host-runner default:** use a small containerized cron runner under user control as the default scheduled host backup mechanism because it works on the documented macOS/colima and Linux host setups; keep a user-level systemd timer as a Linux-only fallback that invokes the same shared host backup script.

---

## Explicit reuse ledger from `2026-05-21-bare-hub-manager.md`

### Reused verbatim — installer policy

The following contract is copied verbatim from the older plan and remains authoritative here:

> `install.sh` must:
> - autodetect its own real location with `dirname "${BASH_SOURCE[0]}"` plus realpath semantics
> - use the checkout/worktree that the script file itself lives in as the source
> - never use the current working directory to choose the source
> - use fixed targets under `$HOME`
> - retain all current install actions from the existing script:
>   - `.zshrc` linking
>   - typewritten theme
>   - zsh-syntax-highlighting
>   - zsh-autosuggestions
>   - `.config/opencode` linking
>   - `npx -y skills add wondelai/skills/pragmatic-programmer`
>   - `npx -y @bybrawe/opencode-loop`
> - refuse hub-root execution

### Reused verbatim — repo-specific agent-policy override

The following wording is also copied verbatim from the older plan and remains authoritative here:

> The generic `using-git-worktrees` skill still applies, but this repository adds a stricter repo-specific rule:
> - `/workspaces/dotfiles` is a **manager hub**, not a normal checkout
> - work must happen in `/workspaces/dotfiles/main` or another explicit worktree
> - the same rule applies recursively to child repos under `repos/*`

### Reused with runtime-wrapper adaptation only

- Older **Task 6** (`opencode-export-all-sessions.sh`) is reused in phase 2 with the same export contract.
- Older **Task 7** (`prepare-state-backup-set.sh`) is reused in phase 2 with the same atomic-promotion and busy-file contract, plus one new status/freshness wrapper.
- Older **Task 8** (`host-pull-and-restic-backup.sh`) is reused in phase 2 with DevSpace pipeline wiring and stale-data warnings added.
- Older **Task 9** (`recover-opencode-sessions.sh`) is reused in phase 2 with the same newest-first dedupe contract.

### Explicitly not carried forward from the older plan

- Host-first bootstrap as the primary workspace creation path.
- DevPod as the launcher/runtime.
- Host-mounted source as the workspace source of truth.
- DevPod-specific persistence verification docs and mount assumptions.

Those assumptions were superseded by the approved DevSpace design and must not re-enter the implementation through copy/paste.

---

## File map

### Phase 1 — Core workspace lifecycle

#### DevSpace and manifest surface
- Create: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/workspace-pvc.yaml`
- Create: `k8s/devspace-bare-hub/workspace-deployment.yaml`
- Create: `tests/devspace/test_devspace_command_surface.sh`
- Create: `tests/devspace/test_workspace_manifest_contract.sh`
- Create: `tests/devspace/test_devspace_ssh_contract.sh`

#### Shared bare-hub core and provision flow
- Create: `scripts/lib/hub-repo-core.sh`
- Create: `scripts/workspace-provision.sh`
- Create: `scripts/devspace-dev-preflight.sh`
- Create: `tests/devspace/test_workspace_provision.sh`
- Create: `tests/devspace/test_devspace_dev_preflight.sh`

#### Install, policy, and docs carried forward from the older plan
- Create: `scripts/install-validate-source.sh`
- Modify: `install.sh`
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Create: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Create: `tests/install/test_install_validate_source.sh`
- Create: `tests/install/test_install_local_source_contract.sh`
- Create: `tests/docs/test_bare_hub_guardrails.sh`

#### Doctor, repair, destroy
- Create: `scripts/devspace-doctor.sh`
- Create: `scripts/workspace-repair.sh`
- Create: `scripts/devspace-destroy.sh`
- Create: `tests/devspace/test_devspace_doctor.sh`
- Create: `tests/devspace/test_workspace_repair.sh`
- Create: `tests/devspace/test_devspace_destroy.sh`
- Create: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`

#### Child repo onboarding
- Create: `scripts/create-hub-repo.sh`
- Create: `tests/devspace/test_create_hub_repo.sh`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`

### Phase 2 — Staging and backup

#### Export and staging core
- Create: `scripts/opencode-export-all-sessions.sh`
- Create: `scripts/prepare-state-backup-set.sh`
- Create: `scripts/workspace-staging.sh`
- Create: `tests/opencode/test_export_all_sessions.sh`
- Create: `tests/opencode/test_prepare_state_backup_set.sh`
- Create: `tests/opencode/test_workspace_staging.sh`

#### CronJob and DevSpace wrappers
- Modify: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/staging-cronjob.yaml`
- Create: `tests/devspace/test_staging_cronjob_contract.sh`

#### Host pull, backup, recovery, and runbooks
- Create: `scripts/host-pull-and-restic-backup.sh`
- Create: `ops/host-backup/run-devspace-backup.sh`
- Create: `ops/host-backup/container/Containerfile`
- Create: `ops/host-backup/container/entrypoint.sh`
- Create: `ops/host-backup/container/crontab`
- Create: `scripts/recover-opencode-sessions.sh`
- Create: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Create: `tests/ops/test_host_backup_runner.sh`
- Create: `tests/ops/test_host_backup_container_contract.sh`
- Create: `tests/opencode/test_recover_opencode_sessions.sh`
- Create: `docs/superpowers/runbooks/devspace-staging-and-backup.md`

---

## Source code organization and repo strategy

### Recommended repository strategy

Use the existing `dotfiles` repo as the single source repo for the v1 implementation.

Why this is the recommended default:

- the approved design keeps the top-level dotfiles repo as the workspace anchor;
- agents are already operating inside the current DevPod checkout of this repo, so keeping DevSpace, shell scripts, tests, and runbooks together minimizes cross-repo drift;
- the host-runner source is small and tightly coupled to the workspace backup contract, so a second repo would add review and release overhead without improving reversibility.

Alternative later structure:

- keep `dotfiles` as the product/workspace repo;
- add a separate private `ops` repo only if multiple independently operated host-runner deployments appear, or if host-specific wrappers and private templates materially diverge from the workspace source.

Do **not** split v1 into two repos. A future private `ops` repo is optional follow-up work, not part of this first implementation plan.

### Exact directory layout and roles

```text
devspace.yaml                                   # thin DevSpace command surface
k8s/devspace-bare-hub/                          # Kubernetes manifests owned by this feature
  workspace-pvc.yaml
  workspace-deployment.yaml
  staging-cronjob.yaml
scripts/                                        # public repo-owned entrypoint scripts
  workspace-provision.sh
  devspace-dev-preflight.sh
  devspace-doctor.sh
  workspace-repair.sh
  devspace-destroy.sh
  create-hub-repo.sh
  opencode-export-all-sessions.sh
  prepare-state-backup-set.sh
  workspace-staging.sh
  host-pull-and-restic-backup.sh
  recover-opencode-sessions.sh
scripts/lib/                                    # sourced helpers only; no user-facing entrypoints
  hub-repo-core.sh
ops/host-backup/                                # host-only runner source; committed, but executed by humans on host
  run-devspace-backup.sh
  container/
    Containerfile
    entrypoint.sh
    crontab
tests/devspace/                                 # DevSpace/Kubernetes contract tests
tests/install/                                  # install-source and hub-root guardrail tests
tests/opencode/                                 # export/staging/pull/recovery tests
tests/ops/                                      # host-runner tests that remain executable inside the current DevPod
tests/docs/                                     # doc/runbook wording contract tests
docs/superpowers/runbooks/                      # human/operator runbooks
docs/superpowers/plans/                         # approved implementation plans
docs/superpowers/specs/                         # approved design specs
```

### Naming conventions

- Public scripts in `scripts/` and `ops/host-backup/` use `verb-noun.sh` naming.
- Files in `scripts/lib/` are sourced helpers, not direct operator entrypoints.
- Manifest files are one resource family per file and use `workspace-*` / `staging-*` prefixes.
- Test files use `test_<subject>.sh` and live in the narrowest domain directory that matches the contract.
- Runbooks use `devspace-*` or `host-*` prefixes and describe user/operator workflows, not internal implementation details.

### Runtime artifacts and backup payloads

- **Do not commit staged or pulled backup payloads to git.**
- The canonical host staging root should live outside the repo, for example:
  - `$HOME/.local/state/devspace-bare-hub/backup-stage/current`
  - `$HOME/.local/state/devspace-bare-hub/runner/`
- Only source code, tests, manifests, templates, and runbooks are committed.
- The workspace `state/backup/staging/latest.log` and `latest.json` are runtime artifacts on the PVC, not repo files.

---

## Implementation, testing, and deployment guidance

### Current authoring environment vs target runtime

- **Current implementation environment for agents:** the existing DevPod-enclosed checkout described in `.config/opencode/AGENTS.md`, currently `/home/vscode/dotfiles`.
- **Target runtime environment being built:** the future DevSpace-managed workspace rooted at `/workspaces/dotfiles` inside the Kubernetes pod.

This distinction is important: agents should implement and test the source from the current checkout/worktree, but humans must deploy DevSpace and the host-runner from the host machine because agents do not have a direct write path back to host state.

### Agent-side implementation and testing inside the current DevPod

Agents should develop from the current checkout or from a git worktree created from it, not from a pretend host path.

Recommended workflow for implementers:

```bash
git worktree add "/tmp/devspace-bare-hub-work" -b work/devspace-bare-hub HEAD
```

Inside that worktree, prefer these local checks:

```bash
bash tests/devspace/test_devspace_command_surface.sh
bash tests/devspace/test_workspace_manifest_contract.sh
bash tests/devspace/test_devspace_ssh_contract.sh
kubectl apply --dry-run=client -f k8s/devspace-bare-hub
devspace deploy --render > /tmp/devspace-rendered.yaml
devspace dev --render > /tmp/devspace-dev-rendered.yaml
git diff --check
```

If `devspace` is not available in the current agent environment, the minimum required local checks remain:

```bash
kubectl apply --dry-run=client -f k8s/devspace-bare-hub
bash tests/devspace/test_workspace_provision.sh
bash tests/devspace/test_devspace_doctor.sh
bash tests/opencode/test_prepare_state_backup_set.sh
git diff --check
```

Agent-side rules:

- use temp directories and fixture paths to simulate `/workspaces/dotfiles` and `$HOME` contracts;
- do not require host kubeconfig, host SSH config, or `restic` credentials inside the agent environment;
- test host-runner logic through shell contract tests (`tests/ops/...`) rather than by installing host services from inside the DevPod.

### Human host deployment of DevSpace

Humans perform the actual deployment from a normal host checkout because DevSpace, kubeconfig selection, SSH config mutation, and host-runner setup are operator responsibilities.

Recommended deployment sequence from the host:

```bash
git pull --ff-only
devspace version
kubectl version --client
kubectl config current-context
devspace deploy --render > /tmp/dotfiles-devspace-rendered.yaml
kubectl apply --dry-run=client -f k8s/devspace-bare-hub
devspace deploy -n "${NAMESPACE:-devspace}"
devspace run-pipeline provision -n "${NAMESPACE:-devspace}"
devspace dev -n "${NAMESPACE:-devspace}"
```

Expected outcomes:

- render and client dry-run succeed;
- `provision` creates the top-level bare hub and runs `main/install.sh`;
- `devspace dev` opens the interactive workflow without hiding provisioning.

### DevSpace-managed SSH details and verification

Implementation contract for v1:

- define the primary dev config as `workspace` under a DevSpace project named `dotfiles`;
- enable DevSpace SSH via the built-in `ssh` dev connection;
- set `ssh.useInclude: true` so DevSpace prefers `~/.ssh/devspace_config` plus an include entry in `~/.ssh/config`;
- rely on DevSpace-generated keys in `~/.devspace/ssh/`;
- let DevSpace manage the local SSH tunnel by forwarding a loopback-only local port to the injected in-container SSH helper and writing the matching SSH alias locally;
- do **not** create a Kubernetes `Service`, LoadBalancer, or NodePort for SSH;
- do **not** bake a long-lived sshd into the image; let DevSpace inject the helper and reach it via local port-forward/tunnel.

Human verification commands after `devspace dev`:

```bash
test -f "$HOME/.devspace/ssh/id_devspace_rsa"
grep -F "Host workspace.dotfiles.devspace" "$HOME/.ssh/devspace_config" || grep -F "Host workspace.dotfiles.devspace" "$HOME/.ssh/config"
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
ssh -o BatchMode=yes workspace.dotfiles.devspace 'test -d /workspaces/dotfiles/main && printf ok\n'
kubectl get svc -n "${NAMESPACE:-devspace}"
```

Expected outcomes:

- the DevSpace SSH private key exists locally;
- the SSH alias `workspace.dotfiles.devspace` is present in the local SSH config;
- remote `pwd` prints `/workspaces/dotfiles/main`;
- the remote check prints `ok`;
- no standalone workspace `Service` appears just to expose SSH.

IDE guidance:

- PyCharm, VS Code Remote SSH, and similar tools should use the DevSpace-generated alias `workspace.dotfiles.devspace`.
- The host's SSH config is the integration boundary; no editor credentials or SSH keys are committed to the repo.

### Human host deployment of the scheduled backup runner

Recommended default: a small containerized cron runner under user control.

Why this is the default:

- it works on the documented macOS + colima/k3d host setup as well as Linux;
- it keeps scheduling under explicit human control;
- it is testable through repo-owned shell contracts without requiring agents to install host services.

Recommended host setup commands:

```bash
mkdir -p "$HOME/.config/devspace-bare-hub" "$HOME/.local/state/devspace-bare-hub/backup-stage" "$HOME/.local/state/devspace-bare-hub/runner"
chmod 700 "$HOME/.config/devspace-bare-hub" "$HOME/.local/state/devspace-bare-hub" "$HOME/.local/state/devspace-bare-hub/backup-stage" "$HOME/.local/state/devspace-bare-hub/runner"
printf '%s\n' \
  "RESTIC_REPOSITORY=/absolute/path/or/restic-url" \
  "RESTIC_PASSWORD_FILE=$HOME/.config/devspace-bare-hub/restic-password" \
  "BACKUP_PULL_ROOT=$HOME/.local/state/devspace-bare-hub/backup-stage" \
  "KUBECONFIG=$HOME/.kube/config" \
  > "$HOME/.config/devspace-bare-hub/backup.env"
chmod 600 "$HOME/.config/devspace-bare-hub/backup.env"

set -a
. "$HOME/.config/devspace-bare-hub/backup.env"
set +a
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

$CONTAINER_RUNTIME build -t devspace-bare-hub-backup -f ops/host-backup/container/Containerfile ops/host-backup/container
$CONTAINER_RUNTIME run -d --name devspace-bare-hub-backup \
  --restart=unless-stopped \
  --env-file "$HOME/.config/devspace-bare-hub/backup.env" \
  -v "$HOME/.config/devspace-bare-hub:$HOME/.config/devspace-bare-hub:ro" \
  -v "$HOME/.local/state/devspace-bare-hub:$HOME/.local/state/devspace-bare-hub" \
  -v "$(dirname \"$KUBECONFIG\")":"$(dirname \"$KUBECONFIG\")":ro \
  -v "$(dirname \"$RESTIC_PASSWORD_FILE\")":"$(dirname \"$RESTIC_PASSWORD_FILE\")":ro \
  devspace-bare-hub-backup
```

If `RESTIC_REPOSITORY` is a local filesystem path, bind-mount it into the container at the same absolute path used in `backup.env`. If it is an object-store URL, mount only the credential files it references.

Linux-only fallback:

- provide a user-level systemd timer example in the runbook that invokes `ops/host-backup/run-devspace-backup.sh` with the same environment file;
- keep the containerized runner as the recommended default because it is cross-host and easier to test from the repo.

Minimal Linux fallback example:

```bash
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/devspace-bare-hub-backup.service" <<'EOF'
[Unit]
Description=Run DevSpace bare-hub backup once

[Service]
Type=oneshot
ExecStart=%h/dotfiles/ops/host-backup/run-devspace-backup.sh --once --env-file %h/.config/devspace-bare-hub/backup.env
EOF

cat > "$HOME/.config/systemd/user/devspace-bare-hub-backup.timer" <<'EOF'
[Unit]
Description=Run DevSpace bare-hub backup at minute 30 of every hour

[Timer]
OnCalendar=*-*-* *:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now devspace-bare-hub-backup.timer
systemctl --user list-timers devspace-bare-hub-backup.timer
```

Host-runner verification commands:

```bash
podman logs devspace-bare-hub-backup | tail -n 20
test -f "$HOME/.local/state/devspace-bare-hub/backup-stage/current/state/backup/staging/latest.json" || true
bash ops/host-backup/run-devspace-backup.sh --once --env-file "$HOME/.config/devspace-bare-hub/backup.env"
```

Expected outcomes:

- the runner container stays up and emits scheduled-run logs;
- the manual `--once` invocation succeeds with the same shared script the scheduler uses;
- stale staging remains warning-only even on repeated runs.

### Credentials handling and restic hints

- keep `RESTIC_PASSWORD_FILE`, kubeconfig, and any cloud/object-store credentials outside the repo;
- prefer host environment files with mode `0600` under `$HOME/.config/devspace-bare-hub/`;
- do not mount the real restic repository writable into the DevSpace pod;
- do not copy host kubeconfig or restic credentials into the in-cluster workspace PVC;
- for first setup, humans should initialize the repository explicitly on the host:

```bash
export RESTIC_REPOSITORY=/absolute/path/to/restic-repo
export RESTIC_PASSWORD_FILE=/absolute/path/to/restic-password
restic snapshots || restic init
```

- verify backup access before enabling the scheduler:

```bash
RESTIC_REPOSITORY=/absolute/path/to/restic-repo \
RESTIC_PASSWORD_FILE=/absolute/path/to/restic-password \
restic snapshots
```


## Acceptance-test mapping

| Acceptance section | Covered by | Notes |
| --- | --- | --- |
| A. Workspace creation and access | Tasks 1, 3 | `devspace.yaml`, manifests, DevSpace-managed SSH, working directory, no Service |
| B. Provisioning behavior | Tasks 3, 2 | top-level bare clone, `origin/main`, `main/install.sh` |
| C. Normal startup vs unprovisioned state | Tasks 1, 3, 4 | explicit refusal path before interactive use |
| D. Bare-hub layout and canonical paths | Tasks 3, 5 | top-level + child repo canonical paths |
| E. `/home/vscode` and install behavior | Task 2 | top-level-only authority, local-source install |
| F. `doctor` behavior | Task 4 | host-side, human-readable, exit codes 0/1/2 |
| G. `repair` behavior | Task 4 | non-destructive structural recovery only |
| H. `destroy` behavior | Task 4 | delete Deployment/PVC, then reprovision cleanly |
| I. Child repo onboarding | Task 5 | public repos only, repo-derived name, `origin/main` only |
| J. Periodic staging | Tasks 6, 7, 8 | export + stage + CronJob + manual trigger |
| K. Backup command and host pull | Tasks 8, 9 | `staging` and `backup` pipelines, scheduled host runner, host pull + `restic` |
| L. Backup visibility and recovery signal | Tasks 7, 8, 9, 10 | status file, logs, stale warning, recovery |

---

## Owners and handoff model

| Task | Plan owner | Execution owner | Planner → implementer handoff point |
| --- | --- | --- | --- |
| 1 | planner | implementer | Start once this plan is approved; no production edits before failing tests exist for command surface + manifests |
| 2 | planner | implementer | Start after Task 1 commit; install/policy contracts must be green before Task 3 invokes `main/install.sh` |
| 3 | planner | implementer | Start after Task 2 commit; this task creates the usable top-level workspace |
| 4 | planner | implementer | Start after Task 3 commit; `doctor` / `repair` / `destroy` depend on a valid provisioned workspace contract |
| 5 | planner | implementer | Start after Task 3 commit; may run after Task 4 if reviewer prefers simpler v1 slices |
| 6 | planner | implementer | Start only after all phase-1 acceptance items are approved |
| 7 | planner | implementer | Start after Task 6 commit |
| 8 | planner | implementer | Start after Task 7 commit |
| 9 | planner | implementer | Start after Task 8 commit |
| 10 | planner | implementer | Start after Task 9 commit |

Recommended human review gates:

1. After Task 3: manual `provision` + `dev` smoke test.
2. After Task 5: full phase-1 acceptance review.
3. After Task 10: phase-2 staging/backup review.

---

## Timeline estimate

PERT-style ranges in implementation days:

| Slice | Optimistic | Most likely | Pessimistic | PERT |
| --- | ---: | ---: | ---: | ---: |
| Task 1 — DevSpace + manifest surface | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 2 — install + policy carry-forward | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 3 — shared core + provision | 1.0 | 1.5 | 2.5 | 1.6 |
| Task 4 — doctor/repair/destroy | 1.0 | 1.5 | 2.5 | 1.6 |
| Task 5 — child repo onboarding | 0.5 | 1.0 | 1.5 | 1.0 |
| **Phase 1 subtotal** | **3.5** | **6.0** | **9.5** | **6.2** |
| Task 6 — export sessions | 0.25 | 0.5 | 1.0 | 0.5 |
| Task 7 — staging core + status | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 8 — CronJob + DevSpace staging wrapper | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 9 — host runner + pull + `restic` | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 10 — recovery + backup runbook | 0.25 | 0.5 | 1.0 | 0.5 |
| **Phase 2 subtotal** | **2.0** | **4.0** | **6.5** | **4.0** |

Working estimate: **~6 implementation days for phase 1** and **~4 implementation days for phase 2**, excluding human review wait time.

---

## Phase 1 — Core workspace lifecycle

### Task 1: Add the thin DevSpace command surface and workspace manifests

**Why first:** Everything else depends on the workspace object existing in a predictable shape.

**Acceptance:** A1-A6, C1-C3.

**Files:**
- Create: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/workspace-pvc.yaml`
- Create: `k8s/devspace-bare-hub/workspace-deployment.yaml`
- Test: `tests/devspace/test_devspace_command_surface.sh`
- Test: `tests/devspace/test_workspace_manifest_contract.sh`
- Test: `tests/devspace/test_devspace_ssh_contract.sh`

- [ ] **Step 1: Write the failing command-surface test first**

`tests/devspace/test_devspace_command_surface.sh` should fail until `devspace.yaml` exists and should assert all of the following exact contracts:

- `devspace dev` is present as the normal entrypoint.
- `devspace run-pipeline provision` exists.
- `devspace run-pipeline doctor` exists.
- `devspace run-pipeline repair` exists.
- `devspace run-pipeline destroy` exists.
- `devspace run-pipeline staging` and `devspace run-pipeline backup` do **not** appear yet in the phase-1 slice.

- [ ] **Step 2: Write the failing manifest contract test**

`tests/devspace/test_workspace_manifest_contract.sh` should parse the YAML and fail until the manifest files exist. It must assert:

- exactly one `Deployment` manifest;
- exactly one PVC manifest;
- no standalone `Service` manifest in the directory;
- container `workingDir: /workspaces/dotfiles/main`;
- one PVC volume mounted at `/workspaces/dotfiles` with `subPath: workspace-root`;
- the same PVC mounted at `/home/vscode` with `subPath: home-vscode`.

- [ ] **Step 2A: Write the failing DevSpace SSH contract test**

`tests/devspace/test_devspace_ssh_contract.sh` should fail until the SSH config exists in `devspace.yaml` and must assert:

- the primary dev config exposes `ssh.enabled: true`;
- `ssh.useInclude: true` is enabled so DevSpace writes `~/.ssh/devspace_config` entries when supported;
- the local hostname/alias resolves to `workspace.dotfiles.devspace`;
- the SSH path relies on a DevSpace-managed localhost tunnel/port-forward and not on cluster-exposed network reachability;
- the plan does not add a Kubernetes `Service`/NodePort/LoadBalancer for SSH because DevSpace reaches the injected SSH helper via local tunnel/port-forward.

- [ ] **Step 3: Run RED**

Run:

```bash
bash tests/devspace/test_devspace_command_surface.sh
bash tests/devspace/test_workspace_manifest_contract.sh
bash tests/devspace/test_devspace_ssh_contract.sh
```

Expected: all fail because the DevSpace and manifest files do not exist yet.

- [ ] **Step 4: Implement the minimal DevSpace and manifest surface**

Implementation contract:

- `devspace.yaml` is thin and repo-owned.
- The `dev` flow may create/start the workload, but it must call a preflight that refuses normal use when the workspace is unprovisioned.
- The Deployment uses the current repo Dockerfile as the image basis and pins one explicit image tag per implementation commit; do not introduce auto-rebuilding logic into v1.
- The Deployment manifest contains no Service.
- The dev config must enable DevSpace-managed SSH and rely on DevSpace's generated local SSH config and key material instead of a cluster-exposed SSH service.

- [ ] **Step 5: Run GREEN**

Run the three tests again and then a manifest sanity pass:

```bash
bash tests/devspace/test_devspace_command_surface.sh
bash tests/devspace/test_workspace_manifest_contract.sh
bash tests/devspace/test_devspace_ssh_contract.sh
kubectl apply --dry-run=client -f k8s/devspace-bare-hub
```

Expected: tests pass and `kubectl apply --dry-run=client` exits 0.

- [ ] **Step 5A: Manual SSH acceptance check from the host**

Run after `devspace dev` starts on the host:

```bash
test -f "$HOME/.devspace/ssh/id_devspace_rsa"
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
ssh -o BatchMode=yes workspace.dotfiles.devspace 'test -d /workspaces/dotfiles/main && printf ok\n'
```

Expected:

```text
/workspaces/dotfiles/main
ok
```

- [ ] **Step 6: Commit**

```bash
git add devspace.yaml k8s/devspace-bare-hub/workspace-pvc.yaml k8s/devspace-bare-hub/workspace-deployment.yaml tests/devspace/test_devspace_command_surface.sh tests/devspace/test_workspace_manifest_contract.sh tests/devspace/test_devspace_ssh_contract.sh
git commit -m "feat(devspace): add workspace command surface and manifests"
```

**Rollback:** revert this commit; no PVC contents exist yet.

### Task 2: Carry forward the reusable install and bare-hub guardrail contracts

**Why second:** The new provision flow must run `main/install.sh`, so the install/policy contract must be correct before Task 3.

**Acceptance:** D1-D4, E1-E4.

**Reuse source:** older Tasks 2, 4, and 5.

**Files:**
- Create: `scripts/install-validate-source.sh`
- Modify: `install.sh`
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Create: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Test: `tests/install/test_install_validate_source.sh`
- Test: `tests/install/test_install_local_source_contract.sh`
- Test: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Reuse the older failing tests first**

Carry over the older contract tests with only the naming/docs changes needed for DevSpace wording:

- `tests/install/test_install_validate_source.sh`
- `tests/install/test_install_local_source_contract.sh`
- `tests/docs/test_bare_hub_guardrails.sh`

The behavioral contract must stay the same as the older plan for install source detection and hub-root refusal.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/install/test_install_validate_source.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: fail because the current repo still uses the old fixed `~/dotfiles` install behavior and does not yet contain the repo-specific DevSpace guardrail wording.

- [ ] **Step 3: Implement the minimal carry-forward changes**

Implementation contract:

- Preserve the verbatim installer policy quoted earlier in this plan.
- Keep the exact refusal string: `Refused — hub-root CWD detected. Provide explicit worktree path.`
- Keep the top-level dotfiles repo as the only `/home/vscode` authority.
- Update the usage runbook so DevSpace users are directed to `/workspaces/dotfiles/main`, not the hub root.

- [ ] **Step 4: Run GREEN**

Run the three tests again plus one manual dry-run check:

```bash
bash tests/install/test_install_validate_source.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/docs/test_bare_hub_guardrails.sh
bash ./install.sh --dry-run -y
```

Expected: tests pass; the manual dry-run uses the script’s own checkout/worktree as the source.

- [ ] **Step 5: Commit**

```bash
git add scripts/install-validate-source.sh install.sh .config/opencode/AGENTS.md .config/opencode/agents/maestro.md .config/opencode/agents/senior-implementer.md docs/superpowers/runbooks/devspace-bare-hub-usage.md tests/install/test_install_validate_source.sh tests/install/test_install_local_source_contract.sh tests/docs/test_bare_hub_guardrails.sh
git commit -m "feat(workspace): carry forward install and bare-hub guardrails"
```

**Rollback:** revert this commit; rerun the three tests to confirm the repo is back at the pre-carry-forward state.

### Task 3: Provision the top-level DevSpace workspace as a bare hub

**Why third:** This is the first task that creates a usable workspace and turns the spec into an end-to-end tracer bullet.

**Acceptance:** A1-A6, B1-B8, C1-C3, D1-D4, E1-E4.

**Files:**
- Create: `scripts/lib/hub-repo-core.sh`
- Create: `scripts/workspace-provision.sh`
- Create: `scripts/devspace-dev-preflight.sh`
- Modify: `devspace.yaml`
- Test: `tests/devspace/test_workspace_provision.sh`
- Test: `tests/devspace/test_devspace_dev_preflight.sh`

- [ ] **Step 1: Write the failing provision tests first**

`tests/devspace/test_workspace_provision.sh` must cover at least these contracts:

- first-time provision from an empty workspace root creates `.bare`, `.git`, `main`, `work`, `repos`, `state`, and `tmp`;
- top-level `main` is attached from the bare repo;
- canonical top-level paths exist: `state/hub/main/` and `tmp/hub/main/`;
- `main/install.sh` is invoked;
- provision refuses if `origin/main` is absent;
- provision refuses if an existing `main/` path is present in a broken or detached state.

`tests/devspace/test_devspace_dev_preflight.sh` must cover these contracts:

- when `.bare` or `main` is missing, the preflight exits non-zero and prints `run devspace run-pipeline provision`;
- when the workspace is provisioned, the preflight exits 0.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_workspace_provision.sh
bash tests/devspace/test_devspace_dev_preflight.sh
```

Expected: fail because the provision and preflight scripts do not exist yet.

- [ ] **Step 3: Implement the smallest shared helper boundary**

Implementation contract:

- `scripts/lib/hub-repo-core.sh` owns only the duplicated bare-hub creation steps.
- `scripts/workspace-provision.sh` remains the public top-level provision entrypoint.
- The top-level provision source is the public dotfiles repo, cloned bare in-pod.
- V1 supports only `origin/main`; do not add branch configurability.
- The script must create `state/hub/main/` and `tmp/hub/main/` immediately after attaching `main`.

- [ ] **Step 4: Wire the DevSpace pipelines**

`devspace run-pipeline provision` must:

1. ensure the Deployment/PVC/pod exist and are running;
2. execute `scripts/workspace-provision.sh` inside the pod;
3. leave `devspace dev` as a separate, non-auto-bootstrap interactive entrypoint.

- [ ] **Step 5: Run GREEN**

Run:

```bash
bash tests/devspace/test_workspace_provision.sh
bash tests/devspace/test_devspace_dev_preflight.sh
devspace run-pipeline provision
devspace run-pipeline doctor || true
```

Expected: both tests pass; `provision` creates the workspace; `doctor` is now able to report a provisioned workspace once Task 4 lands.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/hub-repo-core.sh scripts/workspace-provision.sh scripts/devspace-dev-preflight.sh devspace.yaml tests/devspace/test_workspace_provision.sh tests/devspace/test_devspace_dev_preflight.sh
git commit -m "feat(workspace): provision top-level devspace bare hub"
```

**Manual review gate:** human runs `devspace run-pipeline provision` and then `devspace dev` to confirm the default directory is `/workspaces/dotfiles/main`.

**Rollback:** if the PVC contents are untrusted, run `devspace run-pipeline destroy`, then revert this task’s commit.

### Task 4: Add `doctor`, `repair`, and `destroy` with explicit refusal boundaries

**Why fourth:** This closes the operational loop for v1 and resolves the biggest open questions left in the spec.

**Acceptance:** C1-C3, F1-F8, G1-G8, H1-H4.

**Files:**
- Create: `scripts/devspace-doctor.sh`
- Create: `scripts/workspace-repair.sh`
- Create: `scripts/devspace-destroy.sh`
- Modify: `devspace.yaml`
- Create: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Test: `tests/devspace/test_devspace_doctor.sh`
- Test: `tests/devspace/test_workspace_repair.sh`
- Test: `tests/devspace/test_devspace_destroy.sh`

- [ ] **Step 1: Write the failing tests first**

`tests/devspace/test_devspace_doctor.sh` must assert:

- human-readable output only;
- exit code 0 when all checks pass;
- exit code 1 when any required check fails;
- exit code 2 for invalid CLI usage;
- required checks exactly match acceptance section F.

`tests/devspace/test_workspace_repair.sh` must assert:

- missing managed directories can be recreated;
- missing canonical `state/` and `tmp/` paths can be recreated;
- `main` can be reattached only when `.bare` is valid and recognizable;
- existing tracked/untracked files and worktrees are not deleted;
- a still-valid non-`main` `/home/vscode` symlink target is preserved;
- invalid `.bare`, ambiguous identity, or conflicting path types cause refusal.

`tests/devspace/test_devspace_destroy.sh` must assert that the host-side pipeline deletes both the Deployment/pod and the PVC.

The same task must also retain the SSH acceptance path established by Task 1 at the operational level:

- after `devspace dev`, humans can connect with `ssh workspace.dotfiles.devspace`;
- `doctor` remains host-side and does not require a standalone SSH Service to confirm workspace reachability.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_devspace_doctor.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/devspace/test_devspace_destroy.sh
```

Expected: fail because the scripts and lifecycle runbook do not exist yet.

- [ ] **Step 3: Implement `doctor` exactly to the acceptance checklist**

Implementation contract:

- host-side only;
- human-readable in v1;
- flat checklist, no advisory-only category;
- checks Deployment existence, PVC existence, pod reachability, `.bare`, `main`, `work/`, `repos/`, `state/`, `tmp/`, canonical top-level hub `state/` and `tmp/` paths, and `/home/vscode` symlink targets.

- [ ] **Step 4: Implement `repair` and `destroy`**

Implementation contract:

- `repair` is non-destructive and structural only;
- `destroy` is the true clean reset path;
- neither command guesses when the top-level workspace identity is ambiguous.

- [ ] **Step 5: Run GREEN**

Run:

```bash
bash tests/devspace/test_devspace_doctor.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/devspace/test_devspace_destroy.sh
devspace run-pipeline doctor
```

Expected: tests pass; `doctor` prints a readable pass/fail summary.

- [ ] **Step 6: Commit**

```bash
git add scripts/devspace-doctor.sh scripts/workspace-repair.sh scripts/devspace-destroy.sh devspace.yaml docs/superpowers/runbooks/devspace-workspace-lifecycle.md tests/devspace/test_devspace_doctor.sh tests/devspace/test_workspace_repair.sh tests/devspace/test_devspace_destroy.sh
git commit -m "feat(workspace): add doctor repair and destroy flows"
```

**Rollback:** revert this commit; if `destroy` semantics are in doubt, verify by running only the tests, not the real destructive pipeline.

### Task 5: Add public child-repo onboarding with the same bare-hub conventions

**Why fifth:** It depends on the top-level provision contract but is otherwise isolated enough to land as the last phase-1 slice.

**Acceptance:** D5, I1-I7.

**Reuse source:** older `create-hub-repo.sh` design notes and shared-helper boundary.

**Files:**
- Create: `scripts/create-hub-repo.sh`
- Test: `tests/devspace/test_create_hub_repo.sh`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`

- [ ] **Step 1: Write the failing onboarding test first**

`tests/devspace/test_create_hub_repo.sh` must assert:

- public repo only in v1;
- repo-derived default name is used for `repos/<name>`;
- `--name` override is rejected or absent in v1; repo-derived naming is the only supported naming path for this phase;
- collisions refuse rather than rename automatically;
- `origin/main` is the only supported source ref;
- successful onboarding creates `repos/<name>/.bare`, `repos/<name>/main`, `repos/<name>/work/`, `state/repos/<name>/main/`, and `tmp/repos/<name>/main/`;
- child onboarding does not change `/home/vscode` symlink authority.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_create_hub_repo.sh
```

Expected: fail because `scripts/create-hub-repo.sh` does not exist yet.

- [ ] **Step 3: Implement the public child-repo entrypoint**

Implementation contract:

- keep `scripts/create-hub-repo.sh` as the public entrypoint;
- reuse `scripts/lib/hub-repo-core.sh` only for the duplicated repo-hub steps;
- do not add a user-supplied `--name` override in v1;
- keep `/home/vscode` authority exclusively with the top-level dotfiles repo.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/devspace/test_create_hub_repo.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/create-hub-repo.sh docs/superpowers/runbooks/devspace-bare-hub-usage.md tests/devspace/test_create_hub_repo.sh
git commit -m "feat(workspace): add public child repo onboarding"
```

**Manual review gate:** human provisions the top-level workspace, adds one public child repo, and confirms `~/` links still point into the top-level worktree.

**Rollback:** revert this commit and remove any experimental child repo directory from the PVC manually if needed.

---

## Phase-1 verification and rollback checklist

Before claiming phase 1 complete, run:

```bash
bash tests/devspace/test_devspace_command_surface.sh
bash tests/devspace/test_workspace_manifest_contract.sh
bash tests/devspace/test_devspace_ssh_contract.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/docs/test_bare_hub_guardrails.sh
bash tests/devspace/test_workspace_provision.sh
bash tests/devspace/test_devspace_dev_preflight.sh
bash tests/devspace/test_devspace_doctor.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/devspace/test_devspace_destroy.sh
bash tests/devspace/test_create_hub_repo.sh
devspace run-pipeline provision
devspace run-pipeline doctor
devspace dev
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
git diff --check
```

Expected:

- all shell tests print `PASS`;
- `provision` succeeds from an empty or intentionally reset workspace;
- `doctor` returns exit 0 on the healthy workspace;
- `ssh workspace.dotfiles.devspace 'pwd'` prints `/workspaces/dotfiles/main` without a standalone workspace Service;
- `git diff --check` prints no output.

Phase-1 rollback order if the slice must be backed out:

1. Revert the phase-1 commits in reverse order.
2. If the PVC contents are suspect, run `devspace run-pipeline destroy`.
3. Re-run `devspace run-pipeline provision` from the last known-good revision.

---

## Phase 2 — Deferred staging and backup

> **Traceability gate:** The current approved spec and acceptance checklist explicitly cover staging status, host pull, `restic`, and visibility, but they do not yet name OpenCode session export/recovery as separate acceptance deliverables. Do not start Tasks 6 or 10 until that approval is added, or remove them from the active plan scope for this slice.

### Task 6: Export OpenCode sessions into `state/opencode/exported_sessions/`

**Why first in phase 2:** The exported JSON files are the durable source-of-truth artifact for session recovery and downstream backup.

**Acceptance:** J1-J5, L1-L4.

**Reuse source:** older Task 6 is reused without contract changes.

**Files:**
- Create: `scripts/opencode-export-all-sessions.sh`
- Test: `tests/opencode/test_export_all_sessions.sh`

- [ ] **Step 1: Carry over the older failing test first**

Reuse the older integration/contract test for export behavior. Keep the same mocked CLI rationale and the same guarantees:

- export only valid sessions;
- remove superseded exports for the same session id;
- leave no temp files behind.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh
```

Expected: fail because `scripts/opencode-export-all-sessions.sh` does not exist yet.

- [ ] **Step 3: Implement the reused export contract**

Implementation contract is unchanged from the older plan.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/opencode-export-all-sessions.sh tests/opencode/test_export_all_sessions.sh
git commit -m "feat(opencode): export durable session backups"
```

### Task 7: Stage durable state and record persistent staging status

**Why second in phase 2:** The older staging contract is still right, but the new design adds visible persistent status and freshness tracking.

**Acceptance:** J1-J5, K6-K8, L1-L2.

**Reuse source:** older Task 7 for `prepare-state-backup-set.sh`, plus one new wrapper `workspace-staging.sh`.

**Files:**
- Create: `scripts/prepare-state-backup-set.sh`
- Create: `scripts/workspace-staging.sh`
- Test: `tests/opencode/test_prepare_state_backup_set.sh`
- Test: `tests/opencode/test_workspace_staging.sh`

- [ ] **Step 1: Reuse the older staging-core failing test first**

Carry over the older `tests/opencode/test_prepare_state_backup_set.sh` unchanged for the atomic promotion and busy-file skip behavior.

- [ ] **Step 2: Add one new failing test for the wrapper/status contract**

`tests/opencode/test_workspace_staging.sh` must assert:

- the wrapper runs `opencode-export-all-sessions.sh` and `prepare-state-backup-set.sh` in that order;
- staging writes a human-readable log under the top-level `state/` tree;
- staging writes a machine-readable status file under the top-level `state/` tree with at least `started_at`, `finished_at`, `ok`, and `staging_root` fields;
- failure leaves a visible non-OK status record but does not delete the previous `current` staging set.

- [ ] **Step 3: Run RED**

Run:

```bash
bash tests/opencode/test_prepare_state_backup_set.sh
bash tests/opencode/test_workspace_staging.sh
```

Expected: fail because the staging scripts do not exist yet.

- [ ] **Step 4: Implement the reused core plus the new wrapper**

Implementation contract:

- keep the older atomic `current` symlink promotion model;
- keep the busy-file skip-and-report contract;
- add `state/backup/staging/latest.log` and `state/backup/staging/latest.json` as the canonical persistent status artifacts.

- [ ] **Step 5: Run GREEN**

Run:

```bash
bash tests/opencode/test_prepare_state_backup_set.sh
bash tests/opencode/test_workspace_staging.sh
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/prepare-state-backup-set.sh scripts/workspace-staging.sh tests/opencode/test_prepare_state_backup_set.sh tests/opencode/test_workspace_staging.sh
git commit -m "feat(backup): add staging core and persistent status"
```

### Task 8: Use one staging script for both a CronJob and a manual DevSpace pipeline

**Why third in phase 2:** The design explicitly requires the same staging script for scheduled and manual runs.

**Acceptance:** J1-J5, K2-K3, L2.

**Files:**
- Modify: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/staging-cronjob.yaml`
- Test: `tests/devspace/test_staging_cronjob_contract.sh`
- Modify: `docs/superpowers/runbooks/devspace-staging-and-backup.md`

- [ ] **Step 1: Write the failing CronJob/pipeline test first**

`tests/devspace/test_staging_cronjob_contract.sh` must assert:

- the CronJob invokes `scripts/workspace-staging.sh`;
- the manual `devspace run-pipeline staging` pipeline invokes the same script;
- the CronJob schedule is `0 * * * *`;
- the CronJob writes logs that remain visible through Kubernetes job logs.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_staging_cronjob_contract.sh
```

Expected: fail because the CronJob manifest and pipeline wiring do not exist yet.

- [ ] **Step 3: Implement the shared-script wiring**

Implementation contract:

- the CronJob and manual pipeline both call the same `scripts/workspace-staging.sh` entrypoint;
- staging failures must not block normal `devspace dev` use;
- phase 2 adds `devspace run-pipeline staging`, but phase 1 must not have exposed it.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/devspace/test_staging_cronjob_contract.sh
kubectl apply --dry-run=client -f k8s/devspace-bare-hub/staging-cronjob.yaml
```

Expected: test passes; CronJob manifest validates client-side.

- [ ] **Step 5: Commit**

```bash
git add devspace.yaml k8s/devspace-bare-hub/staging-cronjob.yaml tests/devspace/test_staging_cronjob_contract.sh docs/superpowers/runbooks/devspace-staging-and-backup.md
git commit -m "feat(backup): add staging cronjob and manual pipeline"
```

### Task 9: Add the host-side scheduled runner, pull staged data, and snapshot it with `restic`

**Why fourth in phase 2:** This is the actual off-cluster durability boundary.

**Acceptance:** K1-K9, L1-L4.

**Reuse source:** older Task 8, with stale/freshness warnings added.

**Files:**
- Create: `scripts/host-pull-and-restic-backup.sh`
- Create: `ops/host-backup/run-devspace-backup.sh`
- Create: `ops/host-backup/container/Containerfile`
- Create: `ops/host-backup/container/entrypoint.sh`
- Create: `ops/host-backup/container/crontab`
- Test: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Test: `tests/ops/test_host_backup_runner.sh`
- Test: `tests/ops/test_host_backup_container_contract.sh`
- Test: `tests/devspace/test_backup_pipeline_contract.sh`
- Modify: `devspace.yaml`
- Modify: `docs/superpowers/runbooks/devspace-staging-and-backup.md`

- [ ] **Step 1: Reuse the older failing host-pull test first**

Carry over the older contract test for `kubectl exec ... tar ... | tar ...` plus `restic backup`.

- [ ] **Step 2: Extend the test for freshness/staleness reporting**

Add assertions that:

- fresh staged data reports as fresh;
- stale staged data prints a warning but does not hard-fail by default;
- repeated stale staging still remains warning-only on the next scheduled run;
- pull failure hard-fails;
- `restic` failure hard-fails.

- [ ] **Step 2A: Add failing tests for the host runner options and choose the default**

`tests/ops/test_host_backup_runner.sh` must assert:

- `ops/host-backup/run-devspace-backup.sh --once --env-file <path>` loads the environment file, runs the shared host backup path, and exits non-zero on pull or `restic` failure;
- a stale staging status triggers a warning but not failure;
- two consecutive stale runs still warn without escalating to hard failure by default.

`tests/ops/test_host_backup_container_contract.sh` must assert:

- the container image wraps the same `ops/host-backup/run-devspace-backup.sh` entrypoint;
- the cron file schedules `30 * * * *`;
- the runner writes logs under the host state root instead of the repo.

- [ ] **Step 2B: Add a failing manual-backup pipeline contract test**

`tests/devspace/test_backup_pipeline_contract.sh` must assert:

- `devspace run-pipeline backup` exists in phase 2;
- the pipeline dispatches to the shared host backup contract used by `ops/host-backup/run-devspace-backup.sh`;
- backup reports fresh-or-stale status;
- backup hard-fails on pull or `restic` failure.

- [ ] **Step 3: Run RED**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/ops/test_host_backup_runner.sh
bash tests/ops/test_host_backup_container_contract.sh
bash tests/devspace/test_backup_pipeline_contract.sh
```

Expected: fail because the host backup script and runner sources do not exist yet.

- [ ] **Step 4: Implement the reused host-pull core plus freshness checks**

Implementation contract:

- the host-side script remains the only component that touches the `restic` repository;
- freshness is computed from the persistent status artifact written by `workspace-staging.sh`;
- stale data warns by default, as required by the approved design.
- the shared host entrypoint is `ops/host-backup/run-devspace-backup.sh` and must be used by both the recommended scheduled runner and manual `--once` execution.
- the recommended scheduled runner is the small containerized cron runner; the runbook may also include a Linux-only user-level systemd timer example as fallback.

- [ ] **Step 5: Wire the manual DevSpace backup command and document the alternating schedule**

The runbook and task implementation must document the staggered phase-2 schedule:

- cluster CronJob stages at minute 0 of every hour (cron: `0 * * * *`);
- host-side scheduled backup runs at minute 30 of every hour (cron: `30 * * * *`);

These cadences ensure staging and backup alternate every 30 minutes (staging at :00, backup at :30).

Do not require agents to install host services. The repo must contain the host-runner source and container assets so humans can deploy the scheduler manually on the host.

- [ ] **Step 6: Run GREEN**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/ops/test_host_backup_runner.sh
bash tests/ops/test_host_backup_container_contract.sh
bash tests/devspace/test_backup_pipeline_contract.sh
```

Expected: pass, including the stale-warning and repeated-stale-warning paths.

- [ ] **Step 7: Commit**

```bash
git add scripts/host-pull-and-restic-backup.sh ops/host-backup/run-devspace-backup.sh ops/host-backup/container/Containerfile ops/host-backup/container/entrypoint.sh ops/host-backup/container/crontab tests/opencode/test_host_pull_and_restic_backup.sh tests/ops/test_host_backup_runner.sh tests/ops/test_host_backup_container_contract.sh tests/devspace/test_backup_pipeline_contract.sh devspace.yaml docs/superpowers/runbooks/devspace-staging-and-backup.md
git commit -m "feat(backup): add scheduled host runner and restic snapshot flow"
```

### Task 10: Recover exported sessions newest-first and document the restore path

**Why last:** Recovery proves that the phase-2 artifacts are useful, not just collectible.

**Acceptance:** L1-L4.

**Reuse source:** older Task 9 is reused without contract changes.

**Files:**
- Create: `scripts/recover-opencode-sessions.sh`
- Test: `tests/opencode/test_recover_opencode_sessions.sh`
- Modify: `docs/superpowers/runbooks/devspace-staging-and-backup.md`

- [ ] **Step 1: Carry over the older failing recovery test first**

Keep the same mocked `opencode import` contract:

- newest export wins per session id;
- duplicate older exports are skipped;
- restore order is newest-first.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected: fail because the recovery script does not exist yet.

- [ ] **Step 3: Implement the reused recovery contract**

Implementation contract is unchanged from the older plan.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/recover-opencode-sessions.sh tests/opencode/test_recover_opencode_sessions.sh docs/superpowers/runbooks/devspace-staging-and-backup.md
git commit -m "feat(opencode): recover newest durable session exports"
```

---

## Phase-2 verification and rollback checklist

Before claiming phase 2 complete, run:

```bash
bash tests/opencode/test_export_all_sessions.sh
bash tests/opencode/test_prepare_state_backup_set.sh
bash tests/opencode/test_workspace_staging.sh
bash tests/devspace/test_staging_cronjob_contract.sh
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/ops/test_host_backup_runner.sh
bash tests/ops/test_host_backup_container_contract.sh
bash tests/opencode/test_recover_opencode_sessions.sh
devspace run-pipeline staging
devspace run-pipeline backup
bash ops/host-backup/run-devspace-backup.sh --once --env-file "$HOME/.config/devspace-bare-hub/backup.env"
git diff --check
```

Expected:

- all shell tests print `PASS`;
- manual `staging` produces `state/backup/staging/latest.log` and `latest.json`;
- manual `backup` reports fresh-or-stale status and, when dependencies are healthy, a successful `restic` snapshot;
- the host runner `--once` path succeeds with the same shared script used by the scheduler;
- repeated stale staging remains warning-only by default;
- `git diff --check` prints no output.

Phase-2 rollback order:

1. Disable or remove the staging CronJob manifest.
2. Stop the host-side scheduled backup job.
3. Revert phase-2 commits in reverse order.
4. Keep the last known-good staged set and `restic` snapshots; these are additive artifacts and should not be deleted during rollback unless the human explicitly asks.

---

## Risks, migration notes, and retained assumptions

### Differences from the older plan

1. **Primary bootstrap moved from host-first to in-pod provision.** The older host bootstrap scripts remain useful reference material, but they are not the acceptance path for the DevSpace workspace.
2. **Source of truth moved from host mount to PVC-backed cluster workspace.** The workspace is no longer a mounted host checkout.
3. **Runtime wrapper moved from DevPod to DevSpace.** DevPod-specific docs and persistence checks are intentionally not copied forward.
4. **Phase 2 keeps the same core data contracts, but gains persistent status and freshness reporting.** This is the main functional addition beyond the older backup tasks.

### Retained assumptions

1. The top-level hub root is administrative, not the editable checkout.
2. `main` remains the required primary branch in v1.
3. The top-level dotfiles repo remains the only `/home/vscode` authority.
4. Canonical durable/disposable paths remain:
   - `/workspaces/dotfiles/state/hub/main/`
   - `/workspaces/dotfiles/state/hub/work/<name>/`
   - `/workspaces/dotfiles/state/repos/<repo>/main/`
   - `/workspaces/dotfiles/tmp/...`
5. Host-pull plus `restic` remains the preferred off-cluster backup boundary.

### Main implementation risks

- **DevSpace wrapper drift:** avoid hiding provision inside `devspace dev`; keep the preflight explicit.
- **Repair overreach:** do not let `repair` become destructive or branch-guessing.
- **Child repo authority creep:** keep child repos away from `/home/vscode` ownership.
- **Backup freshness ambiguity:** the status file/log written by `workspace-staging.sh` is the single source of truth for stale/fresh reporting.

---

## Pragmatic-programmer quick diagnostic

Score: **8.5/10**

Remaining remediation tasks to reach 10/10:

1. Keep `scripts/lib/hub-repo-core.sh` tiny so the public scripts stay explicit.
2. Resist adding configurable bootstrap refs or private-repo auth before a new approved spec requires them.
3. After phase 1 lands, consider retiring or clearly labeling the older DevPod-specific runbooks to reduce future drift.
