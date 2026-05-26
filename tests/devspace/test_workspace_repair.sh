#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_repair: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/bin/repair-workspace"
install_script="$repo_root/install.sh"

[ -f "$script" ] || fail "bin/repair-workspace not found"
[ -f "$install_script" ] || fail "install.sh not found"
grep -F 'if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then' "$install_script" >/dev/null || fail "install.sh should use file-based oh-my-zsh guard"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_workspace() {
  local root="$1"
  local home="$2"
  local source="$3"
  local branch="${4:-main}"

  mkdir -p "$root" "$home" "$source"

  git init "$source" >/dev/null 2>&1
  (
    cd "$source"
    git config user.name 'Test User'
    git config user.email 'test@example.com'
    git branch -M "$branch"
    cat > install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
touch "$HOME/.repair-install-ran"
    oh_my_zsh_dir="$HOME/.oh-my-zsh"
    if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then
      mkdir -p "$oh_my_zsh_dir"
      touch "$oh_my_zsh_dir/oh-my-zsh.sh"
    fi
EOF
    chmod +x install.sh
    printf 'zshrc fixture\n' > .zshrc
    printf 'zprofile fixture\n' > .zprofile
    mkdir -p .config/opencode
    printf '{"fixture":true}\n' > .config/opencode/opencode.json
    printf 'fixture\n' > README.md
    git add install.sh .zshrc .zprofile .config/opencode/opencode.json README.md
    git commit -m 'fixture' >/dev/null 2>&1
  )

  git clone --bare "$source" "$root/.bare" >/dev/null 2>&1
  git --git-dir="$root/.bare" worktree add "$root/main" "$branch" >/dev/null 2>&1
  mkdir -p "$root/work/feature" "$root/repos" "$root/state/hub/$branch" "$root/tmp/hub/$branch"
  printf 'tracked\n' > "$root/main/README.md"
  printf 'untracked\n' > "$root/main/.untracked-local"
  mkdir -p "$home/.config"
  ln -s "$root/main/.zshrc" "$home/.zshrc"
  ln -s "$root/main/.zprofile" "$home/.zprofile"
  ln -s "$root/main/.config/opencode" "$home/.config/opencode"
}

workspace_ok="$tmpdir/workspace-ok"
home_ok="$tmpdir/home-ok"
source_ok="$tmpdir/source-ok"
make_workspace "$workspace_ok" "$home_ok" "$source_ok"

rm -rf "$workspace_ok/work" "$workspace_ok/repos" "$workspace_ok/state/hub/main" "$workspace_ok/tmp/hub/main"
git --git-dir="$workspace_ok/.bare" worktree remove "$workspace_ok/main" --force >/dev/null 2>&1

HUB_WORKSPACE_ROOT="$workspace_ok" HUB_HOME_DIR="$home_ok" bash "$script" >"$tmpdir/repair-ok.out" 2>&1 || fail "repair should recover valid workspace"

[ -d "$workspace_ok/work" ] || fail "repair should recreate work directory"
[ -d "$workspace_ok/repos" ] || fail "repair should recreate repos directory"
[ -d "$workspace_ok/state/hub/main" ] || fail "repair should recreate state/hub/main"
[ -d "$workspace_ok/tmp/hub/main" ] || fail "repair should recreate tmp/hub/main"
[ -d "$workspace_ok/main" ] || fail "repair should reattach main when .bare is valid"
[ -f "$home_ok/.repair-install-ran" ] || fail "repair should run main/install.sh when restoring default symlinks"

workspace_preserve="$tmpdir/workspace-preserve"
home_preserve="$tmpdir/home-preserve"
source_preserve="$tmpdir/source-preserve"
make_workspace "$workspace_preserve" "$home_preserve" "$source_preserve"
rm -rf "$workspace_preserve/state/hub/main" "$workspace_preserve/tmp/hub/main"

HUB_WORKSPACE_ROOT="$workspace_preserve" HUB_HOME_DIR="$home_preserve" bash "$script" >"$tmpdir/repair-preserve.out" 2>&1 || fail "repair should succeed for structural-only recovery"

[ -f "$workspace_preserve/main/.untracked-local" ] || fail "repair must preserve untracked files"
[ -f "$workspace_preserve/main/README.md" ] || fail "repair must preserve tracked files"

