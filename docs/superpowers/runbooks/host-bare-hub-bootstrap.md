# Host Bare-Hub Bootstrap

## Choose your environment

- **HOST:** Stay in this runbook for first-time bare-hub bootstrap, host-side verification, and recovery-only host actions.
- **POD:** After the mount exists, switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `bin/new-worktree`, `bin/clone-repo`, `dhub`, `dre`, and `dwt`.

This runbook sets up a **bare-repo + worktree** layout where:

- the host owns the hub and durable state
- you do daily coding inside `/workspaces/dotfiles/main` in the pod

The pattern is inspired by (and thanks to) this article:
https://dev.to/metal3d/git-worktree-like-a-boss-2j1b

In practical terms, after bootstrap you get:

- one managed hub root (admin structure)
- one primary editable worktree (`main`, required)
- a predictable place for feature worktrees (`work/`)
- repo-local durable state paths (`state/`)

Run host steps first, then continue in pod for normal development work.

Set `HUB_PATH` to your host-managed hub directory:

```bash
export HUB_PATH="/srv/devpod-workspaces/dotfiles"
```

## Step 1 (HOST): Create the managed hub

Mode guidance:

- Use `--mode host` for host bootstrap and permission enforcement.
- `--mode auto` exists, but `--mode host` is clearer for this step.
- Help: `bash "./scripts/setup-host-bare-hub.sh" --help`

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "$HUB_PATH" --mode host
```

Username/email behavior:

- Prompt: `Use existing git username/email? Y/N`
- `Y`: keep current values
- `N`: enter GitHub username/email and save to hub-local git config
- If needed, pass `--github-user-name` and `--github-user-email`

Expected output:

```text
ok: ensured host bare-hub layout at /srv/devpod-workspaces/dotfiles
```

After Step 1:

- `$HUB_PATH/.git` points to `./.bare` (so normal `git` works from the hub path)
- fetch refspec is configured in `$HUB_PATH/.bare/config`
- username/email configuration is written in hub-local git config for pod reuse via mounted path
- bootstrap enforces a **main-only** convention: source checkout must have `main`, and hub main worktree is always created from `main`
- bootstrap enforces/repairs `main/install.sh` to mode `700` during host runs
- bootstrap resets top-level bare-repo excludes from `scripts/lib/bare-excludes.list` (managed default pattern set)

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

## Wrapper-first day-2 flow

Once the mount exists and you are working inside the pod, prefer the managed wrappers instead of manual `git worktree` / `git clone` commands.

Create a top-level feature worktree:

```bash
/workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
```

Onboard an additional repo under `repos/`:

```bash
/workspaces/dotfiles/main/bin/clone-repo https://github.com/<owner>/<repo>.git
```

Create a managed worktree inside that child repo:

```bash
/workspaces/dotfiles/main/bin/new-worktree --repo <child-repo-name> feature/example
```

For daily in-pod install, navigation, and managed worktree usage, continue with [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md). For host lifecycle commands after bootstrap, continue with [DevSpace Workspace Lifecycle](devspace-workspace-lifecycle.md).

## Host recovery only

Use these host-side commands only when you need to inspect or rebuild the primary host layout.

Recreate `main` from the host:

```bash
rm -rf "$HUB_PATH/main"
cd "$HUB_PATH"
git worktree add "$HUB_PATH/main" main
```

Verify the host layout quickly:

```bash
cd "$HUB_PATH"
git worktree list
ls -ld "$HUB_PATH/state" "$HUB_PATH/state/opencode" "$HUB_PATH/state/opencode/exported_sessions"
```

## Manual fallback (only when wrappers cannot be used)

Do not treat the manual fallback commands below as the default workflow. Keep them as explicit recovery/reference steps for environments where the managed wrappers are unavailable.

Manual in-pod feature worktree creation:

```bash
git worktree add "/workspaces/dotfiles/work/feature-example" -b feature-example main
```

Manual child repo onboarding fallback:

```bash
REPO_NAME="myrepo"
REPO_URL="git@github.com:your-org/myrepo.git"
REPO_HUB="/workspaces/dotfiles/repos/$REPO_NAME"

mkdir -p "$REPO_HUB"
git clone --bare "$REPO_URL" "$REPO_HUB/.bare"
printf 'gitdir: ./.bare\n' > "$REPO_HUB/.git"
REPO_DEFAULT_BRANCH="$(git --git-dir="$REPO_HUB/.bare" symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##')"

cd "$REPO_HUB"
git worktree add "$REPO_HUB/$REPO_DEFAULT_BRANCH" "$REPO_DEFAULT_BRANCH"
git worktree add "$REPO_HUB/work/feature-example" -b feature-example "$REPO_DEFAULT_BRANCH"
```

After using the manual fallback, return to the wrapper-based flow documented in [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md).
