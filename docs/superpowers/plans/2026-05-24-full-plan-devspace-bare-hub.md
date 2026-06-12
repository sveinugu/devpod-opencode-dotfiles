# DevSpace Bare-Hub Workspace Full Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the DevPod-era bare-hub workflow with a DevSpace-managed, PVC-backed workspace while preserving the top-level dotfiles repo as the `/home/vscode` authority, adding DevSpace-managed SSH access, and carrying forward the approved phase-2 staging/backup model.

**Architecture:** Keep DevSpace thin and keep workspace behavior in repo-owned shell scripts. Phase 1 creates one `Deployment` plus one PVC, provisions the top-level bare hub in-pod from `origin/main` (hard requirement for the controlled top-level repo), preserves the top-level dotfiles repo as the only `/home/vscode` authority, and adds DevSpace-managed SSH plus `doctor` / `repair` / `destroy` / child-repo onboarding contracts. Child repos must preserve their exact remote default branch names (dynamic detection). Phase 2 reuses the approved export/staging/host-pull backup contracts from the older bare-hub plan, adapting only the runtime wrappers from DevPod to DevSpace and adding the CronJob, a portable host-runner default, and freshness/status checks required by the new spec.

**Tech Stack:** Bash, Zsh-compatible shell usage, DevSpace, Kubernetes `Deployment`/PVC/CronJob manifests, Git bare repos + worktrees, `kubectl`, `python3`, `opencode`, `tar`, `restic`, GNU coreutils, util-linux `flock`, and an OCI-compatible host runner (`docker`/`podman`/colima-backed runtime) for scheduled host-side backup.

---

## Inputs and approval basis

Primary design spec: docs/superpowers/specs/2026-05-23-devspace-bare-hub-workspace-design.md at commit cc2c89c
Acceptance checklist: docs/superpowers/plans/2026-05-24-acceptance-tests-devspace-bare-hub.md at commit cc2c89c
- Prior plan to reuse where still valid: `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`.
- This document replaces the older plan as the active implementation plan for this feature set, but the older plan remains in the repo for reference and verbatim reuse tracking.

## Purpose

Provide one approved implementation plan for the full DevSpace bare-hub workspace roadmap: phase 1 workspace lifecycle and phase 2 staging/backup. The plan keeps the good parts of the earlier bare-hub-manager work, removes the host-mounted DevPod assumptions that the new design superseded, and gives implementers one ordered path with explicit verification and rollback checkpoints.

## Scope

### In scope for phase 1

- Thin `devspace.yaml` command surface for `dev`, `provision`, `doctor`, `repair`, and `destroy`.
- One Kubernetes `Deployment` and one PVC with two subPath mounts: `/workspaces/dotfiles` and `/home/vscode`.
- DevSpace-managed SSH access using the built-in DevSpace SSH connection instead of a standalone Kubernetes Service.
- In-pod top-level bare-hub provision from the public dotfiles repo using `origin/main` as a hard requirement.
- Local-source `install.sh` behavior and top-level-only `/home/vscode` authority.
- Human-readable, host-side `doctor`; non-destructive `repair`; destructive `destroy`.
- Public child-repo onboarding under `repos/*` using the same bare-hub conventions.
- Managed per-checkout `.envrc` / `.envrc.local` generation with `direnv`, plus an in-pod worktree-creation command.
- Repo-aware convenience navigation commands: `dhub`, `dre`, and `dwt`, with zsh tab completion, simple text `did you mean` hints, no `fzf`, and no implicit fallback when navigation state is missing or ambiguous.

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
- No bespoke shell-wrapper approach for per-worktree environment automation in v1.

---

## Decisions locked by this plan

1. **Manifest layout:** use plain manifests under `k8s/devspace-bare-hub/`, not Helm.
2. **PVC mount model:** one PVC mounted twice with `subPath` entries, once at `/workspaces/dotfiles` and once at `/home/vscode`.
3. **Top-level provision source:** in-pod `git clone --bare` from the top-level dotfiles repo, with `origin/main` as the only supported top-level bootstrap ref in v1.
4. **DevSpace role:** wrappers only; the repo-owned scripts remain authoritative for provision/doctor/repair/add-repo/staging/backup logic.
5. **Shared helper boundary:** extract only the duplicated repo-hub creation logic into `scripts/lib/hub-repo-core.sh`; keep top-level orchestration and child-repo orchestration separate.
6. **Phase sequencing:** finish all phase-1 acceptance items before starting phase-2 CronJob/backup work.
7. **DevSpace SSH shape:** use DevSpace's built-in `ssh` dev connection (`ssh.enabled: true`, `ssh.useInclude: true`) so DevSpace generates keys under `~/.devspace/ssh/`, writes the local SSH alias, and reaches the container through a loopback-only port-forward/tunnel instead of a Kubernetes Service.
8. **Host-runner default:** use a small containerized cron runner under user control as the default scheduled host backup mechanism because it works on the documented macOS/colima and Linux host setups; keep a user-level systemd timer as a Linux-only fallback that invokes the same shared host backup script.
9. **Managed envrc scope:** generate a managed `.envrc` for every managed checkout, including top-level `main/`, each child repo's exact default-branch checkout, and non-`main` worktrees.
10. **Managed envrc exports:** export exactly `HUB_DIR`, `HUB_MAIN_DIR`, `HUB_STATE_DIR`, `HUB_TMP_DIR`, `DYN_REPO_DIR`, `DYN_REPO_DEFAULT_BRANCH`, `DYN_REPO_DEFAULT_DIR`, `DYN_REPO_STATE_DIR`, `DYN_REPO_TMP_DIR`, `DYN_WORKTREE_DIR`, `DYN_WORKTREE_STATE_DIR`, and `DYN_WORKTREE_TMP_DIR`; do not export `DYN_REPO_MAIN_DIR`.
11. **Managed envrc conflict policy:** refuse generation when `.envrc` already exists; create `.envrc.local` when missing; source `.envrc.local` from the managed `.envrc`; and let `.envrc.local` failures surface normally.
12. **User-facing command layout:** use `bin/` for in-pod human commands without `.sh`, `scripts/` for automation entrypoints, `scripts/lib/` for helpers, and `ops/host/` for host-runner sources.
13. **Explicit install-branch override term:** in this plan, an **explicit install-branch override** means a current-run, caller-intended override for branch selection (for example `HUB_INSTALL_BRANCH=<branch> devspace run-pipeline provision` or `repair`, or equivalent direct `install.sh` inputs). Ambient values inherited from managed `.envrc` after sourcing prior `state/hub/etc/install.env` are installed-state context, not an explicit install-branch override.
14. **Installed-branch state contract:** `install.sh` is the authoritative writer of installed-branch state. It must export and persist `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR` to `/workspaces/dotfiles/state/hub/etc/install.env`. It must hard-fail when an explicit install-branch override declares a different branch/dir than the checkout it is running from, but it must not treat stale values inherited from prior `/workspaces/dotfiles/state/hub/etc/install.env` state as such an override; a fresh run from another checkout must replace the previous installed-branch state.
15. **Installed-branch worktree policy:** keep `/workspaces/dotfiles/main` attached to `main` only. When an explicit install-branch override selects a non-`main` branch, provision/repair must ensure a matching worktree exists under `/workspaces/dotfiles/work/<branch-name>` and then run that worktree's `install.sh` instead of repointing `main/`. Without an explicit install-branch override, provision defaults to `main`, while repair first consults current installed-branch state from `state/hub/etc/install.env` and uses that non-`main` worktree when it is still valid.
16. **Navigation command surface:** `dhub` is the canonical install-root resolver name, paired with `dre` and `dwt`. `dhub` is implemented as a shell function in `.config/shell/workspace-navigation.zsh` backed by `scripts/lib/resolve-install-target.sh`; no compatibility alias is shipped in v1. Keep resolver behavior explicit and keep the "no implicit fallback" rule for all navigation commands.
17. **Child default-branch fidelity:** child-repo onboarding and related tooling must detect and preserve each child repo's exact remote default branch name instead of normalizing it to `main` or any other fixed branch name.
18. **Top-level primary-branch policy in v1:** top-level provision/repair/doctor/navigation checks are `main`-only for the controlled top-level repo and must fail clearly when `main` is unavailable; no implicit mapping to hub root is allowed.

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
- Create: `tests/devspace/test_ssh_contract.sh`

