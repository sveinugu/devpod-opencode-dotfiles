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

if grep -Eq 'OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|GPT_UIO_YELLOW_API_KEY|GPT_UIO_RED_API_KEY' "$deployment"; then
  fail "deployment must not expose provider credential env vars directly"
fi

grep -Eq '^\s*-\s*name:\s*HUB_NONO_PROVIDER_SECRET_DIR\s*$' "$deployment" >/dev/null || fail "deployment should expose only non-sensitive provider secret directory env hint"

for env_credential in '"credential_key": "env://GITHUB_TOKEN"' '"credential_key": "env://GPT_UIO_YELLOW_API_KEY"' '"credential_key": "env://GPT_UIO_RED_API_KEY"'; do
  grep -F "$env_credential" "$profile" >/dev/null || fail "secure profile missing expected env credential contract: $env_credential"
done

printf 'PASS test_nono_secret_boundary_contract\n'
