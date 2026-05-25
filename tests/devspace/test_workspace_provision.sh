#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_provision: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/scripts/provision-workspace.sh"

[ -f "$script" ] || fail "scripts/provision-workspace.sh not found"

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
install_log="$tmpdir/tool-installs.log"

make_source_repo_with_main "$source_repo"
mkdir -p "$workspace_root" "$home_dir"

HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_PROVISION_SOURCE="$source_repo" \
HUB_PYENV_INSTALL_COMMAND="printf 'pyenv-install\n' >> '$install_log'" \
HUB_OPENCODE_INSTALL_COMMAND="printf 'opencode-install\n' >> '$install_log'" \
HOME="$home_dir" \
bash "$script" > "$tmpdir/first-run.out"

for required in .bare .git main work repos state tmp; do
  [ -e "$workspace_root/$required" ] || fail "missing $required after first-time provision"
done

[ -d "$workspace_root/state/hub/main" ] || fail "missing canonical state/hub/main path"
[ -d "$workspace_root/tmp/hub/main" ] || fail "missing canonical tmp/hub/main path"
[ -f "$workspace_root/main/.envrc" ] || fail "missing managed .envrc for top-level main checkout"
[ -f "$workspace_root/main/.envrc.local" ] || fail "missing managed .envrc.local for top-level main checkout"

grep -F 'gitdir: ./.bare' "$workspace_root/.git" >/dev/null || fail ".git did not point to ./.bare"

wt_entry="$(git --git-dir="$workspace_root/.bare" worktree list --porcelain)"
printf '%s\n' "$wt_entry" | grep -F "worktree $workspace_root/main" >/dev/null || fail "top-level main not attached from bare repo"

main_branch="$(git -C "$workspace_root/main" rev-parse --abbrev-ref HEAD)"
[ "$main_branch" = "main" ] || fail "top-level main is not on main branch"

[ -f "$home_dir/.workspace-install-ran" ] || fail "main/install.sh was not invoked"

[ -f "$home_dir/.local/state/workspace-tools/pyenv.installed" ] || fail "missing pyenv marker"
[ -f "$home_dir/.local/state/workspace-tools/opencode.installed" ] || fail "missing opencode marker"

grep -F 'pyenv-install' "$install_log" >/dev/null || fail "pyenv install command was not invoked on first run"
grep -F 'opencode-install' "$install_log" >/dev/null || fail "opencode install command was not invoked on first run"

: > "$install_log"

HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_PROVISION_SOURCE="$source_repo" \
HUB_PYENV_INSTALL_COMMAND="printf 'pyenv-install\n' >> '$install_log'" \
HUB_OPENCODE_INSTALL_COMMAND="printf 'opencode-install\n' >> '$install_log'" \
HOME="$home_dir" \
bash "$script" > "$tmpdir/second-run.out"

if [ -s "$install_log" ]; then
  fail "tool installers should not run when markers are present and --refresh-tools is absent"
fi

HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_PROVISION_SOURCE="$source_repo" \
HUB_PYENV_INSTALL_COMMAND="printf 'pyenv-install\n' >> '$install_log'" \
HUB_OPENCODE_INSTALL_COMMAND="printf 'opencode-install\n' >> '$install_log'" \
HOME="$home_dir" \
bash "$script" --refresh-tools > "$tmpdir/refresh-run.out"

grep -F 'pyenv-install' "$install_log" >/dev/null || fail "--refresh-tools did not force pyenv install"
grep -F 'opencode-install' "$install_log" >/dev/null || fail "--refresh-tools did not force opencode install"

source_no_main="$tmpdir/source-no-main"
workspace_no_main="$tmpdir/workspace-no-main"
make_source_repo_without_main "$source_no_main"
mkdir -p "$workspace_no_main"

