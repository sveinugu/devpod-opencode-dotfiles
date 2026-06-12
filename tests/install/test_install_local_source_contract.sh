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

unset HUB_INSTALL_BRANCH HUB_INSTALL_BRANCH_DIR

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

if [ -f "scripts/lib/validate_install_source_tree.sh" ]; then
  mkdir -p "$workspace_root/main/scripts/lib" "$workspace_root/work/feature-x/scripts/lib" "$workspace_root/scripts/lib"
  cp "scripts/lib/validate_install_source_tree.sh" "$workspace_root/main/scripts/lib/validate_install_source_tree.sh"
  cp "scripts/lib/validate_install_source_tree.sh" "$workspace_root/work/feature-x/scripts/lib/validate_install_source_tree.sh"
  cp "scripts/lib/validate_install_source_tree.sh" "$workspace_root/scripts/lib/validate_install_source_tree.sh"
  chmod +x \
    "$workspace_root/main/scripts/lib/validate_install_source_tree.sh" \
    "$workspace_root/work/feature-x/scripts/lib/validate_install_source_tree.sh" \
    "$workspace_root/scripts/lib/validate_install_source_tree.sh"
fi

(
  cd "$offcwd"
  HOME="$target_home" bash "$workspace_root/main/install.sh" --dry-run -y >"$tmpdir/main.out" 2>&1
)

[ -f "$workspace_root/state/hub/etc/install.env" ] || {
  printf 'expected install.sh to publish state/hub/etc/install.env\n' >&2
  exit 1
}

grep -F "export HUB_INSTALL_BRANCH=main" "$workspace_root/state/hub/etc/install.env" >/dev/null || {
  printf 'expected install.env to publish HUB_INSTALL_BRANCH=main\n' >&2
  exit 1
}

grep -F "export HUB_INSTALL_BRANCH_DIR=$workspace_root/main" "$workspace_root/state/hub/etc/install.env" >/dev/null || {
  printf 'expected install.env to publish HUB_INSTALL_BRANCH_DIR for main\n' >&2
  exit 1
}

grep -F "DRY-RUN ln -sfn $workspace_root/main/.zshrc $target_home/.zshrc" "$tmpdir/main.out" >/dev/null
grep -F "DRY-RUN ln -sfn $workspace_root/main/.config/opencode $target_home/.config/opencode" "$tmpdir/main.out" >/dev/null
! grep -F "$workspace_root/work/feature-x/.zshrc" "$tmpdir/main.out" >/dev/null
grep -F 'shell helper dhub() was not detected' "$tmpdir/main.out" >/dev/null || {
  printf 'expected install helper note to reference dhub()\n' >&2
  exit 1
}
if grep -F 'shell helper dd() was not detected' "$tmpdir/main.out" >/dev/null; then
  printf 'did not expect deprecated dd() install helper note\n' >&2
  exit 1
fi

(
  cd "$offcwd"
  HOME="$target_home" bash "$workspace_root/work/feature-x/install.sh" --dry-run -y >"$tmpdir/feature.out" 2>&1
)

grep -F "export HUB_INSTALL_BRANCH=feature-x" "$workspace_root/state/hub/etc/install.env" >/dev/null || {
  printf 'expected install.env to publish HUB_INSTALL_BRANCH for feature worktree\n' >&2
  exit 1
}

grep -F "export HUB_INSTALL_BRANCH_DIR=$workspace_root/work/feature-x" "$workspace_root/state/hub/etc/install.env" >/dev/null || {
  printf 'expected install.env to publish HUB_INSTALL_BRANCH_DIR for feature worktree\n' >&2
  exit 1
}

workspace_quoted="$tmpdir/workspace quoted"
target_home_quoted="$tmpdir/home quoted"
offcwd_quoted="$tmpdir/offcwd quoted"

mkdir -p \
  "$workspace_quoted/.bare" \
  "$workspace_quoted/work/feature branch/.config/opencode" \
  "$workspace_quoted/state" \
  "$target_home_quoted" \
  "$offcwd_quoted"

printf 'export QUOTED=1\n' > "$workspace_quoted/work/feature branch/.zshrc"
printf '{"name":"quoted"}\n' > "$workspace_quoted/work/feature branch/.config/opencode/opencode.jsonc"

if [ -f "install.sh" ]; then
  cp "install.sh" "$workspace_quoted/work/feature branch/install.sh"
  chmod +x "$workspace_quoted/work/feature branch/install.sh"
fi

if [ -f "scripts/lib/validate_install_source_tree.sh" ]; then
  mkdir -p "$workspace_quoted/work/feature branch/scripts/lib"
  cp "scripts/lib/validate_install_source_tree.sh" "$workspace_quoted/work/feature branch/scripts/lib/validate_install_source_tree.sh"
  chmod +x "$workspace_quoted/work/feature branch/scripts/lib/validate_install_source_tree.sh"
fi

(
  cd "$offcwd_quoted"
  HOME="$target_home_quoted" WORKSPACE_ROOT="$workspace_quoted" bash "$workspace_quoted/work/feature branch/install.sh" --dry-run -y >"$tmpdir/quoted.out" 2>&1
)

quoted_install_env="$workspace_quoted/state/hub/etc/install.env"
[ -f "$quoted_install_env" ] || {
  printf 'expected quoted install env to exist\n' >&2
  exit 1
}

