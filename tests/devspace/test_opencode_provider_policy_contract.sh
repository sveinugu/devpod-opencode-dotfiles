#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_provider_policy_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
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
    ('GPT-OSS 120B', 'gpt-oss-120b'),
    ('Multilingual E5 Large Instruct', 'intfloat/multilingual-e5-large-instruct'),
    ('GLM 5.2', 'nvidia/GLM-5.2-NVFP4'),
]

yellow_expected = [
    ('Gemma 4', 'google/gemma-4-31B-it'),
    ('GPT-5', 'gpt-5'),
    ('GPT-5 mini', 'gpt-5-mini'),
    ('GPT-5.1 Thinking', 'gpt-5.1'),
    ('GPT-5.4', 'gpt-5.4'),
    ('GPT-OSS 120B', 'gpt-oss-120b'),
    ('Multilingual E5 Large Instruct', 'intfloat/multilingual-e5-large-instruct'),
    ('Mistral Medium 3.5 128B', 'mistralai/Mistral-Medium-3.5-128B'),
    ('Kimi K2.6', 'moonshotai/Kimi-K2.6'),
    ('Multilingual E5 Large Instruct', 'multilingual-e5-large-instruct'),
    ('NorwAI Magistral', 'NorwAI/NorwAI-Magistral-24B-reasoning'),
    ('GLM 5.2', 'nvidia/GLM-5.2-NVFP4'),
    ('Qwen 3.6', 'Qwen/Qwen3.6-27B-FP8'),
]

copilot_expected = [
    ('GPT-5 mini', 'github-copilot/gpt-5-mini'),
    ('GPT-5.4', 'github-copilot/gpt-5.4'),
    ('GPT-5.3 Codex', 'github-copilot/gpt-5.3-codex'),
]

def assert_provider(name, expected_mode, expected_models):
    provider = providers[name]
    if provider.get('mode') != expected_mode:
        raise SystemExit(f'{name} mode mismatch: {provider.get("mode")!r}')

    models = provider.get('models', [])
    if expected_models is None:
        if models not in ([], None):
            raise SystemExit(f'{name} must not declare model list when mode=all')
        return

    actual = [(m.get('name'), m.get('id')) for m in models]
    if actual != expected_models:
        raise SystemExit(f'{name} model list mismatch: {actual!r}')

assert_provider('gpt-uio-red', 'full-current-list', red_expected)
assert_provider('gpt-uio-yellow', 'full-current-list', yellow_expected)
assert_provider('github-copilot', 'allowlist', copilot_expected)
assert_provider('openai', 'all', None)
assert_provider('anthropic', 'all', None)
PY

printf 'PASS test_opencode_provider_policy_contract\n'
