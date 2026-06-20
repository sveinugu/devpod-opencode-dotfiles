# P2 Slice 3: install.sh Structure Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `install.sh` into phase-oriented helper scripts under `scripts/lib/install/` while preserving every existing CLI surface, refusal path, side effect, and user-visible message.

**Architecture:** Keep `install.sh` as a thin orchestrator that resolves its own checkout path, sources four phase helpers, and then runs parse → resolve → validate/persist → materialize in order. Use one new helper-layout contract test plus the existing five install tests and one targeted DevSpace guard to prove the extracted structure still behaves exactly like the current script.

**Tech Stack:** Bash, sourced shell helper files under `scripts/lib/install/`, existing shell characterization tests under `tests/install/`, and one targeted DevSpace guard under `tests/devspace/`.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved slice: `P2 Slice 3 — Refactor: install.sh structure`
- Reference plan format: `docs/superpowers/plans/2026-06-20-p1-docs-orientation.md`
- Existing implementation surface: `install.sh`
- Existing validation dependency to reuse unchanged: `scripts/lib/validate_install_source_tree.sh`
- Existing install safety rails that must still pass after the refactor:
  - `tests/install/test_install_local_source_contract.sh`
  - `tests/install/test_install_validate_source.sh`
  - `tests/install/test_read_install_env.sh`
  - `tests/install/test_install_oh_my_zsh_failure_surface.sh`
  - `tests/install/test_workspace_navigation_shell.sh`
- Related behavior/documentation guards to rerun:
  - `tests/devspace/test_workspace_repair.sh`
  - `tests/docs/test_p1_docs_orientation.sh`

## Scope

### In scope

- Extract the current `install.sh` flow into these phase helpers:
  - `scripts/lib/install/parse-args.sh`
  - `scripts/lib/install/resolve-source.sh`
  - `scripts/lib/install/validate-source.sh`
  - `scripts/lib/install/materialize.sh`
- Keep `install.sh` as a thin orchestrator that resolves its own location, sources those helpers, and runs them in sequence.
- Preserve exactly:
  - CLI syntax: `install.sh [--dry-run] [-y|--yes]`
  - hub-root refusal text
  - validator-missing refusal text
  - `HUB_INSTALL_BRANCH*` mismatch refusal texts
  - `install.env` write format
  - `dhub()` helper note text
  - oh-my-zsh install behavior and failure surface
  - symlink orchestration, plugin installs, and OpenCode bootstrap commands
- Add one structural contract test that locks the new helper layout.
- Update synthetic-workspace test fixtures so the refactored `install.sh` can source its new helper files during tests.

### Out of scope

- No CLI changes.
- No new features.
- No error-message wording changes.
- No changes to `scripts/lib/validate_install_source_tree.sh` behavior.
- No changes to `scripts/lib/read-install-env.sh` behavior.
- No runbook, policy, or README content changes.
- No refactor of `bin/new-worktree`, `bin/repair-workspace`, or navigation commands beyond the one structure-sensitive assertion update required by this slice.

## Proposed file map

- Create: `scripts/lib/install/parse-args.sh` — owns `--dry-run` / `-y|--yes` parsing and preserves the exact usage refusal.
- Create: `scripts/lib/install/resolve-source.sh` — owns workspace/home path resolution and install-branch detection.
- Create: `scripts/lib/install/validate-source.sh` — owns hub-root refusal, validator execution, stale inherited env cleanup, branch/dir mismatch refusals, `install.env` persistence, and the `dhub()` helper note.
- Create: `scripts/lib/install/materialize.sh` — owns oh-my-zsh install, symlink helpers, plugin installs, OpenCode bootstrap commands, and the final success message.
- Create: `tests/install/test_install_helper_layout.sh` — locks the new helper-file layout and the thin-orchestrator call order.
- Modify: `install.sh` — becomes the thin orchestrator while preserving the existing top comment block.
- Modify: `tests/install/test_install_local_source_contract.sh` — copies the new helper files into synthetic workspaces before invoking the refactored installer.
- Modify: `tests/install/test_install_oh_my_zsh_failure_surface.sh` — copies the new helper files into the synthetic checkout before invoking the refactored installer.
- Modify: `tests/devspace/test_workspace_repair.sh` — moves the file-based oh-my-zsh guard assertion from top-level `install.sh` to `scripts/lib/install/materialize.sh`.
- Verify only:
  - `tests/install/test_install_validate_source.sh`
  - `tests/install/test_read_install_env.sh`
  - `tests/install/test_workspace_navigation_shell.sh`
  - `tests/docs/test_p1_docs_orientation.sh`

