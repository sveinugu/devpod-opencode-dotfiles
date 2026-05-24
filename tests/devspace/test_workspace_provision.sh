#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_provision: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/scripts/workspace-provision.sh"

[ -f "$script" ] || fail "scripts/workspace-provision.sh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_source_repo_with_main() {
  local path="$1"
  mkdir -p "$path"
  git init "$path" >/dev/null 2>&1
  (
    cd "$path"
    git config user.name 'Test User'
    git config user.email 'test@example.com'
    git branch -M main
    cat > install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'install-ran\n' > "$HOME/.workspace-install-ran"
EOF
    chmod +x install.sh
    git add install.sh
    git commit -m 'fixture main' >/dev/null 2>&1
  )
}

make_source_repo_without_main() {
  local path="$1"
  mkdir -p "$path"
  git init "$path" >/dev/null 2>&1
  (
    cd "$path"
    git config user.name 'Test User'
    git config user.email 'test@example.com'
    printf 'no-main\n' > README.md
    git add README.md
    git commit -m 'fixture no main' >/dev/null 2>&1
  )
}

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
source_repo="$tmpdir/source-main"

make_source_repo_with_main "$source_repo"
mkdir -p "$workspace_root" "$home_dir"

HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_PROVISION_SOURCE="$source_repo" \
HOME="$home_dir" \
bash "$script" > "$tmpdir/first-run.out"

for required in .bare .git main work repos state tmp; do
  [ -e "$workspace_root/$required" ] || fail "missing $required after first-time provision"
done

[ -d "$workspace_root/state/hub/main" ] || fail "missing canonical state/hub/main path"
[ -d "$workspace_root/tmp/hub/main" ] || fail "missing canonical tmp/hub/main path"

grep -F 'gitdir: ./.bare' "$workspace_root/.git" >/dev/null || fail ".git did not point to ./.bare"

wt_entry="$(git --git-dir="$workspace_root/.bare" worktree list --porcelain)"
printf '%s\n' "$wt_entry" | grep -F "worktree $workspace_root/main" >/dev/null || fail "top-level main not attached from bare repo"

main_branch="$(git -C "$workspace_root/main" rev-parse --abbrev-ref HEAD)"
[ "$main_branch" = "main" ] || fail "top-level main is not on main branch"

[ -f "$home_dir/.workspace-install-ran" ] || fail "main/install.sh was not invoked"

source_no_main="$tmpdir/source-no-main"
workspace_no_main="$tmpdir/workspace-no-main"
make_source_repo_without_main "$source_no_main"
mkdir -p "$workspace_no_main"

if HUB_WORKSPACE_ROOT="$workspace_no_main" HUB_PROVISION_SOURCE="$source_no_main" HOME="$home_dir" bash "$script" >"$tmpdir/no-main.out" 2>&1; then
  fail "expected provision to refuse when origin/main is absent"
fi

grep -F 'refused: origin/main is required for bootstrap' "$tmpdir/no-main.out" >/dev/null || fail "missing origin/main refusal message"

workspace_broken="$tmpdir/workspace-broken"
mkdir -p "$workspace_broken" "$tmpdir/home-broken"
make_source_repo_with_main "$tmpdir/source-broken"

HUB_WORKSPACE_ROOT="$workspace_broken" HUB_PROVISION_SOURCE="$tmpdir/source-broken" HOME="$tmpdir/home-broken" bash "$script" >/dev/null

git -C "$workspace_broken/main" checkout --detach >/dev/null 2>&1

if HUB_WORKSPACE_ROOT="$workspace_broken" HUB_PROVISION_SOURCE="$tmpdir/source-broken" HOME="$tmpdir/home-broken" bash "$script" >"$tmpdir/detached.out" 2>&1; then
  fail "expected provision to refuse detached existing main path"
fi

grep -F 'refused: existing main path is detached or invalid' "$tmpdir/detached.out" >/dev/null || fail "missing detached main refusal message"

printf 'PASS test_workspace_provision\n'
