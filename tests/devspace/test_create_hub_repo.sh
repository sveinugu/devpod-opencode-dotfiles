#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_create_hub_repo: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/scripts/create-hub-repo.sh"
runbook="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"

[ -f "$script" ] || fail "scripts/create-hub-repo.sh not found"
[ -f "$runbook" ] || fail "runbook not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
mkdir -p "$workspace_root/repos" "$workspace_root/state/repos" "$workspace_root/tmp/repos" "$home_dir/.config"

top_source="$tmpdir/top-source"
git init "$top_source" >/dev/null 2>&1
(
  cd "$top_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'top\n' > README.md
  git add README.md
  git commit -m 'top fixture' >/dev/null 2>&1
)
git clone --bare "$top_source" "$workspace_root/.bare" >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1

ln -s "$workspace_root/main/.zshrc" "$home_dir/.zshrc"
ln -s "$workspace_root/main/.zprofile" "$home_dir/.zprofile"
ln -s "$workspace_root/main/.config/opencode" "$home_dir/.config/opencode"

child_source="$tmpdir/child-repo"
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

HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" "$child_source" >"$tmpdir/child-ok.out" 2>&1 || fail "onboarding should succeed for valid source"

[ -d "$workspace_root/repos/child-repo/.bare" ] || fail "missing repos/<name>/.bare"
[ -d "$workspace_root/repos/child-repo/main" ] || fail "missing repos/<name>/main"
[ -d "$workspace_root/repos/child-repo/work" ] || fail "missing repos/<name>/work"
[ -d "$workspace_root/state/repos/child-repo/main" ] || fail "missing state/repos/<name>/main"
[ -d "$workspace_root/tmp/repos/child-repo/main" ] || fail "missing tmp/repos/<name>/main"

[ "$(readlink "$home_dir/.zshrc")" = "$workspace_root/main/.zshrc" ] || fail "child onboarding must not repoint /home authority"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" "$child_source" >"$tmpdir/collision.out" 2>&1
collision_rc="$?"
set -e
[ "$collision_rc" = "1" ] || fail "onboarding should refuse path collisions"
grep -F 'refused: child repo path already exists' "$tmpdir/collision.out" >/dev/null || fail "missing collision refusal message"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" --name custom "$child_source" >"$tmpdir/name.out" 2>&1
name_rc="$?"
set -e
[ "$name_rc" = "2" ] || fail "--name override should be rejected in v1"

source_no_main="$tmpdir/child-no-main"
git init "$source_no_main" >/dev/null 2>&1
(
  cd "$source_no_main"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  printf 'no-main\n' > README.md
  git add README.md
  git commit -m 'no main' >/dev/null 2>&1
)

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" "$source_no_main" >"$tmpdir/no-main.out" 2>&1
no_main_rc="$?"
set -e
[ "$no_main_rc" = "1" ] || fail "onboarding should refuse when origin/main is absent"
grep -F 'refused: origin/main is required for bootstrap' "$tmpdir/no-main.out" >/dev/null || fail "missing origin/main refusal"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" git@github.com:owner/private.git >"$tmpdir/public-only.out" 2>&1
public_only_rc="$?"
set -e
[ "$public_only_rc" = "1" ] || fail "v1 should refuse non-public/ssh child sources"
grep -F 'refused: public repo source is required in v1' "$tmpdir/public-only.out" >/dev/null || fail "missing public-only refusal"

grep -F 'create-hub-repo.sh' "$runbook" >/dev/null || fail "runbook should document child repo onboarding usage"

printf 'PASS test_create_hub_repo\n'