#### Shared bare-hub core and provision flow
- Create: `scripts/lib/hub-repo-core.sh`
- Create: `scripts/provision-workspace.sh`
- Create: `scripts/preflight-devspace-dev.sh`
- Create: `tests/devspace/test_workspace_provision.sh`
- Create: `tests/devspace/test_devspace_dev_preflight.sh`

#### Install, policy, and docs carried forward from the older plan
- Create: `scripts/lib/validate_install_source_tree.sh`
- Modify: `install.sh`
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Create: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Create: `tests/install/test_install_validate_source.sh`
- Create: `tests/install/test_install_local_source_contract.sh`
- Create: `tests/docs/test_bare_hub_guardrails.sh`

#### Doctor, repair, destroy
- Create: `ops/check-workspace.sh`
- Create: `bin/repair-workspace`
- Create: `ops/destroy-workspace.sh`
- Create: `tests/devspace/test_devspace_doctor.sh`
- Create: `tests/devspace/test_workspace_repair.sh`
- Create: `tests/devspace/test_devspace_destroy.sh`
- Create: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`

#### Child repo onboarding, navigation commands, and worktree environment support
- Create: `bin/clone-repo`
- Create: `bin/new-worktree`
- Note: `dhub` is implemented as a shell function in `.config/shell/workspace-navigation.zsh`, backed by `scripts/lib/resolve-install-target.sh` (no standalone `bin/dhub` executable)
- Create: `bin/dre`
- Create: `bin/dwt`
- Create: `scripts/lib/validate_hub_repo_root.sh`
- Create: `scripts/lib/worktree-env.sh`
- Modify: `scripts/lib/hub-repo-core.sh`
- Modify: `Dockerfile`
- Modify: `.config/shell/workspace-navigation.zsh`
- Modify: `tests/devspace/test_create_hub_repo.sh`
- Modify: `tests/devspace/test_new_worktree.sh`
- Create: `tests/devspace/test_workspace_navigation_commands.sh`
- Create: `tests/install/test_workspace_navigation_shell.sh`
- Modify: `tests/devspace/test_workspace_preinstalled_tools_contract.sh`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`

### Phase 2 — Staging and backup

#### Export and staging core
- Create: `bin/archive-opencode-sessions`
- Create: `scripts/prepare-backup-set.sh`
- Create: `bin/stage-backup`
- Create: `tests/opencode/test_export_all_sessions.sh`
- Create: `tests/opencode/test_prepare_state_backup_set.sh`
- Create: `tests/opencode/test_workspace_staging.sh`

#### CronJob and DevSpace wrappers
- Modify: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/staging-cronjob.yaml`
- Create: `tests/devspace/test_staging_cronjob_contract.sh`

#### Host pull, backup, recovery, and runbooks
- Create: `ops/host/lib/backup-workspace.sh`
- Create: `ops/host/run-workspace-backup.sh`
- Create: `ops/host/backup-runner/Containerfile`
- Create: `ops/host/backup-runner/entrypoint.sh`
- Create: `ops/host/backup-runner/crontab`
- Create: `bin/restore-opencode-sessions`
- Create: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Create: `tests/opencode/test_host_backup_runner_contract.sh`
- Create: `tests/opencode/test_stale_staging_behavior.sh`
- Create: `tests/ops/test_host_backup_container_contract.sh`
- Create: `tests/devspace/test_backup_pipeline_contract.sh`
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
bin/                                            # in-pod human commands on PATH
  clone-repo
  dre
  dwt
  new-worktree
  repair-workspace
  stage-backup
  archive-opencode-sessions
  restore-opencode-sessions
scripts/                                        # automation entrypoints called by DevSpace/tests/other scripts
  provision-workspace.sh
  preflight-devspace-dev.sh
  prepare-backup-set.sh
scripts/lib/                                    # sourced helpers only; no direct operator entrypoints
  hub-repo-core.sh
  resolve-install-target.sh
  validate_install_source_tree.sh
  validate_hub_repo_root.sh
  worktree-env.sh
ops/                                            # host-oriented operational entrypoints and assets
  check-workspace.sh
  destroy-workspace.sh
  host/
    run-workspace-backup.sh
    lib/
      backup-workspace.sh
    backup-runner/
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

- `bin/` holds in-pod human commands, has no `.sh` suffix, and favors distinct first letters when practical.
- `scripts/` holds automation entrypoints and keeps `.sh` suffixes.
- `scripts/lib/` holds sourced helpers and validation helpers, not direct operator entrypoints.
- `ops/` holds host-oriented operational entrypoints; `ops/host/backup-runner/` contains the local host backup container contents.
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
bash tests/devspace/test_ssh_contract.sh
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
- `provision` creates the top-level bare hub and runs `<bootstrap-branch>/install.sh` from fixed top-level probing (`main` only);
- `devspace dev` opens the interactive workflow without hiding provisioning.

### DevSpace-managed SSH details and verification

This section is the plan-authoritative phase-1 SSH acceptance contract shared by Tasks 1 and 3.

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

This is a repo-owned implementation deliverable under `ops/host-backup/`, not a docs-only note: phase 2 must ship the installable runner source that the human can activate on the host.

Authoritative cadence for the full phase-2 flow:

- staging inside the cluster runs at minute 0 of every hour (cron: `0 * * * *`);
- the host-side backup runner runs at minute 30 of every hour (cron: `30 * * * *`).

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
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
$CONTAINER_RUNTIME logs devspace-bare-hub-backup | tail -n 20
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
| B. Provisioning behavior | Tasks 3, 2, 5c | top-level bare clone with `origin/main` bootstrap and install from selected checkout |
| C. Normal startup vs unprovisioned state | Tasks 1, 3, 4 | explicit refusal path before interactive use |
| D. Bare-hub layout and canonical paths | Tasks 3, 5, 5a, 5c | top-level + child repo canonical paths + canonical `work/` navigation + top-level primary-branch compatibility checks |
| E. `/home/vscode`, install behavior, and convenience navigation | Tasks 2, 5a, 5b, 5c | top-level-only authority, local-source install, install-state publication, `dhub` / `dre` / `dwt`, explicit no-fallback primary-branch compatibility |
| F. `doctor` behavior | Task 4 | host-side, human-readable, exit codes 0/1/2 |
| G. `repair` behavior | Task 4 | non-destructive structural recovery only |
| H. `destroy` behavior | Task 4 | delete Deployment/PVC, then reprovision cleanly |
| I. Child repo onboarding | Tasks 5, 5a | public repos only, repo-derived name, detected child default branch, exact branch-name preservation |
| J. Periodic staging | Tasks 7, 8 | staging status + CronJob + manual trigger |
| K. Backup command and host pull | Tasks 8, 9 | `staging` and `backup` pipelines, staging at `0 * * * *`, scheduled host runner at `30 * * * *`, host pull + `restic` |
| L. Backup visibility and recovery signal | Tasks 7, 8, 9 | status file, job logs, stale warning, and deferred-path documentation |
| M. OpenCode session export deliverable | Task 6 (GATED) | separate export deliverable under `state/opencode/exported_sessions/` |
| N. OpenCode session recovery deliverable | Task 10 (GATED) | separate recovery deliverable restoring readable export artifacts plus workflow |

---

## Owners and handoff model

| Task | Plan owner | Execution owner | Planner → implementer handoff point |
| --- | --- | --- | --- |
| 1 | planner | implementer | Start once this plan is approved; no production edits before failing tests exist for command surface + manifests; `destroy` behavior acceptance stays with Task 4 |
| 2 | planner | implementer | Start after Task 1 commit; install/policy contracts must be green before Task 3 invokes `<bootstrap-branch>/install.sh` |
| 3 | planner | implementer | Start after Task 2 commit; this task creates the usable top-level workspace |
| 4 | planner | implementer | Start after Task 3 commit; `doctor` / `repair` / `destroy` depend on a valid provisioned workspace contract |
| 5 | planner | implementer | Start after Task 3 commit; may run after Task 4 if reviewer prefers simpler v1 slices; if starting fresh after this plan update, keep Task 5 and Task 5a on the same branch so the `main`-only child scaffold never ships alone |
| 5a | planner | implementer | Start after Task 5 scaffold is green; complete the child default-branch retrofit and path-resolver contracts before phase-1 signoff |
| 5b | planner | implementer | Start after Task 5a commit; wire the interactive shell wrappers, completion, and docs on top of the resolver behavior |
| 5c | planner | implementer | Start after Task 5b commit; complete top-level primary-branch compatibility checks and remove remaining hard-coded `main` assumptions from phase-1 contracts |
| 6 | planner | implementer | Start only after all phase-1 acceptance items are approved, including Tasks 5a-5c |
| 7 | planner | implementer | Start after Task 6 commit |
| 8 | planner | implementer | Start after Task 7 commit |
| 9 | planner | implementer | Start after Task 8 commit |
| 10 | planner | implementer | Start after Task 9 commit |

Recommended human review gates:

1. After Task 3: manual `provision` + `dev` smoke test.
2. After Task 5b: full phase-1 acceptance review, including child default-branch fidelity plus `dhub` / `dre` / `dwt` interactive checks.
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
| Task 5a — navigation resolvers + child default-branch fidelity | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 5b — zsh wrappers + completion + docs | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 5c — top-level primary-branch compatibility retrofit (`main`, `master`) | 0.25 | 0.5 | 1.0 | 0.5 |
| **Phase 1 subtotal** | **4.75** | **8.5** | **13.5** | **8.7** |
| Task 6 — export sessions | 0.25 | 0.5 | 1.0 | 0.5 |
| Task 7 — staging core + status | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 8 — CronJob + DevSpace staging wrapper | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 9 — host runner + pull + `restic` | 0.5 | 1.0 | 1.5 | 1.0 |
| Task 10 — recovery + backup runbook | 0.25 | 0.5 | 1.0 | 0.5 |
| **Phase 2 subtotal** | **2.0** | **4.0** | **6.5** | **4.0** |

Working estimate: **~8.5 implementation days for phase 1** and **~4 implementation days for phase 2**, excluding human review wait time.

---

## Phase 1 — Core workspace lifecycle

### Task 1: Add the thin DevSpace command surface and workspace manifests

**Why first:** Everything else depends on the workspace object existing in a predictable shape.

**Acceptance:** A1-A6, C1-C3.

**Boundary:** this task owns the DevSpace command surface and SSH wiring surface only; `destroy` behavior acceptance remains owned by Task 4.

**Files:**
- Create: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/workspace-pvc.yaml`
- Create: `k8s/devspace-bare-hub/workspace-deployment.yaml`
- Test: `tests/devspace/test_devspace_command_surface.sh`
- Test: `tests/devspace/test_workspace_manifest_contract.sh`
- Test: `tests/devspace/test_ssh_contract.sh`

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

