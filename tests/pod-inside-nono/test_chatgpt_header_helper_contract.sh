#!/usr/bin/env bash
set -euo pipefail

# Run the real ChatGPT header helper with synthetic sessions. nono runs this
# helper as a cmd:// credential command and reads its JSON output.

fail() {
  printf 'FAIL test_chatgpt_header_helper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_chatgpt_header_helper_contract'

helper="$repo_root/scripts/lib/chatgpt-headers.py"
[ -f "$helper" ] || fail "header helper not found at scripts/lib/chatgpt-headers.py"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_chatgpt_header_helper_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_chatgpt_header_helper_contract')"
trap 'rm -rf "$tmp_root"' EXIT

token='synthetic-access-7f3a'
account='synthetic-account-91c2'
now="$(date +%s)"
future=$((now + 5 * 86400))
past=$((now - 60))

# run <session|-> : runs the helper; stdout and stderr go to files, exit code is printed.
run() {
  local status=0
  if [ "$1" = '-' ]; then
    env -u OPENAI_CHATGPT_SESSION python3 -I "$helper" >"$tmp_root/out" 2>"$tmp_root/err" || status=$?
  else
    OPENAI_CHATGPT_SESSION="$1" python3 -I "$helper" >"$tmp_root/out" 2>"$tmp_root/err" || status=$?
  fi
  printf '%s' "$status"
}

# expect_headers <residency|-> : checks the printed header object.
expect_headers() {
  python3 - "$tmp_root/out" "$token" "$account" "$1" <<'PY'
import json
import sys

path, token, account, residency = sys.argv[1:]
with open(path, encoding='utf-8') as fh:
    payload = json.load(fh)
expected = {'Authorization': f'Bearer {token}', 'ChatGPT-Account-Id': account}
if residency != '-':
    expected['x-openai-internal-codex-residency'] = residency
if payload != {'headers': expected}:
    raise SystemExit(f'unexpected header payload keys: {sorted(payload.get("headers", {}))}')
PY
}

expect_refused() {
  local label="$1" status="$2"
  [ "$status" != 0 ] || fail "$label: helper must exit non-zero"
  [ ! -s "$tmp_root/out" ] || fail "$label: helper must print nothing on stdout"
  if grep -F -e "$token" -e "$account" "$tmp_root/err" >/dev/null; then
    fail "$label: helper must not print session values on stderr"
  fi
}

status="$(run "{\"access\":\"$token\",\"account_id\":\"$account\",\"expires_at\":$future}")"
[ "$status" = 0 ] || fail "valid session should succeed (exit $status)"
expect_headers - || fail "valid session should print Authorization and ChatGPT-Account-Id only"

status="$(run "{\"access\":\"$token\",\"account_id\":\"$account\",\"expires_at\":$future,\"residency\":\"us\"}")"
[ "$status" = 0 ] || fail "constrained session should succeed (exit $status)"
expect_headers us || fail "constrained session should add the residency header"

expect_refused 'expired' "$(run "{\"access\":\"$token\",\"account_id\":\"$account\",\"expires_at\":$past}")"
expect_refused 'missing variable' "$(run -)"
expect_refused 'empty variable' "$(run '')"
expect_refused 'not JSON' "$(run "access=$token")"
expect_refused 'missing access' "$(run "{\"account_id\":\"$account\",\"expires_at\":$future}")"
expect_refused 'empty access' "$(run "{\"access\":\"\",\"account_id\":\"$account\",\"expires_at\":$future}")"
expect_refused 'missing account' "$(run "{\"access\":\"$token\",\"expires_at\":$future}")"
expect_refused 'missing expiry' "$(run "{\"access\":\"$token\",\"account_id\":\"$account\"}")"
expect_refused 'text expiry' "$(run "{\"access\":\"$token\",\"account_id\":\"$account\",\"expires_at\":\"$future\"}")"
expect_refused 'boolean expiry' "$(run "{\"access\":\"$token\",\"account_id\":\"$account\",\"expires_at\":true}")"
expect_refused 'header injection in token' "$(run "{\"access\":\"$token\\r\\nX-Evil: 1\",\"account_id\":\"$account\",\"expires_at\":$future}")"

printf 'PASS test_chatgpt_header_helper_contract\n'
