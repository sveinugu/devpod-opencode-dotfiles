#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_manifest_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_workspace_manifest_contract'

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

grep -Eq '^\s*mountPath:\s*/workspaces/dotfiles\s*$' "$deployment" || fail "missing /workspaces/dotfiles mount"
grep -Eq '^\s*subPath:\s*workspace-root\s*$' "$deployment" || fail "missing subPath workspace-root"

grep -Eq '^\s*mountPath:\s*/home/vscode\s*$' "$deployment" || fail "missing /home/vscode mount"
grep -Eq '^\s*subPath:\s*home-vscode\s*$' "$deployment" || fail "missing subPath home-vscode"

grep -Eq '^\s*mountPath:\s*/home/agent\s*$' "$deployment" || fail "missing /home/agent mount"
grep -Eq '^\s*subPath:\s*home-agent\s*$' "$deployment" || fail "missing subPath home-agent"

grep -Eq '^\s*mountPath:\s*/var/run/secrets/nono/providers\s*$' "$deployment" || fail "missing nono provider secret mount path"
grep -Eq '^\s*readOnly:\s*true\s*$' "$deployment" || fail "missing readOnly contract for nono provider secret mount"
grep -Eq '^\s*-\s*name:\s*nono-provider-secrets\s*$' "$deployment" || fail "missing nono-provider-secrets volume contract"
grep -Eq '^\s*secretName:\s*dotfiles-nono-provider-credentials\s*$' "$deployment" || fail "missing nono provider secret name contract"
if ! grep -Eq '^\s*defaultMode:\s*0400\s*$|^\s*defaultMode:\s*256\s*$' "$deployment"; then
  fail "missing fixed owner-read-only defaultMode for nono provider secret volume"
fi
grep -Eq '^\s*-\s*name:\s*HUB_NONO_PROVIDER_SECRET_DIR\s*$' "$deployment" || fail "missing non-sensitive provider secret dir env contract"
grep -Eq '^\s*value:\s*/var/run/secrets/nono/providers\s*$' "$deployment" || fail "missing provider secret dir env value contract"
grep -Eq '^\s*-\s*name:\s*HUB_NONO_SECRET_HELPER_SUDO\s*$' "$deployment" || fail "missing nono secret helper sudo env contract"
grep -Eq '^\s*value:\s*sudo -n\s*$' "$deployment" || fail "missing nono secret helper sudo value contract"
if grep -Eq '^\s*-\s*name:\s*HUB_NONO_RUNTIME_HOME\s*$' "$deployment"; then
  fail "deployment must not expose agent runtime HOME override env; wrapper defaults own this contract"
fi
if grep -Eq '^\s*-\s*name:\s*HUB_NONO_RUNTIME_XDG_CONFIG_HOME\s*$' "$deployment"; then
  fail "deployment must not expose agent runtime XDG config override env; wrapper defaults own this contract"
fi
if grep -Eq '^\s*-\s*name:\s*HUB_NONO_RUNTIME_XDG_CACHE_HOME\s*$' "$deployment"; then
  fail "deployment must not expose agent runtime XDG cache override env; wrapper defaults own this contract"
fi
if grep -Eq '^\s*-\s*name:\s*HUB_NONO_RUNTIME_XDG_DATA_HOME\s*$' "$deployment"; then
  fail "deployment must not expose agent runtime XDG data override env; wrapper defaults own this contract"
fi
if grep -Eq '^\s*-\s*name:\s*HUB_NONO_RUNTIME_XDG_STATE_HOME\s*$' "$deployment"; then
  fail "deployment must not expose agent runtime XDG state override env; wrapper defaults own this contract"
fi
if grep -Eq '^\s*-\s*name:\s*HUB_OPENCODE_RUNTIME_XDG_STATE_HOME\s*$' "$deployment"; then
  fail "deployment must not expose opencode runtime XDG state override env; wrapper defaults own this contract"
fi
grep -Eq '^\s*initContainers:\s*$' "$deployment" || fail "missing initContainers contract for /home/agent ownership bootstrap"
grep -Eq '^\s*-\s*name:\s*init-home-agent-permissions\s*$' "$deployment" || fail "missing init-home-agent-permissions contract"
grep -Eq '^\s*runAsUser:\s*0\s*$' "$deployment" || fail "missing root runAsUser contract for home-agent init container"
grep -Eq '^\s*mountPath:\s*/workspace-storage\s*$' "$deployment" || fail "missing workspace-storage mount path for init-home-agent-permissions"
grep -F '/workspace-storage/home-agent/.config/opencode' "$deployment" >/dev/null || fail "missing init mkdir contract for /workspace-storage/home-agent/.config/opencode"
grep -F '/workspace-storage/home-agent/.cache/opencode' "$deployment" >/dev/null || fail "missing init mkdir contract for /workspace-storage/home-agent/.cache/opencode"
grep -F '/workspace-storage/home-agent/.local/share/opencode' "$deployment" >/dev/null || fail "missing init mkdir contract for /workspace-storage/home-agent/.local/share/opencode"
grep -F '/workspace-storage/home-agent/.local/share/opentui' "$deployment" >/dev/null || fail "missing init mkdir contract for /workspace-storage/home-agent/.local/share/opentui"
grep -F '/workspace-storage/home-agent/.local/share/direnv' "$deployment" >/dev/null || fail "missing init mkdir contract for /workspace-storage/home-agent/.local/share/direnv"
grep -F '/workspace-storage/home-agent/.opencode' "$deployment" >/dev/null || fail "missing init mkdir contract for /workspace-storage/home-agent/.opencode"
grep -F 'touch /workspace-storage/home-agent/.gitconfig' "$deployment" >/dev/null || fail "missing init touch contract for /workspace-storage/home-agent/.gitconfig"
grep -Eq '^\s*chown -R agent:agent /workspace-storage/home-agent\s*$' "$deployment" || fail "missing init chown contract for /workspace-storage/home-agent"
grep -Eq '^\s*chmod 0700 /workspace-storage/home-agent\s*$' "$deployment" || fail "missing init chmod contract for /workspace-storage/home-agent"
grep -Eq '^\s*chmod 0600 /workspace-storage/home-agent/.gitconfig\s*$' "$deployment" || fail "missing init chmod contract for /workspace-storage/home-agent/.gitconfig"
grep -Eq '^\s*image:\s*devspace-bare-hub(\s*$|[[:space:]]+\#.*)' "$deployment" || fail "missing workspace image reference with devspace-bare-hub in deployment manifest (DevSpace replaceImageTags auto-fills tag during create_deployments)"
grep -Eq '^\s*setfacl -R -m u:agent:rwX,u:vscode:rwX /workspace-storage/workspace-root\s*$' "$deployment" || fail "missing init acl grant contract for /workspace-storage/workspace-root"
grep -Eq '^\s*setfacl -R -d -m u:agent:rwX,u:vscode:rwX /workspace-storage/workspace-root\s*$' "$deployment" || fail "missing init default acl grant contract for /workspace-storage/workspace-root"

# Verify that workingDir is set explicitly for the workspace container
grep -Eq '^\s*workingDir:\s*/workspaces/dotfiles/main\s*$' "$deployment" || fail "missing workingDir /workspaces/dotfiles/main in Deployment manifest"

printf 'PASS test_workspace_manifest_contract\n'
