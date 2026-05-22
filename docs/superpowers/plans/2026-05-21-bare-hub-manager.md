# Bare Hub Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-contained bare-hub manager workflow for dotfiles where the host creates the hub before DevPod starts, editing happens only in explicit worktrees, `install.sh` always uses the local checkout it lives in, and durable OpenCode history is backed up via exported sessions plus repo-local `state/`.

**Architecture:** The dotfiles workspace root is a manager hub, not a normal checkout. The host creates that hub first, then DevPod mounts the host directory and opens `/workspaces/dotfiles/main` as the primary checkout. Durable state is intentionally narrow: `state/`, `state/opencode/exported_sessions/`, and `repos/*/state/`. Backup uses two phases: in-pod export/staging and host-side pull plus `restic`.

**Tech Stack:** Bash, Zsh-compatible shell usage, Git bare repos + worktrees, DevPod/Dev Container config, `opencode` CLI, `python3`, `kubectl`, `tar`, `restic`.

---

## Why this plan exists

This document is intended to become the single self-contained spec + implementation plan for the bare-hub manager workflow. It supersedes the split understanding that currently lives across:

- `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`
- `docs/superpowers/specs/2026-05-21-persistence-security-design.md`
- `docs/superpowers/specs/2026-05-21-opencode-export-and-state-backup-design.md`

The core operating idea comes from the bare-repo + worktree manager pattern described here:

- https://dev.to/metal3d/git-worktree-like-a-boss-2j1b

The important concept is that the hub root is administrative structure, while editing happens in attached worktrees.

For this repository that distinction matters because `/workspaces/dotfiles` is not just “a checkout”. It is a managed tree that contains:

- the top-level dotfiles hub
- the main dotfiles worktree
- feature worktrees
- child repos under `repos/`
- durable local state
- disposable scratch/runtime state

This plan folds in the reviewer findings and the user’s A–F comments:

- **A.** Remove historical “future edit references” from summary-style text and make the plan itself authoritative.
- **B.** Add the full background, intent, worktree/bare-hub concept, dev.to reference, and file structure so the document stands alone.
- **C.** Strengthen the AGENTS and agent-policy work and explicitly reconcile repo policy with the generic `using-git-worktrees` skill.
- **D.** Add host-first bootstrap for creating the bare-cloned dotfiles repo before DevPod starts.
- **E.** Change the install plan so `install.sh` uses its own local checkout as source, fixed targets only, and retains all existing install actions.
- **F.** Add user documentation and runbook work explicitly.

---

## Source-of-truth operating model

### 1. Host-first bootstrap

The initial dotfiles environment must be generated on the **host** before DevPod launches.

The bootstrap script lives in a normal checked-out dotfiles repo on the host:

```text
<host-normal-checkout>/scripts/setup-host-bare-hub.sh
```

That script creates the managed hub layout at a target host path, for example:

```text
<host-workspace-root>/dotfiles/
├── .bare/
├── main/
├── work/
├── repos/
├── state/
│   └── opencode/
│       └── exported_sessions/
└── tmp/
```

DevPod then mounts that **host directory** and the in-container managed path becomes:

```text
/workspaces/dotfiles
```

### 2. Editing happens only in worktrees

For the top-level dotfiles repo:

- hub root: `/workspaces/dotfiles`
- main worktree: `/workspaces/dotfiles/main`
- feature worktrees: `/workspaces/dotfiles/work/<branch>`

For child repos:

- child hub root: `/workspaces/dotfiles/repos/<repo>`
- child main worktree: `/workspaces/dotfiles/repos/<repo>/main`
- child feature worktrees: `/workspaces/dotfiles/repos/<repo>/work/<branch>`

Hub roots are not editable checkouts.

### 3. Durable vs disposable data

Durable:

- `/workspaces/dotfiles/state/`
- `/workspaces/dotfiles/state/opencode/exported_sessions/`
- `/workspaces/dotfiles/repos/*/state/`

Disposable:

- any `tmp/` directory
- `/tmp/backup_staging/`
- OpenCode runtime scratch not intentionally exported or stored in repo-local `state/`

### 4. Installer policy

`install.sh` must:

- autodetect its own real location with `dirname "${BASH_SOURCE[0]}"` plus `readlink -f`
- use the checkout/worktree that the script file itself lives in as the source
- never use the current working directory to choose the source
- use fixed targets under `$HOME`
- retain all current install actions from the existing script:
  - `.zshrc` linking
  - typewritten theme
  - zsh-syntax-highlighting
  - zsh-autosuggestions
  - `.config/opencode` linking
  - `npx -y skills add wondelai/skills/pragmatic-programmer`
  - `npx -y @bybrawe/opencode-loop`
- refuse hub-root execution

That means:

- `~/dotfiles/install.sh` installs from production checkout content
- `/workspaces/dotfiles/main/install.sh` installs from `main`
- `/workspaces/dotfiles/work/<branch>/install.sh` installs from that feature worktree

### 5. Repo-specific agent-policy override

The generic `using-git-worktrees` skill still applies, but this repository adds a stricter repo-specific rule:

- `/workspaces/dotfiles` is a **manager hub**, not a normal checkout
- work must happen in `/workspaces/dotfiles/main` or another explicit worktree
- the same rule applies recursively to child repos under `repos/*`

This repo-specific policy overrides the generic assumption that a repo root can itself be the editable checkout.

---

## File map

