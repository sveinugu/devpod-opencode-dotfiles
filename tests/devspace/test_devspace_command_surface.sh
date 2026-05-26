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
grep -Eq '^\s{4}flags:\s*$' "$cfg" || fail "provision pipeline should define custom flags"
grep -Eq '^\s{6}-\s+name:\s+no-prompts\s*$' "$cfg" || fail "provision pipeline should expose --no-prompts flag"
grep -Eq '^\s{6}-\s+name:\s+refresh-tools\s*$' "$cfg" || fail "provision pipeline should expose --refresh-tools flag"
grep -Eq '^\s{4}run:\s*\|-\s*$' "$cfg" || fail "provision pipeline should use run block when flags are defined"
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
grep -F 'scripts/resolve-git-identity.sh' "$cfg" >/dev/null || fail "provision pipeline should resolve git identity before pod provisioning"
grep -F 'if [ "$(get_flag "no-prompts")" = "true" ]; then' "$cfg" >/dev/null || fail "provision pipeline should read --no-prompts via get_flag"
grep -F 'HUB_GIT_IDENTITY_ENV=$(bash scripts/resolve-git-identity.sh --no-prompts ${HUB_GIT_IDENTITY_ARGS:-})' "$cfg" >/dev/null || fail "provision pipeline should pass --no-prompts to identity resolver when requested"
grep -F 'if [ "$(get_flag "refresh-tools")" = "true" ]; then' "$cfg" >/dev/null || fail "provision pipeline should read --refresh-tools via get_flag"
grep -F 'HUB_PROVISION_RUNTIME_ARGS="--refresh-tools ${HUB_PROVISION_ARGS:-}"' "$cfg" >/dev/null || fail "provision pipeline should append refresh-tools provision arg when requested"
grep -F 'HUB_GIT_IDENTITY_ENV=$(bash scripts/resolve-git-identity.sh ${HUB_GIT_IDENTITY_ARGS:-})' "$cfg" >/dev/null || fail "provision pipeline should keep interactive prompts by default"
grep -F '/tmp/provision-workspace.sh ${HUB_PROVISION_RUNTIME_ARGS:-}' "$cfg" >/dev/null || fail "provision pipeline should forward computed provision runtime args"
grep -F 'eval "$HUB_GIT_IDENTITY_ENV"' "$cfg" >/dev/null || fail "provision pipeline should evaluate resolved identity assignments before kubectl exec"
grep -F 'env HUB_GITHUB_USER_NAME="${HUB_GITHUB_USER_NAME:-}" HUB_GITHUB_USER_EMAIL="${HUB_GITHUB_USER_EMAIL:-}" HUB_INSTALL_BRANCH="${HUB_INSTALL_BRANCH:-main}"' "$cfg" >/dev/null || fail "provision pipeline should quote identity env vars when forwarding into pod provision"

printf 'PASS test_devspace_command_surface\n'