---

## Task 1: Lock the helper-layout refactor with a failing structural contract

**Files:**
- Create: `tests/install/test_install_helper_layout.sh`

- [ ] **Step 1: Write the failing helper-layout contract first**

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_install_helper_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
install_script="$repo_root/install.sh"
parse_args_helper="$repo_root/scripts/lib/install/parse-args.sh"
resolve_source_helper="$repo_root/scripts/lib/install/resolve-source.sh"
validate_source_helper="$repo_root/scripts/lib/install/validate-source.sh"
materialize_helper="$repo_root/scripts/lib/install/materialize.sh"

[ -f "$install_script" ] || fail "install.sh not found"
[ -f "$parse_args_helper" ] || fail "scripts/lib/install/parse-args.sh not found"
[ -f "$resolve_source_helper" ] || fail "scripts/lib/install/resolve-source.sh not found"
[ -f "$validate_source_helper" ] || fail "scripts/lib/install/validate-source.sh not found"
[ -f "$materialize_helper" ] || fail "scripts/lib/install/materialize.sh not found"

grep -F 'source "$source_root/scripts/lib/install/parse-args.sh"' "$install_script" >/dev/null || fail "install.sh should source parse-args helper"
grep -F 'source "$source_root/scripts/lib/install/resolve-source.sh"' "$install_script" >/dev/null || fail "install.sh should source resolve-source helper"
grep -F 'source "$source_root/scripts/lib/install/validate-source.sh"' "$install_script" >/dev/null || fail "install.sh should source validate-source helper"
grep -F 'source "$source_root/scripts/lib/install/materialize.sh"' "$install_script" >/dev/null || fail "install.sh should source materialize helper"

grep -F 'install_parse_args "$@"' "$install_script" >/dev/null || fail "install.sh should parse CLI args through the helper"
grep -F 'install_resolve_source_context' "$install_script" >/dev/null || fail "install.sh should resolve source context through the helper"
grep -F 'install_validate_source_context' "$install_script" >/dev/null || fail "install.sh should validate source context through the helper"
grep -F 'install_materialize' "$install_script" >/dev/null || fail "install.sh should materialize through the helper"

grep -F 'if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then' "$materialize_helper" >/dev/null || fail "materialize helper should preserve the file-based oh-my-zsh guard"