### Bootstrap and layout
- Create: `scripts/setup-host-bare-hub.sh`
- Create: `tests/bootstrap/test_setup_host_bare_hub.sh`
- Create: `scripts/devpod-ensure-layout.sh`
- Create: `tests/devpod/test_devpod_ensure_layout.sh`
- Modify: `.devcontainer/devcontainer.json`

### Install safety and install behavior
- Create: `scripts/install-validate-source.sh`
- Create: `tests/install/test_install_validate_source.sh`
- Modify: `install.sh`
- Create: `tests/install/test_install_local_source_contract.sh`

### Agent policy and docs
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Create: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- Create: `docs/superpowers/runbooks/bare-hub-manager-usage.md`
- Create: `docs/superpowers/runbooks/devpod-persistence-verification.md`
- Create: `tests/docs/test_bare_hub_guardrails.sh`

### Durable OpenCode export and backup
- Create: `scripts/opencode-export-all-sessions.sh`
- Create: `tests/opencode/test_export_all_sessions.sh`
- Create: `scripts/prepare-state-backup-set.sh`
- Create: `tests/opencode/test_prepare_state_backup_set.sh`
- Create: `scripts/host-pull-and-restic-backup.sh`
- Create: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Create: `scripts/recover-opencode-sessions.sh`
- Create: `tests/opencode/test_recover_opencode_sessions.sh`
- Create: `docs/superpowers/runbooks/opencode-export-and-state-backup.md`

### Historical-doc reconciliation
- Modify: `docs/superpowers/specs/2026-05-21-persistence-security-design.md`

---

## Preserved verbatim sections from the previous plan

The following sections are preserved verbatim because they were already correct and still align with the current design:

- `docs/superpowers/plans/2026-05-21-bare-hub-manager.md` approx. lines 167-283 — Task 2
- `docs/superpowers/plans/2026-05-21-bare-hub-manager.md` approx. lines 674-848 — Task 6
- `docs/superpowers/plans/2026-05-21-bare-hub-manager.md` approx. lines 1113-1259 — Task 9

---

## Part 1 — Host bootstrap and working layout

### Task 1: Bootstrap the host bare-hub layout before DevPod starts

**Files:**
- Create: `scripts/setup-host-bare-hub.sh`
- Test: `tests/bootstrap/test_setup_host_bare_hub.sh`
- Create: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`

- [ ] **Step 1: Write the failing host-only contract test**

Create `tests/bootstrap/test_setup_host_bare_hub.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Host-only contract test.
# This script is intended to be run on the HOST from inside a normal dotfiles checkout,
# before DevPod starts. The bootstrap script under test must live inside that checkout:
#   <checkout>/scripts/setup-host-bare-hub.sh
# It must derive the source checkout from its own location and therefore must NOT require
# a --source-checkout parameter.

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

checkout="$tmpdir/dotfiles-checkout"
hub_root="$tmpdir/host-workspaces/dotfiles"

mkdir -p "$checkout/.config/opencode" "$checkout/scripts" "$tmpdir/host-workspaces"

printf 'export TEST_ZSHRC=1\n' > "$checkout/.zshrc"
printf '{"ok":true}\n' > "$checkout/.config/opencode/opencode.jsonc"

git init "$checkout" >/dev/null 2>&1
(
  cd "$checkout"
  git add . >/dev/null 2>&1
  git -c user.name='Test User' -c user.email='test@example.com' commit -m 'fixture' >/dev/null 2>&1
)

if [ -f "scripts/setup-host-bare-hub.sh" ]; then
  cp "scripts/setup-host-bare-hub.sh" "$checkout/scripts/setup-host-bare-hub.sh"
  chmod +x "$checkout/scripts/setup-host-bare-hub.sh"
fi

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" >"$tmpdir/out.txt"
)

[ -d "$hub_root/.bare" ]
[ -d "$hub_root/main" ]
[ -d "$hub_root/work" ]
[ -d "$hub_root/repos" ]
[ -d "$hub_root/state/opencode/exported_sessions" ]
[ -d "$hub_root/tmp" ]

state_mode="$(stat -c '%a' "$hub_root/state")"
opencode_mode="$(stat -c '%a' "$hub_root/state/opencode")"
exports_mode="$(stat -c '%a' "$hub_root/state/opencode/exported_sessions")"

[ "$state_mode" = "700" ]
[ "$opencode_mode" = "700" ]
[ "$exports_mode" = "700" ]

git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" >"$tmpdir/out-second.txt"
)

[ -d "$hub_root/.bare" ]
[ -d "$hub_root/main" ]
git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null

grep -F "ok: ensured host bare-hub layout at $hub_root" "$tmpdir/out.txt" >/dev/null