- [ ] **Step 2A: Write the failing DevSpace-managed SSH acceptance placeholder**

`tests/devspace/test_ssh_contract.sh` should start as a failing contract placeholder and must spell out these exact checks for the Task-1/Task-3 SSH path:

- `devspace.yaml` exposes `ssh.enabled: true`;
- `ssh.useInclude: true` is enabled so DevSpace writes `~/.ssh/devspace_config` entries when supported;
- the expected DevSpace-managed key path is `$HOME/.devspace/ssh/id_devspace_rsa`;
- the local hostname/alias resolves to `workspace.dotfiles.devspace`;
- the SSH path relies on a DevSpace-managed localhost tunnel/port-forward and not on cluster-exposed network reachability;
- no Kubernetes `Service`/NodePort/LoadBalancer is added for SSH because DevSpace reaches the injected SSH helper via local tunnel/port-forward.

The same placeholder must also record the host-side acceptance steps that Task 3 will complete:

1. run `devspace run-pipeline provision`;
2. run `devspace dev` on the host;
3. verify the DevSpace-managed key exists under `~/.devspace/ssh/` and the alias exists in `~/.ssh/devspace_config` or `~/.ssh/config`;
4. run `ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'`;
5. run `ssh -o BatchMode=yes workspace.dotfiles.devspace 'test -d /workspaces/dotfiles/main && printf ok\n'`.

Expected outcomes recorded in the placeholder: the key-handling path is documented, the alias is present, the SSH session reaches the provisioned workspace through the DevSpace-provided tunnel/port-forward, `pwd` prints `/workspaces/dotfiles/main`, the directory check prints `ok`, and no standalone SSH Service exists.

- [ ] **Step 3: Run RED**

Run:

```bash
bash tests/devspace/test_devspace_command_surface.sh
bash tests/devspace/test_workspace_manifest_contract.sh
bash tests/devspace/test_ssh_contract.sh
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
bash tests/devspace/test_ssh_contract.sh
kubectl apply --dry-run=client -f k8s/devspace-bare-hub
```

Expected: tests pass and `kubectl apply --dry-run=client` exits 0.

- [ ] **Step 5A: Manual SSH acceptance check from the host**

Run after `devspace dev` starts on the host:

```bash
test -f "$HOME/.devspace/ssh/id_devspace_rsa"
grep -F "Host workspace.dotfiles.devspace" "$HOME/.ssh/devspace_config" || grep -F "Host workspace.dotfiles.devspace" "$HOME/.ssh/config"
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
git add devspace.yaml k8s/devspace-bare-hub/workspace-pvc.yaml k8s/devspace-bare-hub/workspace-deployment.yaml tests/devspace/test_devspace_command_surface.sh tests/devspace/test_workspace_manifest_contract.sh tests/devspace/test_ssh_contract.sh
git commit -m "feat(devspace): add workspace command surface and manifests"
```

**Rollback:** revert this commit; no PVC contents exist yet.

### Task 2: Carry forward the reusable install and bare-hub guardrail contracts

**Why second:** The new provision flow must run `<bootstrap-branch>/install.sh` (with fixed top-level `main` bootstrap), so the install/policy contract must be correct before Task 3.

**Acceptance:** D1-D4, E1-E4.

**Reuse source:** older Tasks 2, 4, and 5.

**Files:**
- Create: `scripts/lib/validate_install_source_tree.sh`
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

Extend `tests/install/test_install_local_source_contract.sh` so it distinguishes between an explicit install-branch override mismatch supplied for the current run (still RED/fail) and stale `HUB_INSTALL_BRANCH` / `HUB_INSTALL_BRANCH_DIR` values inherited from prior `state/hub/etc/install.env` state through managed `.envrc` (must stay GREEN/succeed and rewrite state).

The behavioral contract must stay the same as the older plan for install source detection and hub-root refusal.

The same task must now also lock the installed-branch publication contract used by later provision/repair flows:

- `install.sh` must derive the branch and checkout directory it is running from;
- `install.sh` must export `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR` for child commands during the install run;
- `install.sh` must persist those same values to `/workspaces/dotfiles/state/hub/etc/install.env`;
- `install.sh` must hard-fail if any explicit install-branch override field (`HUB_INSTALL_BRANCH` and/or `HUB_INSTALL_BRANCH_DIR`) does not match the actual checkout it is running from;
- `install.sh` must not treat stale `HUB_INSTALL_BRANCH` / `HUB_INSTALL_BRANCH_DIR` values inherited from `/workspaces/dotfiles/state/hub/etc/install.env` via managed `.envrc` as explicit install-branch override intent; if the script is started from a different checkout, it must succeed and rewrite installed-branch state to the new checkout;
- `install.sh` must validate explicit branch and explicit directory inputs independently so mixed explicit/inherited cases behave predictably and only explicit mismatches fail;
- if shell helper `dhub` is not already available, `install.sh` should print a recommendation snippet that users may add to their shell config later; the recommended `dhub()` function should print the resolved install directory before changing into it for user convenience; there is no compatibility alias in v1.

This same task must also update user-facing and agent-facing guidance:

- `docs/superpowers/runbooks/devspace-bare-hub-usage.md` must explain the dev/testing/production policy workflow:
  - develop policy in a non-`main` worktree,
  - test workspace-wide with `HUB_INSTALL_BRANCH=<branch> devspace run-pipeline provision` or `repair`,
  - merge to `main` for staging/testing,
  - push `main` to origin for production/default behavior;