printf 'PASS test_install_helper_layout\n'
```

- [ ] **Step 2: Verify RED**

Run:

```bash
bash tests/install/test_install_helper_layout.sh
```

Expected: FAIL because `scripts/lib/install/*.sh` does not exist yet and `install.sh` does not yet source helper phases.

- [ ] **Step 3: Commit the red structural test**

```bash
git add tests/install/test_install_helper_layout.sh
git commit -m "test(install): lock helper layout contract"
```

---

## Task 2: Extract the phase helpers, thin `install.sh`, and update fixture-based tests

**Files:**
- Create: `scripts/lib/install/parse-args.sh`
- Create: `scripts/lib/install/resolve-source.sh`
- Create: `scripts/lib/install/validate-source.sh`
- Create: `scripts/lib/install/materialize.sh`
- Modify: `install.sh`
- Modify: `tests/install/test_install_local_source_contract.sh`
- Modify: `tests/install/test_install_oh_my_zsh_failure_surface.sh`
- Modify: `tests/devspace/test_workspace_repair.sh`
- Test: `tests/install/test_install_helper_layout.sh`
- Test: `tests/install/test_install_local_source_contract.sh`
- Test: `tests/install/test_install_validate_source.sh`
- Test: `tests/install/test_read_install_env.sh`
- Test: `tests/install/test_install_oh_my_zsh_failure_surface.sh`
- Test: `tests/install/test_workspace_navigation_shell.sh`
- Test: `tests/devspace/test_workspace_repair.sh`
- Test: `tests/docs/test_p1_docs_orientation.sh`

- [ ] **Step 1: Create the four helper files with these exact contents**

`scripts/lib/install/parse-args.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

install_usage() {
  printf 'usage: install.sh [--dry-run] [-y|--yes]\n' >&2
  exit 1
}

install_parse_args() {
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
        install_usage
        ;;
    esac
    shift
  done
}
```

`scripts/lib/install/resolve-source.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

install_detect_branch() {
  local current_branch=''

  if [ "$source_root" = "$workspace_root/main" ]; then
    printf 'main\n'
  elif [ "${source_root#"$workspace_root/work/"}" != "$source_root" ]; then
    printf '%s\n' "${source_root#"$workspace_root/work/"}"
  else
    if current_branch="$(git -C "$source_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
      :
    fi
    if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
      printf '%s\n' "$current_branch"
    else
      printf 'main\n'
    fi
  fi
}

install_resolve_source_context() {
  workspace_root="${WORKSPACE_ROOT:-/workspaces/dotfiles}"
  home_dir="${HOME:?HOME must be set}"
  validator="$source_root/scripts/lib/validate_install_source_tree.sh"

  install_branch="$(install_detect_branch)"
  install_branch_dir="$source_root"
  install_env_dir="$workspace_root/state/hub/etc"
  install_env_file="$install_env_dir/install.env"
  zsh_custom="${ZSH_CUSTOM:-$home_dir/.oh-my-zsh/custom}"
  oh_my_zsh_dir="$home_dir/.oh-my-zsh"
}
```

`scripts/lib/install/validate-source.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

install_unset_stale_inherited_env() {
  local install_env_values=''
  local install_env_branch=''
  local install_env_branch_dir=''

  if [ -f "$install_env_file" ]; then
    install_env_values="$(set +u; source "$install_env_file"; printf '%s\n%s\n' "${HUB_INSTALL_BRANCH:-}" "${HUB_INSTALL_BRANCH_DIR:-}")"
    install_env_branch="$(printf '%s' "$install_env_values" | sed -n '1p')"
    install_env_branch_dir="$(printf '%s' "$install_env_values" | sed -n '2p')"

    if [ -n "${HUB_INSTALL_BRANCH:-}" ] && [ "$HUB_INSTALL_BRANCH" = "$install_env_branch" ]; then
      unset HUB_INSTALL_BRANCH
    fi

    if [ -n "${HUB_INSTALL_BRANCH_DIR:-}" ] && [ "$HUB_INSTALL_BRANCH_DIR" = "$install_env_branch_dir" ]; then
      unset HUB_INSTALL_BRANCH_DIR
    fi
  fi
}

install_validate_branch_identity() {
  if [ -n "${HUB_INSTALL_BRANCH:-}" ] && [ "$HUB_INSTALL_BRANCH" != "$install_branch" ]; then
    printf 'refused: HUB_INSTALL_BRANCH does not match install source (expected %s, got %s)\n' "$install_branch" "$HUB_INSTALL_BRANCH" >&2
    exit 1
  fi

  if [ -n "${HUB_INSTALL_BRANCH_DIR:-}" ] && [ "$HUB_INSTALL_BRANCH_DIR" != "$install_branch_dir" ]; then
    printf 'refused: HUB_INSTALL_BRANCH_DIR does not match install source (expected %s, got %s)\n' "$install_branch_dir" "$HUB_INSTALL_BRANCH_DIR" >&2
    exit 1
  fi
}

install_publish_install_env() {
  export HUB_INSTALL_BRANCH="$install_branch"
  export HUB_INSTALL_BRANCH_DIR="$install_branch_dir"

  mkdir -p "$install_env_dir"
  cat > "$install_env_file" <<EOF
export HUB_INSTALL_BRANCH=$(printf '%q' "$HUB_INSTALL_BRANCH")
export HUB_INSTALL_BRANCH_DIR=$(printf '%q' "$HUB_INSTALL_BRANCH_DIR")
EOF
}

install_print_dhub_note() {
  if ! declare -F dhub >/dev/null 2>&1; then
    cat >&2 <<EOF
note: shell helper dhub() was not detected. Add this snippet to your shell config for quick navigation:
dhub() {
  local resolver="$source_root/scripts/lib/resolve-install-target.sh"
  local target
  if ! target="\$(HUB_INSTALL_ENV_FILE=\"$install_env_file\" bash \"\$resolver\")"; then
    return 1
  fi
  printf 'cd -> %s\n' "\$target"
  cd "\$target"
}
EOF
  fi
}

install_validate_source_context() {
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

  install_unset_stale_inherited_env
  install_validate_branch_identity
  install_publish_install_env
  install_print_dhub_note
}
```

`scripts/lib/install/materialize.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

install_link_path() {
  local source_path="$1"
  local target_path="$2"

  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN ln -sfn %s %s\n' "$source_path" "$target_path"
    return 0
  fi

  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    rm -rf "$target_path"
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

install_run_opencode_command() {
  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN (cd %s && %s)\n' "$home_dir/.config/opencode" "$*"
    return 0
  fi

  (
    cd "$home_dir/.config/opencode"
    "$@"
  )
}

install_ensure_oh_my_zsh() {
  if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then
    if [ -d "$oh_my_zsh_dir" ]; then rm -rf "$oh_my_zsh_dir"; fi
    if [ "$dry_run" = true ]; then
      printf 'DRY-RUN install oh-my-zsh to %s\n' "$oh_my_zsh_dir"
    else
      printf 'installing oh-my-zsh...\n'
      tmp_installer="$(mktemp)"
      if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$tmp_installer"; then
        printf 'failed to download oh-my-zsh installer\n' >&2
        rm -f "$tmp_installer"
        exit 1
      fi
      zsh "$tmp_installer" "" --unattended --skip-chsh
      rm -f "$tmp_installer"
    fi
  fi
}

install_materialize() {
  install_ensure_oh_my_zsh

  mkdir -p "$home_dir/.config"
  mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"

  install_link_path "$source_root/.zshrc" "$home_dir/.zshrc"
  install_link_path "$source_root/.zprofile" "$home_dir/.zprofile"

  printf 'installing workspace navigation package...\n'
  install_link_path "$source_root/.config/shell/workspace-navigation.zsh" "$home_dir/.config/shell/workspace-navigation.zsh"

  install_plugin "https://github.com/reobin/typewritten" "$zsh_custom/themes/typewritten"
  install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$zsh_custom/plugins/zsh-syntax-highlighting"
  install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$zsh_custom/plugins/zsh-autosuggestions"

  install_link_path "$source_root/.config/opencode" "$home_dir/.config/opencode"

  install_run_opencode_command npx -y skills add wondelai/skills/pragmatic-programmer -g -y
  install_run_opencode_command npx -y skills add wondelai/skills/clean-code -g -y
  install_run_opencode_command npx -y @bybrawe/opencode-loop

  if [ "$assume_yes" = true ] && [ "$dry_run" = true ]; then
    :
  fi

  printf 'ok: dotfiles applied from %s\n' "$source_root"
}
```

- [ ] **Step 2: Replace `install.sh` with this exact thin orchestrator**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Installs the dotfiles from the checkout that contains this script.
# High-level flow:
# 1. Resolve the install source/worktree and refuse hub-root execution.
# 2. Validate the source tree and persist install-branch state.
# 3. Link shell/OpenCode config into $HOME and install required tooling.
# Start with README.md for orientation, then see:
# - docs/superpowers/runbooks/devspace-bare-hub-usage.md
# - docs/superpowers/runbooks/devspace-workspace-lifecycle.md

script_path="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source_root="$(dirname "$script_path")"

source "$source_root/scripts/lib/install/parse-args.sh"
source "$source_root/scripts/lib/install/resolve-source.sh"
source "$source_root/scripts/lib/install/validate-source.sh"
source "$source_root/scripts/lib/install/materialize.sh"

install_parse_args "$@"
install_resolve_source_context
install_validate_source_context
install_materialize
```

- [ ] **Step 3: Update the synthetic-workspace tests so they copy the new helper directory too**

In `tests/install/test_install_local_source_contract.sh`, insert this helper function immediately after `unset HUB_INSTALL_BRANCH HUB_INSTALL_BRANCH_DIR`:

```bash
copy_install_support_tree() {
  local target_root="$1"

  mkdir -p "$target_root/scripts/lib"

  if [ -f "scripts/lib/validate_install_source_tree.sh" ]; then
    cp "scripts/lib/validate_install_source_tree.sh" "$target_root/scripts/lib/validate_install_source_tree.sh"
    chmod +x "$target_root/scripts/lib/validate_install_source_tree.sh"
  fi

  if [ -d "scripts/lib/install" ]; then
    mkdir -p "$target_root/scripts/lib/install"
    cp "scripts/lib/install/parse-args.sh" "$target_root/scripts/lib/install/parse-args.sh"
    cp "scripts/lib/install/resolve-source.sh" "$target_root/scripts/lib/install/resolve-source.sh"
    cp "scripts/lib/install/validate-source.sh" "$target_root/scripts/lib/install/validate-source.sh"
    cp "scripts/lib/install/materialize.sh" "$target_root/scripts/lib/install/materialize.sh"
    chmod +x \
      "$target_root/scripts/lib/install/parse-args.sh" \
      "$target_root/scripts/lib/install/resolve-source.sh" \
      "$target_root/scripts/lib/install/validate-source.sh" \
      "$target_root/scripts/lib/install/materialize.sh"
  fi
}
```

Then replace the first validator-copy block with these exact calls:

```bash
copy_install_support_tree "$workspace_root/main"
copy_install_support_tree "$workspace_root/work/feature-x"
copy_install_support_tree "$workspace_root"
```

Replace the quoted-workspace validator-copy block with this exact call:

```bash
copy_install_support_tree "$workspace_quoted/work/feature branch"
```

Replace the regression-workspace validator-copy block with this exact call:

```bash
copy_install_support_tree "$workspace_reg/main"
```

In `tests/install/test_install_oh_my_zsh_failure_surface.sh`, replace the existing two-line copy block under `mkdir -p "$source_root/.config/opencode" "$source_root/scripts/lib" "$home_dir" "$bin_dir"` with this exact block:

```bash
mkdir -p "$source_root/.config/opencode" "$source_root/scripts/lib/install" "$home_dir" "$bin_dir"

cp "$install_script" "$source_root/install.sh"
cp "$validator_script" "$source_root/scripts/lib/validate_install_source_tree.sh"
cp "$repo_root/scripts/lib/install/parse-args.sh" "$source_root/scripts/lib/install/parse-args.sh"
cp "$repo_root/scripts/lib/install/resolve-source.sh" "$source_root/scripts/lib/install/resolve-source.sh"
cp "$repo_root/scripts/lib/install/validate-source.sh" "$source_root/scripts/lib/install/validate-source.sh"
cp "$repo_root/scripts/lib/install/materialize.sh" "$source_root/scripts/lib/install/materialize.sh"
chmod +x \
  "$source_root/install.sh" \
  "$source_root/scripts/lib/validate_install_source_tree.sh" \
  "$source_root/scripts/lib/install/parse-args.sh" \
  "$source_root/scripts/lib/install/resolve-source.sh" \
  "$source_root/scripts/lib/install/validate-source.sh" \
  "$source_root/scripts/lib/install/materialize.sh"
```

In `tests/devspace/test_workspace_repair.sh`, replace the current top-of-file install guard setup with this exact block:

```bash
repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/bin/repair-workspace"
install_script="$repo_root/install.sh"
materialize_helper="$repo_root/scripts/lib/install/materialize.sh"

[ -f "$script" ] || fail "bin/repair-workspace not found"
[ -f "$install_script" ] || fail "install.sh not found"
[ -f "$materialize_helper" ] || fail "scripts/lib/install/materialize.sh not found"
grep -F 'if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then' "$materialize_helper" >/dev/null || fail "install materialize helper should use file-based oh-my-zsh guard"
```

- [ ] **Step 4: Verify GREEN on the structural contract and all existing safety rails**

Run:

```bash
bash tests/install/test_install_helper_layout.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_read_install_env.sh
bash tests/install/test_install_oh_my_zsh_failure_surface.sh
bash tests/install/test_workspace_navigation_shell.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/docs/test_p1_docs_orientation.sh
```

Expected: PASS for all eight commands.

- [ ] **Step 5: Commit the refactor slice**

```bash
git add install.sh \
  scripts/lib/install/parse-args.sh \
  scripts/lib/install/resolve-source.sh \
  scripts/lib/install/validate-source.sh \
  scripts/lib/install/materialize.sh \
  tests/install/test_install_helper_layout.sh \
  tests/install/test_install_local_source_contract.sh \
  tests/install/test_install_oh_my_zsh_failure_surface.sh \
  tests/devspace/test_workspace_repair.sh
git commit -m "refactor(install): split install flow into phases"
```

---

## Task 3: Final verification, refactor checkpoint, and handoff

**Files:**
- Review only: `install.sh`
- Review only: `scripts/lib/install/parse-args.sh`
- Review only: `scripts/lib/install/resolve-source.sh`
- Review only: `scripts/lib/install/validate-source.sh`
- Review only: `scripts/lib/install/materialize.sh`
- Review only: `tests/install/test_install_helper_layout.sh`
- Review only: `tests/install/test_install_local_source_contract.sh`
- Review only: `tests/install/test_install_oh_my_zsh_failure_surface.sh`
- Review only: `tests/devspace/test_workspace_repair.sh`

- [ ] **Step 1: Re-run the full focused verification set from a clean working state**

Run:

```bash
bash tests/install/test_install_helper_layout.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_read_install_env.sh
bash tests/install/test_install_oh_my_zsh_failure_surface.sh
bash tests/install/test_workspace_navigation_shell.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/docs/test_p1_docs_orientation.sh
```

Expected: PASS for all commands.

- [ ] **Step 2: Confirm the slice stayed tightly scoped**

Run:

```bash
git diff --name-only HEAD~1..HEAD
```

Expected: only these paths appear in the refactor commit:

- `install.sh`
- `scripts/lib/install/parse-args.sh`
- `scripts/lib/install/resolve-source.sh`
- `scripts/lib/install/validate-source.sh`
- `scripts/lib/install/materialize.sh`
- `tests/install/test_install_helper_layout.sh`
- `tests/install/test_install_local_source_contract.sh`
- `tests/install/test_install_oh_my_zsh_failure_surface.sh`
- `tests/devspace/test_workspace_repair.sh`

- [ ] **Step 3: Mandatory refactor checkpoint**

Review the extracted structure before handing off:

- `install.sh` should contain orchestration only: comment header, checkout self-resolution, helper sourcing, and four phase calls.
- `parse-args.sh` should own only CLI parsing and usage refusal.
- `resolve-source.sh` should own only path/branch resolution.
- `validate-source.sh` should own only safety checks, env persistence, and the `dhub()` helper note.
- `materialize.sh` should own only side-effecting install steps.
- The user-visible message strings in the helper files should remain byte-for-byte identical to the original script.

If any cleanup is needed during this checkpoint, rerun:

```bash
bash tests/install/test_install_helper_layout.sh
bash tests/install/test_install_local_source_contract.sh
bash tests/install/test_install_validate_source.sh
bash tests/install/test_read_install_env.sh
bash tests/install/test_install_oh_my_zsh_failure_surface.sh
bash tests/install/test_workspace_navigation_shell.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/docs/test_p1_docs_orientation.sh
```

- [ ] **Step 4: User Check-in**

Show the user the top-level `install.sh` orchestrator plus the four extracted helper file names and confirm that the phase split is clear before moving on to any later hotspot refactors.

- [ ] **Step 5: Final handoff note**

Report:

- changed files: `install.sh`, `scripts/lib/install/*.sh`, `tests/install/test_install_helper_layout.sh`, `tests/install/test_install_local_source_contract.sh`, `tests/install/test_install_oh_my_zsh_failure_surface.sh`, `tests/devspace/test_workspace_repair.sh`
- fresh verification commands run
- confirmation that the five pre-existing install tests still pass
- confirmation that CLI, refusal text, install-env writes, oh-my-zsh behavior, symlink behavior, plugin installs, and OpenCode bootstrap behavior were preserved

---

## Final verification checklist

- [ ] `bash tests/install/test_install_helper_layout.sh`
- [ ] `bash tests/install/test_install_local_source_contract.sh`
- [ ] `bash tests/install/test_install_validate_source.sh`
- [ ] `bash tests/install/test_read_install_env.sh`
- [ ] `bash tests/install/test_install_oh_my_zsh_failure_surface.sh`
- [ ] `bash tests/install/test_workspace_navigation_shell.sh`
- [ ] `bash tests/devspace/test_workspace_repair.sh`
- [ ] `bash tests/docs/test_p1_docs_orientation.sh`
- [ ] Re-read `HC-1` in `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` and confirm the final layout matches the approved parse → resolve → validate/persist → materialize split.
- [ ] Confirm `install.sh` still accepts only `--dry-run` and `-y|--yes` and still prints `usage: install.sh [--dry-run] [-y|--yes]` for unknown args.
- [ ] Confirm the hub-root refusal, validator-missing refusal, and `HUB_INSTALL_BRANCH*` mismatch refusals are unchanged.
- [ ] Confirm `install.env` still writes exported `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR` with `printf '%q'` quoting.
- [ ] Confirm the `dhub()` helper note still points at `scripts/lib/resolve-install-target.sh` using the same displayed shell snippet.
- [ ] Confirm the oh-my-zsh installer still uses the file-based guard `if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then` and still surfaces download/install failures.
- [ ] Confirm no behavior changed in symlink replacement, plugin install skipping, or OpenCode bootstrap commands.

## Notes for the implementing agent

- Move logic verbatim where possible; this slice is about boundaries, not behavior.
- Prefer extracting whole coherent blocks instead of rewriting them line-by-line.
- Keep the top comment block in `install.sh` exactly as it is now so `tests/docs/test_p1_docs_orientation.sh` remains green.
- Do not “improve” command output wording or the no-op `if [ "$assume_yes" = true ] && [ "$dry_run" = true ]; then : fi` block; preserving exact behavior matters more than style here.
- If an unexpected test fails outside this slice, stop and surface it instead of broadening the refactor.
