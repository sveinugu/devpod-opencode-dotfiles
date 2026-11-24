#!/usr/bin/env bash
set -euo pipefail

# Spec gate S1: the ChatGPT session stays out of the sandbox on the deployed
# image, and injection still works. Runs through the deployed launch helper
# with synthetic values; see tests/lib/chatgpt-gate.sh.
# Only the human runs this, in a pod shell outside nono.

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_chatgpt_session_isolation_gate'
# shellcheck source=tests/lib/chatgpt-gate.sh
source "$repo_root/tests/lib/chatgpt-gate.sh"

gate_setup test_chatgpt_session_isolation_gate 2

# The probe runs as the agent inside nono. Its regex matches the token but not
# itself, and it records only counts, never process data.
probe="$(gate_probe isolation '#!/bin/sh
R="$1"; PAT="$2"; URL="$3"; CONTROL="$4"
req() {
  curl -sS -o /dev/null -w "%{http_code}" -X POST \
    -H "Authorization: Bearer nono-injects-chatgpt-credentials" -H "content-type: application/json" \
    -d "{\"model\":\"gate\",\"stream\":true}" "$URL" 2>/dev/null || echo 000
}
scan() {
  hits=0
  for file in /proc/[0-9]*/environ /proc/[0-9]*/cmdline; do
    if grep -aqE "$PAT" "$file" 2>/dev/null; then hits=$((hits+1)); fi
  done
  echo "$hits"
}
if grep -aqE "$PAT" "$CONTROL" 2>/dev/null; then echo yes >"$R/control_match"; else echo no >"$R/control_match"; fi
env | grep -c "^OPENAI_CHATGPT_SESSION=" >"$R/child_var"
env | grep -cE "$PAT" >"$R/child_canary"
env | grep -c "^OPENAI_BASE_URL=" >"$R/openai_base_url"
sup=""; p=$$
while [ -n "$p" ] && [ "$p" -gt 1 ]; do
  if [ "$(cat "/proc/$p/comm" 2>/dev/null)" = nono ]; then sup=$p; break; fi
  p="$(sed -n "s/^PPid:[[:space:]]*//p" "/proc/$p/status" 2>/dev/null)"
done
if [ -n "$sup" ] && cat "/proc/$sup/environ" >/dev/null 2>&1; then echo allowed >"$R/supervisor_environ"; else echo "${sup:+denied}" >"$R/supervisor_environ"; fi
scan >"$R/idle_hits"
req >"$R/route_status" &
c=$!
total=0; seen=0; readable=0
while kill -0 "$c" 2>/dev/null; do
  total=$((total + $(scan)))
  for pid in $(grep -lsa dotfiles-chatgpt-headers /proc/[0-9]*/cmdline | cut -d/ -f3); do
    seen=$((seen+1))
    if cat "/proc/$pid/environ" >/dev/null 2>&1; then readable=$((readable+1)); fi
  done
done
wait "$c"
echo "$total" >"$R/held_hits"
echo "$seen" >"$R/helper_seen"
echo "$readable" >"$R/helper_environ_readable"
echo done >"$R/finished"
')"

printf '%s' "$gate_real" >"$gate_tmp/results/control"
chmod 0644 "$gate_tmp/results/control"
result() { cat "$gate_tmp/results/$1" 2>/dev/null || echo not-run; }

valid_profile="$(gate_profile "$(gate_session 3600)")" || gate_fail "deployed generator refused a valid session"
gate_launch "$(gate_session 3600)" "$valid_profile" "$probe" '{}' "$gate_tmp/probe.out" "$gate_tmp/probe.err" \
  "$gate_tmp/results" "$gate_real_re" "$gate_base/responses" "$gate_tmp/results/control" || true
[ "$(result finished)" = done ] || gate_fail "sandboxed probe did not finish; see $gate_tmp/probe.err (kept until exit)"
[ "$(result control_match)" = yes ] || gate_fail "probe could not detect the token in its control file"

echo '== Injection'
gate_check "stub request succeeds through the route" 200 "$(result route_status)"
gate_check "upstream received the real token once" 1 "$(gate_count '"auth": "real"')"
gate_check "upstream received the account header" 1 "$(gate_count '"account": true')"
gate_check "upstream never received the stub" 0 "$(gate_count '"auth": "stub"')"
gate_check "exactly one Authorization header" 1 "$(gate_count '"auth_headers": 1')"

echo '== Sandbox isolation'
gate_check "session variable absent from OpenCode's environment" 0 "$(result child_var)"
gate_check "token absent from OpenCode's environment" 0 "$(result child_canary)"
gate_check "OPENAI_BASE_URL not set" 0 "$(result openai_base_url)"
gate_check "supervisor environment denied" denied "$(result supervisor_environ)"
gate_check "no readable process data holds the token at rest" 0 "$(result idle_hits)"
gate_check "no readable process data holds the token during a request" 0 "$(result held_hits)"
seen="$(result helper_seen)"
gate_check "probe saw the running header helper" yes "$([ "$seen" -ge 1 ] 2>/dev/null && echo yes || echo no)"
gate_check "header helper environment denied" 0 "$(result helper_environ_readable)"

echo '== Expired session'
before="$(gate_hits)"
status_probe="$(gate_probe request '#!/bin/sh
curl -sS -o /dev/null -w "%{http_code}" -X POST -H "Authorization: Bearer nono-injects-chatgpt-credentials" \
  -d "{}" "$1" 2>/dev/null || echo 000')"
gate_launch "$(gate_session -60)" "$valid_profile" "$status_probe" '{}' "$gate_tmp/expired.out" "$gate_tmp/expired.err" \
  "$gate_base/responses" || true
gate_check "expired session gets no successful response" refused "$([ "$(tail -c 3 "$gate_tmp/expired.out")" = 200 ] && echo allowed || echo refused)"
gate_check "expired session: no upstream request" "$before" "$(gate_hits)"

gate_check_no_leak
gate_finish
