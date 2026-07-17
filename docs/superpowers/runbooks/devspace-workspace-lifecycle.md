# DevSpace Workspace Lifecycle

> What changed for implementers: `dhub` is the install-root navigation helper; child repo default branches must be preserved exactly instead of being normalized to `main`.

## Choose your environment

- **HOST:** Stay in this runbook for `devspace run-pipeline provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`.
- **HOST, first-time setup:** If the bare-hub layout does not exist yet, start with [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).
- **POD:** Switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `dhub`, `dre`, `dwt`, `bin/new-worktree`, `bin/clone-repo`, and `bin/retire-worktree`.

## Host lifecycle commands (canonical)

This runbook is the canonical source for host-side DevSpace lifecycle commands. It intentionally routes in-pod install, navigation, and managed worktree details to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) instead of repeating them here.

## Provision

Run the full provision + connect sequence from the host:

```bash
devspace run-pipeline provision
devspace dev
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
devspace run-pipeline verify-ssh
```

To force tool refresh during provision (pyenv + opencode):

```bash
devspace run-pipeline provision --refresh-tools
HUB_PROVISION_ARGS='--refresh-tools' devspace run-pipeline provision
```

To provision using a non-`main` install checkout via environment override:

```bash
HUB_INSTALL_BRANCH=feature/env-override devspace run-pipeline provision
```

If `HUB_INSTALL_BRANCH` is not set, provision defaults to `main`.

## Provider enablement manifest (single source of truth)

Canonical host-local enablement manifest path:

```text
/workspaces/dotfiles/state/hub/etc/provider-enablement.json
```

This file is the single source of truth for provider enablement in the repo-supported secure path.

Contract:

- generated runtime configuration and verification output must both match this manifest exactly
- provider policy updates (for example `.config/opencode/provider-policy.jsonc`) and enablement selections must stay consistent
- if manifest, generated runtime config, and verification output drift, pause and correct before treating the slice as complete

Generated artifacts for this contract:

```text
/workspaces/dotfiles/state/hub/etc/provider-runtime.json
/workspaces/dotfiles/state/hub/etc/provider-verification.json
```

Install-branch generated runtime artifacts (used by wrapped `opencode`):

```text
/workspaces/dotfiles/main/.config/opencode/provider-runtime.json
/workspaces/dotfiles/main/.config/opencode/provider-verification.json
```

Canonical sync command:

```bash
/workspaces/dotfiles/main/bin/sync-provider-enablement
```

Bootstrap guardrail for first-time provision:

- if `/workspaces/dotfiles/state/hub/etc/provider-enablement.json` is missing, provision seeds it from `/workspaces/dotfiles/main/.config/opencode/provider-enablement.seed.json`
- if both are missing, provision must fail closed before runtime-provider sync

## Rebuild workspace image

```bash
devspace build
```

Then redeploy:

```bash
devspace deploy
```

If your Kubernetes cluster cannot pull from your local image store, push to a registry and use a registry-qualified image name in `devspace.yaml`.

## Doctor

Run a read-only health checklist from the host:

```bash
devspace run-pipeline doctor
```

Behavior:

- exit `0`: all required checks pass
- exit `1`: one or more required checks failed
- exit `2`: invalid CLI usage

The v1 checklist includes Deployment/PVC presence, pod reachability, top-level bare-hub validity, managed directory existence, canonical `state/hub/main` and `tmp/hub/main` paths, `/home/vscode` symlink targets, and installed-branch reporting from `state/hub/etc/install.env` when present.

## Repair

Run non-destructive structural recovery:

```bash
devspace run-pipeline repair
```

Behavior:

- recreates missing managed directories (`work/`, `repos/`, `state/`, `tmp/`)
- recreates canonical top-level paths (`state/hub/main`, `tmp/hub/main`)
- reattaches `main` only when `.bare` is valid and recognizable
- preserves valid non-`main` `/home/vscode` symlink targets
- resolves install source in this order: explicit `HUB_INSTALL_BRANCH`, then `state/hub/etc/install.env`, then `main`
- keeps `/workspaces/dotfiles/main` attached to `main` even when install source is non-`main`
- refuses when identity is ambiguous, `.bare` is invalid, or managed paths conflict by type

Inspect installed-branch state before repair:

```bash
cat /workspaces/dotfiles/state/hub/etc/install.env
```

`repair` is best-effort and non-destructive; it does not delete existing files or worktrees.

Child repo note: preserve the exact child remote default branch name when reconstructing or validating managed child checkouts.

## Destroy

Run destructive reset:

```bash
devspace run-pipeline destroy
```

Behavior:

- deletes Deployment/pod
- deletes PVC
- does not preserve uncommitted work, runtime session data, or `/home/vscode` content on the deleted PVC

After `destroy`, run `devspace run-pipeline provision` to recreate from scratch.

## After the host step, continue in pod

Once `devspace dev` is open and `/workspaces/dotfiles` is mounted:

- run `bash /workspaces/dotfiles/main/install.sh` from an explicit checkout
- use `dhub`, `dre`, and `dwt` for navigation
- create managed worktrees with `/workspaces/dotfiles/main/bin/new-worktree`
- onboard child repos with `/workspaces/dotfiles/main/bin/clone-repo`
- retire managed worktrees with `/workspaces/dotfiles/main/bin/retire-worktree`

Secure `opencode` launch reminder after install:

```bash
command -v opencode
type -a opencode
```

Expected:

- wrapped path first: `$HOME/.config/opencode/bin/opencode`
- raw path still available only by explicit absolute path (for example `$HOME/.opencode/bin/opencode`)

For those in-pod commands, use [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md). For first-time host layout creation, use [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).

In pod, interactive `new-worktree` / `clone-repo` shell wrappers auto-jump to created checkouts by default; set `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1` to opt out.
