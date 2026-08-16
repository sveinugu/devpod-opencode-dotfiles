#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_provider_enablement_sync_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_provider_enablement_sync_contract'

sync_cmd="$repo_root/bin/sync-provider-enablement"
policy="$repo_root/.config/opencode/provider-policy.jsonc"
wrapper="$repo_root/.config/opencode/bin/opencode"

[ -x "$sync_cmd" ] || fail "sync-provider-enablement command must exist and be executable"
[ -f "$policy" ] || fail "provider policy must exist"
[ -f "$wrapper" ] || fail "secure opencode wrapper must exist"

grep -F '/workspaces/dotfiles/state/hub/etc/provider-enablement.json' "$sync_cmd" >/dev/null || fail "sync command must default to canonical host-local enablement manifest path"
grep -F '$repo_root/.config/opencode/provider-runtime.json' "$sync_cmd" >/dev/null || fail "sync command must default runtime output path to install-branch wrapper input path"
grep -F '$repo_root/.config/opencode/provider-verification.json' "$sync_cmd" >/dev/null || fail "sync command must default verification output path to install-branch wrapper verification path"
if ! grep -F 'OPENCODE_CONFIG_CONTENT' "$wrapper" >/dev/null && ! grep -F -- '--opencode-config-content' "$wrapper" >/dev/null; then
  fail "secure opencode wrapper must provide generated runtime config to opencode launch chain"
fi
grep -F '$source_root/.config/opencode/provider-runtime.json' "$wrapper" >/dev/null || fail "secure opencode wrapper must default to install-branch generated runtime output path"

seed_manifest="$repo_root/.config/opencode/provider-enablement.seed.json"
[ -f "$seed_manifest" ] || fail "provider enablement seed manifest must exist for bootstrap guardrail"

python3 - "$seed_manifest" "$policy" <<'PY'
import json
import sys

seed_path, policy_path = sys.argv[1:]

with open(seed_path, 'r', encoding='utf-8') as fh:
    seed = json.load(fh)

with open(policy_path, 'r', encoding='utf-8') as fh:
    policy = json.load(fh)

enabled = seed.get('enabled_providers')
if not isinstance(enabled, list):
    raise SystemExit('seed manifest must define enabled_providers list')

supported = set(policy.get('supported_providers', {}).keys())

for provider in enabled:
    if provider not in supported:
        raise SystemExit(f'seed manifest provider is not supported: {provider}')
PY

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_provider_enablement_sync_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_provider_enablement_sync_contract')"
trap 'rm -rf "$tmp_root"' EXIT

manifest="$tmp_root/provider-enablement.json"
runtime_output="$tmp_root/provider-runtime.json"
verification_output="$tmp_root/provider-verification.json"

python3 - "$policy" "$tmp_root/expected-provider-payload.json" <<'PY'
import json
import sys

policy_path, out_path = sys.argv[1:]

with open(policy_path, 'r', encoding='utf-8') as fh:
    policy = json.load(fh)

providers = policy.get('supported_providers', {})

provider_payload = {
    'gpt-uio-red': {
        'api': 'openai',
        'options': {'baseURL': 'https://gpt.uio.no/api/v1'},
        'models': {},
    },
    'gpt-uio-yellow': {
        'api': 'openai',
        'options': {'baseURL': 'https://gpt.uio.no/api/v1'},
        'models': {},
    },
    'github-copilot': {
        'whitelist': [],
    },
}

for provider_name in ('gpt-uio-red', 'gpt-uio-yellow'):
    for model in providers.get(provider_name, {}).get('models', []):
        model_id = model['id']
        provider_payload[provider_name]['models'][model_id] = {
            'name': model['name'],
            'id': model_id,
        }

for model in providers.get('github-copilot', {}).get('models', []):
    model_id = model['id']
    if isinstance(model_id, str) and model_id.startswith('github-copilot/'):
        model_id = model_id.split('/', 1)[1]
    provider_payload['github-copilot']['whitelist'].append(model_id)

for provider_name in ('gpt-uio-red', 'gpt-uio-yellow', 'github-copilot'):
    if provider_name not in providers:
        provider_payload.pop(provider_name, None)

with open(out_path, 'w', encoding='utf-8') as fh:
    json.dump(provider_payload, fh, indent=2)
    fh.write('\n')
PY

cat >"$manifest" <<'JSON'
{
  "enabled_providers": [
    "gpt-uio-red",
    "github-copilot",
    "openai",
    "gpt-uio-yellow"
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

if set(runtime.keys()) != {'enabled_providers', 'provider'}:
    raise SystemExit(f'runtime output keys mismatch: {set(runtime.keys())!r}')

if runtime.get('enabled_providers') != expected:
    raise SystemExit(f'runtime output mismatch: {runtime.get("enabled_providers")!r}')

provider_payload = runtime.get('provider')
if not isinstance(provider_payload, dict):
    raise SystemExit('runtime provider payload must be an object')

copilot_payload = provider_payload.get('github-copilot', {})
if not isinstance(copilot_payload, dict):
    raise SystemExit('runtime github-copilot payload must be an object when enabled')

for model_id in copilot_payload.get('whitelist', []):
    if isinstance(model_id, str) and model_id.startswith('github-copilot/'):
        raise SystemExit(f'github-copilot whitelist must use canonical model ids without provider prefix: {model_id}')

if verification.get('enabled_providers') != expected:
    raise SystemExit(f'verification output mismatch: {verification.get("enabled_providers")!r}')

if verification.get('status') != 'match':
    raise SystemExit(f'verification status mismatch: {verification.get("status")!r}')
PY

python3 - "$runtime_output" "$tmp_root/expected-provider-payload.json" <<'PY'
import json
import sys

runtime_path, expected_path = sys.argv[1:]

with open(runtime_path, 'r', encoding='utf-8') as fh:
    runtime = json.load(fh)

with open(expected_path, 'r', encoding='utf-8') as fh:
    expected = json.load(fh)

if runtime.get('provider') != expected:
    raise SystemExit('runtime provider payload does not match policy-derived expected payload')
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

disabled_manifest="$tmp_root/provider-enablement-disabled-uio.json"
cat >"$disabled_manifest" <<'JSON'
{
  "enabled_providers": [
    "openai"
  ]
}
JSON

"$sync_cmd" --manifest "$disabled_manifest" --policy "$policy" --runtime-output "$runtime_output" --verification-output "$verification_output" >/dev/null

python3 - "$runtime_output" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    runtime = json.load(fh)

provider_payload = runtime.get('provider', {})

for forbidden in ('gpt-uio-red', 'gpt-uio-yellow', 'github-copilot'):
    if forbidden in provider_payload:
        raise SystemExit(f'{forbidden} should be absent from runtime provider payload when disabled in manifest')
PY

chmod 0400 "$runtime_output" "$verification_output"

"$sync_cmd" --manifest "$manifest" --policy "$policy" --runtime-output "$runtime_output" --verification-output "$verification_output" >/dev/null

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

if runtime.get('enabled_providers') != expected:
    raise SystemExit('runtime output should be replaceable even when previous file is read-only')

if verification.get('enabled_providers') != expected:
    raise SystemExit('verification output should be replaceable even when previous file is read-only')
PY

printf 'PASS test_provider_enablement_sync_contract\n'