printf 'PASS test_setup_host_bare_hub\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/bootstrap/test_setup_host_bare_hub.sh
```

Expected: FAIL with `./scripts/setup-host-bare-hub.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/setup-host-bare-hub.sh` with logic that:

1. runs on the host from inside a normal dotfiles checkout
2. discovers the checkout root from the script’s own location
3. accepts `--hub-root /abs/path`
4. creates `"$hub_root/.bare"` as a bare clone seeded from the checkout
5. detects the default branch from the source checkout
6. creates `"$hub_root/main"` as a worktree on that branch
7. creates `"$hub_root/work"`, `"$hub_root/repos"`, `"$hub_root/state/opencode/exported_sessions"`, and `"$hub_root/tmp"`
8. sets mode `700` on `state/`, `state/opencode/`, and `state/opencode/exported_sessions/`
9. is idempotent
10. prints `ok: ensured host bare-hub layout at <hub-root>`

- [ ] **Step 4: Write the host bootstrap runbook**

Create `docs/superpowers/runbooks/host-bare-hub-bootstrap.md` documenting:

- that this bootstrap is run on the **host**, not inside DevPod
- the host command to create the hub
- how DevPod must mount the host directory
- how to recreate `main`
- how to create feature worktrees under `work/`

- [ ] **Step 5: Run the test to verify GREEN**

Run:

```bash
bash tests/bootstrap/test_setup_host_bare_hub.sh
```

Expected:

```text
PASS test_setup_host_bare_hub
```

- [ ] **Step 6: Commit**

```bash
git add scripts/setup-host-bare-hub.sh tests/bootstrap/test_setup_host_bare_hub.sh docs/superpowers/runbooks/host-bare-hub-bootstrap.md
git commit -m "feat(bootstrap): add host bare-hub bootstrap"
```

### Task 2: Validate installer source roots and symlink safety

**Files:**
- Create: `scripts/install-validate-source.sh`
- Test: `tests/install/test_install_validate_source.sh`

- [ ] **Step 1: Write the failing integration test**

Create `tests/install/test_install_validate_source.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source_root="$tmpdir/source"
mkdir -p "$source_root"
printf 'ok\n' > "$source_root/install.sh"

./scripts/install-validate-source.sh "$source_root" "$source_root/install.sh" >"$tmpdir/ok.out"
grep -F "ok: validated source path" "$tmpdir/ok.out" >/dev/null

ln -snf /etc/passwd "$source_root/escape"
if ./scripts/install-validate-source.sh "$source_root" "$source_root/escape" >"$tmpdir/escape.out" 2>&1; then
  printf 'expected escape path to fail\n' >&2
  exit 1
fi
grep -F "refused: symlink escapes source root" "$tmpdir/escape.out" >/dev/null

printf 'gitdir: /etc\n' > "$source_root/.git"
if ./scripts/install-validate-source.sh "$source_root" "$source_root/install.sh" >"$tmpdir/gitdir.out" 2>&1; then
  printf 'expected gitdir validation to fail\n' >&2
  exit 1
fi
grep -F "refused: gitdir outside /workspaces/dotfiles" "$tmpdir/gitdir.out" >/dev/null

printf 'PASS test_install_validate_source\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/install/test_install_validate_source.sh
```

Expected: FAIL with `./scripts/install-validate-source.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/install-validate-source.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

source_root="${1:?usage: scripts/install-validate-source.sh SOURCE_ROOT CANDIDATE_PATH}"
candidate_path="${2:?usage: scripts/install-validate-source.sh SOURCE_ROOT CANDIDATE_PATH}"

source_root_abs="$(readlink -f "$source_root")"
candidate_abs="$(readlink -f "$candidate_path")"

