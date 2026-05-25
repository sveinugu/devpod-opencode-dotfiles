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
  grep -F 'mkdir -p "$home_dir/.config"' "install.sh" >/dev/null || {
    printf 'expected install.sh to create $HOME/.config/opencode before opencode commands\n' >&2
    exit 1
  }

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
exit 0
EOF
chmod +x "$bin_reg/npx"

(
  cd "$offcwd"
  PATH="$bin_reg:$PATH" HOME="$home_reg" WORKSPACE_ROOT="$workspace_reg" bash "$workspace_reg/main/install.sh" >"$tmpdir/reg.out"
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
