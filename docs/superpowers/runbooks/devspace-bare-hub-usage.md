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

To provision a non-default bootstrap branch via environment override:

```bash
HUB_PROVISION_BRANCH=feature/env-override devspace run-pipeline provision
```

If `HUB_PROVISION_BRANCH` is not set, provision defaults to `main`.

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
bash /workspaces/dotfiles/main/scripts/create-hub-repo.sh https://github.com/<owner>/<repo>.git
```

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
