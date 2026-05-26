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
- `dre <repo>` → jump to `/workspaces/dotfiles/repos/<repo>`
- `dwt <name>` → jump to `work/<name>` inside the current managed repo context

Behavior notes:

- `dhub` prints the resolved install checkout before changing directories
- `dre` excludes the top-level hub; use it only for child repos under `repos/`
- `dwt` only works from an existing managed repo context and uses the canonical `work/` directory
- invalid names may print a simple text `did you mean ...` hint
- no `dd()` compatibility alias
- no `fzf` integration in v1

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
