#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_manifest_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
manifest_dir="$repo_root/k8s/devspace-bare-hub"
deployment="$manifest_dir/workspace-deployment.yaml"
pvc="$manifest_dir/workspace-pvc.yaml"

[ -f "$deployment" ] || fail "workspace-deployment.yaml not found"
[ -f "$pvc" ] || fail "workspace-pvc.yaml not found"

deployment_count="$(grep -R -E '^kind:\s*Deployment\s*$' "$manifest_dir"/*.yaml | wc -l | tr -d ' ')"
[ "$deployment_count" = "1" ] || fail "expected exactly one Deployment, got $deployment_count"

pvc_count="$(grep -R -E '^kind:\s*PersistentVolumeClaim\s*$' "$manifest_dir"/*.yaml | wc -l | tr -d ' ')"
[ "$pvc_count" = "1" ] || fail "expected exactly one PersistentVolumeClaim, got $pvc_count"

if grep -R -q -E '^kind:\s*Service\s*$' "$manifest_dir"/*.yaml; then
  fail "standalone Service manifest must not exist"
fi

grep -Eq '^\s*workingDir:\s*/workspaces/dotfiles/main\s*$' "$deployment" || fail "missing workingDir /workspaces/dotfiles/main"

grep -Eq '^\s*mountPath:\s*/workspaces/dotfiles\s*$' "$deployment" || fail "missing /workspaces/dotfiles mount"
grep -Eq '^\s*subPath:\s*workspace-root\s*$' "$deployment" || fail "missing subPath workspace-root"

grep -Eq '^\s*mountPath:\s*/home/vscode\s*$' "$deployment" || fail "missing /home/vscode mount"
grep -Eq '^\s*subPath:\s*home-vscode\s*$' "$deployment" || fail "missing subPath home-vscode"

printf 'PASS test_workspace_manifest_contract\n'
