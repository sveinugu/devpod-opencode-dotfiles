#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
# shellcheck source=tests/lib/git-fixtures.sh
source "$repo_root/tests/lib/git-fixtures.sh"
require_pod_inside_nono_test 'test_allow_direnv_managed_worktrees_failures'

script="$repo_root/bin/allow-direnv-managed-worktrees"
new_worktree_script="$repo_root/bin/new-worktree"

fail() {
  printf 'FAIL test_allow_direnv_managed_worktrees_failures: %s\n' "$1" >&2
  exit 1
}

[ -f "$script" ] || fail 'bin/allow-direnv-managed-worktrees not found'
[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_allow_direnv_managed_worktrees_failures')"
tmpdir="$(context_make_test_tmpdir "$temp_root" 'test_allow_direnv_managed_worktrees_failures')"
trap 'rm -rf "$tmpdir"' EXIT

mock_bin="$tmpdir/bin"
mkdir -p "$mock_bin"
direnv_log="$tmpdir/direnv.log"

cat > "$mock_bin/direnv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
target="${2:-$(pwd -P)}"
printf '%s|%s\n' "$cmd" "$target" >> "${DIRENV_LOG:?DIRENV_LOG must be set}"

if [ "$cmd" = "status" ]; then
  if [ "$#" -ne 1 ]; then
    exit 2
  fi
  printf '{"state":{"foundRC":{"allowed":0,"path":"%s"}}}\n' "$target"
  exit 0
fi

if [ "$cmd" = "allow" ]; then
  if [ -n "${DIRENV_FAIL_FOR:-}" ] && [ "$target" = "$DIRENV_FAIL_FOR" ]; then
    exit 1
  fi
  exit 0
fi

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

context_materialize_bare_repo_from_local "$top_source" "$workspace_root/.bare"
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1

mkdir -p "$workspace_root/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=main\n' > "$workspace_root/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_root/main" >> "$workspace_root/state/hub/etc/install.env"

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/failing >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/later >/dev/null

failing_checkout="$workspace_root/work/feature/failing"
later_checkout="$workspace_root/work/feature/later"

: > "$direnv_log"

set +e
(
  cd "$workspace_root/main"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" DIRENV_FAIL_FOR="$failing_checkout" bash "$script" --allow --force >"$tmpdir/failures.out" 2>&1
)
command_rc="$?"
set -e

[ "$command_rc" = '1' ] || fail 'expected overall exit 1 when one target fails'
grep -F 'error:' "$tmpdir/failures.out" >/dev/null || fail 'expected error reporting'
grep -F "ok: allowed $later_checkout" "$tmpdir/failures.out" >/dev/null || fail 'expected later target to continue'

printf 'PASS test_allow_direnv_managed_worktrees_failures\n'
