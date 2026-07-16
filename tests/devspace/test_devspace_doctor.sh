#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_doctor: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/ops/check-workspace.sh"

[ -f "$script" ] || fail "ops/check-workspace.sh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mock_bin_ok="$tmpdir/mock-bin-ok"
mock_bin_bad="$tmpdir/mock-bin-bad"
mkdir -p "$mock_bin_ok" "$mock_bin_bad"

cat > "$mock_bin_ok/direnv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '2.35.0\n'
EOF
chmod +x "$mock_bin_ok/direnv"

cat > "$mock_bin_bad/direnv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'direnv: command not found\n' >&2
exit 127
EOF
chmod +x "$mock_bin_bad/direnv"

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
source_repo="$tmpdir/source"
mkdir -p "$workspace_root" "$home_dir" "$source_repo"

git init "$source_repo" >/dev/null 2>&1
(
  cd "$source_repo"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'fixture\n' > README.md
  git add README.md
  git commit -m 'fixture' >/dev/null 2>&1
)

git clone --bare "$source_repo" "$workspace_root/.bare" >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" branch feature/install-only main >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/work/feature/install-only" feature/install-only >/dev/null 2>&1
mkdir -p "$workspace_root/work" "$workspace_root/repos" "$workspace_root/state/hub/main" "$workspace_root/tmp/hub/main"
mkdir -p "$workspace_root/main/.config/opencode"
touch "$workspace_root/main/.zshrc" "$workspace_root/main/.zprofile"

mkdir -p "$home_dir/.config"
ln -s "$workspace_root/main/.zshrc" "$home_dir/.zshrc"
ln -s "$workspace_root/main/.zprofile" "$home_dir/.zprofile"
ln -s "$workspace_root/main/.config/opencode" "$home_dir/.config/opencode"

mkdir -p "$workspace_root/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=feature/install-checkout\n' > "$workspace_root/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=/workspaces/dotfiles/work/feature/install-checkout\n' >> "$workspace_root/state/hub/etc/install.env"

if ! PATH="$mock_bin_ok:$PATH" HUB_CHECK_DEPLOYMENT=yes HUB_CHECK_PVC=yes HUB_CHECK_POD=test-pod HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" >"$tmpdir/pass.out" 2>&1; then
  fail "doctor should pass when all checks are healthy"
fi

grep -F 'PASS' "$tmpdir/pass.out" >/dev/null || fail "doctor output should be human-readable checklist"
grep -F 'installed-branch state from install.env' "$tmpdir/pass.out" >/dev/null || fail "doctor should report installed branch state"
grep -F '[PASS] top-level main exists and is attached' "$tmpdir/pass.out" >/dev/null || fail "doctor should explicitly report main attachment check"
grep -F '[PASS] direnv is available in workspace image' "$tmpdir/pass.out" >/dev/null || fail "doctor should report direnv availability"

set +e
PATH="$mock_bin_bad:$PATH" HUB_CHECK_DEPLOYMENT=yes HUB_CHECK_PVC=yes HUB_CHECK_POD=test-pod HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" >"$tmpdir/missing-direnv.out" 2>&1
missing_direnv_rc="$?"
set -e
[ "$missing_direnv_rc" = "1" ] || fail "doctor should fail when direnv is unavailable in the workspace image"
grep -F '[FAIL] direnv is available in workspace image' "$tmpdir/missing-direnv.out" >/dev/null || fail "doctor should include direnv failure in checklist output"

rm -f "$workspace_root/main/.zshrc"
set +e
PATH="$mock_bin_ok:$PATH" HUB_CHECK_DEPLOYMENT=yes HUB_CHECK_PVC=yes HUB_CHECK_POD=test-pod HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" >"$tmpdir/broken-symlink.out" 2>&1
broken_symlink_rc="$?"
set -e
[ "$broken_symlink_rc" = "1" ] || fail "doctor should fail when /home symlink points to missing target"

set +e
PATH="$mock_bin_ok:$PATH" HUB_CHECK_DEPLOYMENT=no HUB_CHECK_PVC=yes HUB_CHECK_POD=test-pod HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" >"$tmpdir/fail.out" 2>&1
doctor_rc="$?"
set -e
if [ "$doctor_rc" = "0" ]; then
  fail "doctor should exit non-zero when a required check fails"
fi

[ "$doctor_rc" = "1" ] || fail "doctor should exit 1 when checks fail"

set +e
PATH="$mock_bin_ok:$PATH" HUB_CHECK_DEPLOYMENT=yes HUB_CHECK_PVC=yes HUB_CHECK_POD=test-pod HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" --bad-flag >"$tmpdir/usage.out" 2>&1
usage_rc="$?"
set -e
if [ "$usage_rc" = "0" ]; then
  fail "doctor should fail on invalid usage"
fi

[ "$usage_rc" = "2" ] || fail "doctor should exit 2 on invalid usage"

printf 'PASS test_devspace_doctor\n'