case "$candidate_abs" in
  "$source_root_abs"|"$source_root_abs"/*) ;;
  *)
    printf 'refused: symlink escapes source root\n' >&2
    exit 1
    ;;
esac

git_file="$source_root_abs/.git"
if [ -f "$git_file" ]; then
  IFS= read -r gitdir_line < "$git_file"
  case "$gitdir_line" in
    gitdir:*)
      gitdir_path="${gitdir_line#gitdir: }"
      case "$gitdir_path" in
        /*) gitdir_abs="$(readlink -f "$gitdir_path" 2>/dev/null || true)" ;;
        *) gitdir_abs="$(readlink -f "$source_root_abs/$gitdir_path" 2>/dev/null || true)" ;;
      esac
      case "$gitdir_abs" in
        /workspaces/dotfiles/*) ;;
        *)
          printf 'refused: gitdir outside /workspaces/dotfiles\n' >&2
          exit 1
          ;;
      esac
      ;;
  esac
fi

printf 'ok: validated source path %s\n' "$candidate_abs"
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/install/test_install_validate_source.sh
```

Expected:

```text
PASS test_install_validate_source
```

- [ ] **Step 5: Commit**

```bash
git add scripts/install-validate-source.sh tests/install/test_install_validate_source.sh
git commit -m "feat(install): validate source roots before linking"
```

### Task 3: Ensure DevPod opens the main worktree, not the hub root

**Files:**
- Create: `scripts/devpod-ensure-layout.sh`
- Test: `tests/devpod/test_devpod_ensure_layout.sh`
- Modify: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Write a failing integration test**

The test must assert that:

- the managed in-container hub path is `/workspaces/dotfiles`
- `workspaceFolder` is `/workspaces/dotfiles/main`
- the ensure-layout script creates `state/opencode/exported_sessions`, `tmp`, `repos`, and `work`

- [ ] **Step 2: Run it to verify RED**

Run:

```bash
bash tests/devpod/test_devpod_ensure_layout.sh
```

Expected: FAIL because the script/config are not yet aligned to the managed bare-hub layout.

- [ ] **Step 3: Implement the minimal layout support**

- `scripts/devpod-ensure-layout.sh` should ensure the managed directory layout under `/workspaces/dotfiles`
- `.devcontainer/devcontainer.json` must set:
  - `"workspaceFolder": "/workspaces/dotfiles/main"`
  - `"postCreateCommand": "bash scripts/devpod-ensure-layout.sh /workspaces/dotfiles"`

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/devpod/test_devpod_ensure_layout.sh
```

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/devcontainer.json scripts/devpod-ensure-layout.sh tests/devpod/test_devpod_ensure_layout.sh
git commit -m "feat(devpod): open main worktree in managed bare-hub layout"
```

### Task 4: Rewrite `install.sh` so it uses its own checkout as the source

**Files:**
- Modify: `install.sh`
- Test: `tests/install/test_install_local_source_contract.sh`

- [ ] **Step 1: Write the failing contract test**

Create `tests/install/test_install_local_source_contract.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Contract:
# - The managed workspace root in DevPod is /workspaces/dotfiles.
# - install.sh must autodetect its own real location using dirname "${BASH_SOURCE[0]}"
#   plus readlink -f semantics.
# - It must use THE WORKTREE IT LIVES IN as the install source, regardless of PWD.
# - It must refuse hub-root execution.
#
# For isolated execution outside a real DevPod, WORKSPACE_ROOT may be overridden.
# The contract path remains /workspaces/dotfiles.

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="${WORKSPACE_ROOT:-/workspaces/dotfiles}"
target_home="$tmpdir/home"
offcwd="$tmpdir/unrelated-cwd"

mkdir -p \
  "$workspace_root/.bare" \
  "$workspace_root/main/.config/opencode" \
  "$workspace_root/work/feature-x/.config/opencode" \
  "$workspace_root/state" \
  "$target_home" \
  "$offcwd"

printf 'export MAIN_ZSHRC=1\n' > "$workspace_root/main/.zshrc"
printf '{"name":"main"}\n' > "$workspace_root/main/.config/opencode/opencode.jsonc"

printf 'export FEATURE_ZSHRC=1\n' > "$workspace_root/work/feature-x/.zshrc"
printf '{"name":"feature-x"}\n' > "$workspace_root/work/feature-x/.config/opencode/opencode.jsonc"

if [ -f "install.sh" ]; then
  cp "install.sh" "$workspace_root/main/install.sh"
  cp "install.sh" "$workspace_root/work/feature-x/install.sh"
  cp "install.sh" "$workspace_root/install.sh"
  chmod +x "$workspace_root/main/install.sh" "$workspace_root/work/feature-x/install.sh" "$workspace_root/install.sh"
fi

if [ -f "scripts/install-validate-source.sh" ]; then
  mkdir -p "$workspace_root/main/scripts" "$workspace_root/work/feature-x/scripts" "$workspace_root/scripts"
  cp "scripts/install-validate-source.sh" "$workspace_root/main/scripts/install-validate-source.sh"
  cp "scripts/install-validate-source.sh" "$workspace_root/work/feature-x/scripts/install-validate-source.sh"
  cp "scripts/install-validate-source.sh" "$workspace_root/scripts/install-validate-source.sh"
  chmod +x \
    "$workspace_root/main/scripts/install-validate-source.sh" \
    "$workspace_root/work/feature-x/scripts/install-validate-source.sh" \
    "$workspace_root/scripts/install-validate-source.sh"
fi

(
  cd "$offcwd"
  HOME="$target_home" bash "$workspace_root/main/install.sh" --dry-run -y >"$tmpdir/main.out"
)

grep -F "DRY-RUN ln -sfn $workspace_root/main/.zshrc $target_home/.zshrc" "$tmpdir/main.out" >/dev/null
grep -F "DRY-RUN ln -sfn $workspace_root/main/.config/opencode $target_home/.config/opencode" "$tmpdir/main.out" >/dev/null
! grep -F "$workspace_root/work/feature-x/.zshrc" "$tmpdir/main.out" >/dev/null

(
  cd "$offcwd"
  HOME="$target_home" bash "$workspace_root/work/feature-x/install.sh" --dry-run -y >"$tmpdir/feature.out"
)

grep -F "DRY-RUN ln -sfn $workspace_root/work/feature-x/.zshrc $target_home/.zshrc" "$tmpdir/feature.out" >/dev/null
grep -F "DRY-RUN ln -sfn $workspace_root/work/feature-x/.config/opencode $target_home/.config/opencode" "$tmpdir/feature.out" >/dev/null
! grep -F "$workspace_root/main/.zshrc" "$tmpdir/feature.out" >/dev/null

(
  cd "$offcwd"
  if HOME="$target_home" bash "$workspace_root/install.sh" --dry-run -y >"$tmpdir/hub.out" 2>&1; then
    printf 'expected hub-root execution to fail\n' >&2
    exit 1
  fi
)

grep -F "Refused — hub-root CWD detected. Provide explicit worktree path." "$tmpdir/hub.out" >/dev/null

printf 'PASS test_install_local_source_contract\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/install/test_install_local_source_contract.sh
```

Expected: FAIL because the current `install.sh` still uses fixed `~/dotfiles` assumptions and does not enforce the new local-source contract.

- [ ] **Step 3: Write the minimal implementation**

Rewrite `install.sh` so that:

1. it resolves its own real path with `dirname "${BASH_SOURCE[0]}"` plus `readlink -f`
2. it uses that resolved checkout/worktree root as the source root
3. it never uses `pwd` to choose the install source
4. it always writes to fixed targets under `$HOME`
5. it validates source paths through `scripts/install-validate-source.sh`
6. it retains all existing install actions from the current script:
   - `.zshrc` linking
   - typewritten theme
   - zsh-syntax-highlighting
   - zsh-autosuggestions
   - `.config/opencode` linking
   - `npx -y skills add wondelai/skills/pragmatic-programmer`
   - `npx -y @bybrawe/opencode-loop`
7. it supports `--dry-run`
8. it supports `-y` / `--yes`
9. it refuses hub-root execution with:
   - `Refused — hub-root CWD detected. Provide explicit worktree path.`

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/install/test_install_local_source_contract.sh
```

Expected:

```text
PASS test_install_local_source_contract
```

- [ ] **Step 5: Manual verification**

Run:

```bash
(cd ~/dotfiles && ./install.sh --dry-run -y)
(cd /workspaces/dotfiles/main && ./install.sh --dry-run -y)
(cd /workspaces/dotfiles/work/feature-x && ./install.sh --dry-run -y)
```

Expected: each run uses the files from the checkout/worktree where that `install.sh` file lives.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install/test_install_local_source_contract.sh
git commit -m "feat(install): use local worktree sources with fixed targets"
```

### Task 5: Strengthen AGENTS policy, agent descriptions, and user docs

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Create: `docs/superpowers/runbooks/bare-hub-manager-usage.md`
- Create: `docs/superpowers/runbooks/devpod-persistence-verification.md`
- Test: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write the failing grep-level doc test**

The test must require:

- `/workspaces/dotfiles` described as a manager hub, not a normal checkout
- explicit worktree requirement
- child-repo rule under `repos/*`
- the exact hub-root refusal string
- repo-specific override text in `maestro.md` and `senior-implementer.md`
- persistence verification commands in the runbook

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

- [ ] **Step 3: Apply the policy/doc changes**

Append these bullets under `## Subagent delegation (short)` in `.config/opencode/AGENTS.md`:

```md
- Bare-hub manager override for this repo: `/workspaces/dotfiles` is a manager hub, not a normal checkout. Agents MUST treat `/workspaces/dotfiles/main` or another explicit worktree path as the editable repository root, and MUST NOT perform repository edits from `/workspaces/dotfiles` itself.
- Worktree-skill reconciliation: the generic `using-git-worktrees` skill still applies, but in this repo it starts from the existing bare-hub layout instead of inventing a parallel checkout model. For dotfiles and for child repos under `repos/*`, agents must create or reuse worktrees beneath the managed hub (`main`, `work/*`) and must not treat the hub root as the working tree.
- Child-repo rule: repositories under `repos/<name>/` follow the same pattern as the top-level repo: hub root at `repos/<name>/`, editable checkout at `repos/<name>/main` or `repos/<name>/work/<branch>`, and durable local files only under `repos/<name>/state/`.
- Bare-hub refusal string: if CWD is detected to be a hub root, the agent or script must refuse with: `Refused — hub-root CWD detected. Provide explicit worktree path.`
```

Also update:

- `.config/opencode/agents/maestro.md`
- `.config/opencode/agents/senior-implementer.md`

to state the same repo-specific override.

Create user docs covering:

- host bootstrap before DevPod launch
- how DevPod mounts the host directory
- worktree creation and usage
- child-repo layout
- what belongs in `state/` vs `tmp/`
- install usage
- persistence verification

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

- [ ] **Step 5: Commit**

```bash
git add .config/opencode/AGENTS.md .config/opencode/agents/maestro.md .config/opencode/agents/senior-implementer.md docs/superpowers/runbooks/bare-hub-manager-usage.md docs/superpowers/runbooks/devpod-persistence-verification.md tests/docs/test_bare_hub_guardrails.sh
git commit -m "docs(agents): define bare-hub manager worktree policy"
```

---

## Part 2 — Durable OpenCode export and backup

### Task 6: Export OpenCode sessions into `state/opencode/exported_sessions/`

Use `opencode session list --format json` plus `opencode export <session-id>` to materialize durable session-history JSON files under `state/opencode/exported_sessions/`. These exported JSONs are the backup source of truth for OpenCode session recovery. We intentionally do not back up OpenCode internal runtime DB files, caches, lockfiles, or in-memory objects, because those are implementation details rather than stable durable artifacts. Re-export when a session is new, malformed on disk, or newer than its last export.

**Files:**
- Create: `scripts/opencode-export-all-sessions.sh`
- Test: `tests/opencode/test_export_all_sessions.sh`

- [ ] **Step 1: Write the failing integration/contract test**

Create `tests/opencode/test_export_all_sessions.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Mock rationale: CI cannot rely on a real OpenCode session database; this test stubs the CLI boundary only.

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/exports"

cat > "$tmpdir/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = "session" ] && [ "$2" = "list" ] && [ "$3" = "--format" ] && [ "$4" = "json" ]; then
  cat <<'JSON'
[
  {"id":"ses_alpha","title":"First Session","updated":"2026-05-21T21:14:32Z"},
  {"id":"ses_beta","title":"Second Session","updated":"2026-05-21T21:15:32Z"}
]
JSON
  exit 0
fi
if [ "$1" = "export" ] && [ "$2" = "ses_alpha" ]; then
  cat <<'JSON'
{"info":{"id":"ses_alpha","title":"First Session"},"messages":[{"role":"user","content":"hi"}]}
JSON
  exit 0
fi
if [ "$1" = "export" ] && [ "$2" = "ses_beta" ]; then
  printf 'forced export failure for %s\n' "$2" >&2
  exit 1
fi
printf 'unexpected args: %s\n' "$*" >&2
exit 1
EOF

chmod +x "$tmpdir/bin/opencode"

OPENCODE_BIN="$tmpdir/bin/opencode" EXPORT_ROOT="$tmpdir/exports" ./scripts/opencode-export-all-sessions.sh >"$tmpdir/out.txt"

alpha_count="$(find "$tmpdir/exports" -name '*-ses_alpha-*.json' | wc -l | tr -d ' ')"
beta_count="$(find "$tmpdir/exports" -name '*-ses_beta-*.json' | wc -l | tr -d ' ')"
tempfile_count="$(find "$tmpdir/exports" -maxdepth 1 -name '.*' -print | wc -l | tr -d ' ')"

[ "$alpha_count" = "1" ]
[ "$beta_count" = "0" ]
[ "$tempfile_count" = "0" ]

grep -F "exported ses_alpha" "$tmpdir/out.txt" >/dev/null
! grep -F "exported ses_beta" "$tmpdir/out.txt" >/dev/null

printf 'PASS test_export_all_sessions\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh
```

Expected: FAIL with `./scripts/opencode-export-all-sessions.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/opencode-export-all-sessions.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

opencode_bin="${OPENCODE_BIN:-opencode}"
export_root="${EXPORT_ROOT:-/workspaces/dotfiles/state/opencode/exported_sessions}"

mkdir -p "$export_root"

session_list_json="$(mktemp)"
trap 'rm -f "$session_list_json"' EXIT

slugify() {
  python3 - "$1" <<'PY'
import re
import sys
title = sys.argv[1].strip().lower()
title = re.sub(r'[^a-z0-9]+', '-', title).strip('-')
print((title or 'session')[:60])
PY
}

process_session() {
  session_id="$1"
  updated="$2"
  title="$3"
  slug="$(slugify "$title")"
  timestamp="$(date -u +'%Y-%m-%dT%H-%M-%SZ')"
  tmpfile="$(mktemp "$export_root/.${session_id}.XXXXXX.json")"
  cleanup_tmpfile() { [ -n "${tmpfile:-}" ] && [ -f "$tmpfile" ] && rm -f "$tmpfile"; }
  # Preserve any pre-existing RETURN trap so this per-session cleanup does not
  # clobber outer function cleanup installed by the caller.
  prev_return_trap="$(trap -p RETURN 2>/dev/null || true)"
  trap cleanup_tmpfile RETURN
  if "$opencode_bin" export "$session_id" > "$tmpfile" && python3 - "$tmpfile" "$session_id" <<'PY'
import json
import sys
path, session_id = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
if not data.get('info', {}).get('id') == session_id:
    raise SystemExit('invalid export: wrong info.id')
if 'messages' not in data:
    raise SystemExit('invalid export: missing messages')
PY
  then
    rm -f "$export_root"/*-"$session_id"-*.json
    final_path="$export_root/$timestamp-$session_id-$slug.json"
    mv "$tmpfile" "$final_path"
    tmpfile=""
    printf 'exported %s -> %s\n' "$session_id" "$final_path"
  fi
  # Restore the caller's RETURN trap after both success and failure. If there
  # was no previous RETURN trap, clear the trap explicitly.
  if [ -n "$prev_return_trap" ]; then
    eval "$prev_return_trap"
  else
    trap - RETURN
  fi
}

"$opencode_bin" session list --format json > "$session_list_json"

python3 - "$session_list_json" <<'PY' | while IFS=$'\t' read -r session_id updated title; do
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    for item in json.load(fh):
        print(f"{item['id']}\t{item['updated']}\t{item.get('title', 'session')}")
PY
  process_session "$session_id" "$updated" "$title" || true
done
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh
```

Expected:

```text
PASS test_export_all_sessions
```

- [ ] **Step 5: Commit**

```bash
git add scripts/opencode-export-all-sessions.sh tests/opencode/test_export_all_sessions.sh
git commit -m "feat(opencode): export durable session backups"
```

### Task 7: Stage durable state with busy-file preservation and safe promotion

This task explicitly fixes the three reviewer gaps:

1. busy-file retry/skip/report contract
2. no delete window for `current/`
3. clear durable-state semantics aligned to the export-and-backup design

**Files:**
- Create: `scripts/prepare-state-backup-set.sh`
- Test: `tests/opencode/test_prepare_state_backup_set.sh`

- [ ] **Step 1: Write the failing integration/contract test**

Create `tests/opencode/test_prepare_state_backup_set.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Contract:
# - The managed workspace root in DevPod is /workspaces/dotfiles.
# - The default staging root is /tmp/backup_staging.
# - The script must:
#   * exclude tmp/
#   * preserve last-known-good staged copies for busy files
#   * emit a skipped-files report
#   * leave current/ untouched on failure
#
# For isolated execution outside a real DevPod, WORKSPACE_ROOT and STAGING_ROOT may be overridden.
# The contract paths remain /workspaces/dotfiles and /tmp/backup_staging.

tmpdir="$(mktemp -d)"
busy_pid=""
cleanup() {
  if [ -n "$busy_pid" ] && kill -0 "$busy_pid" 2>/dev/null; then
    kill "$busy_pid" 2>/dev/null || true
    wait "$busy_pid" 2>/dev/null || true
  fi
  if [ -e "${workspace_root:-}/state/app/unreadable.txt" ]; then
    chmod 600 "${workspace_root}/state/app/unreadable.txt" 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

workspace_root="${WORKSPACE_ROOT:-/workspaces/dotfiles}"
staging_root="${STAGING_ROOT:-/tmp/backup_staging}"

mkdir -p \
  "$workspace_root/state/opencode/exported_sessions" \
  "$workspace_root/state/app" \
  "$workspace_root/repos/omnipy/state" \
  "$workspace_root/tmp/cache" \
  "$staging_root/current/state/app"

printf 'session-json\n' > "$workspace_root/state/opencode/exported_sessions/export.json"
printf 'new-live-cache\n' > "$workspace_root/state/app/cache.txt"
printf 'repo-state\n' > "$workspace_root/repos/omnipy/state/repo-cache.txt"
printf 'skip-me\n' > "$workspace_root/tmp/cache/debug.log"

printf 'old-staged-cache\n' > "$staging_root/current/state/app/cache.txt"

python3 - "$workspace_root/state/app/cache.txt" <<'PY' &
import sys
import time
path = sys.argv[1]
fh = open(path, "a", encoding="utf-8")
fh.write("writer-open\n")
fh.flush()
time.sleep(8)
fh.close()
PY
busy_pid="$!"

bash scripts/prepare-state-backup-set.sh "$workspace_root" "$staging_root" >"$tmpdir/success.out"

[ -f "$staging_root/current/state/opencode/exported_sessions/export.json" ]
[ -f "$staging_root/current/repos/omnipy/state/repo-cache.txt" ]
[ ! -e "$staging_root/current/tmp/cache/debug.log" ]

grep -F "old-staged-cache" "$staging_root/current/state/app/cache.txt" >/dev/null
! grep -F "new-live-cache" "$staging_root/current/state/app/cache.txt" >/dev/null

[ -f "$staging_root/last-skipped.txt" ]
grep -F "$workspace_root/state/app/cache.txt" "$staging_root/last-skipped.txt" >/dev/null

grep -F "ok: staged backup set at $staging_root/current" "$tmpdir/success.out" >/dev/null

printf 'cannot-read\n' > "$workspace_root/state/app/unreadable.txt"
chmod 000 "$workspace_root/state/app/unreadable.txt"

if bash scripts/prepare-state-backup-set.sh "$workspace_root" "$staging_root" >"$tmpdir/fail.out" 2>&1; then
  printf 'expected staging run to fail when source contains unreadable file\n' >&2
  exit 1
fi

[ -f "$staging_root/current/state/opencode/exported_sessions/export.json" ]
[ -f "$staging_root/current/repos/omnipy/state/repo-cache.txt" ]
grep -F "old-staged-cache" "$staging_root/current/state/app/cache.txt" >/dev/null
[ ! -e "$staging_root/current/tmp/cache/debug.log" ]

printf 'PASS test_prepare_state_backup_set\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/opencode/test_prepare_state_backup_set.sh
```

Expected: FAIL with `./scripts/prepare-state-backup-set.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/prepare-state-backup-set.sh` with logic that:

1. uses default staging root `/tmp/backup_staging`
2. seeds `next/` from `current/`
3. stages only:
   - `/workspaces/dotfiles/state/`
   - `/workspaces/dotfiles/repos/*/state/`
4. excludes every `tmp/` directory
5. refreshes included files individually, not by unsafe whole-tree replacement
6. if a file appears open for write:
   - wait briefly and retry once
   - if still busy, keep the prior `current/` copy inside `next/`
   - record the file in `last-skipped.txt`
7. leaves `current/` untouched if preparation fails
8. promotes the prepared tree only after success, using same-filesystem promotion semantics that do not expose a delete window for `current/`
9. prints:
   - `ok: staged backup set at <staging-root>/current`

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/opencode/test_prepare_state_backup_set.sh
```

