# Bare Hub Manager Implementation Plan

## SUMMARY

- **Durable state scope is narrower than the earlier docs implied.** Replace the persistence wording in `docs/superpowers/specs/2026-05-21-persistence-security-design.md` sections **Executive summary**, **Mitigations and guardrails** (bullets 53-55), **Recommended k3d/DevPod default**, and **Prioritized actionable TODOs** items **3** and **4** with the state contract from `docs/superpowers/specs/2026-05-21-opencode-export-and-state-backup-design.md`: durable state is `state/`, `state/opencode/exported_sessions/`, and `repos/*/state/`; `tmp/` stays disposable.
- **The earlier manager plan needs its persistence tasks replaced, not extended.** Replace `docs/superpowers/plans/2026-05-21-bare-hub-manager.md` sections **Architecture**, **File Structure**, **Task 2**, **Task 4**, **Task 5 Step 4**, and **Task 6**. Those sections currently talk about redirecting generic OpenCode state into `/workspaces/dotfiles/state`; they must instead point to the export-and-backup flow in Part 2 of this document.
- **OpenCode durability now comes from exports, not internal storage copying.** Revise `docs/superpowers/specs/2026-05-21-persistence-security-design.md` bullet **54** (`Store transcripts per workspace under /workspaces/dotfiles/state/opencode/<workspace-id>`) so it distinguishes runtime state from durable history: runtime files may live under `state/opencode/`, but keep-worthy session history is backed up via `state/opencode/exported_sessions/` produced by `opencode export`.
- **Backup procedure language must be replaced wholesale.** Any future doc or runbook that says “back up `/workspaces`” or “back up OpenCode state directly” must be updated to the two-phase design from `docs/superpowers/specs/2026-05-21-opencode-export-and-state-backup-design.md` sections **Backup Staging Contract**, **Host Backup Contract**, and **Schedule**.
- **Install and hub-root guardrails still stand.** Keep and execute the install-safety work from `docs/superpowers/specs/2026-05-21-persistence-security-design.md` sections **Mitigations and guardrails**, **Admin tests and verification**, and **Prioritized actionable TODOs** items **1**, **2**, and **5** as Part 1 below.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a coherent bare-hub manager workflow for `/workspaces/dotfiles` with safe installer behavior, explicit hub/worktree guardrails, and a directly executable follow-up that backs up durable OpenCode history via `opencode export` plus repo-local `state/` directories.

**Architecture:** Part 1 establishes the working skeleton: a bare-hub manager root, a `main` worktree as the editor entry point, explicit installer validation, and repo/operator guardrails. Part 2 starts immediately after Part 1 and adds the durable-state pipeline: export OpenCode sessions into `state/opencode/exported_sessions/`, stage keep-worthy `state/` content under `/tmp/opencode-backup-staging`, then let the host pull and snapshot it with `restic`.

**Tech Stack:** Bash, Zsh-compatible shell usage, Git worktrees, Dev Container config, `opencode` CLI, `python3` for JSON parsing inside shell scripts, `kubectl`, `tar`, `restic`.

---

## Scope Check

This is still one implementation plan, but it is deliberately split into two execution phases:

1. **Part 1:** make the bare-hub manager safe and usable.
2. **Part 2:** add the durable export-and-backup pipeline that depends on the `state/` contract from Part 1.

The split is sequential, not independent. Part 2 should start only after Part 1 verification passes.

## File Structure

### Part 1 files

- Create: `.devcontainer/devcontainer.json` — open DevPod into `/workspaces/dotfiles/main` and ensure the manager layout exists.
- Create: `scripts/devpod-ensure-layout.sh` — create `state/`, `tmp/`, `repos/`, and `work/` with the required permissions.
- Create: `scripts/install-validate-source.sh` — reject source-root escapes, malformed `.git` indirection, and unsafe install sources.
- Modify: `install.sh` — require explicit `--source-root` and `--target-home`, refuse hub-root execution, and make link operations source-rooted.
- Create: `tests/devpod/test_devpod_ensure_layout.sh` — integration/contract test for the manager layout script.
- Create: `tests/install/test_install_validate_source.sh` — integration/contract test for source validation.
- Create: `tests/install/test_install_cli_contract.sh` — integration/contract test for `install.sh` CLI, hub-root refusal, and dry-run output.
- Modify: `.config/opencode/AGENTS.md` — encode the hub-root refusal contract for agents.
- Create: `docs/superpowers/runbooks/devpod-persistence-verification.md` — operator runbook for persistence, hub-root, and symlink-race checks.
- Create: `tests/docs/test_bare_hub_guardrails.sh` — grep-level verification for the required guardrail strings and runbook commands.

