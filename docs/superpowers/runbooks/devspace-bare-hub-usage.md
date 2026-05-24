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