quoted_vars_out="$(set +u; source "$quoted_install_env"; printf '%s\n%s\n' "$HUB_INSTALL_BRANCH" "$HUB_INSTALL_BRANCH_DIR")"
quoted_branch="$(printf '%s' "$quoted_vars_out" | sed -n '1p')"
quoted_dir="$(printf '%s' "$quoted_vars_out" | sed -n '2p')"
[ "$quoted_branch" = "feature branch" ] || {
  printf 'expected quoted HUB_INSTALL_BRANCH round-trip, got %s\n' "$quoted_branch" >&2
  exit 1
}
[ "$quoted_dir" = "$workspace_quoted/work/feature branch" ] || {
  printf 'expected quoted HUB_INSTALL_BRANCH_DIR round-trip, got %s\n' "$quoted_dir" >&2
  exit 1
}

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

(
  cd "$offcwd"
  if HOME="$target_home" HUB_INSTALL_BRANCH=wrong-branch bash "$workspace_root/main/install.sh" --dry-run -y >"$tmpdir/branch-mismatch.out" 2>&1; then
    printf 'expected HUB_INSTALL_BRANCH mismatch to fail\n' >&2
    exit 1
  fi
)

grep -F 'refused: HUB_INSTALL_BRANCH does not match install source' "$tmpdir/branch-mismatch.out" >/dev/null || {
  printf 'expected HUB_INSTALL_BRANCH mismatch refusal message\n' >&2
  exit 1
}

(
  cd "$offcwd"
  if HOME="$target_home" HUB_INSTALL_BRANCH_DIR="$workspace_root/wrong-dir" bash "$workspace_root/main/install.sh" --dry-run -y >"$tmpdir/dir-mismatch.out" 2>&1; then
    printf 'expected HUB_INSTALL_BRANCH_DIR mismatch to fail\n' >&2
    exit 1
  fi
)

grep -F 'refused: HUB_INSTALL_BRANCH_DIR does not match install source' "$tmpdir/dir-mismatch.out" >/dev/null || {
  printf 'expected HUB_INSTALL_BRANCH_DIR mismatch refusal message\n' >&2
  exit 1
}

stale_values_out="$(set +u; source "$workspace_root/state/hub/etc/install.env"; printf '%s\n%s\n' "$HUB_INSTALL_BRANCH" "$HUB_INSTALL_BRANCH_DIR")"
stale_branch="$(printf '%s' "$stale_values_out" | sed -n '1p')"
stale_branch_dir="$(printf '%s' "$stale_values_out" | sed -n '2p')"

(
  cd "$offcwd"
  HOME="$target_home" HUB_INSTALL_BRANCH="$stale_branch" HUB_INSTALL_BRANCH_DIR="$stale_branch_dir" bash "$workspace_root/main/install.sh" --dry-run -y >"$tmpdir/stale-inherited.out" 2>&1
)

grep -F "export HUB_INSTALL_BRANCH=main" "$workspace_root/state/hub/etc/install.env" >/dev/null || {
  printf 'expected inherited HUB_INSTALL_BRANCH to be treated as stale and rewritten to main\n' >&2
  exit 1
}

grep -F "export HUB_INSTALL_BRANCH_DIR=$workspace_root/main" "$workspace_root/state/hub/etc/install.env" >/dev/null || {
  printf 'expected inherited HUB_INSTALL_BRANCH_DIR to be treated as stale and rewritten to main path\n' >&2
  exit 1
}

# Regression: existing non-symlink target directory must be replaced, not nested.
workspace_reg="$tmpdir/workspace-reg"
home_reg="$tmpdir/home-reg"
bin_reg="$tmpdir/bin-reg"
mkdir -p "$workspace_reg/main/.config/opencode" "$workspace_reg/main/scripts" "$home_reg/.config/opencode" "$home_reg/.oh-my-zsh" "$bin_reg"
touch "$home_reg/.oh-my-zsh/oh-my-zsh.sh"

printf 'export REG_ZSHRC=1\n' > "$workspace_reg/main/.zshrc"
printf 'source "$HOME/.zshrc"\n' > "$workspace_reg/main/.zprofile"
printf '{"name":"reg"}\n' > "$workspace_reg/main/.config/opencode/opencode.jsonc"
printf 'stale\n' > "$home_reg/.config/opencode/stale.txt"

cp "install.sh" "$workspace_reg/main/install.sh"
mkdir -p "$workspace_reg/main/scripts/lib"
cp "scripts/lib/validate_install_source_tree.sh" "$workspace_reg/main/scripts/lib/validate_install_source_tree.sh"
chmod +x "$workspace_reg/main/install.sh" "$workspace_reg/main/scripts/lib/validate_install_source_tree.sh"

cat > "$bin_reg/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = "clone" ]; then
  mkdir -p "$3"
  exit 0
fi
command git "$@"
EOF
chmod +x "$bin_reg/git"

cat > "$bin_reg/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ ! -d "$HOME/.config/opencode" ]; then
  printf 'missing opencode config directory\n' >&2
  exit 77
fi
exit 0
EOF
chmod +x "$bin_reg/npx"

(
  cd "$offcwd"
  PATH="$bin_reg:$PATH" HOME="$home_reg" WORKSPACE_ROOT="$workspace_reg" bash "$workspace_reg/main/install.sh" >"$tmpdir/reg.out" 2>&1
)

[ -L "$home_reg/.config/opencode" ] || {
  printf 'expected ~/.config/opencode to be a symlink after install\n' >&2
  exit 1
}

resolved_opencode="$(readlink -f "$home_reg/.config/opencode")"
[ "$resolved_opencode" = "$workspace_reg/main/.config/opencode" ] || {
  printf 'expected ~/.config/opencode symlink target %s, got %s\n' "$workspace_reg/main/.config/opencode" "$resolved_opencode" >&2
  exit 1
}

[ ! -e "$home_reg/.config/opencode/stale.txt" ] || {
  printf 'expected stale file to be removed when replacing directory target\n' >&2
  exit 1
}

printf 'PASS test_install_local_source_contract\n'
