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

mock_bin="$tmpdir/bin"
mkdir -p "$mock_bin"
direnv_log="$tmpdir/direnv.log"

cat > "$mock_bin/direnv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${DIRENV_LOG:?DIRENV_LOG must be set}"
exit 0
EOF
chmod +x "$mock_bin/direnv"

export PATH="$mock_bin:$PATH"
export DIRENV_LOG="$direnv_log"

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
printf 'export HUB_INSTALL_BRANCH=main\n' > "$workspace_root/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_root/main" >> "$workspace_root/state/hub/etc/install.env"

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

child_repo_env="$workspace_root/state/repos/child-source/etc/repo.env"
[ -f "$child_repo_env" ] || fail "missing child repo metadata env file"
# shellcheck disable=SC1090
. "$child_repo_env"
child_default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
[ -n "$child_default_branch" ] || fail "missing DYN_REPO_DEFAULT_BRANCH in child metadata"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub main >"$tmpdir/reserved-hub-default.out" 2>&1
reserved_hub_default_rc="$?"
set -e
[ "$reserved_hub_default_rc" = "1" ] || fail "new-worktree should refuse hub feature worktree matching reserved default branch name"
grep -F 'refused: requested worktree name matches reserved default branch name "main"' "$tmpdir/reserved-hub-default.out" >/dev/null || fail "new-worktree should explain reserved hub default-branch refusal"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo child-source "$child_default_branch" >"$tmpdir/reserved-child-default.out" 2>&1
reserved_child_default_rc="$?"
set -e
[ "$reserved_child_default_rc" = "1" ] || fail "new-worktree should refuse child feature worktree matching detected default branch name"
grep -F "refused: requested worktree name matches reserved default branch name \"$child_default_branch\"" "$tmpdir/reserved-child-default.out" >/dev/null || fail "new-worktree should explain reserved child default-branch refusal"

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/top-level >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo child-source feature/child >/dev/null

(
  cd "$workspace_root/main"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" feature/top-level-auto >/dev/null
)

(
  cd "$workspace_root/repos/child-source/$child_default_branch"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" feature/child-auto >/dev/null
)

[ "$(git -C "$workspace_root/work/feature/top-level" config --get "branch.feature/top-level.remote" 2>/dev/null || true)" = "origin" ] || fail "hub worktree branch should set branch.<name>.remote=origin"
[ "$(git -C "$workspace_root/work/feature/top-level" config --get "branch.feature/top-level.merge" 2>/dev/null || true)" = "refs/heads/feature/top-level" ] || fail "hub worktree branch should set branch.<name>.merge to refs/heads/<name>"
[ "$(git -C "$workspace_root/repos/child-source/work/feature/child" config --get "branch.feature/child.remote" 2>/dev/null || true)" = "origin" ] || fail "child worktree branch should set branch.<name>.remote=origin"
[ "$(git -C "$workspace_root/repos/child-source/work/feature/child" config --get "branch.feature/child.merge" 2>/dev/null || true)" = "refs/heads/feature/child" ] || fail "child worktree branch should set branch.<name>.merge to refs/heads/<name>"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/extra unexpected >"$tmpdir/extra-args.out" 2>&1
extra_args_rc="$?"
set -e

[ "$extra_args_rc" = "2" ] || fail "new-worktree should reject unexpected extra positional args"
grep -F 'usage: new-worktree [--repo <hub|repo-name>] <branch>' "$tmpdir/extra-args.out" >/dev/null || fail "new-worktree should show usage on extra positional args"

set +e
HUB_WORKSPACE_ROOT="$tmpdir/missing-workspace-root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/missing-root >"$tmpdir/missing-root.out" 2>&1
missing_root_rc="$?"
set -e

[ "$missing_root_rc" = "1" ] || fail "new-worktree should fail with clear message when workspace root is missing"
grep -F 'refused: checkout path does not exist' "$tmpdir/missing-root.out" >/dev/null || fail "new-worktree should report missing checkout path refusal"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo missing-repo feature/missing-repo >"$tmpdir/missing-repo.out" 2>&1
missing_repo_rc="$?"
set -e

[ "$missing_repo_rc" = "1" ] || fail "new-worktree should fail when child repo metadata is missing"
grep -F 'refused: managed child default branch metadata is missing or invalid' "$tmpdir/missing-repo.out" >/dev/null || fail "new-worktree should report missing child metadata refusal"

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
[ -d "$workspace_root/work/feature/top-level-auto" ] || fail "missing auto-detected top-level worktree"
[ -d "$workspace_root/state/hub/work/feature/top-level" ] || fail "missing top-level canonical state path"
[ -d "$workspace_root/state/hub/work/feature/top-level-auto" ] || fail "missing auto-detected top-level canonical state path"
[ -d "$workspace_root/tmp/hub/work/feature/top-level" ] || fail "missing top-level canonical tmp path"
[ -d "$workspace_root/tmp/hub/work/feature/top-level-auto" ] || fail "missing auto-detected top-level canonical tmp path"