- `.config/opencode/AGENTS.md`, `.config/opencode/agents/maestro.md`, and `.config/opencode/agents/senior-implementer.md` must tell agents to prefer `bin/clone-repo` and `bin/new-worktree` over manual `git clone` / `git worktree add` commands once those commands exist.

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
- Add the installed-branch publication file at `state/hub/etc/install.env` and keep it owned by `install.sh`.
- Treat environment-variable presence alone as insufficient evidence of an explicit install-branch override, because managed `.envrc` files auto-source the prior installed-branch state.
- Keep the install-time recommendation message aligned with the approved `dhub` helper name; there is no compatibility alias in v1.
- Add an explicit short "what changed for implementers" note to the touched runbook/agent-policy docs whenever the command names or install-branch behavior differ from the already-landed implementation in this worktree.

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
git add scripts/lib/validate_install_source_tree install.sh .config/opencode/AGENTS.md .config/opencode/agents/maestro.md .config/opencode/agents/senior-implementer.md docs/superpowers/runbooks/devspace-bare-hub-usage.md tests/install/test_install_validate_source.sh tests/install/test_install_local_source_contract.sh tests/docs/test_bare_hub_guardrails.sh
git commit -m "feat(workspace): carry forward install and bare-hub guardrails"
```

**Rollback:** revert this commit; rerun the three tests to confirm the repo is back at the pre-carry-forward state.

### Task 3: Provision the top-level DevSpace workspace as a bare hub

**Why third:** This is the first task that creates a usable workspace and turns the spec into an end-to-end tracer bullet.

**Acceptance:** A1-A6, B1-B8, C1-C3, D1-D4, E1-E4.

**Files:**
- Create: `scripts/lib/hub-repo-core.sh`
- Create: `scripts/provision-workspace.sh`
- Create: `scripts/preflight-devspace-dev.sh`
- Modify: `devspace.yaml`
- Test: `tests/devspace/test_workspace_provision.sh`
- Test: `tests/devspace/test_devspace_dev_preflight.sh`
- Test: `tests/devspace/test_ssh_contract.sh`

- [ ] **Step 1: Write the failing provision tests first**

`tests/devspace/test_workspace_provision.sh` must cover at least these contracts:

- first-time provision from an empty workspace root creates `.bare`, `.git`, top-level bootstrap checkout (`main/`), `work`, `repos`, `state`, and `tmp`;
- top-level bootstrap checkout is attached from the bare repo using `origin/main`;
- canonical top-level paths exist for the selected bootstrap checkout: `state/hub/<bootstrap-branch>/` and `tmp/hub/<bootstrap-branch>/`;
- `<bootstrap-branch>/install.sh` is invoked;
- without an explicit install-branch override, provision installs from the selected top-level bootstrap checkout and publishes matching values to `state/hub/etc/install.env`, even if the invoking checkout inherited a different installed-branch state through managed `.envrc`;
- with an explicit install-branch override selecting a non-bootstrap branch, provision keeps the selected bootstrap checkout attached to its branch, ensures `/workspaces/dotfiles/work/<branch-name>` exists, runs that worktree's `install.sh`, and publishes matching installed-branch state;
- provision derives the install checkout directory from the resolved branch/worktree and ignores ambient `HUB_INSTALL_BRANCH_DIR` as a branch-selection signal;
- provision refuses if `origin/main` does not exist;
- provision refuses if an existing top-level bootstrap checkout path is present in a broken or detached state;
- provision refuses if the requested install branch cannot be materialized as a matching worktree.

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
- `scripts/provision-workspace.sh` remains the public top-level provision entrypoint.
- The top-level provision source is the public dotfiles repo, cloned bare in-pod.
- V1 supports only fixed top-level bootstrap probing (`origin/main`); do not add configurable probe lists.
- The script must create `state/hub/<bootstrap-branch>/` and `tmp/hub/<bootstrap-branch>/` immediately after attaching the selected top-level bootstrap checkout.
- `HUB_INSTALL_BRANCH` replaces the earlier `HUB_PROVISION_BRANCH` behavior and means "which checkout should supply install.sh" only when it is provided as an explicit install-branch override for the current run, not merely inherited from managed `.envrc`.
- without an explicit install-branch override, provision must install from the bootstrap checkout (`main` in v1).
- with an explicit install-branch override naming a non-bootstrap branch, provision must ensure `/workspaces/dotfiles/work/<branch-name>` exists and run `install.sh` from there while leaving the bootstrap checkout attached to its selected branch.
- provision must derive the install checkout directory from the resolved branch/worktree and must not use ambient `HUB_INSTALL_BRANCH_DIR` as a branch-selection input.
- the chosen `install.sh` invocation must write `/workspaces/dotfiles/state/hub/etc/install.env` with `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR`.
- Task 1's SSH placeholder must become a real acceptance path here: once `devspace dev` is active on the host, the DevSpace-managed alias must reach `/workspaces/dotfiles/main` without adding a standalone SSH Service.

- [ ] **Step 4: Wire the DevSpace pipelines**

`devspace run-pipeline provision` must:

1. ensure the Deployment/PVC/pod exist and are running;
2. execute `scripts/provision-workspace.sh` inside the pod;
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

- [ ] **Step 5A: Complete the SSH acceptance path against the provisioned workspace**

Run from the host after `devspace run-pipeline provision` and `devspace dev`:

```bash
bash tests/devspace/test_ssh_contract.sh
test -f "$HOME/.devspace/ssh/id_devspace_rsa"
grep -F "Host workspace.dotfiles.devspace" "$HOME/.ssh/devspace_config" || grep -F "Host workspace.dotfiles.devspace" "$HOME/.ssh/config"
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
ssh -o BatchMode=yes workspace.dotfiles.devspace 'test -d /workspaces/dotfiles/main && printf ok\n'
```

Expected: the SSH contract test passes, the DevSpace-managed key and alias exist locally, `pwd` prints `/workspaces/dotfiles/main`, and the directory check prints `ok` through the DevSpace-managed tunnel/port-forward.

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/hub-repo-core.sh scripts/provision-workspace.sh scripts/preflight-devspace-dev.sh devspace.yaml tests/devspace/test_workspace_provision.sh tests/devspace/test_devspace_dev_preflight.sh
git commit -m "feat(workspace): provision top-level devspace bare hub"
```

**Manual review gate:** human runs `devspace run-pipeline provision` and then `devspace dev` to confirm the default directory is `/workspaces/dotfiles/main`.

The same manual gate must also confirm the Task-1/Task-3 SSH acceptance path with `ssh workspace.dotfiles.devspace`.

**Rollback:** if the PVC contents are untrusted, run `devspace run-pipeline destroy`, then revert this task’s commit.

### Task 4: Add `doctor`, `repair`, and `destroy` with explicit refusal boundaries

**Why fourth:** This closes the operational loop for v1 and resolves the biggest open questions left in the spec.

**Acceptance:** C1-C3, F1-F8, G1-G8, H1-H4.

**Files:**
- Create: `ops/check-workspace.sh`
- Create: `bin/repair-workspace`
- Create: `ops/destroy-workspace.sh`
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
- without an explicit install-branch override, repair inspects existing installed-branch state via `state/hub/etc/install.env` before choosing the install checkout;
- without an explicit install-branch override, repair reinstalls from a valid installed non-`main` worktree when present, otherwise falls back to `main/`;
- with an explicit install-branch override naming a non-`main` branch, repair keeps `main/` on `main`, ensures `/workspaces/dotfiles/work/<branch-name>` exists, and reinstalls from that worktree;
- repair derives the install checkout directory from the resolved branch/worktree and ignores ambient `HUB_INSTALL_BRANCH_DIR` as a branch-selection signal;
- inherited managed-`.envrc` install state does not by itself count as an explicit install-branch override for repair;
- repair must not silently publish contradictory state;
- existing tracked/untracked files and worktrees are not deleted;
- a still-valid non-`main` `/home/vscode` symlink target is preserved;
- invalid `.bare`, ambiguous identity, or conflicting path types cause refusal.

The lifecycle runbook created in this task must also explain:

- how `doctor` reports the installed branch using `state/hub/etc/install.env`;
- how `repair` honors `HUB_INSTALL_BRANCH` without retargeting `main/`;
- how humans can inspect current installed state before asking agents to repair.

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

