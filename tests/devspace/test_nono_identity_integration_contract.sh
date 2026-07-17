#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_identity_integration_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
wrapper="$repo_root/.config/opencode/bin/opencode"
helper="$repo_root/scripts/lib/nono-secret-env.sh"
dockerfile="$repo_root/Dockerfile"

[ -f "$wrapper" ] || fail "secure opencode wrapper not found"
[ -f "$helper" ] || fail "nono secret helper not found"
[ -f "$dockerfile" ] || fail "Dockerfile not found"

grep -F 'sudo -n /bin/cat' "$helper" >/dev/null || fail "helper must perform privileged reads via sudo -n /bin/cat"
grep -F 'sudo -n -u "$agent_user" -- env OPENCODE_CONFIG_CONTENT=' "$wrapper" >/dev/null || fail "wrapper must execute opencode through constrained sudo -n -u agent path"

grep -F 'NOPASSWD: /bin/cat /var/run/secrets/nono/providers/*' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for mounted provider secret reads"
grep -F 'NOPASSWD: /usr/bin/env OPENCODE_CONFIG_CONTENT=* opencode *' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for runtime wrapper path"

if grep -E 'NOPASSWD:.*(ALL|/bin/sh|/bin/bash|/usr/bin/su)' "$dockerfile" >/dev/null; then
  fail "Dockerfile sudoers contract must not allow broad shell/su escalation paths"
fi

printf 'PASS test_nono_identity_integration_contract\n'
