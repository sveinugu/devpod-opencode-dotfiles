#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_command_surface: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cfg="$repo_root/devspace.yaml"

[ -f "$cfg" ] || fail "devspace.yaml not found"

grep -Eq '^dev:\s*$' "$cfg" || fail "missing dev section"
grep -Eq '^\s{2}workspace:\s*$' "$cfg" || fail "missing dev workspace entry"

grep -Eq '^\s{2}provision:\s*' "$cfg" || fail "missing provision pipeline"
grep -Eq '^\s{2}doctor:\s*' "$cfg" || fail "missing doctor pipeline"
grep -Eq '^\s{2}repair:\s*' "$cfg" || fail "missing repair pipeline"
grep -Eq '^\s{2}destroy:\s*' "$cfg" || fail "missing destroy pipeline"

if grep -Eq '^\s{2}staging:\s*' "$cfg"; then
  fail "staging pipeline must not exist in phase 1"
fi

if grep -Eq '^\s{2}backup:\s*' "$cfg"; then
  fail "backup pipeline must not exist in phase 1"
fi

grep -F 'install_env=/workspaces/dotfiles/state/hub/etc/install.env' "$cfg" >/dev/null || fail "dev command should consult install.env for install branch directory"
grep -F 'preflight_dir="${HUB_INSTALL_BRANCH_DIR:-/workspaces/dotfiles/main}"' "$cfg" >/dev/null || fail "dev command should default preflight directory to main checkout"
grep -F '"$preflight_dir/scripts/preflight-devspace-dev.sh"' "$cfg" >/dev/null || fail "dev command should run renamed preflight from resolved install checkout"
grep -F '/workspaces/dotfiles/main/scripts/devspace-dev-preflight.sh' "$cfg" >/dev/null || fail "dev command should support legacy preflight fallback in main"
grep -F 'if [ -d /workspaces/dotfiles/.bare ]; then' "$cfg" >/dev/null || fail "dev command should only warn when bare workspace exists"
grep -F 'workspace not provisioned; run devspace run-pipeline provision' "$cfg" >/dev/null || fail "dev command should preserve not-provisioned guidance"

printf 'PASS test_devspace_command_surface\n'
