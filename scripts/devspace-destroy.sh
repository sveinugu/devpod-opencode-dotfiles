#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 0 ]; then
  printf 'usage: devspace-destroy.sh\n' >&2
  exit 2
fi

kubectl_bin="${KUBECTL_BIN:-kubectl}"
namespace="${DEVSPACE_NAMESPACE:-default}"
deployment_name="${HUB_WORKSPACE_DEPLOYMENT:-dotfiles-workspace}"
devspace_deployment_name="${HUB_DEVSPACE_DEPLOYMENT:-dotfiles-workspace-devspace}"
pvc_name="${HUB_WORKSPACE_PVC:-dotfiles-workspace}"

"$kubectl_bin" delete deployment "$deployment_name" --ignore-not-found=true -n "$namespace"
"$kubectl_bin" delete deployment "$devspace_deployment_name" --ignore-not-found=true -n "$namespace"
"$kubectl_bin" delete pvc "$pvc_name" --ignore-not-found=true -n "$namespace"

printf 'ok: destroy requested for deployments/%s,%s and pvc/%s in namespace %s\n' "$deployment_name" "$devspace_deployment_name" "$pvc_name" "$namespace"
