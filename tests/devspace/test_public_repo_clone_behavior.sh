#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_public_repo_clone_behavior: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
clone_script="$repo_root/bin/clone-repo"
provision_script="$repo_root/scripts/provision-workspace.sh"

[ -f "$clone_script" ] || fail "bin/clone-repo not found"
[ -f "$provision_script" ] || fail "scripts/provision-workspace.sh not found"

tmpdir="$(mktemp -d)"
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
  git add README.md
  git commit -m 'public fixture main' >/dev/null 2>&1

  git checkout -b feature/public-fetch >/dev/null 2>&1
  printf 'feature\n' > FETCH_MARKER
  git add FETCH_MARKER
  git commit -m 'public fixture feature branch' >/dev/null 2>&1
  git checkout main >/dev/null 2>&1
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

require_non_interactive() {
  if [ "${GIT_TERMINAL_PROMPT:-}" != "0" ]; then
    printf 'Username for %s: ' "$1" >&2
    sleep 5
    exit 98
  fi
}

git_dir=""
args=()
for arg in "$@"; do
  case "$arg" in
    --git-dir=*)
      git_dir="${arg#--git-dir=}"
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

cmd="${args[0]:-}"

if [ "$cmd" = "ls-remote" ]; then
  source="${args[3]:-}"
  if [ "$source" = "$public_url" ]; then
    require_non_interactive "$public_url"
    exec "$real_git" ls-remote --exit-code --heads "$public_source" "${args[4]:-main}"
  fi
  if [ "$source" = "$private_url" ]; then
    require_non_interactive "$private_url"
    printf 'fatal: could not read Username for %s: terminal prompts disabled\n' "$private_url" >&2
    exit 128
  fi
fi

if [ "$cmd" = "clone" ] && [ "${args[1]:-}" = "--bare" ]; then
  source="${args[2]:-}"
  dest="${args[3]:-}"
  if [ "$source" = "$public_url" ]; then
    require_non_interactive "$public_url"
    exec "$real_git" clone --bare "$public_source" "$dest"
  fi
  if [ "$source" = "$private_url" ]; then
    require_non_interactive "$private_url"
    printf 'fatal: could not read Username for %s: terminal prompts disabled\n' "$private_url" >&2
    exit 128
  fi
fi

if [ "$cmd" = "fetch" ]; then
  remote_name="${args[1]:-origin}"
  remote_url=""
  if [ -n "$git_dir" ]; then
    remote_url="$($real_git --git-dir="$git_dir" remote get-url "$remote_name" 2>/dev/null || true)"
  fi

  if [ "$remote_url" = "$public_url" ]; then
    require_non_interactive "$public_url"
    if [ -n "$git_dir" ]; then
      exec "$real_git" --git-dir="$git_dir" fetch "$public_source" "${args[2]:-}"
    fi
    exec "$real_git" fetch "$public_source" "${args[2]:-}"
  fi

  if [ "$remote_url" = "$private_url" ]; then
    require_non_interactive "$private_url"
    printf 'fatal: could not read Username for %s: terminal prompts disabled\n' "$private_url" >&2
    exit 128
  fi
fi

if [ -n "$git_dir" ]; then
  exec "$real_git" --git-dir="$git_dir" "${args[@]}"
fi
exec "$real_git" "${args[@]}"
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

PATH="$mock_bin:$PATH" \
REAL_GIT="$real_git" \
MOCK_PUBLIC_URL="$public_url" \
MOCK_PRIVATE_URL="$private_url" \
MOCK_PUBLIC_SOURCE="$public_source" \
HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_HOME_DIR="$home_dir" \
bash "$clone_script" "$public_url" >"$tmpdir/public-clone.out" 2>&1 || fail "public HTTPS onboarding should succeed"

[ -d "$workspace_root/repos/fixture/.bare" ] || fail "missing bare repo for public HTTPS clone"

start_private_clone="$(date +%s)"
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
end_private_clone="$(date +%s)"

[ "$private_clone_rc" != "0" ] || fail "private-like HTTPS clone should fail"
[ $((end_private_clone - start_private_clone)) -lt 3 ] || fail "private-like HTTPS clone should fail fast without hanging"
grep -F 'refused: unable to access source repo non-interactively' "$tmpdir/private-clone.out" >/dev/null || fail "missing actionable non-interactive clone failure message"
if grep -F 'Username for' "$tmpdir/private-clone.out" >/dev/null; then
  fail "clone output should not include interactive username prompts"
fi

workspace_provision="$tmpdir/workspace-provision"
home_provision="$tmpdir/home-provision"
mkdir -p "$workspace_provision" "$home_provision"

PATH="$mock_bin:$PATH" \
REAL_GIT="$real_git" \
MOCK_PUBLIC_URL="$public_url" \
MOCK_PRIVATE_URL="$private_url" \
MOCK_PUBLIC_SOURCE="$public_source" \
HUB_WORKSPACE_ROOT="$workspace_provision" \
HUB_PROVISION_SOURCE="$public_url" \
HUB_PYENV_INSTALL_COMMAND=":" \
HUB_OPENCODE_INSTALL_COMMAND=":" \
HOME="$home_provision" \
bash "$provision_script" >"$tmpdir/public-provision-main.out" 2>&1 || fail "public provision main bootstrap should succeed"

PATH="$mock_bin:$PATH" \
REAL_GIT="$real_git" \
MOCK_PUBLIC_URL="$public_url" \
MOCK_PRIVATE_URL="$private_url" \
MOCK_PUBLIC_SOURCE="$public_source" \
HUB_WORKSPACE_ROOT="$workspace_provision" \
HUB_PROVISION_SOURCE="$public_url" \
HUB_INSTALL_BRANCH='feature/public-fetch' \
HUB_PYENV_INSTALL_COMMAND=":" \
HUB_OPENCODE_INSTALL_COMMAND=":" \
HOME="$home_provision" \
bash "$provision_script" >"$tmpdir/public-provision-feature.out" 2>&1 || fail "public provision fetch should succeed"

[ -f "$workspace_provision/work/feature/public-fetch/FETCH_MARKER" ] || fail "public provision fetch should attach requested branch"

start_private_provision="$(date +%s)"
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
end_private_provision="$(date +%s)"

[ "$private_provision_rc" != "0" ] || fail "private-like provision source should fail"
[ $((end_private_provision - start_private_provision)) -lt 3 ] || fail "private-like provision source should fail fast without hanging"
grep -F 'refused: unable to access source repo non-interactively' "$tmpdir/private-provision.out" >/dev/null || fail "missing actionable non-interactive provision failure message"
if grep -F 'Username for' "$tmpdir/private-provision.out" >/dev/null; then
  fail "provision output should not include interactive username prompts"
fi

printf 'PASS test_public_repo_clone_behavior\n'
