# Bare Hub Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-contained bare-hub manager workflow for dotfiles where the host creates the hub before DevPod starts, editing happens only in explicit worktrees, `install.sh` always uses the local checkout it lives in, and durable OpenCode history is backed up via exported sessions plus repo-local `state/`.

**Architecture:** The dotfiles workspace root is a manager hub, not a normal checkout. The host creates that hub first, then DevPod mounts the host directory and opens `/workspaces/dotfiles/main` as the primary checkout. Durable state is intentionally narrow: `state/`, `state/opencode/exported_sessions/`, and `repos/*/state/`. Backup uses two phases: in-pod export/staging and host-side pull plus `restic`.

**Tech Stack:** Bash, Zsh-compatible shell usage, Git bare repos + worktrees, DevPod/Dev Container config, `opencode` CLI, `python3`, `kubectl`, `tar`, `restic`, GNU coreutils, util-linux `flock`. # ADDED

---

## Policy baseline # ADDED

- Repo policy source: `.config/opencode/AGENTS.md` at commit `30a30cb783d8e76859c529b16ad79be161fa285c`. # ADDED
- This plan conforms to the repo policy text present at that commit and must be refreshed if that policy changes materially before implementation starts. # ADDED
- Repo-specific policy override: `/workspaces/dotfiles` is a manager hub, not a normal checkout; editable work must happen from `/workspaces/dotfiles/main` or another explicit worktree. # ADDED

## Ownership & Commit # ADDED

- Planner is the author and committer of plan/spec documents unless the human issues a two-step Maestro override. # ADDED
- Other agents must not commit planner-owned plan/spec artifacts without that override. # ADDED
- Exact refusal string used by scripts and docs in this plan: `Refused — hub-root CWD detected. Provide explicit worktree path.` # ADDED

## Portability and prerequisites # ADDED

- The executable scripts in this plan prefer portable Bash plus `python3` for path logic where feasible. # ADDED
- The test harnesses in this plan assume Linux with GNU coreutils and util-linux, specifically `readlink -f`, `stat -c`, `mv -Tf`, and `flock`. # ADDED
- If host bootstrap must run from macOS, either run the tests from the Linux DevPod/container environment or install GNU equivalents (`greadlink`, `gstat`) and adapt locally; the implementation target for this repo remains Linux. # ADDED

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

The bootstrap script lives in a normal checked-out dotfiles repo on the host, for example:

```text
/home/dev/src/dotfiles/scripts/setup-host-bare-hub.sh
```

That script creates the managed hub layout at a target host path, for example:

```text
/srv/devpod-workspaces/dotfiles/
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
- feature worktree example: `/workspaces/dotfiles/work/feature-example`

For child repos, `omnipy` is the reference example:

- child hub root: `/workspaces/dotfiles/repos/omnipy`
- child main worktree: `/workspaces/dotfiles/repos/omnipy/main`
- child feature worktree example: `/workspaces/dotfiles/repos/omnipy/work/feature-example`

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

- autodetect its own real location with `dirname "${BASH_SOURCE[0]}"` plus realpath semantics
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
- `/workspaces/dotfiles/work/feature-example/install.sh` installs from that feature worktree

### 5. Repo-specific agent-policy override

The generic `using-git-worktrees` skill still applies, but this repository adds a stricter repo-specific rule:

- `/workspaces/dotfiles` is a **manager hub**, not a normal checkout
- work must happen in `/workspaces/dotfiles/main` or another explicit worktree
- the same rule applies recursively to child repos under `repos/*`

This repo-specific policy overrides the generic assumption that a repo root can itself be the editable checkout.

---

## File map # ADDED

### Bootstrap and layout
- Create: `scripts/setup-host-bare-hub.sh`
- Create: `tests/bootstrap/test_setup_host_bare_hub.sh`
- Create: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- Create: `scripts/devpod-ensure-layout.sh`
- Create: `tests/devpod/test_devpod_ensure_layout.sh`
- Create: `.devcontainer/devcontainer.json` # ADDED

### Install safety and install behavior
- Create: `scripts/install-validate-source.sh`
- Create: `tests/install/test_install_validate_source.sh`
- Modify: `install.sh`
- Create: `tests/install/test_install_local_source_contract.sh`

### Agent policy and docs
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
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
- Create: `tests/docs/test_persistence_doc_reconciliation.sh` # ADDED

---

## Preserved verbatim sections from the previous plan # ADDED

Tasks 2, 6, and 9 are intentionally preserved from the previous revision except for top-level consistency updates around file-map references and plan-wide policy text. # ADDED

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

Create `scripts/setup-host-bare-hub.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: scripts/setup-host-bare-hub.sh --hub-root /absolute/path\n' >&2
  exit 1
}

hub_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hub-root)
      shift
      hub_root="${1:-}"
      ;;
    *)
      usage
      ;;
  esac
  shift || true
done

[ -n "$hub_root" ] || usage

case "$hub_root" in
  /*) ;;
  *)
    printf 'refused: --hub-root must be absolute\n' >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_checkout="$(cd "$script_dir/.." && pwd -P)"
default_branch="$(git -C "$source_checkout" symbolic-ref --quiet --short HEAD || git -C "$source_checkout" rev-parse --abbrev-ref HEAD)"

mkdir -p "$hub_root"

if [ ! -d "$hub_root/.bare" ]; then
  git clone --bare "$source_checkout" "$hub_root/.bare" >/dev/null
fi

mkdir -p \
  "$hub_root/work" \
  "$hub_root/repos" \
  "$hub_root/state/opencode/exported_sessions" \
  "$hub_root/tmp"

chmod 700 \
  "$hub_root/state" \
  "$hub_root/state/opencode" \
  "$hub_root/state/opencode/exported_sessions"

if ! git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null 2>&1; then
  rm -rf "$hub_root/main"
  git --git-dir="$hub_root/.bare" worktree add "$hub_root/main" "$default_branch" >/dev/null
fi

printf 'ok: ensured host bare-hub layout at %s\n' "$hub_root"
```

- [ ] **Step 4: Write the host bootstrap runbook**

Create `docs/superpowers/runbooks/host-bare-hub-bootstrap.md` with this exact content:

```markdown
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
```

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

### Task 3: Ensure DevPod opens the main worktree, not the hub root # ADDED

**Files:**
- Create: `scripts/devpod-ensure-layout.sh`
- Test: `tests/devpod/test_devpod_ensure_layout.sh`
- Create: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Write the failing integration test**

Create `tests/devpod/test_devpod_ensure_layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

hub_root="$tmpdir/workspaces/dotfiles"

bash "./scripts/devpod-ensure-layout.sh" "$hub_root" >"$tmpdir/script.out"

[ -d "$hub_root/main" ]
[ -d "$hub_root/work" ]
[ -d "$hub_root/repos" ]
[ -d "$hub_root/tmp" ]
[ -d "$hub_root/state/opencode/exported_sessions" ]

python3 - ".devcontainer/devcontainer.json" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    data = json.load(fh)

assert data["workspaceFolder"] == "/workspaces/dotfiles/main", data["workspaceFolder"]
assert data["postCreateCommand"] == "bash scripts/devpod-ensure-layout.sh /workspaces/dotfiles", data["postCreateCommand"]
PY

grep -F "ok: ensured devpod layout at $hub_root" "$tmpdir/script.out" >/dev/null

printf 'PASS test_devpod_ensure_layout\n'
```

- [ ] **Step 2: Run it to verify RED**

Run:

```bash
bash tests/devpod/test_devpod_ensure_layout.sh
```

Expected: FAIL because `scripts/devpod-ensure-layout.sh` and `.devcontainer/devcontainer.json` do not yet exist.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/devpod-ensure-layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

hub_root="${1:-/workspaces/dotfiles}"

mkdir -p \
  "$hub_root/main" \
  "$hub_root/work" \
  "$hub_root/repos" \
  "$hub_root/state/opencode/exported_sessions" \
  "$hub_root/tmp"

chmod 700 \
  "$hub_root/state" \
  "$hub_root/state/opencode" \
  "$hub_root/state/opencode/exported_sessions"

printf 'ok: ensured devpod layout at %s\n' "$hub_root"
```

Create `.devcontainer/devcontainer.json` with this exact content:

```json
{
  "name": "dotfiles",
  "workspaceFolder": "/workspaces/dotfiles/main",
  "postCreateCommand": "bash scripts/devpod-ensure-layout.sh /workspaces/dotfiles"
}
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
bash tests/devpod/test_devpod_ensure_layout.sh
```

Expected:

```text
PASS test_devpod_ensure_layout
```

- [ ] **Step 5: Commit**

```bash
git add .devcontainer/devcontainer.json scripts/devpod-ensure-layout.sh tests/devpod/test_devpod_ensure_layout.sh
git commit -m "feat(devpod): open main worktree in managed bare-hub layout"
```

### Task 4: Rewrite `install.sh` so it uses its own checkout as the source # ADDED

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
#   plus realpath semantics.
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

Replace `install.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

dry_run=false
assume_yes=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    -y|--yes)
      assume_yes=true
      ;;
    *)
      printf 'usage: install.sh [--dry-run] [-y|--yes]\n' >&2
      exit 1
      ;;
  esac
  shift
done

script_path="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source_root="$(dirname "$script_path")"
workspace_root="${WORKSPACE_ROOT:-/workspaces/dotfiles}"
home_dir="${HOME:?HOME must be set}"
validator="$source_root/scripts/install-validate-source.sh"

if [ "$source_root" = "$workspace_root" ]; then
  printf 'Refused — hub-root CWD detected. Provide explicit worktree path.\n' >&2
  exit 1
fi

if [ ! -x "$validator" ]; then
  printf 'missing validator: %s\n' "$validator" >&2
  exit 1
fi

"$validator" "$source_root" "$source_root/.zshrc" >/dev/null
"$validator" "$source_root" "$source_root/.config/opencode" >/dev/null

zsh_custom="${ZSH_CUSTOM:-$home_dir/.oh-my-zsh/custom}"

run_or_print() {
  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN %s\n' "$*"
  else
    "$@"
  fi
}

link_path() {
  local source_path="$1"
  local target_path="$2"

  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN ln -sfn %s %s\n' "$source_path" "$target_path"
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  ln -sfn "$source_path" "$target_path"
}

install_plugin() {
  local repo_url="$1"
  local dest_path="$2"

  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN git clone %s %s\n' "$repo_url" "$dest_path"
    return 0
  fi

  if [ ! -d "$dest_path" ]; then
    git clone "$repo_url" "$dest_path"
  else
    printf '%s already installed, skipping.\n' "$(basename "$dest_path")"
  fi
}

run_opencode_command() {
  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN (cd %s && %s)\n' "$home_dir/.config/opencode" "$*"
    return 0
  fi

  (
    cd "$home_dir/.config/opencode"
    "$@"
  )
}

mkdir -p "$home_dir/.config"
mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"

link_path "$source_root/.zshrc" "$home_dir/.zshrc"

install_plugin "https://github.com/reobin/typewritten" "$zsh_custom/themes/typewritten"
install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$zsh_custom/plugins/zsh-syntax-highlighting"
install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$zsh_custom/plugins/zsh-autosuggestions"

link_path "$source_root/.config/opencode" "$home_dir/.config/opencode"

run_opencode_command npx -y skills add wondelai/skills/pragmatic-programmer
run_opencode_command npx -y @bybrawe/opencode-loop

if [ "$assume_yes" = true ] && [ "$dry_run" = true ]; then
  :
fi

printf 'ok: dotfiles applied from %s\n' "$source_root"
```

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
(cd "$HOME/dotfiles" && ./install.sh --dry-run -y)
(cd /workspaces/dotfiles/main && ./install.sh --dry-run -y)
(cd /workspaces/dotfiles/work/feature-x && ./install.sh --dry-run -y)
```

Expected: each run uses the files from the checkout/worktree where that `install.sh` file lives.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install/test_install_local_source_contract.sh
git commit -m "feat(install): use local worktree sources with fixed targets"
```

### Task 5: Strengthen AGENTS policy, agent descriptions, and user docs # ADDED

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/senior-implementer.md`
- Create: `docs/superpowers/runbooks/bare-hub-manager-usage.md`
- Create: `docs/superpowers/runbooks/devpod-persistence-verification.md`
- Test: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write the failing grep-level doc test**

Create `tests/docs/test_bare_hub_guardrails.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

grep -F '`/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Agents MUST treat `/workspaces/dotfiles/main` or another explicit worktree path as the editable repository root.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Child repos under `repos/` follow the same pattern; `repos/omnipy/main` and `repos/omnipy/work/feature-example` are the reference examples.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Refused — hub-root CWD detected. Provide explicit worktree path.' .config/opencode/AGENTS.md >/dev/null

grep -F 'Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/agents/maestro.md >/dev/null
grep -F 'Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/agents/senior-implementer.md >/dev/null

grep -F 'bash "./scripts/setup-host-bare-hub.sh" --hub-root "/srv/devpod-workspaces/dotfiles"' docs/superpowers/runbooks/bare-hub-manager-usage.md >/dev/null
grep -F 'bash /workspaces/dotfiles/main/install.sh --dry-run -y' docs/superpowers/runbooks/bare-hub-manager-usage.md >/dev/null
grep -F 'kubectl exec -n "$namespace" "$pod" -- sh -lc '"'"'echo persist-1 > /workspaces/.persist-check && sync && ls -l /workspaces/.persist-check'"'"'' docs/superpowers/runbooks/devpod-persistence-verification.md >/dev/null
grep -F 'kubectl exec -n "$namespace" "$pod" -- bash -lc '"'"'cd /workspaces/dotfiles/main && bash scripts/opencode-export-all-sessions.sh && bash scripts/prepare-state-backup-set.sh /workspaces/dotfiles /tmp/backup_staging'"'"'' docs/superpowers/runbooks/devpod-persistence-verification.md >/dev/null

printf 'PASS test_bare_hub_guardrails\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: FAIL because the repo-specific bare-hub text and runbooks are not yet present with the required exact wording.

- [ ] **Step 3: Apply the policy/doc changes**

Insert this exact block under `## Subagent delegation (short)` in `.config/opencode/AGENTS.md`:

```md
- Bare-hub manager override for this repo: `/workspaces/dotfiles` is a manager hub, not a normal checkout.
- Agents MUST treat `/workspaces/dotfiles/main` or another explicit worktree path as the editable repository root.
- Worktree-skill reconciliation: the generic `using-git-worktrees` skill still applies, but in this repo it starts from the existing bare-hub layout instead of inventing a parallel checkout model.
- Child repos under `repos/` follow the same pattern; `repos/omnipy/main` and `repos/omnipy/work/feature-example` are the reference examples.
- Durable local files for child repos belong only under `repos/omnipy/state/` or another repo-local `state/` directory, never under the hub root.
- Bare-hub refusal string: if CWD is detected to be a hub root, the agent or script must refuse with: `Refused — hub-root CWD detected. Provide explicit worktree path.`
```

Append this exact section to `.config/opencode/agents/maestro.md`:

```md
## Repo-specific bare-hub override

Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.
The Maestro must dispatch work against `/workspaces/dotfiles/main` or another explicit worktree path and must not treat `/workspaces/dotfiles` itself as an editable checkout.
The same rule applies to child repos under `repos/`, with `repos/omnipy/main` and `repos/omnipy/work/feature-example` as the reference layout.
If a hub-root working directory is detected, preserve the exact refusal string: `Refused — hub-root CWD detected. Provide explicit worktree path.`
```

Append this exact section to `.config/opencode/agents/senior-implementer.md`:

```md
## Repo-specific bare-hub override

Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.
Senior implementers must perform implementation work from `/workspaces/dotfiles/main` or another explicit worktree path and must not edit from `/workspaces/dotfiles` itself.
The same rule applies to child repos under `repos/`, with `repos/omnipy/main` and `repos/omnipy/work/feature-example` as the reference layout.
If a hub-root working directory is detected, preserve the exact refusal string: `Refused — hub-root CWD detected. Provide explicit worktree path.`
```

Create `docs/superpowers/runbooks/bare-hub-manager-usage.md` with this exact content:

```markdown
# Bare Hub Manager Usage

## Host bootstrap before DevPod launch

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "/srv/devpod-workspaces/dotfiles"
```

## DevPod mount and workspace folder

Mount `/srv/devpod-workspaces/dotfiles` into the container as `/workspaces/dotfiles`.
Open `/workspaces/dotfiles/main` as the DevPod workspace folder.

## Create a top-level feature worktree

```bash
git --git-dir="/workspaces/dotfiles/.bare" worktree add "/workspaces/dotfiles/work/feature-example" -b feature-example main
```

## Child repo layout

Use the same pattern for child repos. `omnipy` is the reference example:

```bash
git --git-dir="/workspaces/dotfiles/repos/omnipy/.bare" worktree add "/workspaces/dotfiles/repos/omnipy/work/feature-example" -b feature-example main
```

## Durable vs disposable files

Durable:
- `/workspaces/dotfiles/state/`
- `/workspaces/dotfiles/state/opencode/exported_sessions/`
- `/workspaces/dotfiles/repos/omnipy/state/`

Disposable:
- `/workspaces/dotfiles/tmp/`
- `/workspaces/dotfiles/repos/omnipy/tmp/`
- `/tmp/backup_staging/`

## Install usage

```bash
bash /workspaces/dotfiles/main/install.sh --dry-run -y
bash /workspaces/dotfiles/work/feature-example/install.sh --dry-run -y
```

Never run the hub-root copy at `/workspaces/dotfiles/install.sh`; it must refuse with:

```text
Refused — hub-root CWD detected. Provide explicit worktree path.
```
```

Create `docs/superpowers/runbooks/devpod-persistence-verification.md` with this exact content:

```markdown
# DevPod Persistence Verification

Use these commands from a Linux shell with `kubectl` configured.

## Verify `/workspaces` persistence

```bash
namespace="${NAMESPACE:-devpod}"
pod="${POD_NAME:-devpod-workspace-0}"

kubectl exec -n "$namespace" "$pod" -- sh -lc 'echo persist-1 > /workspaces/.persist-check && sync && ls -l /workspaces/.persist-check'
kubectl exec -n "$namespace" "$pod" -- cat /workspaces/.persist-check
```

## Verify export and staging commands

```bash
namespace="${NAMESPACE:-devpod}"
pod="${POD_NAME:-devpod-workspace-0}"

kubectl exec -n "$namespace" "$pod" -- bash -lc 'cd /workspaces/dotfiles/main && bash scripts/opencode-export-all-sessions.sh && bash scripts/prepare-state-backup-set.sh /workspaces/dotfiles /tmp/backup_staging'
kubectl exec -n "$namespace" "$pod" -- find /tmp/backup_staging/current -maxdepth 4 -type f | sort
```

## Verify host-side pull prerequisites

```bash
namespace="${NAMESPACE:-devpod}"
pod="${POD_NAME:-devpod-workspace-0}"

kubectl exec -n "$namespace" "$pod" -- tar -C /tmp/backup_staging/current -cf - . | tar -tf -
```
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected:

```text
PASS test_bare_hub_guardrails
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

### Task 7: Stage durable state with busy-file preservation and safe promotion # ADDED

This task fixes the three reviewer gaps with a deterministic contract:

1. busy-file retry/skip/report contract via `flock`
2. no delete window for `current/` by making `current` a symlink that is atomically replaced
3. clear durable-state semantics aligned to the export-and-backup design

**Files:**
- Create: `scripts/prepare-state-backup-set.sh`
- Test: `tests/opencode/test_prepare_state_backup_set.sh`

- [ ] **Step 1: Write the failing integration/contract test**

Create `tests/opencode/test_prepare_state_backup_set.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
busy_pid=""

cleanup() {
  if [ -n "$busy_pid" ] && kill -0 "$busy_pid" 2>/dev/null; then
    kill "$busy_pid" 2>/dev/null || true
    wait "$busy_pid" 2>/dev/null || true
  fi
  if [ -e "$tmpdir/workspaces/dotfiles/state/app/unreadable.txt" ]; then
    chmod 600 "$tmpdir/workspaces/dotfiles/state/app/unreadable.txt" 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

workspace_root="$tmpdir/workspaces/dotfiles"
staging_root="$tmpdir/backup_staging"

mkdir -p \
  "$workspace_root/state/opencode/exported_sessions" \
  "$workspace_root/state/app" \
  "$workspace_root/repos/omnipy/state" \
  "$workspace_root/tmp/cache" \
  "$staging_root/sets/set-prev/state/app"

printf 'session-json\n' > "$workspace_root/state/opencode/exported_sessions/export.json"
printf 'new-live-cache\n' > "$workspace_root/state/app/cache.txt"
printf 'repo-state\n' > "$workspace_root/repos/omnipy/state/repo-cache.txt"
printf 'skip-me\n' > "$workspace_root/tmp/cache/debug.log"

printf 'old-staged-cache\n' > "$staging_root/sets/set-prev/state/app/cache.txt"
ln -s "$staging_root/sets/set-prev" "$staging_root/current"

(
  exec 9>"$workspace_root/state/app/cache.txt.backup.lock"
  flock -n 9
  sleep 8
) &
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

current_target_before="$(readlink -f "$staging_root/current")"

printf 'cannot-read\n' > "$workspace_root/state/app/unreadable.txt"
chmod 000 "$workspace_root/state/app/unreadable.txt"

if bash scripts/prepare-state-backup-set.sh "$workspace_root" "$staging_root" >"$tmpdir/fail.out" 2>&1; then
  printf 'expected staging run to fail when source contains unreadable file\n' >&2
  exit 1
fi

current_target_after="$(readlink -f "$staging_root/current")"
[ "$current_target_before" = "$current_target_after" ]

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

Create `scripts/prepare-state-backup-set.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

workspace_root="${1:-/workspaces/dotfiles}"
staging_root="${2:-/tmp/backup_staging}"

sets_dir="$staging_root/sets"
current_link="$staging_root/current"
next_link="$staging_root/current.next"
skip_report_tmp="$staging_root/last-skipped.txt.next"
live_files="$(mktemp)"
staged_files="$(mktemp)"
new_set="$sets_dir/set-$(date -u +'%Y%m%dT%H%M%SZ')-$$"
success=false

cleanup() {
  rm -f "$live_files" "$staged_files" "$skip_report_tmp"
  if [ "$success" != true ] && [ -d "$new_set" ]; then
    rm -rf "$new_set"
  fi
}
trap cleanup EXIT

mkdir -p "$sets_dir"
: > "$skip_report_tmp"

ensure_current() {
  if [ -L "$current_link" ] || [ -d "$current_link" ]; then
    return 0
  fi

  mkdir -p "$sets_dir/set-initial"
  ln -sfn "$sets_dir/set-initial" "$next_link"
  mv -Tf "$next_link" "$current_link"
}

ensure_current

current_target="$(readlink -f "$current_link")"

mkdir -p "$new_set"
if [ -d "$current_target" ]; then
  cp -a "$current_target/." "$new_set/" 2>/dev/null || true
fi

python3 - "$workspace_root" <<'PY' > "$live_files"
import glob
import os
import sys

root = os.path.realpath(sys.argv[1])
files = []

top_state = os.path.join(root, "state")
if os.path.isdir(top_state):
    for base, dirs, names in os.walk(top_state):
        dirs[:] = [d for d in dirs if d != "tmp"]
        for name in names:
            files.append(os.path.join(base, name))

for repo_state in glob.glob(os.path.join(root, "repos", "*", "state")):
    for base, dirs, names in os.walk(repo_state):
        dirs[:] = [d for d in dirs if d != "tmp"]
        for name in names:
            files.append(os.path.join(base, name))

for path in sorted(set(files)):
    print(path)
PY

copy_live_file() {
  local source_file="$1"
  local rel_path="${source_file#$workspace_root/}"
  local dest_file="$new_set/$rel_path"
  local lock_file="$source_file.backup.lock"

  mkdir -p "$(dirname "$dest_file")"

  if [ -e "$lock_file" ]; then
    if ! flock -n "$lock_file" -c true 2>/dev/null; then
      sleep 1
      if ! flock -n "$lock_file" -c true 2>/dev/null; then
        printf '%s\n' "$source_file" >> "$skip_report_tmp"
        return 0
      fi
    fi
  fi

  cp -a "$source_file" "$dest_file"
}

while IFS= read -r source_file; do
  [ -n "$source_file" ] || continue
  copy_live_file "$source_file"
done < "$live_files"

python3 - "$new_set" <<'PY' > "$staged_files"
import os
import sys

root = os.path.realpath(sys.argv[1])
files = []

for base_name in ("state", "repos"):
    base_root = os.path.join(root, base_name)
    if not os.path.exists(base_root):
        continue
    for base, dirs, names in os.walk(base_root):
        dirs[:] = [d for d in dirs if d != "tmp"]
        for name in names:
            files.append(os.path.join(base, name))

for path in sorted(set(files)):
    print(path)
PY

while IFS= read -r staged_file; do
  [ -n "$staged_file" ] || continue
  rel_path="${staged_file#$new_set/}"
  case "$rel_path" in
    state/*|repos/*/state/*)
      if ! grep -Fx "$workspace_root/$rel_path" "$live_files" >/dev/null 2>&1; then
        rm -f "$staged_file"
      fi
      ;;
  esac
done < "$staged_files"

mv "$skip_report_tmp" "$staging_root/last-skipped.txt"
ln -sfn "$new_set" "$next_link"
mv -Tf "$next_link" "$current_link"

success=true
printf 'ok: staged backup set at %s/current\n' "$staging_root"
```

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

### Task 8: Add host pull, snapshot backup, and user-facing backup docs # ADDED

**Files:**
- Create: `scripts/host-pull-and-restic-backup.sh`
- Test: `tests/opencode/test_host_pull_and_restic_backup.sh`
- Create: `docs/superpowers/runbooks/opencode-export-and-state-backup.md`

- [ ] **Step 1: Write the failing contract test**

Create `tests/opencode/test_host_pull_and_restic_backup.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/bin" \
  "$tmpdir/pod-current/state/opencode/exported_sessions" \
  "$tmpdir/restic-repo"

printf 'session-json\n' > "$tmpdir/pod-current/state/opencode/exported_sessions/export.json"

cat > "$tmpdir/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$KUBECTL_LOG"
if [ "$1" = "exec" ] && [ "$2" = "-n" ] && [ "$5" = "--" ] && [ "$6" = "tar" ]; then
  tar -C "$KUBECTL_MOCK_SOURCE" -cf - .
  exit 0
fi
printf 'unexpected kubectl args: %s\n' "$*" >&2
exit 1
EOF

cat > "$tmpdir/bin/restic" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'RESTIC_REPOSITORY=%s\n' "${RESTIC_REPOSITORY:-}" >> "$RESTIC_LOG"
printf '%s\n' "$*" >> "$RESTIC_LOG"
[ "$1" = "backup" ]
[ -f "$2/state/opencode/exported_sessions/export.json" ]
printf 'snapshot created\n'
EOF

chmod +x "$tmpdir/bin/kubectl" "$tmpdir/bin/restic"

KUBECTL_BIN="$tmpdir/bin/kubectl" \
RESTIC_BIN="$tmpdir/bin/restic" \
KUBECTL_LOG="$tmpdir/kubectl.log" \
RESTIC_LOG="$tmpdir/restic.log" \
KUBECTL_MOCK_SOURCE="$tmpdir/pod-current" \
./scripts/host-pull-and-restic-backup.sh "devpod" "workspace-0" "$tmpdir/pulled" "$tmpdir/restic-repo" >"$tmpdir/out.txt"

[ -f "$tmpdir/pulled/current/state/opencode/exported_sessions/export.json" ]

grep -F "exec -n devpod workspace-0 -- tar -C /tmp/backup_staging/current -cf - ." "$tmpdir/kubectl.log" >/dev/null
grep -F "RESTIC_REPOSITORY=$tmpdir/restic-repo" "$tmpdir/restic.log" >/dev/null
grep -F "backup $tmpdir/pulled/current" "$tmpdir/restic.log" >/dev/null
! grep -F "$tmpdir/restic-repo" "$tmpdir/kubectl.log" >/dev/null

grep -F "ok: pulled staged backup set to $tmpdir/pulled/current" "$tmpdir/out.txt" >/dev/null
grep -F "ok: restic snapshot created from $tmpdir/pulled/current" "$tmpdir/out.txt" >/dev/null

printf 'PASS test_host_pull_and_restic_backup\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
```

Expected: FAIL with `./scripts/host-pull-and-restic-backup.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/host-pull-and-restic-backup.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

namespace="${1:?usage: scripts/host-pull-and-restic-backup.sh NAMESPACE POD PULL_ROOT RESTIC_REPOSITORY}"
pod="${2:?usage: scripts/host-pull-and-restic-backup.sh NAMESPACE POD PULL_ROOT RESTIC_REPOSITORY}"
pull_root="${3:?usage: scripts/host-pull-and-restic-backup.sh NAMESPACE POD PULL_ROOT RESTIC_REPOSITORY}"
restic_repository="${4:?usage: scripts/host-pull-and-restic-backup.sh NAMESPACE POD PULL_ROOT RESTIC_REPOSITORY}"

kubectl_bin="${KUBECTL_BIN:-kubectl}"
restic_bin="${RESTIC_BIN:-restic}"
pod_staging_path="${POD_STAGING_PATH:-/tmp/backup_staging/current}"
pull_current="$pull_root/current"

rm -rf "$pull_current"
mkdir -p "$pull_current"

"$kubectl_bin" exec -n "$namespace" "$pod" -- tar -C "$pod_staging_path" -cf - . | tar -C "$pull_current" -xf -

RESTIC_REPOSITORY="$restic_repository" "$restic_bin" backup "$pull_current"

printf 'ok: pulled staged backup set to %s\n' "$pull_current"
printf 'ok: restic snapshot created from %s\n' "$pull_current"
```

Create `docs/superpowers/runbooks/opencode-export-and-state-backup.md` with this exact content:

```markdown
# OpenCode Export And State Backup

This runbook documents the two-phase backup flow.

## Phase A: in-pod export and staging

```bash
namespace="${NAMESPACE:-devpod}"
pod="${POD_NAME:-devpod-workspace-0}"

kubectl exec -n "$namespace" "$pod" -- bash -lc 'cd /workspaces/dotfiles/main && bash scripts/opencode-export-all-sessions.sh && bash scripts/prepare-state-backup-set.sh /workspaces/dotfiles /tmp/backup_staging'
kubectl exec -n "$namespace" "$pod" -- find /tmp/backup_staging/current -maxdepth 5 -type f | sort
```

## Phase B: host pull and `restic` snapshot

```bash
namespace="${NAMESPACE:-devpod}"
pod="${POD_NAME:-devpod-workspace-0}"

kubectl exec -n "$namespace" "$pod" -- tar -C /tmp/backup_staging/current -cf - . | tar -C "$HOME/dotfiles-backup-stage/current" -xf -
RESTIC_REPOSITORY="$HOME/restic-repos/dotfiles" restic backup "$HOME/dotfiles-backup-stage/current"
```

Equivalent wrapper command:

```bash
bash scripts/host-pull-and-restic-backup.sh "$namespace" "$pod" "$HOME/dotfiles-backup-stage" "$HOME/restic-repos/dotfiles"
```

## Restore flow

```bash
RESTIC_REPOSITORY="$HOME/restic-repos/dotfiles" restic restore latest --target "$HOME/dotfiles-restore"
find "$HOME/dotfiles-restore/current/state/opencode/exported_sessions" -type f -name '*.json' | sort
bash scripts/recover-opencode-sessions.sh "$HOME/dotfiles-restore/current/state/opencode/exported_sessions"
```

## Cleanup guidance

```bash
rm -rf "$HOME/dotfiles-backup-stage/current"
find /tmp/backup_staging -maxdepth 2 -type l -o -type f | sort
```

The real `restic` repository remains host-side only. Do not mount it writable into DevPod.
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/opencode/test_host_pull_and_restic_backup.sh
```

Expected:

```text
PASS test_host_pull_and_restic_backup
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

### Task 10: Reconcile the older persistence document and verify canonical wording # ADDED

**Files:**
- Modify: `docs/superpowers/specs/2026-05-21-persistence-security-design.md`
- Create: `tests/docs/test_persistence_doc_reconciliation.sh`

- [ ] **Step 1: Write the failing doc test**

Create `tests/docs/test_persistence_doc_reconciliation.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

grep -F '> **Superseded in part:** The durable-state, host-bootstrap, worktree-policy, and backup guidance in this document is now governed by `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`, which is the canonical combined spec + implementation plan for the bare-hub manager workflow.' docs/superpowers/specs/2026-05-21-persistence-security-design.md >/dev/null
grep -F 'Read all persistence, installer-source, and bare-hub policy decisions through that newer plan first.' docs/superpowers/specs/2026-05-21-persistence-security-design.md >/dev/null

grep -F 'Repo policy source: `.config/opencode/AGENTS.md` at commit `30a30cb783d8e76859c529b16ad79be161fa285c`.' docs/superpowers/plans/2026-05-21-bare-hub-manager.md >/dev/null
grep -F 'Refused — hub-root CWD detected. Provide explicit worktree path.' docs/superpowers/plans/2026-05-21-bare-hub-manager.md >/dev/null
grep -F '/tmp/backup_staging/current' docs/superpowers/plans/2026-05-21-bare-hub-manager.md >/dev/null

git diff --check >/dev/null

printf 'PASS test_persistence_doc_reconciliation\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/docs/test_persistence_doc_reconciliation.sh
```

Expected: FAIL because the older persistence spec does not yet include the new exact superseded banner text.

- [ ] **Step 3: Write the minimal implementation**

Replace the existing superseded banner block in `docs/superpowers/specs/2026-05-21-persistence-security-design.md` with this exact text:

```md
> **Superseded in part:** The durable-state, host-bootstrap, worktree-policy, and backup guidance in this document is now governed by `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`, which is the canonical combined spec + implementation plan for the bare-hub manager workflow.
>
> Read all persistence, installer-source, and bare-hub policy decisions through that newer plan first.
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/docs/test_persistence_doc_reconciliation.sh
```

Expected:

```text
PASS test_persistence_doc_reconciliation
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-05-21-persistence-security-design.md tests/docs/test_persistence_doc_reconciliation.sh
git commit -m "docs(spec): point persistence guidance to canonical bare-hub plan"
```

---

## Verification-before-completion checklist for the implementer # ADDED

Before claiming this work complete, run:

```bash
bash tests/bootstrap/test_setup_host_bare_hub.sh
bash tests/devpod/test_devpod_ensure_layout.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/docs/test_bare_hub_guardrails.sh
bash tests/docs/test_persistence_doc_reconciliation.sh
bash tests/opencode/test_export_all_sessions.sh
bash tests/opencode/test_prepare_state_backup_set.sh
bash tests/opencode/test_host_pull_and_restic_backup.sh
bash tests/opencode/test_recover_opencode_sessions.sh
```

Then run:

```bash
git diff --check
```

Expected:

```text
All listed shell tests print PASS.
git diff --check prints no output.
```

---

## Pragmatic-programmer quick diagnostic

Score: **8/10**

Remaining remediation tasks to reach 10/10:

1. Keep the host bootstrap script narrowly scoped and idempotent.
2. Keep the AGENTS override text explicit enough that it cannot be mistaken for the generic worktree skill.
3. Remove or fully retire older overlapping docs once this plan is adopted.
