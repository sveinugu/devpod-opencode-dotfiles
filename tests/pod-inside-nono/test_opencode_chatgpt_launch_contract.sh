#!/usr/bin/env bash
set -euo pipefail

# ChatGPT launch states through the real wrapper, secret helper, config-content
# helper, profile generator and launch helper, with synthetic sessions.
# Doubles, and why:
# - sudo passes the environment through, as the image's env_keep list does for
#   the session variable; it cannot change identity inside nono.
# - setpriv cannot drop privileges inside nono; it only runs its command.
# - nono records its own environment and profile, then runs the child without
#   filtering, so the launch helper's own scrubbing is what the child sees.
# - opencode-raw records its environment instead of starting OpenCode.

fail() {
  printf 'FAIL test_opencode_chatgpt_launch_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_opencode_chatgpt_launch_contract'

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_opencode_chatgpt_launch_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_opencode_chatgpt_launch_contract')"
trap 'rm -rf "$tmp_root"' EXIT

install_root="$tmp_root/install-root"
mock_bin="$tmp_root/mock-bin"
secret_root="$tmp_root/secrets"
logs="$tmp_root/logs"
profiles="$tmp_root/profiles"
mkdir -p "$install_root/scripts/lib" "$install_root/.config/opencode/agents" "$mock_bin" "$secret_root" "$logs" "$profiles"

cp "$repo_root/scripts/lib/nono-secret-env.sh" "$repo_root/scripts/lib/opencode-config-content.py" "$repo_root/scripts/lib/chatgpt-headers.py" "$install_root/scripts/lib/"
cp "$repo_root/scripts/lib/launch-opencode-nono.sh" "$tmp_root/launch-helper"
cp "$repo_root/scripts/lib/generate-nono-profile.py" "$tmp_root/profile-writer"
chmod +x "$tmp_root/launch-helper" "$tmp_root/profile-writer"
printf '#!/usr/bin/env bash\n' >"$install_root/.config/opencode/bash_env.sh"

base_config="$install_root/.config/opencode/opencode.jsonc"
write_base_config() {
  printf '{\n  // comment as in the real file\n  "model": "%s"\n}\n' "$1" >"$base_config"
}
write_base_config 'gpt-uio-yellow/gpt-6-luna'

runtime="$tmp_root/provider-runtime.json"
write_runtime() {
  python3 - "$runtime" "$@" <<'PY'
import json
import sys
path, *enabled = sys.argv[1:]
provider = {'gpt-uio-yellow': {'api': 'openai', 'options': {'baseURL': 'https://gpt.uio.no/api/v1'},
                               'models': {'gpt-6-luna': {'id': 'gpt-6-luna', 'name': 'GPT-6 Luna'}}}}
with open(path, 'w', encoding='utf-8') as fh:
    json.dump({'enabled_providers': enabled, 'provider': {k: v for k, v in provider.items() if k in enabled}}, fh)
PY
}

cat >"$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = "-n" ] || exit 64
shift
printf '%s\n' "$*" >>"$MOCK_LOGS/sudo"
[ "${1:-}" = "--" ] && shift
exec "$@"
EOF

cat >"$mock_bin/id" <<'EOF'
#!/usr/bin/env bash
if [ "$#" -eq 2 ] && [ "$2" = "agent" ]; then printf '1001\n'; exit 0; fi
exec /usr/bin/id "$@"
EOF

cat >"$mock_bin/setpriv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while [ "$#" -gt 0 ] && [[ "$1" == --* ]]; do shift; done
exec "$@"
EOF

cat >"$mock_bin/nono" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = run ] && shift
[ "$1" = --profile ] && { printf '%s' "$2" >"$MOCK_LOGS/profile"; shift 2; }
if [ "${OPENAI_CHATGPT_SESSION+set}" = set ]; then printf '%s' "$OPENAI_CHATGPT_SESSION" >"$MOCK_LOGS/supervisor_session"; fi
if [ "${GPT_UIO_YELLOW_API_KEY+set}" = set ]; then printf '%s' "$GPT_UIO_YELLOW_API_KEY" >"$MOCK_LOGS/supervisor_yellow"; fi
while [ "$#" -gt 0 ]; do case "$1" in --) shift; break ;; *) shift ;; esac; done
exec "$@"
EOF

cat >"$mock_bin/opencode-raw" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for name in OPENAI_CHATGPT_SESSION OPENCODE_AUTH_CONTENT OPENCODE_EXPERIMENTAL_WEBSOCKETS OPENCODE_CONFIG_CONTENT; do
  if [ "${!name+set}" = set ]; then printf '%s' "${!name}" >"$MOCK_LOGS/child_$name"; fi