Expected:

```text
PASS test_prepare_state_backup_set
```

- [ ] **Step 5: Commit**

```bash
git add scripts/prepare-state-backup-set.sh tests/opencode/test_prepare_state_backup_set.sh
git commit -m "feat(backup): preserve busy files during staging"
```

### Task 8: Add host pull, snapshot backup, and user-facing backup docs

**Files:**
- Create: `scripts/host-pull-and-restic-backup.sh`
- Test: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Create: `docs/superpowers/runbooks/opencode-export-and-state-backup.md`

- [ ] **Step 1: Write the failing contract test**

The test must require:

- host-side pull via `kubectl exec ... tar ...`
- `restic backup` against the pulled `current/` tree
- no in-pod writable mount of the real backup destination

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
```

- [ ] **Step 3: Implement**

- `scripts/host-pull-and-restic-backup.sh` must pull staged data from `/tmp/backup_staging/current`
- the runbook must document:
  - phase A: export + staging
  - phase B: host pull + `restic`
  - restore flow
  - cleanup guidance

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/host-pull-and-restic-backup.sh tests/opencode/test_host_pull_and_restic_backup.sh docs/superpowers/runbooks/opencode-export-and-state-backup.md
git commit -m "feat(backup): add host pull and restic snapshot step"
```

### Task 9: Recover exported sessions newest-first with per-session dedupe

