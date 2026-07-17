#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_provider_enablement_sync_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
sync_cmd="$repo_root/bin/sync-provider-enablement"
policy="$repo_root/.config/opencode/provider-policy.jsonc"
wrapper="$repo_root/.config/opencode/bin/opencode"

[ -x "$sync_cmd" ] || fail "sync-provider-enablement command must exist and be executable"
[ -f "$policy" ] || fail "provider policy must exist"
[ -f "$wrapper" ] || fail "secure opencode wrapper must exist"

grep -F '/workspaces/dotfiles/state/hub/etc/provider-enablement.json' "$sync_cmd" >/dev/null || fail "sync command must default to canonical host-local enablement manifest path"
grep -F 'OPENCODE_CONFIG_CONTENT' "$wrapper" >/dev/null || fail "secure opencode wrapper must provide generated runtime config to opencode via OPENCODE_CONFIG_CONTENT"
grep -F '$source_root/.config/opencode/provider-runtime.json' "$wrapper" >/dev/null || fail "secure opencode wrapper must default to install-branch generated runtime output path"

tmp_root="$(mktemp -d "$repo_root/.tmp-provider-enablement-sync-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

manifest="$tmp_root/provider-enablement.json"
runtime_output="$tmp_root/provider-runtime.json"
verification_output="$tmp_root/provider-verification.json"

cat >"$manifest" <<'JSON'
{
  "enabled_providers": [
    "gpt-uio-red",
    "github-copilot",
    "openai"
  ]
}
JSON

"$sync_cmd" \
  --manifest "$manifest" \
  --policy "$policy" \
  --runtime-output "$runtime_output" \
  --verification-output "$verification_output" >/dev/null

python3 - "$manifest" "$runtime_output" "$verification_output" <<'PY'
import json
import sys

manifest_path, runtime_path, verification_path = sys.argv[1:4]

with open(manifest_path, 'r', encoding='utf-8') as fh:
    manifest = json.load(fh)

with open(runtime_path, 'r', encoding='utf-8') as fh:
    runtime = json.load(fh)

with open(verification_path, 'r', encoding='utf-8') as fh:
    verification = json.load(fh)

expected = manifest.get('enabled_providers', [])

if set(runtime.keys()) != {'enabled_providers'}:
    raise SystemExit(f'runtime output keys mismatch: {set(runtime.keys())!r}')

if runtime.get('enabled_providers') != expected:
    raise SystemExit(f'runtime output mismatch: {runtime.get("enabled_providers")!r}')

if verification.get('enabled_providers') != expected:
    raise SystemExit(f'verification output mismatch: {verification.get("enabled_providers")!r}')

if verification.get('status') != 'match':
    raise SystemExit(f'verification status mismatch: {verification.get("status")!r}')
PY

invalid_manifest="$tmp_root/provider-enablement-invalid.json"
cat >"$invalid_manifest" <<'JSON'
{
  "enabled_providers": [
    "openai",
    "does-not-exist"
  ]
}
JSON

if "$sync_cmd" --manifest "$invalid_manifest" --policy "$policy" --runtime-output "$runtime_output" --verification-output "$verification_output" >"$tmp_root/invalid.out" 2>&1; then
  fail "sync command should fail for unknown provider entries"
fi

grep -F 'unknown providers in enablement manifest' "$tmp_root/invalid.out" >/dev/null || fail "sync command should explain unknown provider failure"

invalid_runtime="$tmp_root/provider-runtime-invalid.json"
cat >"$invalid_runtime" <<'JSON'
{
  "enabled_providers": [
    "openai"
  ],
  "unexpected": true
}
JSON

secret_dir="$tmp_root/secrets"
mkdir -p "$secret_dir"
for key in openai_api_key anthropic_api_key github_token gpt_uio_yellow_api_key gpt_uio_red_api_key; do
  printf '%s-value\n' "$key" >"$secret_dir/$key"
done

if HUB_INSTALL_BRANCH_DIR="$repo_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_dir" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' OPENCODE_PROVIDER_RUNTIME_PATH="$invalid_runtime" bash "$wrapper" --version >"$tmp_root/invalid-runtime.out" 2>&1; then
  fail "wrapper should fail closed when generated runtime output is malformed"
fi

grep -F 'refused: generated provider runtime output contains unsupported keys' "$tmp_root/invalid-runtime.out" >/dev/null || fail "wrapper should explain malformed runtime-output failure"

printf 'PASS test_provider_enablement_sync_contract\n'