### Part 2 files

- Create: `scripts/opencode-export-all-sessions.sh` — export/re-export session JSON files into `state/opencode/exported_sessions/`.
- Create: `tests/opencode/test_export_all_sessions.sh` — contract test using a stub `opencode` binary.
- Create: `scripts/prepare-state-backup-set.sh` — double-buffer stage `state/` and `repos/*/state/` into `/tmp/opencode-backup-staging`.
- Create: `tests/opencode/test_prepare_state_backup_set.sh` — contract test for staging, `tmp/` exclusion, and last-known-good preservation.
- Create: `scripts/host-pull-and-restic-backup.sh` — host-side pull plus `restic backup`.
- Create: `tests/opencode/test_host_pull_and_restic_backup.sh` — contract test with stub `kubectl` and `restic`.
- Create: `scripts/recover-opencode-sessions.sh` — newest-first import with per-session dedupe.
- Create: `tests/opencode/test_recover_opencode_sessions.sh` — contract test for ordering and dedupe.
- Create: `docs/superpowers/runbooks/opencode-export-and-state-backup.md` — operator runbook for cron/scheduling, restore, and cleanup.

---

## Part 1 — Revised Bare-Hub Manager Plan

### Task 1: Create the bare-hub layout tracer bullet

**Files:**
- Create: `.devcontainer/devcontainer.json`
- Create: `scripts/devpod-ensure-layout.sh`
- Test: `tests/devpod/test_devpod_ensure_layout.sh`

- [ ] **Step 1: Write the failing integration test**

Create `tests/devpod/test_devpod_ensure_layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

root="$tmpdir/workspaces/dotfiles"

./scripts/devpod-ensure-layout.sh "$root" >"$tmpdir/out.txt"

[ -d "$root/state/opencode/exported_sessions" ]
[ -d "$root/tmp" ]
[ -d "$root/repos" ]
[ -d "$root/work" ]

state_mode="$(stat -c '%a' "$root/state")"
opencode_mode="$(stat -c '%a' "$root/state/opencode")"
exports_mode="$(stat -c '%a' "$root/state/opencode/exported_sessions")"

[ "$state_mode" = "700" ]
[ "$opencode_mode" = "700" ]
[ "$exports_mode" = "700" ]

grep -F "ok: ensured bare-hub layout at $root" "$tmpdir/out.txt" >/dev/null

printf 'PASS test_devpod_ensure_layout\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/devpod/test_devpod_ensure_layout.sh
```

Expected: FAIL with `./scripts/devpod-ensure-layout.sh: No such file or directory`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/devpod-ensure-layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="${1:-/workspaces/dotfiles}"

mkdir -p "$root/state/opencode/exported_sessions"
mkdir -p "$root/tmp"
mkdir -p "$root/repos"
mkdir -p "$root/work"

chmod 700 "$root/state"
chmod 700 "$root/state/opencode"
chmod 700 "$root/state/opencode/exported_sessions"

printf 'ok: ensured bare-hub layout at %s\n' "$root"
```

Create `.devcontainer/devcontainer.json` with this exact content:

```json
{
  "name": "dotfiles-main-worktree",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "remoteUser": "vscode",
  "workspaceFolder": "/workspaces/dotfiles/main",
  "postCreateCommand": "bash scripts/devpod-ensure-layout.sh /workspaces/dotfiles"
}
```

- [ ] **Step 4: Run the test to verify GREEN**

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
git commit -m "feat(devpod): add bare-hub layout tracer bullet"
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

### Task 3: Make `install.sh` explicit, source-rooted, and hub-safe

**Files:**
- Modify: `install.sh`
- Test: `tests/install/test_install_cli_contract.sh`

- [ ] **Step 1: Write the failing integration test**

Create `tests/install/test_install_cli_contract.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source_root="$tmpdir/source"
target_home="$tmpdir/home"
hub_root="$tmpdir/hub"