done
printf '%s\n' "$*" >"$MOCK_LOGS/child_args"
EOF
chmod +x "$mock_bin"/*

token='synthetic-access-5d1e'
account='synthetic-account-c4b7'
now="$(date +%s)"
session_with_expiry() {
  printf '{"access":"%s","account_id":"%s","expires_at":%s}' "$token" "$account" "$1"
}
valid_session="$(session_with_expiry $((now + 5 * 86400)))"
expiring_session="$(session_with_expiry $((now + 2 * 3600)))"
expired_session="$(session_with_expiry $((now - 60)))"
printf 'synthetic-yellow-key' >"$secret_root/gpt_uio_yellow_api_key"

set_session() {
  if [ "$1" = '-' ]; then rm -f "$secret_root/openai_chatgpt_session"; else printf '%s' "$1" >"$secret_root/openai_chatgpt_session"; fi
}

# launch [env assignments...] -- [opencode args...]: runs the wrapper and prints its exit status.
launch() {
  local env_args=()
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do env_args+=("$1"); shift; done
  [ "$#" -gt 0 ] && shift
  rm -rf "$logs" && mkdir -p "$logs"
  local status=0
  env -u OPENAI_CHATGPT_SESSION -u OPENCODE_AUTH_CONTENT -u OPENCODE_EXPERIMENTAL_WEBSOCKETS \
    PATH="$mock_bin:$PATH" \
    MOCK_LOGS="$logs" \
    HUB_INSTALL_BRANCH_DIR="$install_root" \
    HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" \
    HUB_NONO_SECRET_HELPER_SUDO='sudo -n' \
    HUB_NONO_AGENT_USER=agent \
    HUB_NONO_BINARY="$mock_bin/nono" \
    HUB_NONO_SET_PRIV_BINARY="$mock_bin/setpriv" \
    HUB_NONO_PROFILE_TEMPLATE_PATH="$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc" \
    HUB_NONO_GENERATED_PROFILE_WRITER="$tmp_root/profile-writer" \
    HUB_NONO_GENERATED_PROFILE_DIR="$profiles" \
    HUB_NONO_LAUNCH_HELPER="$tmp_root/launch-helper" \
    HUB_OPENCODE_MODEL_OVERRIDES_PATH="$tmp_root/model-overrides.json" \
    OPENCODE_PROVIDER_RUNTIME_PATH="$runtime" \
    OPENCODE_RAW_BINARY="$mock_bin/opencode-raw" \
    "${env_args[@]}" \
    bash "$tmp_root/wrapper" "$@" >"$tmp_root/stdout" 2>"$tmp_root/stderr" || status=$?
  printf '%s' "$status"
}
# Run a copy of the repository wrapper, never the installed one.
cp "$repo_root/.config/opencode/bin/opencode" "$tmp_root/wrapper"

login_hint() { grep -F 'devspace run-pipeline provider-login --provider chatgpt' "$tmp_root/stderr" >/dev/null; }
launched() { [ -e "$logs/child_args" ]; }

# Parsed view of one launch; prints "<route> <stub> <openai-enabled> <chatgpt-token-enabled>".
launch_view() {
  python3 - "$logs" "$token" "$now" <<'PY'
import json
import os
import sys

logs, token, now = sys.argv[1], sys.argv[2], int(sys.argv[3])
with open(open(os.path.join(logs, 'profile')).read(), encoding='utf-8') as fh:
    profile = json.load(fh)
route = 'openai-chatgpt' in profile['network']['custom_credentials']

stub = 'no'
stub_path = os.path.join(logs, 'child_OPENCODE_AUTH_CONTENT')
if os.path.exists(stub_path):
    raw = open(stub_path).read()
    if token in raw:
        raise SystemExit('stub must not contain the real token')
    entry = json.loads(raw)['openai']
    far_future_ms = (now + 10 * 365 * 86400) * 1000
    stub = 'yes' if entry.get('type') == 'oauth' and entry.get('expires', 0) > far_future_ms else 'bad'

config = json.loads(open(os.path.join(logs, 'child_OPENCODE_CONFIG_CONTENT')).read())
enabled = config['enabled_providers']
print(f"{'yes' if route else 'no'} {stub} {'yes' if 'openai' in enabled else 'no'} {'yes' if 'openai-chatgpt' in enabled else 'no'}")
PY
}

assert_isolated() {
  local label="$1"
  [ ! -e "$logs/child_OPENAI_CHATGPT_SESSION" ] || fail "$label: OpenCode must not receive the session"
  if grep -rF "$token" "$logs"/child_* "$tmp_root/stdout" "$tmp_root/stderr" >/dev/null 2>&1; then
    fail "$label: the real token must not reach OpenCode or the terminal"
  fi
  [ ! -e "$logs/child_OPENCODE_EXPERIMENTAL_WEBSOCKETS" ] || fail "$label: WebSocket transport must not be enabled"
}

assert_connected() {
  local label="$1" expected_session="$2"
  [ "$(cat "$logs/supervisor_session" 2>/dev/null)" = "$expected_session" ] || fail "$label: the nono supervisor must receive the session"
  [ "$(launch_view)" = 'yes yes yes no' ] || fail "$label: expected route, stub and OpenCode provider openai (got: $(launch_view))"
  assert_isolated "$label"
}

assert_disconnected() {
  local label="$1"
  [ ! -e "$logs/supervisor_session" ] || fail "$label: the nono supervisor must not receive a session"
  [ "$(launch_view)" = 'no no no no' ] || fail "$label: expected no route, no stub and no openai provider (got: $(launch_view))"
  [ "$(cat "$logs/supervisor_yellow" 2>/dev/null)" = 'synthetic-yellow-key' ] || fail "$label: other providers must keep their credentials"
  assert_isolated "$label"
}

write_runtime gpt-uio-yellow openai-chatgpt

# Valid session.
set_session "$valid_session"
[ "$(launch -- --version)" = 0 ] || fail "valid: launch should succeed: $(cat "$tmp_root/stderr")"
assert_connected valid "$valid_session"
! login_hint || fail "valid: no login hint expected"

# Expires within 24 hours: launch connected, with a warning.
set_session "$expiring_session"
[ "$(launch -- --version)" = 0 ] || fail "expiring: launch should succeed"
assert_connected expiring "$expiring_session"
login_hint || fail "expiring: warning should name the login command"

# Missing, expired and malformed sessions: launch without ChatGPT.
for state in missing expired empty not-json missing-access text-expiry; do
  case "$state" in
    missing) set_session - ;;
    expired) set_session "$expired_session" ;;
    empty) set_session '' ;;
    not-json) set_session "access=$token" ;;
    missing-access) set_session "{\"account_id\":\"$account\",\"expires_at\":$((now + 86400))}" ;;
    text-expiry) set_session "{\"access\":\"$token\",\"account_id\":\"$account\",\"expires_at\":\"soon\"}" ;;
  esac
  [ "$(launch -- --version)" = 0 ] || fail "$state: launch should continue without ChatGPT: $(cat "$tmp_root/stderr")"
  assert_disconnected "$state"
  login_hint || fail "$state: notice should name the login command"
done

# A session in the caller's environment is not a connection.
set_session -
[ "$(launch "OPENAI_CHATGPT_SESSION=$valid_session" -- --version)" = 0 ] || fail "caller session: launch should continue"
assert_disconnected 'caller session'

# Caller-supplied stub and WebSocket settings never reach OpenCode.
[ "$(launch 'OPENCODE_AUTH_CONTENT={"openai":{"type":"api","key":"caller"}}' OPENCODE_EXPERIMENTAL_WEBSOCKETS=true -- --version)" = 0 ] || fail "caller stub: launch should continue"
assert_disconnected 'caller stub, disconnected'
set_session "$valid_session"
[ "$(launch 'OPENCODE_AUTH_CONTENT={"openai":{"type":"api","key":"caller"}}' OPENCODE_EXPERIMENTAL_WEBSOCKETS=true -- --version)" = 0 ] || fail "caller stub: connected launch should succeed"
assert_connected 'caller stub, connected' "$valid_session"

# ChatGPT not enabled: the session key is not read and nothing changes.
write_runtime gpt-uio-yellow
[ "$(launch -- --version)" = 0 ] || fail "not enabled: launch should succeed"
assert_disconnected 'not enabled'
! login_hint || fail "not enabled: no login hint expected"
if grep -F 'openai_chatgpt_session' "$logs/sudo" >/dev/null 2>&1; then
  fail "not enabled: the session key must not be read"
fi
write_runtime gpt-uio-yellow openai-chatgpt

# Explicit selection while disconnected refuses the launch.
set_session "$expired_session"
for args in '--model openai/gpt-6-luna' '--model=openai/gpt-6-luna' '-m openai/gpt-6-luna' 'run --model openai/gpt-6-luna hello'; do
  # shellcheck disable=SC2086
  status="$(launch -- $args)"
  [ "$status" != 0 ] || fail "explicit '$args': launch must be refused while disconnected"
  ! launched || fail "explicit '$args': OpenCode must not start"
  login_hint || fail "explicit '$args': refusal should name the login command"
done

write_base_config 'openai/gpt-6-luna'
[ "$(launch -- --version)" != 0 ] || fail "base config model: launch must be refused while disconnected"
login_hint || fail "base config model: refusal should name the login command"
write_base_config 'gpt-uio-yellow/gpt-6-luna'

printf '{"defaults":{"model":{"model":"openai/gpt-6-luna","reason":"test"}}}\n' >"$tmp_root/model-overrides.json"
[ "$(launch -- --version)" != 0 ] || fail "override default model: launch must be refused while disconnected"
login_hint || fail "override default model: refusal should name the login command"

# A role override is not an explicit selection; that role fails at first use.
printf '{"agents":{"build":{"model":"openai/gpt-6-luna","reason":"test"}}}\n' >"$tmp_root/model-overrides.json"
[ "$(launch -- --version)" = 0 ] || fail "role override: launch should continue while disconnected: $(cat "$tmp_root/stderr")"
assert_disconnected 'role override'
rm -f "$tmp_root/model-overrides.json"

# Explicit selection while connected launches normally.
set_session "$valid_session"
[ "$(launch -- --model openai/gpt-6-luna)" = 0 ] || fail "explicit while connected: launch should succeed"
assert_connected 'explicit while connected' "$valid_session"
grep -F -- '--model openai/gpt-6-luna' "$logs/child_args" >/dev/null || fail "explicit while connected: arguments must reach OpenCode unchanged"

printf 'PASS test_opencode_chatgpt_launch_contract\n'