**Files:**
- Create: `scripts/recover-opencode-sessions.sh`
- Test: `tests/opencode/test_recover_opencode_sessions.sh`

- [ ] **Step 1: Write the failing contract test**

Create `tests/opencode/test_recover_opencode_sessions.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Mock rationale: the recovery contract is ordering and dedupe; the test stubs `opencode import` only.

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/exports"

cat > "$tmpdir/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'import %s\n' "$2"
EOF

chmod +x "$tmpdir/bin/opencode"

cat > "$tmpdir/exports/2026-05-21T21-14-32Z-ses_alpha-first.json" <<'EOF'
{"info":{"id":"ses_alpha"},"messages":[{"role":"user","content":"first"}]}
EOF

cat > "$tmpdir/exports/2026-05-21T21-15-32Z-ses_alpha-second.json" <<'EOF'
{"info":{"id":"ses_alpha"},"messages":[{"role":"user","content":"second"}]}
EOF

cat > "$tmpdir/exports/2026-05-21T21-16-32Z-ses_beta-third.json" <<'EOF'
{"info":{"id":"ses_beta"},"messages":[{"role":"assistant","content":"third"}]}
EOF

PATH="$tmpdir/bin:$PATH" ./scripts/recover-opencode-sessions.sh "$tmpdir/exports" >"$tmpdir/out.txt"

grep -F "import $tmpdir/exports/2026-05-21T21-16-32Z-ses_beta-third.json" "$tmpdir/out.txt" >/dev/null
grep -F "import $tmpdir/exports/2026-05-21T21-15-32Z-ses_alpha-second.json" "$tmpdir/out.txt" >/dev/null
if grep -F "2026-05-21T21-14-32Z-ses_alpha-first.json" "$tmpdir/out.txt" >/dev/null; then
  printf 'expected older ses_alpha export to be skipped\n' >&2
  exit 1
fi

printf 'PASS test_recover_opencode_sessions\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected: FAIL with `./scripts/recover-opencode-sessions.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/recover-opencode-sessions.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  printf 'usage: scripts/recover-opencode-sessions.sh <dir-or-json> [more paths...]\n' >&2
  exit 1
