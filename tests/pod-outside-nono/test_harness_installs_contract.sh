#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_harness_installs_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_harness_installs_contract'

manifest="$repo_root/harness-installs.jsonc"
runner="$repo_root/scripts/lib/install/run-harness-installs.sh"

[ -f "$manifest" ] || fail 'missing top-level harness-installs.jsonc'
[ -f "$runner" ] || fail 'missing run-harness-installs helper'

python3 - "$manifest" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
data = json.loads(manifest_path.read_text(encoding='utf-8'))

installs = data.get('installs')
if not isinstance(installs, list) or len(installs) == 0:
    raise SystemExit('installs must be a non-empty list')

entry = None
for candidate in installs:
    if candidate.get('name') == 'opencode-loop':
        entry = candidate
        break

if entry is None:
    raise SystemExit('missing opencode-loop manifest entry')

if entry.get('workingDirectory') != '.config/opencode':
    raise SystemExit('workingDirectory must be .config/opencode for opencode-loop')

if entry.get('install') != ['npx', '-y', '@bybrawe/opencode-loop']:
    raise SystemExit('install command mismatch for opencode-loop')

if entry.get('uninstall') != ['npx', '-y', '@bybrawe/opencode-loop', '--uninstall']:
    raise SystemExit('uninstall command mismatch for opencode-loop')

expected_outputs = [
    '.config/opencode/plugins/opencode-loop.js',
    '.config/opencode/commands/loop-help.md',
    '.config/opencode/commands/loop.md',
]
if entry.get('outputs') != expected_outputs:
    raise SystemExit('outputs mismatch for opencode-loop')
PY

grep -F 'run_install_command "$name" "uninstall"' "$runner" >/dev/null || fail 'runner must execute uninstall phase before install'
grep -F 'run_install_command "$name" "install"' "$runner" >/dev/null || fail 'runner must execute install phase'
grep -F 'verify_declared_outputs "$name"' "$runner" >/dev/null || fail 'runner must verify manifest outputs'

if grep -F 'sudo ' "$runner" >/dev/null; then
  fail 'runner must stay unprivileged and must not use sudo'
fi

grep -F '@bybrawe/opencode-loop' "$repo_root/.config/opencode/package.json" >/dev/null || fail '.config/opencode/package.json should keep repo-local dependency surface for installer-managed package'

if grep -F '"@bybrawe/opencode-loop"' "$repo_root/.config/opencode/opencode.jsonc" >/dev/null; then
  fail '.config/opencode/opencode.jsonc must not duplicate installer-managed authority for @bybrawe/opencode-loop'
fi

printf 'PASS test_harness_installs_contract\n'
