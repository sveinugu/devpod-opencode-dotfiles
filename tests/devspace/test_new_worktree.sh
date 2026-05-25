#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_new_worktree: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
new_worktree_script="$repo_root/bin/new-worktree"
clone_repo_script="$repo_root/bin/clone-repo"
env_helper="$repo_root/scripts/lib/worktree-env.sh"

[ -f "$new_worktree_script" ] || fail "bin/new-worktree not found"
[ -f "$clone_repo_script" ] || fail "bin/clone-repo not found"
[ -f "$env_helper" ] || fail "scripts/lib/worktree-env.sh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
mkdir -p "$workspace_root/repos" "$workspace_root/state/repos" "$workspace_root/tmp/repos" "$home_dir"

top_source="$tmpdir/top-source"
git init "$top_source" >/dev/null 2>&1
(
  cd "$top_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'top\n' > README.md
  printf '#!/usr/bin/env bash\nset -euo pipefail\n' > install.sh
  chmod +x install.sh
  mkdir -p .config/opencode
  printf '{}\n' > .config/opencode/opencode.json
  git add README.md install.sh .config/opencode/opencode.json
  git commit -m 'top fixture' >/dev/null 2>&1
)

git clone --bare "$top_source" "$workspace_root/.bare" >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1

mkdir -p "$workspace_root/state/hub/etc"
printf 'HUB_INSTALL_BRANCH=main\n' > "$workspace_root/state/hub/etc/install.env"
printf 'HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_root/main" >> "$workspace_root/state/hub/etc/install.env"

child_source="$tmpdir/child-source"
git init "$child_source" >/dev/null 2>&1
(
  cd "$child_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'child\n' > README.md
  git add README.md
  git commit -m 'child fixture' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$clone_repo_script" "$child_source" >/dev/null

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/top-level >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo child-source feature/child >/dev/null

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/extra unexpected >"$tmpdir/extra-args.out" 2>&1
extra_args_rc="$?"
set -e

[ "$extra_args_rc" = "2" ] || fail "new-worktree should reject unexpected extra positional args"
grep -F 'usage: new-worktree --repo <hub|repo-name> <branch>' "$tmpdir/extra-args.out" >/dev/null || fail "new-worktree should show usage on extra positional args"

validator_path="$repo_root/scripts/lib/validate_hub_repo_root.sh"
validator_backup="$tmpdir/validate_hub_repo_root.sh.bak"
cp "$validator_path" "$validator_backup"
restore_validator() {
  cp "$validator_backup" "$validator_path"
}
trap 'restore_validator; rm -rf "$tmpdir"' EXIT

cat > "$validator_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'validator-invoked\n' >&2
exit 1
EOF
chmod +x "$validator_path"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/validator-check >"$tmpdir/validator-invocation.out" 2>&1
validator_invocation_rc="$?"
set -e

[ "$validator_invocation_rc" = "1" ] || fail "new-worktree should fail when hub root validator fails"
grep -F 'validator-invoked' "$tmpdir/validator-invocation.out" >/dev/null || fail "new-worktree should invoke hub root validator"

restore_validator

[ -d "$workspace_root/work/feature/top-level" ] || fail "missing top-level worktree"
[ -d "$workspace_root/state/hub/work/feature/top-level" ] || fail "missing top-level canonical state path"
[ -d "$workspace_root/tmp/hub/work/feature/top-level" ] || fail "missing top-level canonical tmp path"

[ -d "$workspace_root/repos/child-source/work/feature/child" ] || fail "missing child worktree"
[ -d "$workspace_root/state/repos/child-source/work/feature/child" ] || fail "missing child canonical state path"
[ -d "$workspace_root/tmp/repos/child-source/work/feature/child" ] || fail "missing child canonical tmp path"

for checkout in \
  "$workspace_root/main" \
  "$workspace_root/work/feature/top-level" \
  "$workspace_root/repos/child-source/main" \
  "$workspace_root/repos/child-source/work/feature/child"
do
  [ -f "$checkout/.envrc" ] || fail "missing managed .envrc in $checkout"
  [ -f "$checkout/.envrc.local" ] || fail "missing managed .envrc.local in $checkout"

  grep -F 'export HUB_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_DIR export in $checkout/.envrc"
  grep -F 'export HUB_MAIN_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_MAIN_DIR export in $checkout/.envrc"
  grep -F 'export HUB_STATE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_STATE_DIR export in $checkout/.envrc"
  grep -F 'export HUB_TMP_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_TMP_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_MAIN_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_MAIN_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_STATE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_STATE_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_TMP_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_TMP_DIR export in $checkout/.envrc"
  grep -F 'export DYN_WORKTREE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_WORKTREE_DIR export in $checkout/.envrc"
  grep -F 'export DYN_WORKTREE_STATE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_WORKTREE_STATE_DIR export in $checkout/.envrc"
  grep -F 'export DYN_WORKTREE_TMP_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_WORKTREE_TMP_DIR export in $checkout/.envrc"

  grep -F '/workspaces/dotfiles/state/hub/etc/install.env' "$checkout/.envrc" >/dev/null || fail "missing install.env source in $checkout/.envrc"
  grep -F '.envrc.local' "$checkout/.envrc" >/dev/null || fail "missing .envrc.local source in $checkout/.envrc"
done

mkdir -p "$workspace_root/work/has-manual-envrc"
cat > "$workspace_root/work/has-manual-envrc/.envrc" <<'EOF'
export MANUAL=1
EOF

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$env_helper" "$workspace_root/work/has-manual-envrc" hub >"$tmpdir/manual-envrc.out" 2>&1
manual_envrc_rc="$?"
set -e

[ "$manual_envrc_rc" = "1" ] || fail "expected .envrc generation refusal for existing .envrc"
grep -F 'refused: managed .envrc generation requires absent .envrc' "$tmpdir/manual-envrc.out" >/dev/null || fail "missing refusal message for existing .envrc"

grep -F 'direnv' "$repo_root/Dockerfile" >/dev/null || fail "interactive image should include direnv"

printf 'PASS test_new_worktree\n'