Expected: fail because the commands/scripts and lifecycle runbook do not exist yet.

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
- without an explicit install-branch override, `repair` must resolve the install checkout from current installed-branch state in `state/hub/etc/install.env` when that state points to a still-valid top-level worktree, otherwise fall back to `main`;
- `repair` may honor `HUB_INSTALL_BRANCH` as an explicit install-branch override, but it must resolve that into a real worktree under `work/` and then run the matching `install.sh`;
- `repair` must derive the install checkout directory from the resolved branch/worktree and must not use ambient `HUB_INSTALL_BRANCH_DIR` as a branch-selection input;
- `repair` must never retarget `/workspaces/dotfiles/main` away from `main`;
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
git add ops/check-workspace.sh bin/repair-workspace ops/destroy-workspace.sh devspace.yaml docs/superpowers/runbooks/devspace-workspace-lifecycle.md tests/devspace/test_devspace_doctor.sh tests/devspace/test_workspace_repair.sh tests/devspace/test_devspace_destroy.sh
git commit -m "feat(workspace): add doctor repair and destroy flows"
```

**Rollback:** revert this commit; if `destroy` semantics are in doubt, verify by running only the tests, not the real destructive pipeline.

### Task 5: Add public child-repo onboarding plus managed per-worktree `.envrc` support

**Why fifth:** It depends on the top-level provision contract and establishes the child repo/worktree scaffold that Tasks 5a-5c immediately retrofit into the final v1 navigation surface.

**Acceptance:** D5, I1-I7, plus the approved per-worktree direnv subtask.

**Reuse source:** older `create-hub-repo.sh` design notes, shared-helper boundary, and the approved direnv notes from `2026-05-21-bare-hub-manager.md` lines 736-746.

**Transitional note:** This task's child-repo `main` assumptions reflect the already-landed scaffold in the current worktree. Final v1 behavior is defined by Tasks 5a, 5b, and 5c below: preserve each child repo's exact remote default branch, keep `dhub`/`dre`/`dwt` with no-implicit-fallback behavior, and enforce top-level `main`-only bootstrap policy. If starting from a fresh branch after this plan update, keep Task 5 and Task 5a on the same implementation branch so the `main`-only child scaffold never ships as an intermediate merge.

**Files:**
- Create: `bin/clone-repo`
- Create: `bin/new-worktree`
- Create: `scripts/lib/validate_hub_repo_root.sh`
- Create: `scripts/lib/worktree-env.sh`
- Modify: `Dockerfile`
- Test: `tests/devspace/test_create_hub_repo.sh`
- Test: `tests/devspace/test_new_worktree.sh`
- Modify: `tests/devspace/test_workspace_preinstalled_tools_contract.sh`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`

- [ ] **Step 1: Write the failing onboarding and worktree-environment tests first**

`tests/devspace/test_create_hub_repo.sh` must assert:

- public repo only in v1;
- repo-derived default name is used for `repos/<name>`;
- `--name` override is rejected or absent in v1; repo-derived naming is the only supported naming path for this phase;
- collisions refuse rather than rename automatically;
- `origin/main` is the only supported source ref;
- successful onboarding creates `repos/<name>/.bare`, `repos/<name>/main`, `repos/<name>/work/`, `state/repos/<name>/main/`, and `tmp/repos/<name>/main/`;
- successful onboarding also creates managed `.envrc` and `.envrc.local` for the child repo `main/` checkout;
- child onboarding does not change `/home/vscode` symlink authority.

`tests/devspace/test_new_worktree.sh` must assert:

- `bin/new-worktree` creates a managed worktree under the repo hub worktree area and the matching canonical `state/` / `tmp/` paths;
- the generated `.envrc` exists for every managed checkout, including top-level `main/`, child-repo `main/`, and non-`main` worktrees;
- generated `.envrc` exports exactly `HUB_DIR`, `HUB_MAIN_DIR`, `HUB_STATE_DIR`, `HUB_TMP_DIR`, `DYN_REPO_DIR`, `DYN_REPO_MAIN_DIR`, `DYN_REPO_STATE_DIR`, `DYN_REPO_TMP_DIR`, `DYN_WORKTREE_DIR`, `DYN_WORKTREE_STATE_DIR`, and `DYN_WORKTREE_TMP_DIR`;
- generated `.envrc` also sources `/workspaces/dotfiles/state/hub/etc/install.env` when present so every checkout sees the current `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR` values without editing each `.envrc` file;
- that inherited installed-state visibility is for navigation and repair-state discovery only; it must not by itself count as an explicit install-branch override or block a later direct `install.sh` run from a different checkout;
- generated `.envrc` sources `.envrc.local` after the managed exports, and `.envrc.local` is auto-created for new managed checkouts;
- generation refuses if `.envrc` already exists;
- `.envrc.local` failures surface normally through direnv instead of being swallowed;
- `direnv` is present in the interactive image, with shell hooks available for bash and zsh.

**Retrofit note for existing Tasks 1-5:** implementers must update any already-landed phase-1 code, tests, docs, and DevSpace wiring that still mention pre-rename paths or the earlier `CUR_*` variable names. In practice this means: Task 1 user-facing docs/command-surface references should match the renamed command layout where surfaced; Task 2 must use `scripts/lib/validate_install_source_tree.sh`; Task 3 must rename the provision/preflight entrypoints to `scripts/provision-workspace.sh` and `scripts/preflight-devspace-dev.sh`; Task 4 must use `ops/check-workspace.sh`, `bin/repair-workspace`, and `ops/destroy-workspace.sh`; and Task 5 must use the final `DYN_*` env var names consistently in generated `.envrc`, tests, docs, and any helper code.

The same retrofit applies to the install-branch override feature: replace `HUB_PROVISION_BRANCH` with `HUB_INSTALL_BRANCH`, stop repointing `main/` to non-`main` branches, ensure non-`main` install sources live under `/workspaces/dotfiles/work/<branch-name>`, and have `install.sh` publish verified installed-branch state to `state/hub/etc/install.env`.

The same retrofit also applies to documentation and agent workflow guidance: update any already-landed docs or agent instructions that still point users/agents toward manual repo/worktree creation, manual branch-switching of `main/`, or older script names. The current implementation handoff must explicitly call out that implementers now need to touch `docs/superpowers/runbooks/devspace-bare-hub-usage.md`, `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`, `.config/opencode/AGENTS.md`, `.config/opencode/agents/maestro.md`, and `.config/opencode/agents/senior-implementer.md` in addition to the shell scripts/tests.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_workspace_preinstalled_tools_contract.sh
```

Expected: fail because the onboarding/worktree commands and helper wiring do not exist yet.

- [ ] **Step 3: Implement the public child-repo and worktree entrypoints**

Implementation contract:

- keep `bin/clone-repo` as the in-pod public child-repo entrypoint;
- add `bin/new-worktree` as the in-pod public worktree-creation entrypoint for both hub and child repos;
- reuse `scripts/lib/hub-repo-core.sh` only for the duplicated repo-hub steps;
- use a shared helper in `scripts/lib/worktree-env.sh` to generate managed `.envrc` and `.envrc.local` files and canonical `state/` / `tmp/` directories for every managed checkout;
- have those generated `.envrc` files source the shared installed-branch state file at `/workspaces/dotfiles/state/hub/etc/install.env` when present;
- `.envrc` generation must refuse when `.envrc` already exists; `.envrc.local` should be created if missing and sourced from `.envrc` with normal error propagation;
- top-level hub `main/` and child-repo `main/` checkouts must receive the same managed env treatment as non-`main` worktrees;
- install `direnv` in the interactive image and expose hooks for bash and zsh;
- keep install-branch filesystem layout independent from branch naming policy: use `/workspaces/dotfiles/work/<branch-name>` even when branch names themselves contain slashes such as `work/devspace-bare-hub`;
- do not add a user-supplied `--name` override in v1;
- keep `/home/vscode` authority exclusively with the top-level dotfiles repo.

The usage runbook updated in this task must explicitly document:

- `bin/clone-repo` and `bin/new-worktree` as the preferred human and agent entrypoints;
- the dev/testing/production policy-promotion idea using `HUB_INSTALL_BRANCH` and install from branch worktrees;
- how `.envrc`, `.envrc.local`, and `state/hub/etc/install.env` interact;
- that `dhub`, `dre`, and `dwt` are the canonical navigation helpers, and why those navigation helpers remain optional shell customization rather than required infrastructure.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_workspace_preinstalled_tools_contract.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add bin/clone-repo bin/new-worktree scripts/lib/validate_hub_repo_root scripts/lib/worktree-env.sh Dockerfile docs/superpowers/runbooks/devspace-bare-hub-usage.md tests/devspace/test_create_hub_repo.sh tests/devspace/test_new_worktree.sh tests/devspace/test_workspace_preinstalled_tools_contract.sh
git commit -m "feat(workspace): add repo onboarding and worktree env commands"
```

**Manual review gate:** human provisions the top-level workspace, adds one public child repo, creates one non-`main` worktree, confirms `~/` links still point into the top-level worktree, and confirms `direnv` exposes the managed variables in both a `main/` checkout and a non-`main` worktree.