mkdir -p "$source_root/.config/opencode" "$target_home" "$hub_root/main" "$hub_root/repos" "$hub_root/state"
printf 'export TEST_ZSHRC=1\n' > "$source_root/.zshrc"
printf '{"ok":true}\n' > "$source_root/.config/opencode/opencode.jsonc"

git init "$source_root" >/dev/null 2>&1

./install.sh --source-root "$source_root" --target-home "$target_home" --dry-run -y >"$tmpdir/dry-run.out"
grep -F "DRY-RUN ln -sfn $source_root/.zshrc $target_home/.zshrc" "$tmpdir/dry-run.out" >/dev/null
grep -F "DRY-RUN ln -sfn $source_root/.config/opencode $target_home/.config/opencode" "$tmpdir/dry-run.out" >/dev/null

if ./install.sh --source-root relative/path --target-home "$target_home" --dry-run -y >"$tmpdir/relative.out" 2>&1; then
  printf 'expected relative source-root to fail\n' >&2
  exit 1
fi
grep -F "refused: source-root must be absolute" "$tmpdir/relative.out" >/dev/null

(
  cd "$hub_root"
  if /home/vscode/dotfiles/install.sh --source-root "$source_root" --target-home "$target_home" --dry-run -y >"$tmpdir/hub.out" 2>&1; then
    printf 'expected hub-root execution to fail\n' >&2
    exit 1
  fi
)
grep -F "Refused — hub-root CWD detected. Provide explicit worktree path." "$tmpdir/hub.out" >/dev/null

printf 'PASS test_install_cli_contract\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/install/test_install_cli_contract.sh
```

Expected: FAIL because the current `install.sh` does not accept `--source-root` / `--target-home` and does not print the required refusal messages.

- [ ] **Step 3: Write the minimal implementation**

Replace `install.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root=""
target_home=""
dry_run=0
yes_all=0

usage() {
  printf 'usage: ./install.sh --source-root /abs/path --target-home /abs/path [--dry-run] [-y]\n' >&2
}

confirm_replace() {
  local target_path="$1"

  if [ "$yes_all" -eq 1 ] || [ ! -e "$target_path" ] || [ -L "$target_path" ]; then
    return 0
  fi

  printf 'Replace %s with a symlink? [y/N] ' "$target_path" >&2
  read -r reply
  [ "$reply" = "y" ] || [ "$reply" = "Y" ]
}

link_path() {
  local source_path="$1"
  local target_path="$2"

  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    if ! confirm_replace "$target_path"; then
      printf 'skipped %s\n' "$target_path"
      return 0
    fi
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf 'DRY-RUN ln -sfn %s %s\n' "$source_path" "$target_path"
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    rm -rf "$target_path"
  fi
  ln -sfn "$source_path" "$target_path"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-root)
      source_root="$2"
      shift 2
      ;;
    --target-home)
      target_home="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -y|--yes)
      yes_all=1
      shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