[ -d "$workspace_root/repos/child-source/work/feature/child" ] || fail "missing child worktree"
[ -d "$workspace_root/repos/child-source/work/feature/child-auto" ] || fail "missing auto-detected child worktree"
[ -d "$workspace_root/state/repos/child-source/work/feature/child" ] || fail "missing child canonical state path"
[ -d "$workspace_root/state/repos/child-source/work/feature/child-auto" ] || fail "missing auto-detected child canonical state path"
[ -d "$workspace_root/tmp/repos/child-source/work/feature/child" ] || fail "missing child canonical tmp path"
[ -d "$workspace_root/tmp/repos/child-source/work/feature/child-auto" ] || fail "missing auto-detected child canonical tmp path"

child_exclude="$workspace_root/repos/child-source/.bare/info/exclude"
[ -f "$child_exclude" ] || fail "missing child bare info/exclude"

for pattern in '.envrc' '.envrc.local' '.envrc.bak.*' '.opencode/'; do
  grep -Fx "$pattern" "$child_exclude" >/dev/null || fail "missing $pattern exclude in $child_exclude"
done

printf 'manual-child-only\n' > "$child_exclude"
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo child-source feature/child-preserve >/dev/null
grep -Fx 'manual-child-only' "$child_exclude" >/dev/null || fail "new-worktree should not overwrite child bare excludes"

for pattern in '.envrc' '.envrc.local' '.envrc.bak.*' '.opencode/'; do
  printf '%s\n' "$pattern" >> "$child_exclude"
done

mkdir -p "$workspace_root/repos/child-source/work/feature/child/.opencode"
printf 'child backup\n' > "$workspace_root/repos/child-source/work/feature/child/.envrc.bak.20260612000000"
child_status="$(git -C "$workspace_root/repos/child-source/work/feature/child" status --porcelain)"
[ -z "$child_status" ] || fail "expected clean child worktree status with generated artifacts ignored"

mkdir -p "$workspace_root/repos/child-source/work/feature/child-preserve/.opencode"
printf 'child preserve backup\n' > "$workspace_root/repos/child-source/work/feature/child-preserve/.envrc.bak.20260612000000"
child_preserve_status="$(git -C "$workspace_root/repos/child-source/work/feature/child-preserve" status --porcelain)"
[ -z "$child_preserve_status" ] || fail "expected clean preserved child worktree status with generated artifacts ignored"

for checkout in \
  "$workspace_root/main" \
  "$workspace_root/work/feature/top-level" \
  "$workspace_root/work/feature/top-level-auto" \
  "$workspace_root/repos/child-source/$child_default_branch" \
  "$workspace_root/repos/child-source/work/feature/child" \
  "$workspace_root/repos/child-source/work/feature/child-preserve" \
  "$workspace_root/repos/child-source/work/feature/child-auto"
do
  [ -f "$checkout/.envrc" ] || fail "missing managed .envrc in $checkout"
  [ -f "$checkout/.envrc.local" ] || fail "missing managed .envrc.local in $checkout"

  grep -F 'export HUB_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_DIR export in $checkout/.envrc"
  grep -F 'export HUB_MAIN_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_MAIN_DIR export in $checkout/.envrc"
  grep -F 'export HUB_STATE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_STATE_DIR export in $checkout/.envrc"
  grep -F 'export HUB_TMP_DIR=' "$checkout/.envrc" >/dev/null || fail "missing HUB_TMP_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_DEFAULT_BRANCH=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_DEFAULT_BRANCH export in $checkout/.envrc"
  grep -F 'export DYN_REPO_DEFAULT_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_DEFAULT_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_STATE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_STATE_DIR export in $checkout/.envrc"
  grep -F 'export DYN_REPO_TMP_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_REPO_TMP_DIR export in $checkout/.envrc"
  grep -F 'export DYN_WORKTREE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_WORKTREE_DIR export in $checkout/.envrc"
  grep -F 'export DYN_WORKTREE_STATE_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_WORKTREE_STATE_DIR export in $checkout/.envrc"
  grep -F 'export DYN_WORKTREE_TMP_DIR=' "$checkout/.envrc" >/dev/null || fail "missing DYN_WORKTREE_TMP_DIR export in $checkout/.envrc"
  grep -F 'export TMPDIR=' "$checkout/.envrc" >/dev/null || fail "missing TMPDIR export in $checkout/.envrc"
  grep -F 'export TMP=' "$checkout/.envrc" >/dev/null || fail "missing TMP export in $checkout/.envrc"
  grep -F 'export TEMP=' "$checkout/.envrc" >/dev/null || fail "missing TEMP export in $checkout/.envrc"

  dyn_worktree_tmp_line="$(grep -F 'export DYN_WORKTREE_TMP_DIR=' "$checkout/.envrc" || true)"
  tmpdir_line="$(grep -F 'export TMPDIR=' "$checkout/.envrc" || true)"
  tmp_line="$(grep -F 'export TMP=' "$checkout/.envrc" || true)"
  temp_line="$(grep -F 'export TEMP=' "$checkout/.envrc" || true)"

  dyn_worktree_tmp_value="${dyn_worktree_tmp_line#export DYN_WORKTREE_TMP_DIR=\"}"
  dyn_worktree_tmp_value="${dyn_worktree_tmp_value%\"}"

  tmpdir_value="${tmpdir_line#export TMPDIR=\"}"
  tmpdir_value="${tmpdir_value%\"}"

  tmp_value="${tmp_line#export TMP=\"}"
  tmp_value="${tmp_value%\"}"

  temp_value="${temp_line#export TEMP=\"}"
  temp_value="${temp_value%\"}"

  [ "$tmpdir_value" = "$dyn_worktree_tmp_value" ] || fail "TMPDIR should match DYN_WORKTREE_TMP_DIR in $checkout/.envrc"
  [ "$tmp_value" = "$dyn_worktree_tmp_value" ] || fail "TMP should match DYN_WORKTREE_TMP_DIR in $checkout/.envrc"
  [ "$temp_value" = "$dyn_worktree_tmp_value" ] || fail "TEMP should match DYN_WORKTREE_TMP_DIR in $checkout/.envrc"

  grep -F '/workspaces/dotfiles/state/hub/etc/install.env' "$checkout/.envrc" >/dev/null || fail "missing install.env source in $checkout/.envrc"
  grep -F '.envrc.local' "$checkout/.envrc" >/dev/null || fail "missing .envrc.local source in $checkout/.envrc"