workspace_symlink="$tmpdir/workspace-symlink"
home_symlink="$tmpdir/home-symlink"
source_symlink="$tmpdir/source-symlink"
make_workspace "$workspace_symlink" "$home_symlink" "$source_symlink"

git --git-dir="$workspace_symlink/.bare" worktree add -b feature-nonmain "$workspace_symlink/work/feature-nonmain" main >/dev/null 2>&1
rm -f "$home_symlink/.zshrc"
ln -s "$workspace_symlink/work/feature-nonmain/.zshrc" "$home_symlink/.zshrc"

HUB_WORKSPACE_ROOT="$workspace_symlink" HUB_HOME_DIR="$home_symlink" bash "$script" >"$tmpdir/repair-symlink.out" 2>&1 || fail "repair should allow valid non-main symlink target"

target_after="$(readlink "$home_symlink/.zshrc")"
[ "$target_after" = "$workspace_symlink/work/feature-nonmain/.zshrc" ] || fail "repair should preserve valid non-main /home symlink target"

workspace_invalid="$tmpdir/workspace-invalid"
home_invalid="$tmpdir/home-invalid"
mkdir -p "$workspace_invalid/.bare" "$home_invalid"
printf 'not-a-git-dir\n' > "$workspace_invalid/.bare/README"

set +e
HUB_WORKSPACE_ROOT="$workspace_invalid" HUB_HOME_DIR="$home_invalid" bash "$script" >"$tmpdir/repair-invalid.out" 2>&1
invalid_rc="$?"
set -e

[ "$invalid_rc" = "1" ] || fail "repair should refuse invalid .bare"
grep -F 'refused: existing .bare path is invalid' "$tmpdir/repair-invalid.out" >/dev/null || fail "repair should explain invalid .bare refusal"

workspace_conflict="$tmpdir/workspace-conflict"
home_conflict="$tmpdir/home-conflict"
source_conflict="$tmpdir/source-conflict"
make_workspace "$workspace_conflict" "$home_conflict" "$source_conflict"
rm -rf "$workspace_conflict/work"
printf 'conflict\n' > "$workspace_conflict/work"

set +e
HUB_WORKSPACE_ROOT="$workspace_conflict" HUB_HOME_DIR="$home_conflict" bash "$script" >"$tmpdir/repair-conflict.out" 2>&1
conflict_rc="$?"
set -e

[ "$conflict_rc" = "1" ] || fail "repair should refuse managed path type conflicts"
grep -F 'refused: managed path conflicts by type' "$tmpdir/repair-conflict.out" >/dev/null || fail "repair should explain conflict refusal"

workspace_ambiguous="$tmpdir/workspace-ambiguous"
home_ambiguous="$tmpdir/home-ambiguous"
source_ambiguous="$tmpdir/source-ambiguous"
make_workspace "$workspace_ambiguous" "$home_ambiguous" "$source_ambiguous"
git --git-dir="$workspace_ambiguous/.bare" worktree remove "$workspace_ambiguous/main" --force >/dev/null 2>&1
git --git-dir="$workspace_ambiguous/.bare" branch -D main >/dev/null 2>&1

git --git-dir="$workspace_ambiguous/.bare" branch feature/install-only master >/dev/null 2>&1 || true

set +e
HUB_WORKSPACE_ROOT="$workspace_ambiguous" HUB_HOME_DIR="$home_ambiguous" HUB_INSTALL_BRANCH='feature/install-only' bash "$script" >"$tmpdir/repair-ambiguous.out" 2>&1
ambiguous_rc="$?"
set -e

[ "$ambiguous_rc" = "1" ] || fail "repair should refuse ambiguous workspace identity even with HUB_INSTALL_BRANCH override"
grep -F 'refused: workspace identity is ambiguous' "$tmpdir/repair-ambiguous.out" >/dev/null || fail "repair should explain ambiguous identity refusal"

workspace_install_fail="$tmpdir/workspace-install-fail"
home_install_fail="$tmpdir/home-install-fail"
source_install_fail="$tmpdir/source-install-fail"
make_workspace "$workspace_install_fail" "$home_install_fail" "$source_install_fail"

cat > "$workspace_install_fail/main/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 1
EOF
chmod +x "$workspace_install_fail/main/install.sh"

set +e
HUB_WORKSPACE_ROOT="$workspace_install_fail" HUB_HOME_DIR="$home_install_fail" bash "$script" >"$tmpdir/repair-install-fail.out" 2>&1
install_fail_rc="$?"
set -e