fi

tmp_list="$(mktemp)"
tmp_sorted="$(mktemp)"
trap 'rm -f "$tmp_list" "$tmp_sorted"' EXIT

for input_path in "$@"; do
  if [ -d "$input_path" ]; then
    find "$input_path" -type f -name '*.json' -print >> "$tmp_list"
  else
    printf '%s\n' "$input_path" >> "$tmp_list"
  fi
done

sort -r "$tmp_list" > "$tmp_sorted"

python3 - "$tmp_sorted" <<'PY' | while IFS=$'\t' read -r session_id file_path; do
import json
import sys

seen = set()
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    for line in fh:
        path = line.strip()
        if not path:
            continue
        filename = path.rsplit('/', 1)[-1]
        parts = filename.split('-', 3)
        session_id = None
        if len(parts) >= 3 and parts[2].startswith('ses_'):
            session_id = parts[2]
        if session_id is None:
            with open(path, 'r', encoding='utf-8') as fh:
                session_id = json.load(fh)['info']['id']
        if session_id in seen:
            continue
        seen.add(session_id)
        print(f"{session_id}\t{path}")
PY
  opencode import "$file_path"
done
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected:

```text
PASS test_recover_opencode_sessions
```

- [ ] **Step 5: Migration and cleanup**

Run:

