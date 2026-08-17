#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_cleanup_conformance_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_cleanup_conformance_contract'

legacy_agents_dir="$repo_root/.config/opencode/.agents"
legacy_skills_dir="$repo_root/.config/opencode/skills"
legacy_skills_lock="$repo_root/.config/opencode/skills-lock.json"

[ ! -e "$legacy_agents_dir" ] || fail 'deprecated .config/opencode/.agents surface should not exist'
[ ! -e "$legacy_skills_dir" ] || fail 'deprecated .config/opencode/skills surface should not exist'
[ ! -e "$legacy_skills_lock" ] || fail 'deprecated .config/opencode/skills-lock.json should not exist'

[ ! -e "$repo_root/.config/opencode/plugins/opencode-loop.ts" ] || fail 'installer-generated plugin output should be regenerated output, not committed repo content'
[ ! -e "$repo_root/.config/opencode/commands/loop-help.md" ] || fail 'installer-generated command output loop-help should be regenerated output, not committed repo content'
[ ! -e "$repo_root/.config/opencode/commands/loop.md" ] || fail 'installer-generated command output loop should be regenerated output, not committed repo content'

[ -d "$repo_root/.agents/skills" ] || fail 'canonical top-level .agents/skills surface missing'
[ -f "$repo_root/skills-lock.json" ] || fail 'canonical top-level skills-lock.json missing'
[ -f "$repo_root/harness-installs.jsonc" ] || fail 'canonical top-level harness-installs.jsonc missing'

python3 - "$repo_root/harness-installs.jsonc" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
outputs = set()
for entry in manifest.get('installs', []):
    for output in entry.get('outputs', []):
        outputs.add(output)

declared_outputs = {
    '.config/opencode/plugins/opencode-loop.ts',
    '.config/opencode/commands/loop-help.md',
    '.config/opencode/commands/loop.md',
}

if outputs != declared_outputs:
    raise SystemExit(f'manifest output set mismatch: {outputs!r}')
PY

printf 'PASS test_cleanup_conformance_contract\n'
