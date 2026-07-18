#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_runtime_contract_alignment: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
policy="$repo_root/.config/opencode/provider-policy.jsonc"
profile="$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc"
opencode_cfg="$repo_root/.config/opencode/opencode.jsonc"

[ -f "$policy" ] || fail "provider policy file not found"
[ -f "$profile" ] || fail "secure nono profile not found"
[ -f "$opencode_cfg" ] || fail "opencode config not found"

for required_provider in 'gpt-uio-red' 'gpt-uio-yellow' 'github-copilot' 'openai' 'anthropic'; do
  grep -F "\"$required_provider\"" "$policy" >/dev/null || fail "provider policy missing $required_provider"
done

for required_credential in '"github-copilot"'; do
  grep -F "$required_credential" "$profile" >/dev/null || fail "nono profile missing credential route for $required_credential"
done

for forbidden_credential in '"openai"' '"anthropic"' '"gpt-uio-yellow"' '"gpt-uio-red"'; do
  if grep -F "$forbidden_credential" "$profile" >/dev/null; then
    fail "nono profile should not proxy unmanaged credential route $forbidden_credential in secure runtime profile"
  fi
done

for required_env in '"credential_key": "env://GITHUB_TOKEN"'; do
  grep -F "$required_env" "$profile" >/dev/null || fail "nono profile missing env credential route contract: $required_env"
done

if grep -F '"enabled_providers"' "$opencode_cfg" >/dev/null; then
  fail "opencode runtime config must not introduce global enabled_providers allowlist"
fi

printf 'PASS test_opencode_runtime_contract_alignment\n'
