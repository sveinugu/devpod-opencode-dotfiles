# DevSpace Workspace Lifecycle

> What changed for implementers: `dhub` is the install-root navigation helper; child repo default branches must be preserved exactly instead of being normalized to `main`.

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

## In-pod managed repo/worktree commands

Use these in-pod commands for managed repo/worktree setup:

```bash
/workspaces/dotfiles/main/bin/clone-repo https://github.com/<owner>/<repo>.git
/workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
/workspaces/dotfiles/main/bin/new-worktree --repo <child-repo-name> feature/example
```

Example lane-safe creation with explicit lane identity:

```bash
MANAGED_LANE_ID=lane/example /workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
```

Managed checkouts get generated `.envrc` and `.envrc.local`. The managed `.envrc` exports `HUB_*`, `DYN_REPO_*`, and `DYN_WORKTREE_*`, sources `state/hub/etc/install.env` when present, then sources `.envrc.local`.

For interactive navigation, the repo-managed shell package is expected to provide:

- `dhub` for the active install checkout
- `dre <repo>` for child default checkouts (`/workspaces/dotfiles/repos/<repo>/<default-branch>`)
- `dwt` with no argument for current repo default checkout
- `dwt <default-branch-name>` for that same default checkout alias
- `dwt <name>` for switching to `work/<name>` inside the current managed repo context

Navigation guardrails:

- `dhub` prints the destination before changing directories
- `dre` excludes the top-level hub
- `dwt` fails outside managed repo context instead of guessing
- top-level default alias is `main`; child-repo default alias is the exact detected remote default branch name
- invalid names may print a simple text `did you mean ...` hint
- no `dd()` compatibility alias

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

## Managed local retirement

For retiring a managed worktree locally, use:

```bash
/workspaces/dotfiles/main/bin/retire-worktree --repo hub lane/example
/workspaces/dotfiles/main/bin/retire-worktree --repo <child-repo-name> lane/example
```

Recommended flow:

- run `--dry-run` first
- review loss evidence and force-token retry command (if printed)
- rerun with `--force --force-token <token>` only when intentional destructive cleanup is required

remote branch deletion remains out of scope for v1

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
