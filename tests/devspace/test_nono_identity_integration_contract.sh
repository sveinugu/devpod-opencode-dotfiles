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
grep -F 'sudo -n -u "$agent_user" -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" "$nono_binary" run --profile "$profile_path" -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" OPENCODE_CONFIG_CONTENT=' "$wrapper" >/dev/null || fail "wrapper must pin runtime HOME/XDG and switch to agent user before entering nono sandbox"

grep -F 'NOPASSWD: /bin/cat /var/run/secrets/nono/providers/*' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for mounted provider secret reads"
grep -F 'NOPASSWD: /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* /home/vscode/.local/bin/nono run --profile * -- /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* OPENCODE_CONFIG_CONTENT=* /home/vscode/.opencode/bin/opencode *' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for pinned runtime env and pre-sandbox user-switch path"

python3 - "$wrapper" "$dockerfile" <<'PY'
import re
import sys

wrapper_path, dockerfile_path = sys.argv[1:]

with open(wrapper_path, 'r', encoding='utf-8') as fh:
    wrapper = fh.read()

with open(dockerfile_path, 'r', encoding='utf-8') as fh:
    dockerfile = fh.read()

match = re.search(r'raw_opencode_binary="\$\{OPENCODE_RAW_BINARY:-([^}]+)\}"', wrapper)
if not match:
    raise SystemExit('wrapper missing default raw_opencode_binary contract')

default_path = match.group(1)
expected_rule = f'NOPASSWD: /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* /home/vscode/.local/bin/nono run --profile * -- /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* OPENCODE_CONFIG_CONTENT=* {default_path} *'

if expected_rule not in dockerfile:
    raise SystemExit('dockerfile sudoers rule does not match wrapper default raw binary path')
PY

if grep -E 'NOPASSWD:.*(ALL|/bin/sh|/bin/bash|/usr/bin/su)' "$dockerfile" >/dev/null; then
  fail "Dockerfile sudoers contract must not allow broad shell/su escalation paths"
fi

printf 'PASS test_nono_identity_integration_contract\n'