**Rollback:** revert this commit and remove any experimental child repo directory from the PVC manually if needed.

### Task 5a: Retrofit child repos to preserve exact default branches and add `bin/` navigation resolvers

**Why now:** Task 5 provides the repo/worktree scaffold, but the current surface still hard-codes child `main` and lacks the agreed navigation contract. This task lands the final v1 child-branch and resolver behavior before phase 2 begins.

**Acceptance:** updated Phase-1 section E navigation items plus section I child-repo default-branch items.

**Files:**
- Create: `bin/dre`
- Create: `bin/dwt`
- Modify: `bin/clone-repo`
- Modify: `bin/new-worktree`
- Modify: `scripts/lib/hub-repo-core.sh`
- Test: `tests/devspace/test_workspace_navigation_commands.sh`
- Modify: `tests/devspace/test_create_hub_repo.sh`
- Modify: `tests/devspace/test_new_worktree.sh`

- [ ] **Step 1: Extend the failing child-repo and navigation tests first**

`tests/devspace/test_create_hub_repo.sh` must now assert:

- child onboarding detects the remote default branch from the source repo and keeps the exact branch name;
- child onboarding creates `repos/<name>/<default-branch>` and matching `state/repos/<name>/<default-branch>/` / `tmp/repos/<name>/<default-branch>/` paths;
- child onboarding refuses if the child default branch cannot be determined or materialized;
- no child onboarding path normalizes the branch name to `main`.

`tests/devspace/test_new_worktree.sh` must now assert:

- non-default child worktrees still live under `repos/<name>/work/<branch>`;
- any repo/worktree helper touched by this task preserves the exact branch name, including slashes, when mapping to the managed `work/` area;
- the `dwt` command contract remains anchored to the canonical `work/` directory and does not guess outside the current repo context.

`tests/devspace/test_workspace_navigation_commands.sh` must assert:

- `bin/dre` and `bin/dwt` exist with no `.sh` suffix;
- `dhub` resolves exactly `$HUB_INSTALL_BRANCH_DIR` (via `.config/shell/workspace-navigation.zsh` + `scripts/lib/resolve-install-target.sh`) and exits non-zero with a clear message when install state is missing, unreadable, or points to a non-directory;
- `bin/dre <repo>` resolves exactly `/workspaces/dotfiles/repos/<repo>` for existing child repos and refuses top-level or hub pseudo-targets;
- `bin/dwt <name>` resolves exactly `work/<name>` inside the current managed repo context and refuses outside that context;
- invalid repo/worktree names print simple non-interactive `did you mean ...` hints when there is a close single match;
- the resolver commands remain text-only and do not require or invoke `fzf`.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_workspace_navigation_commands.sh
```

Expected: fail because the child default-branch retrofit and the navigation resolvers do not exist yet.

- [ ] **Step 3: Implement the resolver and branch-fidelity retrofit**

Implementation contract:

- keep `bin/` as the authoritative home for the new command entrypoints;
- treat `bin/dre` and `bin/dwt` as path resolvers that print one exact destination path on success; `dhub` remains a shell helper backed by `scripts/lib/resolve-install-target.sh`; the interactive shell wrappers that actually `cd` are owned by Task 5b;
- audit `bin/clone-repo`, `bin/new-worktree`, `scripts/lib/hub-repo-core.sh`, and any other touched child-repo helper for `main` assumptions and replace them with detected child default-branch handling;
- preserve exact remote default-branch names; do not normalize `master` or any other name to `main`;
- keep top-level hub bootstrap policy main-only (`origin/main`) with exact branch-name preservation;
- keep the no-implicit-fallback rule: `dhub`, `dre`, and `dwt` must fail clearly instead of guessing a target.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_workspace_navigation_commands.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add bin/dre bin/dwt bin/clone-repo bin/new-worktree scripts/lib/hub-repo-core.sh tests/devspace/test_create_hub_repo.sh tests/devspace/test_new_worktree.sh tests/devspace/test_workspace_navigation_commands.sh
git commit -m "feat(workspace): add navigation resolvers and child branch fidelity"
```

**Manual review gate:** onboard one public repo whose default branch is not `main` (for example `master`), confirm the managed checkout keeps that exact branch name, and confirm the resolver commands print the expected paths and hint text without changing the current shell yet.

### Task 5b: Wire zsh navigation wrappers, completion, and docs for `dhub`, `dre`, and `dwt`

**Why last in phase 1:** After Task 5a defines the authoritative path-resolution behavior, this task makes the commands ergonomic for humans and documents the final v1 shell surface.

**Acceptance:** updated Phase-1 section E navigation items, the additional documentation items, and the requested guardrail/doc updates for the navigation retrofit.

**Files:**
- Modify: `install.sh`
- Modify: `.config/shell/workspace-navigation.zsh`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Test: `tests/install/test_workspace_navigation_shell.sh`
- Modify: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write the failing shell and doc contract tests first**

`tests/install/test_workspace_navigation_shell.sh` must assert:

- `.config/shell/workspace-navigation.zsh` defines `dhub`, `dre`, and `dwt` shell functions that call the matching `bin/` resolver and `cd` only when the resolver succeeds;
- no compatibility alias is installed in v1;
- zsh completion is registered for `dhub`, `dre`, and `dwt`;
- the completion sources candidates from managed repo/worktree state and remains text-only (no `fzf`);
- the install-time recommended helper snippet uses `dhub` only.

`tests/docs/test_bare_hub_guardrails.sh` must now assert:

- the usage and lifecycle runbooks document `dhub`, `dre`, `dwt`, their failure semantics, and the lack of a compatibility alias;
- the navigation docs say `dwt` only works from an existing managed repo context and that `dre` excludes the top-level hub;
- the same docs continue to tell agents and humans to prefer `bin/clone-repo` and `bin/new-worktree`.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/install/test_workspace_navigation_shell.sh
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: fail because the shell wrapper/completion contract and the retrofit docs are not updated yet.

- [ ] **Step 3: Implement the shell wrapper and doc retrofit**

Implementation contract:

- keep the actual `cd` behavior in `.config/shell/workspace-navigation.zsh`, not in a standalone binary, because child processes cannot change the caller's working directory;
- shell wrappers should print the resolved destination before changing directories, matching the old convenience-helper ergonomics;
- register zsh completion for `dhub`, `dre`, and `dwt` inside the repo-managed shell package that `.zshrc` already sources;
- update install guidance so the recommended helper snippet is `dhub` and there is no compatibility alias;
- update the runbooks and guardrail docs/tests to describe the final command surface and the no-implicit-fallback rule.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/install/test_workspace_navigation_shell.sh
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add install.sh .config/shell/workspace-navigation.zsh docs/superpowers/runbooks/devspace-bare-hub-usage.md docs/superpowers/runbooks/devspace-workspace-lifecycle.md tests/install/test_workspace_navigation_shell.sh tests/docs/test_bare_hub_guardrails.sh
git commit -m "feat(shell): add repo navigation wrappers and docs"
```

**Manual review gate:** open a fresh interactive zsh session, confirm `dhub`, `dre`, and `dwt` are available with tab completion, verify they print the destination before changing directories, and verify invalid names emit plain-text hint output without invoking `fzf`.

### Task 5c: Enforce top-level `main` policy and wire canonical `dhub` navigation (no implicit fallback)

**Why now:** The navigation/provision retrofit must explicitly enforce top-level `main` policy for the controlled top-level repo, while keeping child repos default-branch dynamic and preserving explicit no-fallback semantics.

**Acceptance:** updated phase-1 provisioning and navigation behavior where top-level bootstrap/primary-branch assumptions appear.

**Files:**
- Modify: `scripts/provision-workspace.sh`
- Modify: `ops/check-workspace.sh`
- Modify: `bin/new-worktree`
- Modify: `.config/shell/workspace-navigation.zsh`
- Modify: `tests/devspace/test_workspace_provision.sh`
- Modify: `tests/devspace/test_devspace_doctor.sh`
- Modify: `tests/devspace/test_new_worktree.sh`
- Modify: `tests/devspace/test_workspace_navigation_commands.sh`
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`

- [ ] **Step 1: Extend failing tests first**

Update the listed tests to assert:

- top-level provisioning requires `origin/main` and fails clearly if `main` is unavailable;
- child onboarding remains dynamic-default (no forced child-branch normalization);
- `doctor` reports installed-branch state and fails clearly when top-level required paths/state are missing;
- `dhub` remains anchored to installed-branch state (`HUB_INSTALL_BRANCH_DIR`) and navigation helpers keep explicit names without implicit fallback to hub root.
- no compatibility alias exists in v1.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/devspace/test_workspace_provision.sh
bash tests/devspace/test_devspace_doctor.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_workspace_navigation_commands.sh
```

Expected: fail until top-level `main` policy and `dhub`-anchored navigation behavior are implemented consistently.

- [ ] **Step 3: Implement minimal compatibility retrofit**

Implementation contract:

- keep top-level bootstrap `main`-only and fail clearly when `origin/main` is unavailable;
- keep child repos dynamic-default and exact-name preserving;
- keep `dwt` explicit (no hidden aliasing);
- keep `dhub` anchored to installed-branch state (`HUB_INSTALL_BRANCH_DIR`) and fail clearly when state is missing/invalid;
- keep `dhub` as the only install-root helper in v1.
- do not add configurable probe lists, fuzzy pickers, or implicit root fallback.

- [ ] **Step 4: Run GREEN**

Run the same four tests again.

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/provision-workspace.sh ops/check-workspace.sh bin/new-worktree .config/shell/workspace-navigation.zsh tests/devspace/test_workspace_provision.sh tests/devspace/test_devspace_doctor.sh tests/devspace/test_new_worktree.sh tests/devspace/test_workspace_navigation_commands.sh docs/superpowers/runbooks/devspace-bare-hub-usage.md
git commit -m "feat(workspace): enforce top-level main policy and dhub navigation"
```

**Manual review gate:** confirm top-level provisioning fails clearly when `main` is absent, confirm child onboarding succeeds for a public repo whose default branch is not `main`, and confirm navigation remains explicit (no implicit fallback to hub root).

---

## Phase-1 verification and rollback checklist

Before claiming phase 1 complete, run:

```bash
bash tests/devspace/test_devspace_command_surface.sh
bash tests/devspace/test_workspace_manifest_contract.sh
bash tests/devspace/test_ssh_contract.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/docs/test_bare_hub_guardrails.sh
bash tests/devspace/test_workspace_provision.sh
bash tests/devspace/test_devspace_dev_preflight.sh
bash tests/devspace/test_devspace_doctor.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/devspace/test_devspace_destroy.sh
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/install/test_workspace_navigation_shell.sh
bash tests/devspace/test_workspace_preinstalled_tools_contract.sh
devspace run-pipeline provision
devspace run-pipeline doctor
devspace dev
test -f "$HOME/.devspace/ssh/id_devspace_rsa"
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
git diff --check
```

Expected:

- all shell tests print `PASS`;
- `provision` succeeds from an empty or intentionally reset workspace;
- `doctor` returns exit 0 on the healthy workspace;
- `ssh workspace.dotfiles.devspace 'pwd'` prints `/workspaces/dotfiles/main` without a standalone workspace Service;
- `direnv` is available in the interactive environment and the managed `.envrc` variables load for at least one `main/` checkout and one non-`main` worktree;
- child onboarding preserves the exact default branch name for at least one non-`main` public repo fixture;
- top-level bootstrap compatibility uses `main` only and fails clearly when `origin/main` is missing;
- `dhub`, `dre`, and `dwt` work from interactive zsh with completion enabled, print their destinations before changing directories, and fail with plain-text hints instead of implicit fallback when names are wrong;
- `git diff --check` prints no output.

Phase-1 rollback order if the slice must be backed out:

1. Revert the phase-1 commits in reverse order.
2. If the PVC contents are suspect, run `devspace run-pipeline destroy`.
3. Re-run `devspace run-pipeline provision` from the last known-good revision.

---

## Phase 2 — Deferred staging and backup

> **Traceability gate:** The approved spec and acceptance checklist now treat OpenCode session export (section M) and OpenCode session recovery (section N) as separate phase-2 deliverables. Keep Task 6 independently testable from host pull + `restic`, and keep Task 10 independently testable from full workspace rebuild or exact live-session resumability.
>
> **Plan-authoritative schedule lock:** staging at minute 0 of every hour (cron: `0 * * * *`); host-side backup at minute 30 of every hour (cron: `30 * * * *`).

### Task 6: Archive OpenCode sessions into `state/opencode/exported_sessions/`

**Why first in phase 2:** The exported JSON files are the durable source-of-truth artifact for session recovery and downstream backup.

**Acceptance:** M1-M5.

**Reuse source:** older Task 6 is reused without contract changes.

**Files:**
- Create: `bin/archive-opencode-sessions`
- Test: `tests/opencode/test_export_all_sessions.sh`

- [ ] **Step 1: Carry over the older failing test first**

Reuse the older integration/contract test for export behavior, but extend it so the export remains a separate deliverable. The test must assert:

- exported session artifacts are written under `state/opencode/exported_sessions/`;
- export is runnable and verifiable without invoking host-side pull + `restic`;
- export success/failure is visible separately from the general backup flow;
- exported session artifacts remain readable as files after export;
- export only valid sessions;
- remove superseded exports for the same session id;
- leave no temp files behind.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh
```

Expected: fail because `bin/archive-opencode-sessions` does not exist yet.

- [ ] **Step 3: Implement the reused export contract**

Implementation contract:

- keep the older export/dedupe behavior;
- write exported artifacts under `state/opencode/exported_sessions/`;
- keep export as a standalone script path that does not invoke host-side pull or `restic`;
- report export failure distinctly from later host-backup failure paths.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add bin/archive-opencode-sessions tests/opencode/test_export_all_sessions.sh
git commit -m "feat(opencode): export durable session backups"
```

### Task 7: Stage durable state and record persistent staging status

**Why second in phase 2:** The older staging contract is still right, but the new design adds visible persistent status and freshness tracking.

**Acceptance:** J3-J5.

**Reuse source:** older Task 7 for `prepare-state-backup-set.sh`, plus one new wrapper `bin/stage-backup`.

**Files:**
- Create: `scripts/prepare-backup-set.sh`
- Create: `bin/stage-backup`
- Test: `tests/opencode/test_prepare_state_backup_set.sh`
- Test: `tests/opencode/test_workspace_staging.sh`

- [ ] **Step 1: Reuse the older staging-core failing test first**

Carry over the older `tests/opencode/test_prepare_state_backup_set.sh` unchanged for the atomic promotion and busy-file skip behavior.

- [ ] **Step 2: Add one new failing test for the wrapper/status contract**

`tests/opencode/test_workspace_staging.sh` must assert:

- the wrapper runs `archive-opencode-sessions` and `prepare-backup-set.sh` in that order;
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
git add scripts/prepare-backup-set.sh bin/stage-backup tests/opencode/test_prepare_state_backup_set.sh tests/opencode/test_workspace_staging.sh
git commit -m "feat(backup): add staging core and persistent status"
```

### Task 8: Use one staging script for both a CronJob and a manual DevSpace pipeline

**Why third in phase 2:** The design explicitly requires the same staging script for scheduled and manual runs.

**Acceptance:** J1-J2, K2, L2.

**Files:**
- Modify: `devspace.yaml`
- Create: `k8s/devspace-bare-hub/staging-cronjob.yaml`
- Test: `tests/devspace/test_staging_cronjob_contract.sh`
- Modify: `docs/superpowers/runbooks/devspace-staging-and-backup.md`

- [ ] **Step 1: Write the failing CronJob/pipeline test first**

`tests/devspace/test_staging_cronjob_contract.sh` must assert:

- the CronJob invokes `bin/stage-backup`;
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

- the CronJob and manual pipeline both call the same `bin/stage-backup` entrypoint;
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

**Acceptance:** K1, K3-K9, L1-L4.

**Reuse source:** older Task 8, with stale/freshness warnings added.

**Files:**
- Create: `ops/host/lib/backup-workspace.sh`
- Create: `ops/host/run-workspace-backup.sh`
- Create: `ops/host/backup-runner/Containerfile`
- Create: `ops/host/backup-runner/entrypoint.sh`
- Create: `ops/host/backup-runner/crontab`
- Test: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Test: `tests/opencode/test_host_backup_runner_contract.sh`
- Test: `tests/opencode/test_stale_staging_behavior.sh`
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
- pull failure hard-fails;
- `restic` failure hard-fails.

- [ ] **Step 2A: Add a failing test for the installable host-runner contract**

`tests/opencode/test_host_backup_runner_contract.sh` must assert:

- the repo ships an installable host-runner option under `ops/host/` that a human can activate on the host;
- the default install path is the containerized runner using `ops/host/backup-runner/Containerfile`, `entrypoint.sh`, and `crontab`;
- the container cron schedule is `30 * * * *` and runs the shared host backup entrypoint on schedule;
- `ops/host/run-workspace-backup.sh --once --env-file <path>` loads the environment file, runs the shared host pull + `restic` path, and exits non-zero on pull or `restic` failure;
- the Linux-only systemd fallback is documented and invokes the same shared script.

- [ ] **Step 2B: Add a failing repeated-stale warning contract test**

`tests/opencode/test_stale_staging_behavior.sh` must assert:

- a stale staging status triggers a warning but not failure;
- repeated stale staging runs remain warning-only by default and do not escalate to hard failure on later scheduled runs;
- warning records accumulate over time in the status/log outputs so operators can see recurring staleness.

`tests/ops/test_host_backup_container_contract.sh` must assert:

- the container image wraps the same `ops/host/run-workspace-backup.sh` entrypoint;
- the cron file schedules `30 * * * *`;
- the runner writes logs under the host state root instead of the repo.

- [ ] **Step 2C: Add a failing manual-backup pipeline contract test**

`tests/devspace/test_backup_pipeline_contract.sh` must assert:

- `devspace run-pipeline backup` exists in phase 2;
- the pipeline dispatches to the shared host backup contract used by `ops/host/run-workspace-backup.sh`;
- backup reports fresh-or-stale status;
- backup hard-fails on pull or `restic` failure.

- [ ] **Step 3: Run RED**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/opencode/test_host_backup_runner_contract.sh
bash tests/opencode/test_stale_staging_behavior.sh
bash tests/ops/test_host_backup_container_contract.sh
bash tests/devspace/test_backup_pipeline_contract.sh
```

