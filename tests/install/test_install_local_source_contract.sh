#!/usr/bin/env bash
set -euo pipefail

# Contract:
# - The managed workspace root in DevSpace is /workspaces/dotfiles.
# - install.sh must autodetect its own real location using dirname "${BASH_SOURCE[0]}"
#   plus realpath semantics.
# - It must use THE WORKTREE IT LIVES IN as the install source, regardless of PWD.
# - It must refuse hub-root execution.
#
# For isolated execution outside a real DevSpace pod, WORKSPACE_ROOT may be overridden.
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
