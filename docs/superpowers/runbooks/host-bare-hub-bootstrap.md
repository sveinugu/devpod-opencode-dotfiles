# Host Bare-Hub Bootstrap

Run this on the host from a normal dotfiles checkout before DevPod starts.

Set `HUB_PATH` to your host-managed hub directory before running commands.

```bash
export HUB_PATH="/srv/devpod-workspaces/dotfiles"
```

## Step 1 (HOST): Create the managed hub

Mode note for this step:

- Use `--mode host` when validating host permissions and ownership semantics.
- `--mode auto` is the default and auto-detects container markers.
- For host bootstrap, keep `--mode host` explicit.
- Script help: `bash "./scripts/setup-host-bare-hub.sh" --help` (usage line shows `--github-user-name`, `--github-user-email`, and `--fetch-origin`).

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "$HUB_PATH" --mode host
```

Credential behavior during bootstrap:

- Prompt shown: `Use existing git username/email? Y/N`
- `Y`: keep current repo identity settings as-is.
- `N`: script prompts for GitHub username/email and writes them into hub git config.
- Optional non-interactive override: pass `--github-user-name` and `--github-user-email`.

Expected output:

```text
ok: ensured host bare-hub layout at /srv/devpod-workspaces/dotfiles
```

The script writes `.git` at `$HUB_PATH/.git` with `gitdir: ./.bare`, so host and pod workflows can use the hub-local git metadata without repeatedly passing `--git-dir`.

The script also sets `remote.origin.fetch` to `+refs/heads/*:refs/remotes/origin/*` inside `$HUB_PATH/.bare/config` and can optionally fetch with `--fetch-origin yes`.

Identity and fetch settings are stored in the hub-managed git config (`$HUB_PATH/.bare/config`), making them reusable from pod-mounted paths.

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

This is a host-side recovery/bootstrap action. Do not run this recreate-main step inside the pod.

```bash
rm -rf "$HUB_PATH/main"
git --git-dir="$HUB_PATH/.bare" worktree add "$HUB_PATH/main" main
```

## Step 5 (HOST): Verify the bootstrap layout

```bash
git --git-dir="$HUB_PATH/.bare" worktree list
ls -ld "$HUB_PATH/state" "$HUB_PATH/state/opencode" "$HUB_PATH/state/opencode/exported_sessions"
```

Optional host convenience helper (avoids repeating `--git-dir` for host bootstrap checks):

```bash
hubgit() { git --git-dir="$HUB_PATH/.bare" "$@"; }
hubgit worktree list
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

Optional pod convenience helper (avoids repeating `--git-dir`):

```bash
podhubgit() { git --git-dir="/workspaces/dotfiles/.bare" "$@"; }
podhubgit worktree list
```

## Step 8 (IN POD): Onboard an additional repo under the hub

Use this pattern to add a new managed repo under `repos/` (example: `myrepo`):

```bash
REPO_NAME="myrepo"
REPO_URL="git@github.com:your-org/myrepo.git"
REPO_HUB="/workspaces/dotfiles/repos/$REPO_NAME"

mkdir -p "$REPO_HUB"
git clone --bare "$REPO_URL" "$REPO_HUB/.bare"
git --git-dir="$REPO_HUB/.bare" worktree add "$REPO_HUB/main" main
git --git-dir="$REPO_HUB/.bare" worktree add "$REPO_HUB/work/feature-example" -b feature-example main
```

After onboarding, open and work from `"$REPO_HUB/main"` or another explicit worktree path.
