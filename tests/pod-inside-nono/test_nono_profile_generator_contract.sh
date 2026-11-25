#!/usr/bin/env bash
set -euo pipefail

# Run the real profile generator on the repository template and check the
# parsed output. No mocks: the generator only reads files and its environment.
# The session value is synthetic; the generator only needs to know it is present.

fail() {
  printf 'FAIL test_nono_profile_generator_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_nono_profile_generator_contract'

generator="$repo_root/scripts/lib/generate-nono-profile.py"
template="$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_nono_profile_generator_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_nono_profile_generator_contract')"
trap 'rm -rf "$tmp_root"' EXIT

synthetic_session='{"access":"synthetic-access","account_id":"synthetic-account","expires_at":4102444800}'

# generate <name> <session|-> <providers...>: prints the generated profile path.
generate() {
  local name="$1" session="$2"
  shift 2
  local out_dir="$tmp_root/$name"
  mkdir -p "$out_dir"
  python3 - "$tmp_root/$name.runtime.json" "$@" <<'PY'
import json
import sys
with open(sys.argv[1], 'w', encoding='utf-8') as fh:
    json.dump({'enabled_providers': sys.argv[2:], 'provider': {}}, fh)
PY
  if [ "$session" = '-' ]; then
    env -u OPENAI_CHATGPT_SESSION python3 "$generator" --template "$template" --runtime "$tmp_root/$name.runtime.json" --output-dir "$out_dir"
  else
    OPENAI_CHATGPT_SESSION="$session" python3 "$generator" --template "$template" --runtime "$tmp_root/$name.runtime.json" --output-dir "$out_dir"
  fi
}

# check <profile> <expect-chatgpt yes|no> <expect-copilot yes|no>
check() {
  python3 - "$@" <<'PY'
import json
import sys

path, expect_chatgpt, expect_copilot = sys.argv[1:]
with open(path, encoding='utf-8') as fh:
    profile = json.load(fh)

network = profile['network']
routes = network['custom_credentials']
listed = network['credentials']
capture = profile.get('credential_capture', {})
deny = profile['environment']['deny_vars']

def need(condition, message):
    if not condition:
        raise SystemExit(message)

for name in ('OPENAI_CHATGPT_SESSION', 'OPENAI_API_KEY'):
    need(name in deny, f'{name} must be in environment.deny_vars')

# The API-key route is removed, and no route may claim the plain openai name,
# because nono would then export OPENAI_BASE_URL and change OpenCode's request path.
need('openai' not in routes and 'openai' not in listed, 'profile must not contain an openai route')
for name, route in routes.items():
    need(route.get('credential_key') != 'env://OPENAI_API_KEY', f'{name} must not use OPENAI_API_KEY')

has_chatgpt = 'openai-chatgpt' in routes
need(has_chatgpt == ('openai-chatgpt' in listed), 'openai-chatgpt must be listed exactly when its route exists')
need(has_chatgpt == ('openai_chatgpt' in capture), 'openai-chatgpt capture entry must exist exactly when its route exists')
need(has_chatgpt == (expect_chatgpt == 'yes'), f'openai-chatgpt route present={has_chatgpt}, expected {expect_chatgpt}')
need(('github-copilot' in routes) == (expect_copilot == 'yes'), 'github-copilot route must follow its own enablement')

if has_chatgpt:
    route = routes['openai-chatgpt']
    need(route.get('upstream') == 'https://chatgpt.com/backend-api/codex', 'ChatGPT route upstream mismatch')
    need(route.get('credential_key') == 'cmd://openai_chatgpt', 'ChatGPT route must use the cmd:// header helper')
    need(route.get('env_var') not in (None, 'OPENAI_API_KEY'), 'ChatGPT route needs its own route variable')
    entry = capture['openai_chatgpt']
    need(entry.get('cache_ttl_secs') == 0, 'ChatGPT headers must not be cached')
    need(entry.get('command', [None])[0] == '/usr/local/libexec/dotfiles-chatgpt-headers', 'capture must run the root-owned header helper')
    output = entry.get('output', {})
    need(output.get('format') == 'json', 'header helper output must be JSON')
    need(set(output.get('allow_headers', [])) == {'Authorization', 'ChatGPT-Account-Id', 'x-openai-internal-codex-residency'}, 'allowed header set mismatch')
PY
}

profile="$(generate connected "$synthetic_session" gpt-uio-yellow github-copilot openai-chatgpt)" || fail "generator should accept openai-chatgpt"
check "$profile" yes yes || fail "enabled and connected: ChatGPT route expected"
nono profile show "$profile" --json >/dev/null 2>&1 || fail "nono should accept the generated profile with the ChatGPT route"

profile="$(generate disconnected - gpt-uio-yellow github-copilot openai-chatgpt)" || fail "generator should accept enabled but disconnected ChatGPT"
check "$profile" no yes || fail "enabled but disconnected: no ChatGPT route expected"

profile="$(generate empty-session '' gpt-uio-yellow openai-chatgpt)" || fail "generator should accept an empty session variable"
check "$profile" no no || fail "empty session: no ChatGPT route expected"

profile="$(generate not-enabled "$synthetic_session" gpt-uio-yellow github-copilot)" || fail "generator should run without ChatGPT enabled"
check "$profile" no yes || fail "not enabled: no ChatGPT route expected even with a session"

for token in openai does-not-exist; do
  if generate "refused-$token" - gpt-uio-yellow "$token" >"$tmp_root/refused.out" 2>&1; then
    fail "generator must refuse unknown enablement token: $token"
  fi
  if find "$tmp_root/refused-$token" -type f | grep -q .; then
    fail "generator must not write a profile for unknown token: $token"
  fi
done

printf 'PASS test_nono_profile_generator_contract\n'