Expected: fail because the host backup script and runner sources do not exist yet.

- [ ] **Step 4: Implement the reused host-pull core plus freshness checks**

Implementation contract:

- the host-side script remains the only component that touches the `restic` repository;
- freshness is computed from the persistent status artifact written by `bin/stage-backup`;
- stale data warns by default, as required by the approved design.
- the shared host entrypoint is `ops/host/run-workspace-backup.sh` and must be used by both the recommended scheduled runner and manual `--once` execution.
- the recommended scheduled runner is the small containerized cron runner shipped under `ops/host/`; the runbook may also include a Linux-only user-level systemd timer example as fallback.
- phase 2 must implement the installable host-runner source in the repo; only activation on the human's host remains manual.

- [ ] **Step 5: Wire the manual DevSpace backup command and document the authoritative schedule**

The runbook and task implementation must document: staging at minute 0 of every hour (cron: `0 * * * *`); host-side backup at minute 30 of every hour (cron: `30 * * * *`).

Do not require agents to install host services. The repo must contain the host-runner source and container assets so humans can deploy the scheduler manually on the host.

- [ ] **Step 6: Run GREEN**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/opencode/test_host_backup_runner_contract.sh
bash tests/opencode/test_stale_staging_behavior.sh
bash tests/ops/test_host_backup_container_contract.sh
bash tests/devspace/test_backup_pipeline_contract.sh
```

Expected: pass, including the stale-warning and repeated-stale-warning paths.

- [ ] **Step 7: Commit**

```bash
git add ops/host/lib/backup-workspace.sh ops/host/run-workspace-backup.sh ops/host/backup-runner/Containerfile ops/host/backup-runner/entrypoint.sh ops/host/backup-runner/crontab tests/opencode/test_host_pull_and_restic_backup.sh tests/opencode/test_host_backup_runner_contract.sh tests/opencode/test_stale_staging_behavior.sh tests/ops/test_host_backup_container_contract.sh tests/devspace/test_backup_pipeline_contract.sh devspace.yaml docs/superpowers/runbooks/devspace-staging-and-backup.md
git commit -m "feat(backup): add scheduled host runner and restic snapshot flow"
```

### Task 10: Recover exported sessions newest-first and document the restore path

**Why last:** Recovery proves that the phase-2 artifacts are useful, not just collectible.

**Acceptance:** N1-N5.

**Reuse source:** older Task 9 is reused without contract changes.

**Files:**
- Create: `bin/restore-opencode-sessions`
- Test: `tests/opencode/test_recover_opencode_sessions.sh`
- Modify: `docs/superpowers/runbooks/devspace-staging-and-backup.md`

- [ ] **Step 1: Carry over the older failing recovery test first**

Keep the older newest-first recovery shape, but align the test to the current recovery deliverable contract:

- newest export wins per session id;
- duplicate older exports are skipped;
- restore order is newest-first;
- restored export artifacts land back under `state/opencode/exported_sessions/`;
- success is measured by readable restored artifacts plus a documented workflow, not by live `opencode import` or exact session resumability.

- [ ] **Step 2: Run RED**

Run:

```bash
bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected: fail because `bin/restore-opencode-sessions` does not exist yet.

- [ ] **Step 3: Implement the reused recovery contract**

Implementation contract:

- restore previously exported session artifacts from backup storage into `state/opencode/exported_sessions/`;
- keep the older newest-first dedupe behavior where multiple exports exist for the same session id;
- document the recovery workflow in `docs/superpowers/runbooks/devspace-staging-and-backup.md`;
- do not require live `opencode import` or exact live-session resumability in v1.

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add bin/restore-opencode-sessions tests/opencode/test_recover_opencode_sessions.sh docs/superpowers/runbooks/devspace-staging-and-backup.md
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
bash tests/opencode/test_host_backup_runner_contract.sh
bash tests/opencode/test_stale_staging_behavior.sh
bash tests/ops/test_host_backup_container_contract.sh
bash tests/devspace/test_backup_pipeline_contract.sh
bash tests/opencode/test_recover_opencode_sessions.sh
devspace run-pipeline staging
devspace run-pipeline backup
bash ops/host/run-workspace-backup.sh --once --env-file "$HOME/.config/devspace-bare-hub/backup.env"
git diff --check
```

Expected:

- all shell tests print `PASS`;
- export leaves readable artifacts under `state/opencode/exported_sessions/` before host-side pull + `restic` runs;
- manual `staging` produces `state/backup/staging/latest.log` and `latest.json`;
- manual `backup` reports fresh-or-stale status and, when dependencies are healthy, a successful `restic` snapshot;
- recovery restores readable exported-session artifacts without requiring exact live-session resumability;
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
4. **Phase 2 keeps the same core data contracts, but gains persistent status/freshness reporting and separate OpenCode export/recovery deliverables.** This is the main functional addition beyond the older backup tasks.

### Retained assumptions

1. The top-level hub root is administrative, not the editable checkout.
2. The top-level hub uses fixed-priority bootstrap compatibility in v1 (`main` only) with exact branch-name preservation; child repos preserve their exact remote default branch names.
3. The top-level dotfiles repo remains the only `/home/vscode` authority.
4. Canonical durable/disposable paths remain:
   - `/workspaces/dotfiles/state/hub/main/`
   - `/workspaces/dotfiles/state/hub/work/<name>/`
   - `/workspaces/dotfiles/state/repos/<repo>/<default-branch>/`
   - `/workspaces/dotfiles/tmp/...`
5. Host-pull plus `restic` remains the preferred off-cluster backup boundary.

### Main implementation risks

- **DevSpace wrapper drift:** avoid hiding provision inside `devspace dev`; keep the preflight explicit.
- **Repair overreach:** do not let `repair` become destructive or branch-guessing.
- **Child repo authority creep:** keep child repos away from `/home/vscode` ownership.
- **Navigation fallback creep:** keep `dhub`, `dre`, and `dwt` explicit; do not reintroduce silent fallback or fuzzy pickers without a new approved spec.
- **Backup freshness ambiguity:** the status file/log written by `bin/stage-backup` is the single source of truth for stale/fresh reporting.

---

## Pragmatic-programmer quick diagnostic

Score: **8.5/10**

Remaining remediation tasks to reach 10/10:

1. Keep `scripts/lib/hub-repo-core.sh` tiny so the public scripts stay explicit.
2. Resist adding configurable top-level bootstrap-ref lists beyond the fixed v1 `main` probe, fuzzy navigation, or private-repo auth before a new approved spec requires them.
3. After phase 1 lands, consider retiring or clearly labeling the older DevPod-specific runbooks to reduce future drift.