```bash
find state/opencode/exported_sessions -type f -name '*.json' | sort
```

Expected: reviewable list of export files before any recovery import is attempted.

- [ ] **Step 6: Commit**

```bash
git add scripts/recover-opencode-sessions.sh tests/opencode/test_recover_opencode_sessions.sh
git commit -m "feat(opencode): recover newest durable session exports"
```

### Task 10: Reconcile the older persistence document and verify the plan text

**Files:**
- Modify: `docs/superpowers/specs/2026-05-21-persistence-security-design.md`

- [ ] **Step 1: Add the superseded/canonical banner**

Add a banner stating that the durable-state and backup model is now governed by this plan.

- [ ] **Step 2: Verify stale wording no longer acts as source of truth**

Run:

```bash
grep -n "Superseded in part" docs/superpowers/specs/2026-05-21-persistence-security-design.md
grep -n "https://dev.to/metal3d/git-worktree-like-a-boss-2j1b" docs/superpowers/plans/2026-05-21-bare-hub-manager.md
grep -n 'dirname "${BASH_SOURCE\[0\]}"' docs/superpowers/plans/2026-05-21-bare-hub-manager.md
grep -n "/tmp/backup_staging" docs/superpowers/plans/2026-05-21-bare-hub-manager.md
grep -n "wait briefly and retry once" docs/superpowers/plans/2026-05-21-bare-hub-manager.md
grep -n "manager hub, not a normal checkout" .config/opencode/AGENTS.md
git diff --check
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-21-persistence-security-design.md docs/superpowers/plans/2026-05-21-bare-hub-manager.md .config/opencode/AGENTS.md .config/opencode/agents/maestro.md .config/opencode/agents/senior-implementer.md
git commit -m "docs(plan): consolidate bare-hub manager spec and implementation plan"
```

---

## Verification-before-completion checklist for the implementer

Before claiming this work complete, run:

```bash
bash tests/bootstrap/test_setup_host_bare_hub.sh
bash tests/devpod/test_devpod_ensure_layout.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/docs/test_bare_hub_guardrails.sh
bash tests/opencode/test_export_all_sessions.sh
bash tests/opencode/test_prepare_state_backup_set.sh
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/opencode/test_recover_opencode_sessions.sh
```

Then run:

```bash
git diff --check
```

---

## Pragmatic-programmer quick diagnostic

Score: **8/10**

Remaining remediation tasks to reach 10/10:

1. Keep the host bootstrap script narrowly scoped and idempotent.
2. Keep the AGENTS override text explicit enough that it cannot be mistaken for the generic worktree skill.
3. Remove or fully retire older overlapping docs once this plan is adopted.
