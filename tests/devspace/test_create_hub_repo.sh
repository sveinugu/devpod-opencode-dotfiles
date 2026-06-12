#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_create_hub_repo: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/bin/clone-repo"
runbook="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"

[ -f "$script" ] || fail "bin/clone-repo not found"
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
[ "$(git -C "$workspace_root/repos/child-repo/main" config --get "branch.main.remote" 2>/dev/null || true)" = "origin" ] || fail "child default branch should set branch.<name>.remote=origin"
[ "$(git -C "$workspace_root/repos/child-repo/main" config --get "branch.main.merge" 2>/dev/null || true)" = "refs/heads/main" ] || fail "child default branch should set branch.<name>.merge to refs/heads/<name>"
[ -d "$workspace_root/state/repos/child-repo/main" ] || fail "missing state/repos/<name>/main"
[ -d "$workspace_root/tmp/repos/child-repo/main" ] || fail "missing tmp/repos/<name>/main"
[ -f "$workspace_root/state/repos/child-repo/etc/repo.env" ] || fail "missing state/repos/<name>/etc/repo.env"
child_exclude="$workspace_root/repos/child-repo/.bare/info/exclude"
[ -f "$child_exclude" ] || fail "missing child bare info/exclude"
for pattern in '.envrc' '.envrc.local' '.envrc.bak.*' '.opencode/'; do
  grep -Fx "$pattern" "$child_exclude" >/dev/null || fail "missing $pattern in child bare info/exclude"
done
grep -F 'export DYN_REPO_DEFAULT_BRANCH=main' "$workspace_root/state/repos/child-repo/etc/repo.env" >/dev/null || fail "repo.env should record detected default branch"
grep -F "export DYN_REPO_DEFAULT_DIR=$workspace_root/repos/child-repo/main" "$workspace_root/state/repos/child-repo/etc/repo.env" >/dev/null || fail "repo.env should record detected default directory"

repo_env_out="$(set +u; source "$workspace_root/state/repos/child-repo/etc/repo.env"; printf '%s\n%s\n' "$DYN_REPO_DEFAULT_BRANCH" "$DYN_REPO_DEFAULT_DIR")"
[ "$(printf '%s' "$repo_env_out" | sed -n '1p')" = "main" ] || fail "repo.env should remain source-able for default branch"
[ "$(printf '%s' "$repo_env_out" | sed -n '2p')" = "$workspace_root/repos/child-repo/main" ] || fail "repo.env should remain source-able for default directory"

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

source_default_branch="$tmpdir/child-default-branch"
git init "$source_default_branch" >/dev/null 2>&1
(
  cd "$source_default_branch"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  printf 'default-branch\n' > README.md
  git add README.md
  git commit -m 'default branch repo' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" "$source_default_branch" >"$tmpdir/default-branch.out" 2>&1 || fail "onboarding should use source default branch when origin/main is absent"
[ -d "$workspace_root/repos/child-default-branch/.bare" ] || fail "missing bare repo for default-branch source"
default_branch_name="$(git -C "$workspace_root/repos/child-default-branch/master" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[ "$default_branch_name" = "master" ] || fail "default-branch source should attach source default branch"
[ "$(git -C "$workspace_root/repos/child-default-branch/master" config --get "branch.master.remote" 2>/dev/null || true)" = "origin" ] || fail "detected default branch should set branch.<name>.remote=origin"
[ "$(git -C "$workspace_root/repos/child-default-branch/master" config --get "branch.master.merge" 2>/dev/null || true)" = "refs/heads/master" ] || fail "detected default branch should set branch.<name>.merge to refs/heads/<name>"
[ -d "$workspace_root/state/repos/child-default-branch/master" ] || fail "default-branch source should use canonical state path for detected branch"
[ -d "$workspace_root/tmp/repos/child-default-branch/master" ] || fail "default-branch source should use canonical tmp path for detected branch"
[ -f "$workspace_root/state/repos/child-default-branch/etc/repo.env" ] || fail "default-branch source should persist repo metadata"
grep -F 'export DYN_REPO_DEFAULT_BRANCH=master' "$workspace_root/state/repos/child-default-branch/etc/repo.env" >/dev/null || fail "repo.env should record detected non-main default branch"
grep -F "export DYN_REPO_DEFAULT_DIR=$workspace_root/repos/child-default-branch/master" "$workspace_root/state/repos/child-default-branch/etc/repo.env" >/dev/null || fail "repo.env should record detected non-main default directory"

quoted_name='repo with space'
quoted_source="$tmpdir/$quoted_name.git"
git init "$quoted_source" >/dev/null 2>&1
(
  cd "$quoted_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'quoted child\n' > README.md
  git add README.md
  git commit -m 'quoted child fixture' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" "$quoted_source" >"$tmpdir/quoted-child.out" 2>&1 || fail "onboarding should succeed for quoted-style repo names"
[ -f "$workspace_root/state/repos/$quoted_name/etc/repo.env" ] || fail "quoted repo should persist repo.env"
[ "$(git -C "$workspace_root/repos/$quoted_name/main" config --get "branch.main.remote" 2>/dev/null || true)" = "origin" ] || fail "quoted-style child default branch should set branch.<name>.remote=origin"
[ "$(git -C "$workspace_root/repos/$quoted_name/main" config --get "branch.main.merge" 2>/dev/null || true)" = "refs/heads/main" ] || fail "quoted-style child default branch should set branch.<name>.merge to refs/heads/<name>"

quoted_repo_env_out="$(set +u; source "$workspace_root/state/repos/$quoted_name/etc/repo.env"; printf '%s\n%s\n' "$DYN_REPO_DEFAULT_BRANCH" "$DYN_REPO_DEFAULT_DIR")"
[ "$(printf '%s' "$quoted_repo_env_out" | sed -n '1p')" = "main" ] || fail "quoted repo.env should remain source-able for branch"
[ "$(printf '%s' "$quoted_repo_env_out" | sed -n '2p')" = "$workspace_root/repos/$quoted_name/main" ] || fail "quoted repo.env should remain source-able for directory"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HUB_HOME_DIR="$home_dir" bash "$script" git@github.com:owner/private.git >"$tmpdir/public-only.out" 2>&1
public_only_rc="$?"
set -e
[ "$public_only_rc" = "1" ] || fail "v1 should refuse non-public/ssh child sources"
grep -F 'refused: public repo source is required in v1' "$tmpdir/public-only.out" >/dev/null || fail "missing public-only refusal"

grep -F 'bin/clone-repo' "$runbook" >/dev/null || fail "runbook should document child repo onboarding usage"

printf 'PASS test_create_hub_repo\n'
