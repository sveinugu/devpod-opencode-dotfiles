# DevPod OpenCode Dotfiles

Dotfiles, bootstrap scripts, and agent policy for a DevSpace-managed bare-git workspace hub. Use this repo to provision the workspace, apply the in-pod shell/OpenCode setup, and work safely from explicit checkouts such as `/workspaces/dotfiles/main` or `/workspaces/dotfiles/work/<branch>`.

## Start here

Choose the first command based on where you are:

- **Inside the workspace pod:** run `bash install.sh` from `/workspaces/dotfiles/main` or another explicit worktree to apply the dotfiles into `$HOME`.
- **On the host or DevSpace operator side:** run `devspace run-pipeline provision` to create or rebuild the workspace before opening a shell.
- **When the workspace already exists:** use `devspace run-pipeline doctor` for read-only health checks and `devspace run-pipeline repair` for non-destructive structural recovery.

Important guardrails:

- Never work directly from `/workspaces/dotfiles`; it is the bare hub manager root, not a normal checkout.
- Use `/workspaces/dotfiles/main` for the default checkout and `/workspaces/dotfiles/work/<branch>` for feature worktrees.
- Prefer `bin/new-worktree` and `bin/clone-repo` over manual `git worktree add` or `git clone` in the managed workspace.

## Main runbooks

- [DevSpace Bare Hub Usage](docs/superpowers/runbooks/devspace-bare-hub-usage.md) — day-to-day pod usage, install flow, navigation helpers, child repo onboarding, and managed worktree commands.
- [DevSpace Workspace Lifecycle](docs/superpowers/runbooks/devspace-workspace-lifecycle.md) — host-side lifecycle commands such as `provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`.
- [Host Bare-Hub Bootstrap](docs/superpowers/runbooks/host-bare-hub-bootstrap.md) — first-time host bootstrap for the bare-hub + worktree layout before the workspace is mounted into DevPod.

## Key commands

### Host / operator

```bash
devspace run-pipeline provision
devspace run-pipeline doctor
devspace run-pipeline repair
devspace run-pipeline destroy
devspace dev
```

### In-pod setup and navigation

```bash
bash install.sh
bash install.sh --dry-run
dhub
dre <repo>
dwt <branch>
bin/new-worktree --repo hub feature/example
bin/clone-repo https://github.com/<owner>/<repo>.git
```

### Agent / verification

```bash
bash tests/docs/test_p1_docs_orientation.sh
bash tests/devspace/test_devspace_command_surface.sh
bash tests/install/test_install_local_source_contract.sh
```

## Repo layout

- `/workspaces/dotfiles` — bare hub manager root; not an editable checkout
- `/workspaces/dotfiles/main` — default editable checkout
- `/workspaces/dotfiles/work/<branch>` — top-level hub feature worktrees
- `/workspaces/dotfiles/repos/<name>/<default-branch>` — child repo default checkout
- `/workspaces/dotfiles/repos/<name>/work/<branch>` — child repo feature worktrees
- `/workspaces/dotfiles/state/hub/etc/install.env` — persisted install-branch metadata used by shell/workspace helpers

## Agent docs

- [Canonical policy: `.config/opencode/AGENTS.md`](.config/opencode/AGENTS.md)
- [Maestro orchestrator: `.config/opencode/agents/maestro.md`](.config/opencode/agents/maestro.md)
- [Agent configuration directory: `.config/opencode/`](.config/opencode/)