[ "$install_fail_rc" != "0" ] || fail "repair must return non-zero when a sub-step fails"
grep -F 'error: workspace repair failed during run main/install.sh' "$tmpdir/repair-install-fail.out" >/dev/null || fail "repair should report sub-step failure"

workspace_install_branch="$tmpdir/workspace-install-branch"
home_install_branch="$tmpdir/home-install-branch"
source_install_branch="$tmpdir/source-install-branch"
install_branch='work/devspace-bare-hub'
make_workspace "$workspace_install_branch" "$home_install_branch" "$source_install_branch" "main"

git --git-dir="$workspace_install_branch/.bare" branch "$install_branch" main >/dev/null 2>&1

git --git-dir="$workspace_install_branch/.bare" worktree add "$workspace_install_branch/work/$install_branch" "$install_branch" >/dev/null 2>&1
mkdir -p "$workspace_install_branch/state/hub/work/$install_branch" "$workspace_install_branch/tmp/hub/work/$install_branch"
mkdir -p "$workspace_install_branch/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=%s\n' "$install_branch" > "$workspace_install_branch/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_install_branch/work/$install_branch" >> "$workspace_install_branch/state/hub/etc/install.env"

rm -rf "$workspace_install_branch/state/hub/work/$install_branch" "$workspace_install_branch/tmp/hub/work/$install_branch"
git --git-dir="$workspace_install_branch/.bare" worktree remove "$workspace_install_branch/work/$install_branch" --force >/dev/null 2>&1

HUB_WORKSPACE_ROOT="$workspace_install_branch" HUB_HOME_DIR="$home_install_branch" bash "$script" >"$tmpdir/repair-install-branch-state.out" 2>&1 || fail "repair should recover install branch from install.env"

[ -d "$workspace_install_branch/work/$install_branch" ] || fail "repair should recreate non-main install worktree from install.env"
[ -d "$workspace_install_branch/state/hub/work/$install_branch" ] || fail "repair should recreate canonical state path for install branch"
[ -d "$workspace_install_branch/tmp/hub/work/$install_branch" ] || fail "repair should recreate canonical tmp path for install branch"
[ "$(git -C "$workspace_install_branch/main" rev-parse --abbrev-ref HEAD)" = "main" ] || fail "repair must not retarget main away from main"

workspace_install_branch_env_override="$tmpdir/workspace-install-branch-env-override"
home_install_branch_env_override="$tmpdir/home-install-branch-env-override"
source_install_branch_env_override="$tmpdir/source-install-branch-env-override"
make_workspace "$workspace_install_branch_env_override" "$home_install_branch_env_override" "$source_install_branch_env_override" main
git --git-dir="$workspace_install_branch_env_override/.bare" branch feature/env-override main >/dev/null 2>&1

HUB_WORKSPACE_ROOT="$workspace_install_branch_env_override" HUB_HOME_DIR="$home_install_branch_env_override" HUB_INSTALL_BRANCH='feature/env-override' bash "$script" >"$tmpdir/repair-install-branch-env-override.out" 2>&1 || fail "repair should honor HUB_INSTALL_BRANCH env override"
[ -d "$workspace_install_branch_env_override/work/feature/env-override" ] || fail "repair should create install worktree from HUB_INSTALL_BRANCH env override"
[ "$(git -C "$workspace_install_branch_env_override/main" rev-parse --abbrev-ref HEAD)" = "main" ] || fail "repair must keep main on main when HUB_INSTALL_BRANCH env override is set"

workspace_branch_tip="$tmpdir/workspace-branch-tip"
home_branch_tip="$tmpdir/home-branch-tip"
source_branch_tip="$tmpdir/source-branch-tip"
tip_branch='work/devspace-bare-hub'
make_workspace "$workspace_branch_tip" "$home_branch_tip" "$source_branch_tip" "main"

git --git-dir="$workspace_branch_tip/.bare" worktree add -b "$tip_branch" "$workspace_branch_tip/work/$tip_branch" main >/dev/null 2>&1
mkdir -p "$workspace_branch_tip/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=%s\n' "$tip_branch" > "$workspace_branch_tip/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_branch_tip/work/$tip_branch" >> "$workspace_branch_tip/state/hub/etc/install.env"