case "$source_root" in
  /*) ;;
  *)
    printf 'refused: source-root must be absolute\n' >&2
    exit 1
    ;;
esac

case "$target_home" in
  /*) ;;
  *)
    printf 'refused: target-home must be absolute\n' >&2
    exit 1
    ;;
esac

if [ "$(pwd -P)" = "/workspaces/dotfiles" ] || { [ -d main ] && [ -d repos ] && [ -d state ] && [ ! -e .git ]; }; then
  printf 'Refused — hub-root CWD detected. Provide explicit worktree path.\n' >&2
  exit 1
fi

git_top="$(git -C "$source_root" rev-parse --show-toplevel 2>/dev/null || true)"
if [ "$git_top" != "$source_root" ]; then
  printf 'refused: source-root must equal git toplevel\n' >&2
  exit 1
fi

"$script_dir/scripts/install-validate-source.sh" "$source_root" "$source_root"

link_path "$source_root/.zshrc" "$target_home/.zshrc"
mkdir -p "$target_home/.config"
link_path "$source_root/.config/opencode" "$target_home/.config/opencode"

if [ "$dry_run" -eq 1 ]; then
  printf 'DRY-RUN git clone https://github.com/reobin/typewritten ${ZSH_CUSTOM:-$target_home/.oh-my-zsh/custom}/themes/typewritten\n'
  printf 'DRY-RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-$target_home/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting\n'
  printf 'DRY-RUN git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$target_home/.oh-my-zsh/custom}/plugins/zsh-autosuggestions\n'
  printf 'DRY-RUN (cd %s/.config/opencode && npx -y skills add wondelai/skills/pragmatic-programmer && npx -y @bybrawe/opencode-loop)\n' "$target_home"
  exit 0
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$target_home/.oh-my-zsh/custom}"

install_plugin() {
  local repo_url="$1"
  local dest_path="$2"
  if [ ! -d "$dest_path" ]; then
    printf 'Installing %s...\n' "$(basename "$dest_path")"
    git clone "$repo_url" "$dest_path"
  else
    printf '%s already installed, skipping.\n' "$(basename "$dest_path")"
  fi
}

install_plugin "https://github.com/reobin/typewritten" "$ZSH_CUSTOM/themes/typewritten"
install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

(
  cd "$target_home/.config/opencode"
  npx -y skills add wondelai/skills/pragmatic-programmer
  npx -y @bybrawe/opencode-loop
)

printf '✅ Dotfiles applied from %s into %s\n' "$source_root" "$target_home"
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
bash tests/install/test_install_cli_contract.sh
```

Expected:

```text
PASS test_install_cli_contract
```

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install/test_install_cli_contract.sh
git commit -m "feat(install): require explicit safe install roots"
```

### Task 4: Encode agent guardrails and the operator verification runbook

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Create: `docs/superpowers/runbooks/devpod-persistence-verification.md`
- Test: `tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Write the failing verification test**

Create `tests/docs/test_bare_hub_guardrails.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

grep -F "Agents MUST NOT run with CWD set to a hub root." .config/opencode/AGENTS.md >/dev/null
grep -F "Refused — hub-root CWD detected. Provide explicit worktree path." .config/opencode/AGENTS.md >/dev/null
grep -F "kubectl get pod <workspace-pod> -o jsonpath='{range .spec.volumes[*]}{.name}{\"\\t\"}{.persistentVolumeClaim.claimName}{\"\\t\"}{.hostPath.path}{\"\\n\"}{end}'" docs/superpowers/runbooks/devpod-persistence-verification.md >/dev/null
grep -F "./scripts/install-validate-source.sh /tmp/race/src /tmp/race/src/current" docs/superpowers/runbooks/devpod-persistence-verification.md >/dev/null

printf 'PASS test_bare_hub_guardrails\n'
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: FAIL because the hub-root sentence is missing from `.config/opencode/AGENTS.md` and the runbook file does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Append this exact paragraph under the **Subagent delegation (short)** section in `.config/opencode/AGENTS.md`:

```md
- Bare-hub guardrail: Agents MUST NOT run with CWD set to a hub root. All repository tasks must receive both the repo hub path and the explicit worktree path. If CWD is detected to be a hub root, the agent must refuse with: `Refused — hub-root CWD detected. Provide explicit worktree path.`
```

Create `docs/superpowers/runbooks/devpod-persistence-verification.md` with this exact content:

```md
# DevPod Persistence And Bare-Hub Verification Runbook

## 1. Identify the `/workspaces` volume type

```bash
kubectl get pod <workspace-pod> -o jsonpath='{range .spec.volumes[*]}{.name}{"\t"}{.persistentVolumeClaim.claimName}{"\t"}{.hostPath.path}{"\n"}{end}'
kubectl describe pvc <pvc-name>
```

Expected: the `/workspaces` volume shows either a PVC claim name or a concrete `hostPath`.

## 2. Verify pod/node persistence

```bash
kubectl exec <workspace-pod> -- sh -lc 'echo persist-1 > /workspaces/.persist-check && sync && ls -l /workspaces/.persist-check'
kubectl delete pod <workspace-pod>
kubectl exec <new-workspace-pod> -- cat /workspaces/.persist-check
docker restart k3d-<cluster>-server-0
kubectl exec <workspace-pod> -- cat /workspaces/.persist-check
```

Expected: `/workspaces/.persist-check` survives pod recreation and node restart.

## 3. Verify installer symlink-race refusal

```bash
mkdir -p /tmp/race/src /tmp/race/home
printf ok > /tmp/race/src/good
ln -snf /tmp/race/src/good /tmp/race/src/current
(while true; do ln -snf /etc/passwd /tmp/race/src/current; ln -snf /tmp/race/src/good /tmp/race/src/current; done) &
./scripts/install-validate-source.sh /tmp/race/src /tmp/race/src/current
```

Expected: the validator refuses with `refused: symlink escapes source root`.

## 4. Verify hub-root refusal

```bash
mkdir -p /tmp/hub-check/main /tmp/hub-check/repos /tmp/hub-check/state
(cd /tmp/hub-check && /home/vscode/dotfiles/install.sh --source-root /home/vscode/dotfiles --target-home "$HOME" --dry-run -y)
```

Expected: the installer refuses with `Refused — hub-root CWD detected. Provide explicit worktree path.`
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
git add .config/opencode/AGENTS.md docs/superpowers/runbooks/devpod-persistence-verification.md tests/docs/test_bare_hub_guardrails.sh
git commit -m "docs(guardrails): document bare-hub safety checks"
```

### Task 5: Verify the Part 1 tracer bullet end-to-end

Verification checkpoint task (non-TDD by design; no new implementation).

**Files:**
- None

- [ ] **Step 1: Run the full Part 1 verification set**

Run:

```bash
bash tests/devpod/test_devpod_ensure_layout.sh && bash tests/install/test_install_validate_source.sh && bash tests/install/test_install_cli_contract.sh && bash tests/docs/test_bare_hub_guardrails.sh
```

Expected:

```text
PASS test_devpod_ensure_layout
PASS test_install_validate_source
PASS test_install_cli_contract
PASS test_bare_hub_guardrails
```

- [ ] **Step 2: Manually verify the workspace contract**

Run:

```bash
bash scripts/devpod-ensure-layout.sh /tmp/manual-dotfiles-check
ls -ld /tmp/manual-dotfiles-check/state /tmp/manual-dotfiles-check/state/opencode /tmp/manual-dotfiles-check/state/opencode/exported_sessions
```

Expected: the three directories exist and each has mode `drwx------`.

- [ ] **Step 3: Commit the Part 1 verification checkpoint**

```bash
git add .
git commit -m "test(plan): verify bare-hub manager tracer bullet"
```

---

## Part 2 — OpenCode Export And State Backup: Executable Next Step

### Short checklist for the next execution phase

- [ ] Add the session exporter (`scripts/opencode-export-all-sessions.sh`) and its contract test.
- [ ] Add the staging script (`scripts/prepare-state-backup-set.sh`) and verify `tmp/` exclusion plus last-known-good preservation.
- [ ] Add the host pull + `restic` script (`scripts/host-pull-and-restic-backup.sh`) and its stubbed contract test.
- [ ] Add the recovery script (`scripts/recover-opencode-sessions.sh`) and verify newest-first dedupe.
- [ ] Add the backup runbook (`docs/superpowers/runbooks/opencode-export-and-state-backup.md`) and wire the half-hour schedule there.

### Task 6: Export OpenCode sessions into `state/opencode/exported_sessions/`

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
  trap cleanup_tmpfile RETURN
  "$opencode_bin" export "$session_id" > "$tmpfile"
  python3 - "$tmpfile" "$session_id" <<'PY'
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
  rm -f "$export_root"/*-"$session_id"-*.json
  final_path="$export_root/$timestamp-$session_id-$slug.json"
  mv "$tmpfile" "$final_path"
  tmpfile=""
  trap - RETURN
  printf 'exported %s -> %s\n' "$session_id" "$final_path"
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

### Task 7: Stage durable state into the double-buffer backup set

**Files:**
- Create: `scripts/prepare-state-backup-set.sh`
- Test: `tests/opencode/test_prepare_state_backup_set.sh`

- [ ] **Step 1: Write the failing integration/contract test**

Create `tests/opencode/test_prepare_state_backup_set.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspaces/dotfiles"
staging_root="$tmpdir/staging"

mkdir -p "$workspace_root/state/opencode/exported_sessions" "$workspace_root/repos/omnipy/state" "$workspace_root/tmp/cache"
printf 'session-json\n' > "$workspace_root/state/opencode/exported_sessions/export.json"
printf 'repo-state\n' > "$workspace_root/repos/omnipy/state/cache.txt"
printf 'skip-me\n' > "$workspace_root/tmp/cache/debug.log"

./scripts/prepare-state-backup-set.sh "$workspace_root" "$staging_root" >"$tmpdir/out.txt"

[ -f "$staging_root/current/state/opencode/exported_sessions/export.json" ]
[ -f "$staging_root/current/repos/omnipy/state/cache.txt" ]
[ ! -e "$staging_root/current/tmp/cache/debug.log" ]

grep -F "ok: staged backup set" "$tmpdir/out.txt" >/dev/null

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
staging_root="${2:-/tmp/opencode-backup-staging}"
current_root="$staging_root/current"
next_root="$staging_root/next"

rm -rf "$next_root"
mkdir -p "$next_root"

if [ -d "$current_root" ]; then
  cp -a "$current_root/." "$next_root/"
fi

rm -rf "$next_root/state" "$next_root/repos"
mkdir -p "$next_root/state" "$next_root/repos"

cp -a "$workspace_root/state/." "$next_root/state/"

if [ -d "$workspace_root/repos" ]; then
  while IFS= read -r repo_state_dir; do
    repo_rel="${repo_state_dir#"$workspace_root/"}"
    mkdir -p "$next_root/$(dirname "$repo_rel")"
    cp -a "$repo_state_dir" "$next_root/$repo_rel"
  done < <(find "$workspace_root/repos" -mindepth 2 -maxdepth 2 -type d -name state | sort)
fi

rm -rf "$current_root"
mv "$next_root" "$current_root"

printf 'ok: staged backup set at %s\n' "$current_root"
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

- [ ] **Step 5: Migration and cleanup before commit**

Run:

```bash
mkdir -p state/opencode/exported_sessions
mkdir -p repos && : > repos/.keep
```

Expected: the durable-state directories exist before the backup script is introduced into regular use.

- [ ] **Step 6: Commit**

```bash
git add scripts/prepare-state-backup-set.sh tests/opencode/test_prepare_state_backup_set.sh repos/.keep
git commit -m "feat(backup): stage durable state for host snapshots"
```

### Task 8: Add the host-side pull and `restic` snapshot step

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

fixture_dir="$tmpdir/fixture"

mkdir -p "$tmpdir/bin" "$tmpdir/host-copy" "$fixture_dir"
printf 'staged-file\n' > "$fixture_dir/export.json"
export fixture_dir

cat > "$tmpdir/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 11 ] \
  && [ "$1" = "exec" ] \
  && [ "$2" = "-n" ] \
  && [ "$3" = "devpod" ] \
  && [ "$4" = "workspace-pod" ] \
  && [ "$5" = "--" ] \
  && [ "$6" = "tar" ] \
  && [ "$7" = "-C" ] \
  && [ "$8" = "/tmp/opencode-backup-staging/current" ] \
  && [ "$9" = "-cf" ] \
  && [ "${10}" = "-" ] \
  && [ "${11}" = "." ]; then
  tar -C "${fixture_dir}" -cf - .
  exit 0
fi
printf 'unexpected kubectl args: %s\n' "$*" >&2
exit 1
EOF

cat > "$tmpdir/bin/restic" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'restic called %s\n' "$*"
EOF

chmod +x "$tmpdir/bin/kubectl" "$tmpdir/bin/restic"

PATH="$tmpdir/bin:$PATH" POD_NAME="workspace-pod" NAMESPACE="devpod" HOST_BACKUP_ROOT="$tmpdir/host-copy" RESTIC_REPOSITORY="/tmp/restic-repo" ./scripts/host-pull-and-restic-backup.sh >"$tmpdir/out.txt"

[ -f "$tmpdir/host-copy/current/staged.tar" ]
grep -F "restic called backup $tmpdir/host-copy/current" "$tmpdir/out.txt" >/dev/null

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

pod_name="${POD_NAME:?set POD_NAME}"
namespace="${NAMESPACE:?set NAMESPACE}"
host_backup_root="${HOST_BACKUP_ROOT:?set HOST_BACKUP_ROOT}"
restic_repository="${RESTIC_REPOSITORY:?set RESTIC_REPOSITORY}"

mkdir -p "$host_backup_root/current"

kubectl exec -n "$namespace" "$pod_name" -- tar -C /tmp/opencode-backup-staging/current -cf - . > "$host_backup_root/current/staged.tar"
mkdir -p "$host_backup_root/current/extracted"
tar -C "$host_backup_root/current/extracted" -xf "$host_backup_root/current/staged.tar"

RESTIC_REPOSITORY="$restic_repository" restic backup "$host_backup_root/current"
```

Create `docs/superpowers/runbooks/opencode-export-and-state-backup.md` with this exact content:

```md
# OpenCode Export And State Backup Runbook

## Phase A (`:00`) — in-pod export and staging

```bash
bash scripts/opencode-export-all-sessions.sh
bash scripts/prepare-state-backup-set.sh /workspaces/dotfiles /tmp/opencode-backup-staging
```

Expected: `state/opencode/exported_sessions/` contains one newest export per session and `/tmp/opencode-backup-staging/current` is refreshed.

## Phase B (`:30`) — host pull and snapshot

```bash
POD_NAME=<workspace-pod> NAMESPACE=<namespace> HOST_BACKUP_ROOT="$HOME/.cache/devpod-backups/opencode" RESTIC_REPOSITORY=<restic-repo> bash scripts/host-pull-and-restic-backup.sh
```

Expected: a new `restic` snapshot is created from the pulled `current/` tree.

## Cleanup and migration

- Move any keep-worthy repo-local flat files from `tmp/` into the relevant `state/` directory before enabling the cron jobs.
- Remove legacy backup instructions that mention copying OpenCode internal storage directly.
- Keep `tmp/` disposable; do not add it to the staged tree.
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

### Task 10: Verify the full Part 2 pipeline before claiming completion

**Files:**
- None

- [ ] **Step 1: Run the full automated Part 2 verification set**

Run:

```bash
bash tests/opencode/test_export_all_sessions.sh && bash tests/opencode/test_prepare_state_backup_set.sh && bash tests/opencode/test_host_pull_and_restic_backup.sh && bash tests/opencode/test_recover_opencode_sessions.sh
```

Expected:

```text
PASS test_export_all_sessions
PASS test_prepare_state_backup_set
PASS test_host_pull_and_restic_backup
PASS test_recover_opencode_sessions
```

- [ ] **Step 2: Run the live command sequence manually once**

Run:

```bash
bash scripts/opencode-export-all-sessions.sh && bash scripts/prepare-state-backup-set.sh /workspaces/dotfiles /tmp/opencode-backup-staging
```

Expected: the exporter prints one line per exported or refreshed session and the staging script prints `ok: staged backup set at /tmp/opencode-backup-staging/current`.

- [ ] **Step 3: Run the host pull against a real pod**

Run:

```bash
POD_NAME=<workspace-pod> NAMESPACE=<namespace> HOST_BACKUP_ROOT="$HOME/.cache/devpod-backups/opencode" RESTIC_REPOSITORY=<restic-repo> bash scripts/host-pull-and-restic-backup.sh
```

Expected: `restic backup` exits `0` and creates a new snapshot.

- [ ] **Step 4: Commit the Part 2 verification checkpoint**

```bash
git add .
git commit -m "test(backup): verify opencode export and backup pipeline"
```

---

## Self-Review

### Spec coverage

- Bare-hub manager layout and `/workspaces/dotfiles/main` editor target — **Task 1**.
- Source-root validation, hub-root refusal, and safe install contract — **Tasks 2-4**.
- Persistence/operator verification commands from the earlier security doc — **Task 4**.
- OpenCode durable export instead of internal-state copying — **Task 6**.
- Double-buffer staging and `tmp/` exclusion — **Task 7**.
- Host-side pull plus `restic` backup — **Task 8**.
- Recovery via newest-first dedupe and `opencode import` — **Task 9**.

### Placeholder scan

This document intentionally contains no `TODO`, `TBD`, or “implement later” placeholders. Every task includes exact file paths, exact commands, and explicit expected outputs.

### Type and naming consistency

- Durable runtime root: `state/`
- Durable OpenCode export root: `state/opencode/exported_sessions/`
- Disposable runtime root: `tmp/`
- Host staging root: `/tmp/opencode-backup-staging/current`
- Agent refusal string: `Refused — hub-root CWD detected. Provide explicit worktree path.`

### Pragmatic-programmer quick diagnostic

Score: **9/10**

Remaining remediation tasks to reach 10/10:

1. If the exporter and recovery scripts grow further, factor shared JSON parsing into one helper instead of duplicating inline Python.
2. Keep host backup write access host-side only; do not later mount the real backup destination into DevPod for convenience.
