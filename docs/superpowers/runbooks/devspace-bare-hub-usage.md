# DevSpace Bare Hub Usage

> What changed for implementers: `dhub` is the install-checkout helper; child repos keep their exact remote default branch names instead of being normalized to `main`.

## Provision and connect

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

Workflow policy for dev/testing/production behavior changes:

- develop policy in a non-`main` worktree
- test with `HUB_INSTALL_BRANCH=<branch> devspace run-pipeline provision` or `repair`
- merge to `main` for staging/testing
- push `main` to origin for production/default behavior

## Rebuild workspace image

```bash
devspace build -i workspace
```

Then redeploy:

```bash
devspace deploy
```

If your Kubernetes cluster cannot pull from your local image store, push to a registry and use a registry-qualified image name in `devspace.yaml`.

Use `/workspaces/dotfiles/main` as the editable workspace checkout.

## Install usage

```bash
bash /workspaces/dotfiles/main/install.sh --dry-run -y
bash /workspaces/dotfiles/work/feature-example/install.sh --dry-run -y
```

Never run the hub-root copy at `/workspaces/dotfiles/install.sh`; it must refuse with:

```text
Refused — hub-root CWD detected. Provide explicit worktree path.
```

## Child repo onboarding (public repos, v1)

From inside the workspace pod, add a child repo as a managed bare hub under `repos/<name>`:

```bash
/workspaces/dotfiles/main/bin/clone-repo https://github.com/<owner>/<repo>.git
```

Create managed worktrees (top-level hub and child repos):

```bash
/workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
/workspaces/dotfiles/main/bin/new-worktree --repo <child-repo-name> feature/example
```

When creating a lane-safe worktree, keep lane identity distinct from branch naming whenever needed:

```bash
MANAGED_LANE_ID=lane/example /workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
```

For scoped authoring, scoped authoring should not proceed from hub root or unrelated worktrees.

Managed checkout environment behavior:

- each managed checkout gets `.envrc` and `.envrc.local`
- managed `.envrc` exports `HUB_*`, `DYN_REPO_*`, and `DYN_WORKTREE_*` variables
- managed `.envrc` sources `state/hub/etc/install.env` when present
- managed `.envrc` sources `.envrc.local` after managed exports

`install.sh` writes installed-branch state to:

```text
/workspaces/dotfiles/state/hub/etc/install.env
```

## Convenience navigation commands

The repo-managed shell package is the intended home for the interactive wrappers:

- `dhub` → jump to `$HUB_INSTALL_BRANCH_DIR`
- `dre <repo>` → jump to child default checkout at `/workspaces/dotfiles/repos/<repo>/<default-branch>`
- `dwt` with no argument → jump to the current managed repo default checkout
- `dwt <default-branch-name>` → jump to that same default checkout
- `dwt <name>` → jump to `work/<name>` inside the current managed repo context

Behavior notes:

- `dhub` prints the resolved install checkout before changing directories
- `dre` excludes the top-level hub; use it only for child repos under `repos/`
- `dwt` only works from an existing managed repo context and uses the canonical `work/` directory
- for top-level hub, default alias is `main`; for child repos, it is the detected remote default branch name
- invalid names may print a simple text `did you mean ...` hint
- no `dd()` compatibility alias
- no `fzf` integration in v1

## Managed local retirement

Retire lane worktrees with the managed command instead of manual `git worktree remove` + `git branch -D`:

```bash
/workspaces/dotfiles/main/bin/retire-worktree --repo hub lane/example
/workspaces/dotfiles/main/bin/retire-worktree --repo <child-repo-name> lane/example
```

Use `--dry-run` first to inspect potential loss evidence and the force-token retry command when applicable.

## Child repo branch behavior

Child onboarding preserves the child repo's exact remote default branch name. Example: if a child repo defaults to `master`, the managed checkout is `repos/<name>/master`, not `repos/<name>/main`.

V1 constraints:

- public source only
- child repo default branch is detected from the remote and kept exactly as-is
- `repos/<name>` is derived from the repo URL/path
- `--name` override is not supported
- collisions refuse (no auto-rename)

Successful onboarding creates:

- `repos/<name>/.bare`
- `repos/<name>/<default-branch>`
- `repos/<name>/work/`
- `state/repos/<name>/<default-branch>/`
- `tmp/repos/<name>/<default-branch>/`

Child onboarding does not change `/home/vscode` symlink authority; top-level dotfiles remains the only authority.
