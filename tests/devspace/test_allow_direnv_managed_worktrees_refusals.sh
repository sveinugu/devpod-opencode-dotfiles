#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
# shellcheck source=tests/lib/git-fixtures.sh
source "$repo_root/tests/lib/git-fixtures.sh"
require_pod_inside_nono_test 'test_allow_direnv_managed_worktrees_refusals'

script="$repo_root/bin/allow-direnv-managed-worktrees"

fail() {
  printf 'FAIL test_allow_direnv_managed_worktrees_refusals: %s\n' "$1" >&2
  exit 1
}

[ -f "$script" ] || fail 'bin/allow-direnv-managed-worktrees not found'

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_allow_direnv_managed_worktrees_refusals')"
tmpdir="$(context_make_test_tmpdir "$temp_root" 'test_allow_direnv_managed_worktrees_refusals')"
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
  git add README.md
  git commit -m 'top fixture' >/dev/null 2>&1
)

context_materialize_bare_repo_from_local "$top_source" "$workspace_root/.bare"
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1

mkdir -p "$workspace_root/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=main\n' > "$workspace_root/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_root/main" >> "$workspace_root/state/hub/etc/install.env"

set +e
bash "$script" --help >"$tmpdir/help.out" 2>&1
help_rc="$?"
set -e

[ "$help_rc" = '0' ] || fail 'expected --help to exit 0'
grep -F 'usage: allow-direnv-managed-worktrees [--allow] [--force]' "$tmpdir/help.out" >/dev/null || fail 'missing usage text in --help output'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --force >"$tmpdir/force-only.out" 2>&1
force_only_rc="$?"
set -e

[ "$force_only_rc" = '2' ] || fail 'expected --force without --allow to exit 2'
grep -F 'usage: allow-direnv-managed-worktrees [--allow] [--force]' "$tmpdir/force-only.out" >/dev/null || fail 'missing usage text for --force without --allow'

set +e
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --allow unexpected >"$tmpdir/extra-arg.out" 2>&1
extra_arg_rc="$?"
set -e

[ "$extra_arg_rc" = '2' ] || fail 'expected extra positional args to exit 2'
grep -F 'usage: allow-direnv-managed-worktrees [--allow] [--force]' "$tmpdir/extra-arg.out" >/dev/null || fail 'missing usage text for extra positional args'

set +e
(
  cd "$workspace_root"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script"
) >"$tmpdir/hub-root.out" 2>&1
hub_root_rc="$?"
set -e

[ "$hub_root_rc" = '3' ] || fail 'expected hub-root refusal exit 3'
grep -F 'Refused — hub-root CWD detected. Provide explicit worktree path.' "$tmpdir/hub-root.out" >/dev/null || fail 'missing exact hub-root refusal'

set +e
(
  cd "$tmpdir"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script"
) >"$tmpdir/unmanaged.out" 2>&1
unmanaged_rc="$?"
set -e

[ "$unmanaged_rc" = '3' ] || fail 'expected unmanaged launch refusal exit 3'
grep -F 'refused:' "$tmpdir/unmanaged.out" >/dev/null || fail 'missing unmanaged launch refusal message'

printf 'PASS test_allow_direnv_managed_worktrees_refusals\n'
