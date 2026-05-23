# Host Bare-Hub Bootstrap

Run this on the host from a normal dotfiles checkout before DevPod starts.

Set `HUB_PATH` to your host-managed hub directory before running commands.

```bash
export HUB_PATH="/srv/devpod-workspaces/dotfiles"
```

## Step 1 (HOST): Create the managed hub

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "$HUB_PATH" --mode host
```

Expected output:

```text
ok: ensured host bare-hub layout at /srv/devpod-workspaces/dotfiles
```

## Step 2 (HOST): Verify bootstrap result

```bash
bash "./scripts/verify-host-bare-hub.sh" --hub-root "$HUB_PATH"
```

Expected verifier result includes:

```text
result: PASS
```

## Step 3 (HOST/DevPod config): Mount in DevPod

Mount `$HUB_PATH` into the container as `/workspaces/dotfiles`.
Open `/workspaces/dotfiles/main` as the workspace folder.

Feature worktrees are a day-to-day development operation and should be created from inside the pod after mount, not during host bootstrap.

## Step 4 (HOST): Recreate main

```bash
rm -rf "$HUB_PATH/main"
git --git-dir="$HUB_PATH/.bare" worktree add "$HUB_PATH/main" main
```

## Step 5 (HOST): Verify the bootstrap layout

```bash
git --git-dir="$HUB_PATH/.bare" worktree list
ls -ld "$HUB_PATH/state" "$HUB_PATH/state/opencode" "$HUB_PATH/state/opencode/exported_sessions"
```

## Step 6 (IN POD): Confirm mounted workspace

Inside the DevPod/container, verify the mounted workspace opens at:

```text
/workspaces/dotfiles/main
```

## Step 7 (IN POD): Create a feature worktree for development

```bash
git --git-dir="/workspaces/dotfiles/.bare" worktree add "/workspaces/dotfiles/work/feature-example" -b feature-example main
```

Run feature worktree creation inside the pod so development branches are managed from the active DevPod workspace context.

### Mode note

Use `--mode host` when validating host permissions and ownership semantics.
`--mode auto` is the default and auto-detects container markers; keep `--mode host` explicit for host bootstrap validation.