(
  cd "$source_branch_tip"
  git checkout -b "$tip_branch" >/dev/null 2>&1
  cat > install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
touch "$HOME/.repair-install-ran"
touch "$HOME/.repair-branch-tip"
EOF
  chmod +x install.sh
  git add install.sh
  git commit -m 'update install to branch tip' >/dev/null 2>&1
)

repair_before_head="$(git -C "$workspace_branch_tip/work/$tip_branch" rev-parse HEAD)"
source_tip_head="$(git -C "$source_branch_tip" rev-parse "$tip_branch")"
[ "$repair_before_head" != "$source_tip_head" ] || fail "fixture setup should leave install worktree behind origin tip"

HUB_WORKSPACE_ROOT="$workspace_branch_tip" HUB_HOME_DIR="$home_branch_tip" bash "$script" >"$tmpdir/repair-branch-tip.out" 2>&1 || fail "repair should update existing HUB_INSTALL_BRANCH worktree to latest origin tip"

repair_after_head="$(git -C "$workspace_branch_tip/work/$tip_branch" rev-parse HEAD)"
[ "$repair_after_head" = "$source_tip_head" ] || fail "repair should fast-forward existing HUB_INSTALL_BRANCH worktree to origin tip"
[ -f "$home_branch_tip/.repair-branch-tip" ] || fail "repair should run install.sh from updated branch tip"

workspace_install_postcheck="$tmpdir/workspace-install-postcheck"
home_install_postcheck="$tmpdir/home-install-postcheck"
source_install_postcheck="$tmpdir/source-install-postcheck"
make_workspace "$workspace_install_postcheck" "$home_install_postcheck" "$source_install_postcheck"

cat > "$workspace_install_postcheck/main/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd /definitely/missing/path || true
exit 0
EOF
chmod +x "$workspace_install_postcheck/main/install.sh"

rm -f "$home_install_postcheck/.zshrc"
ln -s /definitely/missing/path/.zshrc "$home_install_postcheck/.zshrc"

set +e
HUB_WORKSPACE_ROOT="$workspace_install_postcheck" HUB_HOME_DIR="$home_install_postcheck" bash "$script" >"$tmpdir/repair-install-postcheck.out" 2>&1
install_postcheck_rc="$?"
set -e

[ "$install_postcheck_rc" = "1" ] || fail "repair should fail when install leaves broken symlink targets"
grep -F 'error: workspace repair failed during run /tmp/' "$tmpdir/repair-install-postcheck.out" >/dev/null || fail "repair should report install post-condition symlink failure"
grep -F '(symlink target .zshrc -> /definitely/missing/path/.zshrc does not exist)' "$tmpdir/repair-install-postcheck.out" >/dev/null || fail "repair should report install post-condition symlink failure"

workspace_ohmyzsh_missing="$tmpdir/workspace-ohmyzsh-missing"
home_ohmyzsh_missing="$tmpdir/home-ohmyzsh-missing"
source_ohmyzsh_missing="$tmpdir/source-ohmyzsh-missing"
make_workspace "$workspace_ohmyzsh_missing" "$home_ohmyzsh_missing" "$source_ohmyzsh_missing"

cat > "$workspace_ohmyzsh_missing/main/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
oh_my_zsh_dir="$HOME/.oh-my-zsh"
if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then
  mkdir -p "$oh_my_zsh_dir"
  touch "$oh_my_zsh_dir/oh-my-zsh.sh"
fi
touch "$HOME/.repair-install-ran"
exit 0
EOF
chmod +x "$workspace_ohmyzsh_missing/main/install.sh"

rm -f "$home_ohmyzsh_missing/.oh-my-zsh/oh-my-zsh.sh"

set +e
HUB_WORKSPACE_ROOT="$workspace_ohmyzsh_missing" HUB_HOME_DIR="$home_ohmyzsh_missing" bash "$script" >"$tmpdir/repair-ohmyzsh-missing.out" 2>&1
ohmyzsh_missing_rc="$?"
set -e

[ "$ohmyzsh_missing_rc" = "0" ] || fail "repair should succeed when install.sh reinstalls missing oh-my-zsh"
[ -f "$home_ohmyzsh_missing/.oh-my-zsh/oh-my-zsh.sh" ] || fail "repair should reinstall oh-my-zsh when oh-my-zsh.sh is missing"

printf 'PASS test_workspace_repair\n'
