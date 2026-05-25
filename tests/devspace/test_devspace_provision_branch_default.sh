#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_provision_branch_default: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cfg="$repo_root/devspace.yaml"
runbook="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"

[ -f "$cfg" ] || fail "devspace.yaml not found"
[ -f "$runbook" ] || fail "runbook not found"

grep -F 'HUB_INSTALL_BRANCH="${HUB_INSTALL_BRANCH:-main}"' "$cfg"  >/dev/null || fail "provision pipeline must default HUB_INSTALL_BRANCH to main"

if grep -F 'HUB_INSTALL_BRANCH=work/devspace-bare-hub' "$cfg" >/dev/null; then
  fail "provision pipeline must not hardcode work/devspace-bare-hub"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source_repo="$tmpdir/source"
workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"

mkdir -p "$source_repo" "$workspace_root" "$home_dir"
git init "$source_repo" >/dev/null 2>&1
(
  cd "$source_repo"
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

  git checkout -b feature/env-override >/dev/null 2>&1
  printf 'feature-branch\n' > BRANCH_MARKER
  git add BRANCH_MARKER
  git commit -m 'add branch marker' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" \
HUB_PROVISION_SOURCE="$source_repo" \
  HUB_INSTALL_BRANCH='feature/env-override' \
  HUB_PYENV_INSTALL_COMMAND=":" \
  HUB_OPENCODE_INSTALL_COMMAND=":" \
  HOME="$home_dir" \
  bash "$repo_root/scripts/provision-workspace.sh" >/dev/null

[ -f "$workspace_root/work/feature/env-override/BRANCH_MARKER" ] || fail "env-based HUB_INSTALL_BRANCH override did not provision requested branch worktree"
[ "$(git -C "$workspace_root/main" rev-parse --abbrev-ref HEAD)" = "main" ] || fail "main worktree must remain on main under HUB_INSTALL_BRANCH override"

grep -F "HUB_INSTALL_BRANCH=feature/env-override devspace run-pipeline provision" "$runbook" >/dev/null || fail "runbook must document HUB_INSTALL_BRANCH env override usage"
grep -F "devspace run-pipeline verify-ssh" "$runbook" >/dev/null || fail "runbook must document verify-ssh pipeline"

printf 'PASS test_devspace_provision_branch_default\n'