if HUB_WORKSPACE_ROOT="$workspace_no_main" \
  HUB_PROVISION_SOURCE="$source_no_main" \
  HUB_PYENV_INSTALL_COMMAND=":" \
  HUB_OPENCODE_INSTALL_COMMAND=":" \
  HOME="$home_dir" \
  bash "$script" >"$tmpdir/no-main.out" 2>&1; then
  fail "expected provision to refuse when origin/main is absent"
fi

grep -F 'refused: origin/main is required for bootstrap' "$tmpdir/no-main.out" >/dev/null || fail "missing origin/main refusal message"

workspace_broken="$tmpdir/workspace-broken"
mkdir -p "$workspace_broken" "$tmpdir/home-broken"
make_source_repo_with_main "$tmpdir/source-broken"

workspace_empty_main="$tmpdir/workspace-empty-main"
mkdir -p "$workspace_empty_main/main" "$tmpdir/home-empty-main"
make_source_repo_with_main "$tmpdir/source-empty-main"

HUB_WORKSPACE_ROOT="$workspace_empty_main" \
HUB_PROVISION_SOURCE="$tmpdir/source-empty-main" \
HUB_PYENV_INSTALL_COMMAND=":" \
HUB_OPENCODE_INSTALL_COMMAND=":" \
HOME="$tmpdir/home-empty-main" \
bash "$script" >"$tmpdir/empty-main.out"

empty_main_branch="$(git -C "$workspace_empty_main/main" rev-parse --abbrev-ref HEAD)"
[ "$empty_main_branch" = "main" ] || fail "pre-created empty main directory was not converted into tracked main worktree"

empty_main_wt_entry="$(git --git-dir="$workspace_empty_main/.bare" worktree list --porcelain)"
printf '%s\n' "$empty_main_wt_entry" | grep -F "worktree $workspace_empty_main/main" >/dev/null || fail "empty main directory was not attached as .bare worktree"

workspace_empty_main_cwd="$tmpdir/workspace-empty-main-cwd"
mkdir -p "$workspace_empty_main_cwd/main" "$tmpdir/home-empty-main-cwd"
make_source_repo_with_main "$tmpdir/source-empty-main-cwd"

if ! (
  cd "$workspace_empty_main_cwd/main"
  HUB_WORKSPACE_ROOT="$workspace_empty_main_cwd" \
  HUB_PROVISION_SOURCE="$tmpdir/source-empty-main-cwd" \
  HUB_PYENV_INSTALL_COMMAND=":" \
  HUB_OPENCODE_INSTALL_COMMAND=":" \
  HOME="$tmpdir/home-empty-main-cwd" \
  bash "$script" >"$tmpdir/empty-main-cwd.out" 2>&1
); then
  fail "provision should succeed when starting from runtime-created main as current working directory"
fi

empty_main_cwd_branch="$(git -C "$workspace_empty_main_cwd/main" rev-parse --abbrev-ref HEAD)"
[ "$empty_main_cwd_branch" = "main" ] || fail "cwd-started empty main directory was not converted into tracked main worktree"

HUB_WORKSPACE_ROOT="$workspace_broken" \
HUB_PROVISION_SOURCE="$tmpdir/source-broken" \
HUB_PYENV_INSTALL_COMMAND=":" \
HUB_OPENCODE_INSTALL_COMMAND=":" \
HOME="$tmpdir/home-broken" \
bash "$script" >/dev/null

git -C "$workspace_broken/main" checkout --detach >/dev/null 2>&1

if HUB_WORKSPACE_ROOT="$workspace_broken" \
  HUB_PROVISION_SOURCE="$tmpdir/source-broken" \
  HUB_PYENV_INSTALL_COMMAND=":" \
  HUB_OPENCODE_INSTALL_COMMAND=":" \
  HOME="$tmpdir/home-broken" \
  bash "$script" >"$tmpdir/detached.out" 2>&1; then
  fail "expected provision to refuse detached existing main path"
fi

grep -F 'refused: existing main path is detached or invalid' "$tmpdir/detached.out" >/dev/null || fail "missing detached main refusal message"

printf 'PASS test_workspace_provision\n'
