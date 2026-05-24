# DevSpace Bare Hub Usage

## Provision and connect

```bash
devspace run-pipeline provision
devspace dev
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
```

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
