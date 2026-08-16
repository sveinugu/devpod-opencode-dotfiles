#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
# shellcheck source=tests/lib/git-fixtures.sh
source "$repo_root/tests/lib/git-fixtures.sh"
require_pod_inside_nono_test 'test_allow_direnv_managed_worktrees'

script="$repo_root/bin/allow-direnv-managed-worktrees"
new_worktree_script="$repo_root/bin/new-worktree"
clone_repo_script="$repo_root/bin/clone-repo"

fail() {
  printf 'FAIL test_allow_direnv_managed_worktrees: %s\n' "$1" >&2
  exit 1
}

[ -f "$script" ] || fail 'bin/allow-direnv-managed-worktrees not found'
[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'
[ -f "$clone_repo_script" ] || fail 'bin/clone-repo not found'

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_allow_direnv_managed_worktrees')"
tmpdir="$(context_make_test_tmpdir "$temp_root" 'test_allow_direnv_managed_worktrees')"
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

state_dir="${DIRENV_STATE_DIR:?DIRENV_STATE_DIR must be set}"
mkdir -p "$state_dir"

if [ "$cmd" = "allow" ]; then
  if [ -n "${DIRENV_FAIL_FOR:-}" ] && [ "$target" = "$DIRENV_FAIL_FOR" ]; then
    exit 1
  fi
  : > "$state_dir/${target//\//__}.allowed"
  exit 0
fi

if [ "$cmd" = "status" ]; then
  if [ "$#" -ne 1 ]; then
    exit 2
  fi

  trust_file="$state_dir/${target//\//__}.trust"
  if [ -f "$trust_file" ]; then
    cat "$trust_file"
    exit 0
  fi

  allowed_file="$state_dir/${target//\//__}.allowed"
  if [ -f "$allowed_file" ]; then
    printf '{"state":{"foundRC":{"allowed":1,"path":"%s"}}}\n' "$target"
    exit 0
  fi

  printf '{"state":{"foundRC":{"allowed":0,"path":"%s"}}}\n' "$target"
  exit 0
fi

exit 0
EOF
chmod +x "$mock_bin/direnv"

export PATH="$mock_bin:$PATH"
export DIRENV_LOG="$direnv_log"
export DIRENV_STATE_DIR="$tmpdir/direnv-state"

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

child_source="$tmpdir/child-source"
child_source_url='https://public.example/fixtures/child-source.git'
git init "$child_source" >/dev/null 2>&1
(
  cd "$child_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M trunk
  printf 'child\n' > README.md
  git add README.md
  git commit -m 'child fixture' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" \
HOME="$home_dir" \
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0="url.$child_source.insteadOf" \
GIT_CONFIG_VALUE_0="$child_source_url" \
bash "$clone_repo_script" "$child_source_url" >/dev/null

child_repo_env="$workspace_root/state/repos/child-source/etc/repo.env"
[ -f "$child_repo_env" ] || fail 'missing child repo metadata env file'
# shellcheck disable=SC1090
. "$child_repo_env"
child_default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
[ -n "$child_default_branch" ] || fail 'missing DYN_REPO_DEFAULT_BRANCH in child metadata'

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/allowed >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/not-allowed >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/unknown >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/missing-envrc >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo hub feature/missing-envrc-local >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$new_worktree_script" --repo child-source feature/divergent >/dev/null

allowed_checkout="$workspace_root/work/feature/allowed"
not_allowed_checkout="$workspace_root/work/feature/not-allowed"
unknown_checkout="$workspace_root/work/feature/unknown"
missing_envrc_checkout="$workspace_root/work/feature/missing-envrc"
missing_envrc_local_checkout="$workspace_root/work/feature/missing-envrc-local"
divergent_checkout="$workspace_root/repos/child-source/work/feature/divergent"

: > "$direnv_log"
rm -rf "$DIRENV_STATE_DIR"
mkdir -p "$DIRENV_STATE_DIR"

: > "$DIRENV_STATE_DIR/${allowed_checkout//\//__}.allowed"

cat > "$DIRENV_STATE_DIR/${unknown_checkout//\//__}.trust" <<EOF
status unknown for $unknown_checkout
EOF

rm -f "$missing_envrc_checkout/.envrc" "$missing_envrc_checkout/.envrc.local"
rm -f "$missing_envrc_local_checkout/.envrc.local"

cat > "$divergent_checkout/.envrc" <<'EOF'
export MANUAL=1
EOF

snapshot_before="$tmpdir/snapshot-before"
mkdir -p "$snapshot_before"
cp "$not_allowed_checkout/.envrc" "$snapshot_before/not-allowed.envrc"
cp "$not_allowed_checkout/.envrc.local" "$snapshot_before/not-allowed.envrc.local"
cp "$divergent_checkout/.envrc" "$snapshot_before/divergent.envrc"

(
  cd "$workspace_root/main"
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" >"$tmpdir/dry-run.out"
)

grep -F 'plan: ' "$tmpdir/dry-run.out" >/dev/null || fail 'expected plan lines'
grep -F "$allowed_checkout" "$tmpdir/dry-run.out" | grep -F 'allowed' >/dev/null || fail 'missing allowed state'
grep -F "$not_allowed_checkout" "$tmpdir/dry-run.out" | grep -F 'not allowed' >/dev/null || fail 'missing not allowed state'
grep -F "$unknown_checkout" "$tmpdir/dry-run.out" | grep -F 'unknown' >/dev/null || fail 'missing unknown state'
grep -F "$missing_envrc_checkout" "$tmpdir/dry-run.out" | grep -F 'missing .envrc (repair+allow pending)' >/dev/null || fail 'missing .envrc status'
grep -F "$missing_envrc_local_checkout" "$tmpdir/dry-run.out" | grep -F 'missing .envrc.local (repair+allow pending)' >/dev/null || fail 'missing .envrc.local status'
grep -F "$divergent_checkout" "$tmpdir/dry-run.out" | grep -F 'divergent .envrc (force required)' >/dev/null || fail 'missing divergent status'
grep -F 'summary:' "$tmpdir/dry-run.out" >/dev/null || fail 'missing summary line'

[ ! -f "$missing_envrc_checkout/.envrc" ] || fail 'dry-run should not recreate missing .envrc'
[ ! -f "$missing_envrc_checkout/.envrc.local" ] || fail 'dry-run should not recreate missing .envrc.local'
[ ! -f "$missing_envrc_local_checkout/.envrc.local" ] || fail 'dry-run should not recreate missing .envrc.local'

cmp -s "$snapshot_before/not-allowed.envrc" "$not_allowed_checkout/.envrc" || fail 'dry-run should not mutate .envrc'
cmp -s "$snapshot_before/not-allowed.envrc.local" "$not_allowed_checkout/.envrc.local" || fail 'dry-run should not mutate .envrc.local'
cmp -s "$snapshot_before/divergent.envrc" "$divergent_checkout/.envrc" || fail 'dry-run should not rewrite divergent .envrc'

if [ -f "$direnv_log" ] && grep -F 'allow|' "$direnv_log" >/dev/null; then
  fail 'dry-run should not call direnv allow'
fi

printf 'PASS test_allow_direnv_managed_worktrees\n'
