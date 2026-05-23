# Host Bare-Hub Bootstrap

Run this on the host from a normal dotfiles checkout before DevPod starts.

## Create the managed hub

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "/srv/devpod-workspaces/dotfiles"
```

Expected output:

```text
ok: ensured host bare-hub layout at /srv/devpod-workspaces/dotfiles
```

## Mount in DevPod

Mount `/srv/devpod-workspaces/dotfiles` into the container as `/workspaces/dotfiles`.
Open `/workspaces/dotfiles/main` as the workspace folder.

## Recreate main

```bash
rm -rf "/srv/devpod-workspaces/dotfiles/main"
git --git-dir="/srv/devpod-workspaces/dotfiles/.bare" worktree add "/srv/devpod-workspaces/dotfiles/main" main
```

## Create a feature worktree

```bash
git --git-dir="/srv/devpod-workspaces/dotfiles/.bare" worktree add "/srv/devpod-workspaces/dotfiles/work/feature-example" -b feature-example main
```

## Verify the layout

```bash
git --git-dir="/srv/devpod-workspaces/dotfiles/.bare" worktree list
ls -ld "/srv/devpod-workspaces/dotfiles/state" "/srv/devpod-workspaces/dotfiles/state/opencode" "/srv/devpod-workspaces/dotfiles/state/opencode/exported_sessions"
```

These checks are the **minimum user validation** for this runbook.

## Advanced/contributor validation (optional)

For contributors or when troubleshooting, run the host bootstrap contract test manually:

```bash
bash tests/bootstrap/test_setup_host_bare_hub.sh
```

Expected output:

```text
PASS test_setup_host_bare_hub
```

This test step is **optional for normal users** following the runbook, but **recommended for contributors** and troubleshooting sessions.

### Linux/GNU tools note

`tests/bootstrap/test_setup_host_bare_hub.sh` assumes Linux/GNU tooling (for example `stat -c` and `readlink -f`).
If you are on macOS, run this test from a Linux environment (for example your DevPod/container) or install GNU equivalents.