done

set +e
(
  cd "$workspace_root"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" feature/no-context
) >"$tmpdir/no-context.out" 2>&1
no_context_rc="$?"
set -e

[ "$no_context_rc" = "1" ] || fail "new-worktree should fail without --repo outside managed repo context"
grep -F 'refused: unable to infer managed repo context; use --repo <hub|repo-name>' "$tmpdir/no-context.out" >/dev/null || fail "new-worktree should explain no-context refusal"

if grep -F 'export DYN_REPO_MAIN_DIR=' "$workspace_root/repos/child-source/$child_default_branch/.envrc" >/dev/null; then
  fail "managed child envrc should not export retired DYN_REPO_MAIN_DIR"
fi

mkdir -p "$workspace_root/work/has-manual-envrc"
cat > "$workspace_root/work/has-manual-envrc/.envrc" <<'EOF'
export MANUAL=1
EOF

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$env_helper" "$workspace_root/work/has-manual-envrc" hub >"$tmpdir/manual-envrc.out" 2>&1
manual_envrc_rc="$?"
set -e

[ "$manual_envrc_rc" = "0" ] || fail "expected managed .envrc regeneration with backup for differing existing .envrc"

backup_file="$(ls "$workspace_root/work/has-manual-envrc"/.envrc.bak.* 2>/dev/null | head -n1 || true)"
[ -n "$backup_file" ] || fail "expected backup file when existing .envrc differs"
grep -F 'warning: backed up existing .envrc to .envrc.bak.' "$tmpdir/manual-envrc.out" >/dev/null || fail "missing backup warning for differing existing .envrc"

grep -F 'export HUB_DIR=' "$workspace_root/work/has-manual-envrc/.envrc" >/dev/null || fail "expected managed .envrc content after regeneration"
grep -F "allow $workspace_root/work/has-manual-envrc" "$direnv_log" >/dev/null || fail "expected direnv allow after envrc generation"

backup_count_before="$(ls "$workspace_root/work/has-manual-envrc"/.envrc.bak.* 2>/dev/null | wc -l | tr -d ' ')"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$env_helper" "$workspace_root/work/has-manual-envrc" hub >"$tmpdir/manual-envrc-identical.out" 2>&1
manual_envrc_identical_rc="$?"
set -e

[ "$manual_envrc_identical_rc" = "0" ] || fail "expected no-op success when existing .envrc matches generated content"
[ ! -s "$tmpdir/manual-envrc-identical.out" ] || fail "expected silent no-op when .envrc content is identical"

backup_count_after="$(ls "$workspace_root/work/has-manual-envrc"/.envrc.bak.* 2>/dev/null | wc -l | tr -d ' ')"
[ "$backup_count_after" = "$backup_count_before" ] || fail "expected no additional backup when .envrc content is identical"

rm -f "$workspace_root/work/has-manual-envrc/.envrc.local"
set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$env_helper" "$workspace_root/work/has-manual-envrc" hub >"$tmpdir/manual-envrc-local-recreate.out" 2>&1
manual_envrc_local_recreate_rc="$?"
set -e

[ "$manual_envrc_local_recreate_rc" = "0" ] || fail "expected success when recreating missing .envrc.local on no-op .envrc"
[ -f "$workspace_root/work/has-manual-envrc/.envrc.local" ] || fail "expected .envrc.local to be recreated when missing"

grep -F 'direnv' "$repo_root/Dockerfile" >/dev/null || fail "interactive image should include direnv"

printf 'PASS test_new_worktree\n'
