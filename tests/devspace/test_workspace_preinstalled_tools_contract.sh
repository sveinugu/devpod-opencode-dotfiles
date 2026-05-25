#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_preinstalled_tools_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
deployment="$repo_root/k8s/devspace-bare-hub/workspace-deployment.yaml"
dockerfile="$repo_root/Dockerfile"
provision_script="$repo_root/scripts/provision-workspace.sh"

[ -f "$deployment" ] || fail "workspace-deployment.yaml not found"
[ -f "$dockerfile" ] || fail "Dockerfile not found"
[ -f "$provision_script" ] || fail "provision-workspace.sh not found"

grep -Eq '^\s*mountPath:\s*/home/vscode\s*$' "$deployment" || fail "missing /home/vscode mount from PVC"
grep -Eq '^\s*subPath:\s*home-vscode\s*$' "$deployment" || fail "missing home-vscode PVC subPath"

if grep -F 'curl https://pyenv.run | zsh' "$dockerfile" >/dev/null; then
  fail "pyenv must not be image-installed; install at provision time"
fi

if grep -F 'curl -fsSL https://opencode.ai/install | zsh' "$dockerfile" >/dev/null; then
  fail "opencode must not be image-installed; install at provision time"
fi

if grep -F 'mkdir -p /home/vscode/.ssh' "$dockerfile" >/dev/null; then
  fail "/home/vscode setup must not happen in Dockerfile; PVC mount hides it"
fi

if grep -F 'mkdir -p /home/vscode/.local/share/opencode' "$dockerfile" >/dev/null; then
  fail "/home/vscode/.local/share/opencode setup must not happen in Dockerfile"
fi

if grep -F 'mkdir -p /home/vscode/.config/opencode' "$dockerfile" >/dev/null; then
  fail "/home/vscode/.config/opencode setup must not happen in Dockerfile"
fi

grep -F -- '--refresh-tools' "$provision_script" >/dev/null || fail "missing --refresh-tools contract in provision script"
grep -F 'https://pyenv.run' "$provision_script" >/dev/null || fail "missing pyenv provision installer"
grep -F 'https://opencode.ai/install' "$provision_script" >/dev/null || fail "missing opencode provision installer"
grep -F 'mkdir -p "$home_dir/.ssh" "$home_dir/.local/share/opencode"' "$provision_script" >/dev/null || fail "missing provision-time /home/vscode bootstrap directories"

printf 'PASS test_workspace_preinstalled_tools_contract\n'
