#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_provider_policy_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_opencode_provider_policy_contract'

policy="$repo_root/.config/opencode/provider-policy.jsonc"

[ -f "$policy" ] || fail "provider policy file not found"

python3 - "$policy" <<'PY'
import json
import sys

policy_path = sys.argv[1]

with open(policy_path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)

providers = data.get('supported_providers')
if not isinstance(providers, dict):
    raise SystemExit('supported_providers must be an object')

expected_keys = {
    'gpt-uio-red',
    'gpt-uio-yellow',
    'github-copilot',
    'openai',
    'anthropic',
}

if set(providers.keys()) != expected_keys:
    raise SystemExit(f'supported_providers keys mismatch: {set(providers.keys())!r}')

red_expected = [
    ('GPT-OSS 120B', 'gpt-oss-120b', None),
    ('GLM 5.3', 'Inferact/GLM-5.3-NVFP4', None),
    ('Multilingual E5 Large Instruct', 'intfloat/multilingual-e5-large-instruct', None),
]

yellow_expected = [
    ('Gemma 4', 'google/gemma-4-31B-it', None),
    ('GPT-5', 'gpt-5', 'openai-responses'),
    ('GPT-5 mini', 'gpt-5-mini', 'openai-responses'),
    ('GPT-5.1 Thinking', 'gpt-5.1', 'openai-responses'),
    ('GPT-5.4', 'gpt-5.4', 'openai-responses'),
    ('GPT-OSS 120B', 'gpt-oss-120b', 'openai-responses'),
    ('GLM 5.3', 'Inferact/GLM-5.3-NVFP4', None),
    ('Multilingual E5 Large Instruct', 'intfloat/multilingual-e5-large-instruct', None),
    ('Kimi K2.6', 'moonshotai/Kimi-K2.6', None),
    ('Mistral Medium 3.5 128B', 'mistralai/Mistral-Medium-3.5-128B', None),
    ('NorMistral 11B', 'norallm/normistral-11b-thinking', None),
    ('NorwAI Magistral', 'NorwAI/NorwAI-Magistral-24B-reasoning', None),
    ('Qwen 3.8', 'Qwen/Qwen3.8-27B-FP8', None),
    ('GPT-6 Luna', 'gpt-6-luna', 'openai-responses'),
    ('GPT-6.1 Sol', 'gpt-6.1-sol', 'openai-responses'),
    ('GPT-6.1 Terra', 'gpt-6.1-terra', 'openai-responses'),
]

copilot_expected = None

def assert_provider(name, expected_mode, expected_models):
    provider = providers[name]
    if provider.get('mode') != expected_mode:
        raise SystemExit(f'{name} mode mismatch: {provider.get("mode")!r}')

    models = provider.get('models', [])
    if expected_models is None:
        if models not in ([], None):
            raise SystemExit(f'{name} must not declare model list when mode=all')
        return

    actual = [
        (m.get('name'), m.get('id'), (m.get('provider') or {}).get('api'))
        for m in models
    ]
    if actual != expected_models:
        raise SystemExit(f'{name} model list mismatch: {actual!r}')

assert_provider('gpt-uio-red', 'full-current-list', red_expected)
assert_provider('gpt-uio-yellow', 'full-current-list', yellow_expected)
assert_provider('github-copilot', 'all', copilot_expected)
assert_provider('openai', 'all', None)
assert_provider('anthropic', 'all', None)
PY

printf 'PASS test_opencode_provider_policy_contract\n'