#!/usr/bin/env bash
set -euo pipefail

# Spec gate S3: on the deployed image, OpenCode selects its ChatGPT transport
# from the launch helper's stub in OPENCODE_AUTH_CONTENT, writes no auth.json,
# attempts no refresh, and gets the stub only with a session. Runs through the
# deployed launch helper with synthetic values; see tests/lib/chatgpt-gate.sh.
# Rerun at each OpenCode upgrade: OPENCODE_AUTH_CONTENT is specific to
# OpenCode 1.x. Only the human runs this, in a pod shell outside nono.

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_chatgpt_opencode_stub_gate'
# shellcheck source=tests/lib/chatgpt-gate.sh
source "$repo_root/tests/lib/chatgpt-gate.sh"

gate_setup test_chatgpt_opencode_stub_gate 0

auth_file="$gate_tmp/home/.local/share/opencode/auth.json"
valid="$(gate_session 3600)"
profile="$(gate_profile "$valid")" || gate_fail "deployed generator refused a valid session"
no_session_profile="$(gate_profile -)" || gate_fail "deployed generator refused a launch without a session"

# Records what the launch helper gave OpenCode, as classes only.
stub_probe="$(gate_probe stub '#!/bin/sh
R="$1"
if [ -n "${OPENCODE_AUTH_CONTENT+set}" ]; then
  printf "%s" "$OPENCODE_AUTH_CONTENT" | python3 -I -c "
import json, sys
entry = json.load(sys.stdin).get(\"openai\", {})
print(\"oauth-stub\" if entry.get(\"type\") == \"oauth\" and \"nono-injects-chatgpt-credentials\" in entry.get(\"access\", \"\") else \"other\")
" >"$R/stub" 2>/dev/null || echo unparsable >"$R/stub"
else
  echo absent >"$R/stub"
fi
if [ -n "${OPENCODE_EXPERIMENTAL_WEBSOCKETS+set}" ]; then echo set >"$R/websockets"; else echo absent >"$R/websockets"; fi
')"
stub_result() { cat "$gate_tmp/results/stub" 2>/dev/null || echo not-run; }

echo '== Stub only with a session'
gate_launch "$valid" "$profile" "$stub_probe" '{}' "$gate_tmp/stub.out" "$gate_tmp/stub.err" "$gate_tmp/results" || true
gate_check "with a session, OpenCode gets the fixed stub" oauth-stub "$(stub_result)"
rm -f "$gate_tmp/results/stub"
gate_launch - "$no_session_profile" "$stub_probe" '{}' "$gate_tmp/nostub.out" "$gate_tmp/nostub.err" "$gate_tmp/results" || true
gate_check "without a session, OpenCode gets no stub" absent "$(stub_result)"
rm -f "$gate_tmp/results/stub" "$gate_tmp/results/websockets"
OPENCODE_AUTH_CONTENT='{"openai":{"type":"api","key":"caller"}}' OPENCODE_EXPERIMENTAL_WEBSOCKETS=true \
  gate_launch - "$no_session_profile" "$stub_probe" '{}' "$gate_tmp/caller.out" "$gate_tmp/caller.err" "$gate_tmp/results" || true
gate_check "caller-supplied auth content never reaches OpenCode" absent "$(stub_result)"
gate_check "WebSocket transport is never enabled" absent "$(cat "$gate_tmp/results/websockets" 2>/dev/null || echo not-run)"

echo '== OpenCode through the ChatGPT route'
config="$(python3 -I -c '
import json, sys
model = {"name": "GPT-6 Luna (gate)", "tool_call": True, "limit": {"context": 100000, "output": 10000}}
print(json.dumps({"enabled_providers": ["openai"], "model": "openai/gpt-6-luna", "small_model": "openai/gpt-6-luna",
                  "autoupdate": False, "share": "disabled", "plugin": [], "mcp": {},
                  "provider": {"openai": {"options": {"baseURL": sys.argv[1]}, "models": {"gpt-6-luna": model}}}}))
' "$gate_base")"
gate_check "no auth.json before OpenCode" absent "$([ -e "$auth_file" ] && echo present || echo absent)"
before="$(gate_hits)"
oc_status=0
gate_launch "$valid" "$profile" /usr/local/bin/opencode-raw "$config" "$gate_tmp/opencode.out" "$gate_tmp/opencode.err" \
  run --format json --model openai/gpt-6-luna 'Reply with the gate marker.' || oc_status=$?
gate_check "OpenCode exits cleanly" 0 "$oc_status"
gate_check "streamed reply reached OpenCode" yes "$(grep -qF "$gate_marker" "$gate_tmp/opencode.out" && echo yes || echo no)"
gate_check "OpenCode used the ChatGPT route" yes "$([ "$(gate_hits)" -gt "$before" ] && echo yes || echo no)"
gate_check "every request had the real token" "$(gate_hits)" "$(gate_count '"auth": "real"')"
gate_check "upstream never received the stub" 0 "$(gate_count '"auth": "stub"')"
gate_check "OpenCode created no auth.json" absent "$([ -e "$auth_file" ] && echo present || echo absent)"
gate_check "OpenCode attempted no token refresh" 0 "$(grep -c 'auth\.openai\.com' "$gate_tmp/opencode.err" || true)"

gate_check_no_leak
gate_finish
