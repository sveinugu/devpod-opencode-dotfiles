# Host Bare-Hub Bootstrap

This runbook sets up a **bare-repo manager hub + worktree workflow** so your host owns durable git/state layout, while day-to-day development happens in mounted worktrees inside DevPod.

The pattern is inspired by (and thanks to) this article:
https://dev.to/metal3d/git-worktree-like-a-boss-2j1b

In practical terms, after bootstrap you get:

- one managed hub root (admin structure)
- one primary editable worktree (`main`, required)
- a predictable place for feature worktrees (`work/`)
- repo-local durable state paths (`state/`)

Run host steps before DevPod starts, then switch to in-pod steps for ongoing development.

Set `HUB_PATH` to your host-managed hub directory:

```bash
export HUB_PATH="/srv/devpod-workspaces/dotfiles"
```

## Step 1 (HOST): Create the managed hub

Mode guidance:

- Use `--mode host` for host bootstrap/permission enforcement.
- `--mode auto` is available, but explicit `--mode host` is recommended here.
- Help: `bash "./scripts/setup-host-bare-hub.sh" --help`

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "$HUB_PATH" --mode host
```

Username/email behavior during bootstrap:

- Prompt: `Use existing git username/email? Y/N`
- `Y`: keep existing repo identity values
- `N`: prompt for GitHub username/email and store in hub-local git config
- Optional non-interactive override: `--github-user-name` and `--github-user-email`

Expected output:

```text
ok: ensured host bare-hub layout at /srv/devpod-workspaces/dotfiles
```

What this gives you immediately:

- `$HUB_PATH/.git` points to `./.bare` (so normal `git ...` works from hub path)
- fetch refspec is configured in `$HUB_PATH/.bare/config`
- username/email configuration is written in hub-local git config for pod reuse via mounted path
- bootstrap enforces a **main-only** convention: source checkout must have `main`, and hub main worktree is always created from `main`
- bootstrap enforces/repairs `main/install.sh` to mode `700` during host runs

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

Tip: host bootstrap establishes structure; feature branches/worktrees are best created inside the pod where you actively develop.

## Step 4 (HOST): Recreate main (recovery only)

Use this only when you need to rebuild the primary worktree from host side.
Do **not** run this recovery step in pod.

```bash
rm -rf "$HUB_PATH/main"
git -C "$HUB_PATH" worktree add "$HUB_PATH/main" main
```

## Step 5 (HOST): Verify host layout quickly

```bash
git -C "$HUB_PATH" worktree list
ls -ld "$HUB_PATH/state" "$HUB_PATH/state/opencode" "$HUB_PATH/state/opencode/exported_sessions"
```

Optional host helper:

```bash
hubgit() { git -C "$HUB_PATH" "$@"; }
hubgit worktree list
```

## Step 6 (IN POD): Confirm mounted workspace

Inside DevPod/container, confirm you are working from:

```text
/workspaces/dotfiles/main
```

## Step 7 (IN POD): Create a feature worktree

```bash
git -C "/workspaces/dotfiles" worktree add "/workspaces/dotfiles/work/feature-example" -b feature-example main
```

This keeps branch/worktree lifecycle tied to your active development context.

Optional pod helper:

```bash
podhubgit() { git -C "/workspaces/dotfiles" "$@"; }
podhubgit worktree list
```

## Step 8 (IN POD): Onboard an additional repo under `repos/`

Use this when adding another managed repository into the same hub structure.

```bash
REPO_NAME="myrepo"
REPO_URL="git@github.com:your-org/myrepo.git"
REPO_HUB="/workspaces/dotfiles/repos/$REPO_NAME"

mkdir -p "$REPO_HUB"
git clone --bare "$REPO_URL" "$REPO_HUB/.bare"
printf 'gitdir: ./.bare\n' > "$REPO_HUB/.git"

git -C "$REPO_HUB" worktree add "$REPO_HUB/main" main
git -C "$REPO_HUB" worktree add "$REPO_HUB/work/feature-example" -b feature-example main
```

After onboarding, open and work from `"$REPO_HUB/main"` (or another explicit worktree).
