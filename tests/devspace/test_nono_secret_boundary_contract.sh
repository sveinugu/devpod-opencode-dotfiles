#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_secret_boundary_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
deployment="$repo_root/k8s/devspace-bare-hub/workspace-deployment.yaml"
profile="$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc"

[ -f "$deployment" ] || fail "workspace deployment manifest not found"
[ -f "$profile" ] || fail "secure nono profile not found"

grep -F '/var/run/secrets/nono/providers' "$deployment" >/dev/null || fail "deployment must mount nono provider secret path"
grep -Eq '^\s*mountPath:\s*/var/run/secrets/nono/providers\s*$' "$deployment" || fail "deployment must use fixed secret mount path contract"
grep -Eq '^\s*-\s*name:\s*nono-provider-secrets\s*$' "$deployment" || fail "deployment must declare nono-provider-secrets volume"
grep -Eq '^\s*secretName:\s*dotfiles-nono-provider-credentials\s*$' "$deployment" || fail "deployment must bind expected Kubernetes secret name"

if ! grep -Eq '^\s*defaultMode:\s*0400\s*$|^\s*defaultMode:\s*256\s*$' "$deployment"; then
  fail "deployment must pin secret volume defaultMode to owner-read-only (0400/256)"
fi

if grep -Eq 'OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|GPT_UIO_YELLOW_API_KEY|GPT_UIO_RED_API_KEY' "$deployment"; then
  fail "deployment must not expose provider credential env vars directly"
fi

grep -Eq '^\s*-\s*name:\s*HUB_NONO_PROVIDER_SECRET_DIR\s*$' "$deployment" >/dev/null || fail "deployment should expose only non-sensitive provider secret directory env hint"

if ! grep -Eq '^\s*-\s*name:\s*HUB_NONO_SECRET_HELPER_SUDO\s*$' "$deployment"; then
  fail "deployment must expose explicit HUB_NONO_SECRET_HELPER_SUDO contract"
fi

grep -Eq '^\s*value:\s*sudo -n\s*$' "$deployment" >/dev/null || fail "deployment must pin HUB_NONO_SECRET_HELPER_SUDO to sudo -n"

for env_credential in '"credential_key": "env://GITHUB_TOKEN"' '"credential_key": "env://GPT_UIO_YELLOW_API_KEY"' '"credential_key": "env://GPT_UIO_RED_API_KEY"'; do
  grep -F "$env_credential" "$profile" >/dev/null || fail "secure profile missing expected env credential contract: $env_credential"
done

printf 'PASS test_nono_secret_boundary_contract\n'
