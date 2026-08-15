#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/context/lib/context-guards.sh
source "$repo_root/tests/context/lib/context-guards.sh"
require_workspace_pod 'test_public_repo_clone_behavior_ux' 'bash tests/context/run.sh pod-outside-nono'
require_outside_nono_sandbox 'test_public_repo_clone_behavior_ux' 'bash tests/context/run.sh pod-outside-nono'

fail() {
  printf 'FAIL test_public_repo_clone_behavior_ux: %s\n' "$1" >&2
  exit 1
}

temp_root="${TEMP:-${TMP:-${TMPDIR:-}}}"
[ -n "$temp_root" ] || fail 'TEMP/TMP/TMPDIR must be set (expected from .envrc)'
case "$temp_root" in
  /*) ;;
  *) fail "TEMP/TMP/TMPDIR must be an absolute path: $temp_root" ;;
esac
test_tmp_root="$temp_root/tests"
mkdir -p "$test_tmp_root"

clone_script="$repo_root/bin/clone-repo"
provision_script="$repo_root/scripts/provision-workspace.sh"

[ -f "$clone_script" ] || fail "bin/clone-repo not found"
[ -f "$provision_script" ] || fail "scripts/provision-workspace.sh not found"

tmpdir="$(mktemp -d "$test_tmp_root/test_public_repo_clone_behavior_ux-XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

real_git="$(command -v git)"
public_url='https://public.example/fixture.git'
private_url='https://private.example/secret.git'

public_source="$tmpdir/public-source"
git init "$public_source" >/dev/null 2>&1
(
  cd "$public_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'main\n' > README.md
  printf '#!/usr/bin/env bash\nset -euo pipefail\n:\n' > install.sh
  chmod +x install.sh
  git add README.md install.sh
  git commit -m 'public fixture main' >/dev/null 2>&1
)

mock_bin="$tmpdir/mock-bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

real_git="${REAL_GIT:?REAL_GIT must be set}"
public_url="${MOCK_PUBLIC_URL:?MOCK_PUBLIC_URL must be set}"
private_url="${MOCK_PRIVATE_URL:?MOCK_PRIVATE_URL must be set}"
public_source="${MOCK_PUBLIC_SOURCE:?MOCK_PUBLIC_SOURCE must be set}"

if [ "${1:-}" = "ls-remote" ]; then
  source=""
  if [ "${2:-}" = "--symref" ]; then
    source="${3:-}"
  elif [ "${2:-}" = "--exit-code" ] && [ "${3:-}" = "--heads" ]; then
    source="${4:-}"
  fi
  if [ "$source" = "$public_url" ]; then
    exec "$real_git" "${@/$public_url/$public_source}"
  fi
  if [ "$source" = "$private_url" ]; then
    printf 'fatal: could not read Username for %s: terminal prompts disabled\n' "$private_url" >&2
    exit 128
  fi
fi

if [ "${1:-}" = "clone" ] && [ "${2:-}" = "--bare" ]; then
  source="${3:-}"
  if [ "$source" = "$public_url" ]; then
    exec "$real_git" clone --bare "$public_source" "${4:-}"
  fi
  if [ "$source" = "$private_url" ]; then
    printf 'fatal: could not read Username for %s: terminal prompts disabled\n' "$private_url" >&2
    exit 128
  fi
fi

exec "$real_git" "$@"
EOF
chmod +x "$mock_bin/git"

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

set +e
PATH="$mock_bin:$PATH" \
REAL_GIT="$real_git" \
MOCK_PUBLIC_URL="$public_url" \
MOCK_PRIVATE_URL="$private_url" \
MOCK_PUBLIC_SOURCE="$public_source" \
HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_HOME_DIR="$home_dir" \
bash "$clone_script" "$private_url" >"$tmpdir/private-clone.out" 2>&1
private_clone_rc="$?"
set -e
[ "$private_clone_rc" != "0" ] || fail "private-like HTTPS clone should fail"
grep -F 'refused: unable to access source repo non-interactively' "$tmpdir/private-clone.out" >/dev/null || fail "missing actionable non-interactive clone failure message"
if grep -F 'Username for' "$tmpdir/private-clone.out" >/dev/null; then
  fail "clone output should not include interactive username prompts"
fi

set +e
PATH="$mock_bin:$PATH" \
REAL_GIT="$real_git" \
MOCK_PUBLIC_URL="$public_url" \
MOCK_PRIVATE_URL="$private_url" \
MOCK_PUBLIC_SOURCE="$public_source" \
HUB_WORKSPACE_ROOT="$tmpdir/workspace-private-provision" \
HUB_PROVISION_SOURCE="$private_url" \
HUB_PYENV_INSTALL_COMMAND=":" \
HUB_OPENCODE_INSTALL_COMMAND=":" \
HOME="$tmpdir/home-private-provision" \
bash "$provision_script" >"$tmpdir/private-provision.out" 2>&1
private_provision_rc="$?"
set -e
[ "$private_provision_rc" != "0" ] || fail "private-like provision source should fail"
grep -F 'refused: unable to access source repo non-interactively' "$tmpdir/private-provision.out" >/dev/null || fail "missing actionable non-interactive provision failure message"
if grep -F 'Username for' "$tmpdir/private-provision.out" >/dev/null; then
  fail "provision output should not include interactive username prompts"
fi

printf 'PASS test_public_repo_clone_behavior_ux\n'
