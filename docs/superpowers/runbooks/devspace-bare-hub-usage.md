# DevSpace Bare Hub Usage

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

If `dd()` is not already available in your shell, `install.sh` prints a recommended helper snippet that prints the resolved install checkout before changing directories.

V1 constraints:

- public source only
- `origin/main` only
- `repos/<name>` is derived from the repo URL/path
- `--name` override is not supported
- collisions refuse (no auto-rename)

Successful onboarding creates:

- `repos/<name>/.bare`
- `repos/<name>/main`
- `repos/<name>/work/`
- `state/repos/<name>/main/`
- `tmp/repos/<name>/main/`

Child onboarding does not change `/home/vscode` symlink authority; top-level dotfiles remains the only authority.
