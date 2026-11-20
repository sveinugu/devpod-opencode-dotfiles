#!/usr/bin/env bash
set -euo pipefail

# Read-only checks of harness discovery surfaces, not policy wording or behavior.
repo_root="$(git rev-parse --show-toplevel)"
python3 - "$repo_root" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
policy = root / '.config/opencode'

def metadata(path):
    lines = path.read_text().splitlines()
    if not lines or lines[0] != '---' or '---' not in lines[1:]:
        raise SystemExit(f'Missing frontmatter boundaries: {path}')
    end = lines.index('---', 1)
    # Check required top-level scalar fields in the repository's frontmatter.
    # This is a discovery sanity check, not a full YAML parser.
    fields = {}
    for line in lines[1:end]:
        match = re.fullmatch(r'([a-zA-Z][\w-]*):\s*(.*)', line)
        if match:
            key, value = match.groups()
            if key in fields:
                raise SystemExit(f'Duplicate metadata key {key}: {path}')
            fields[key] = value.strip().strip('\"\'')
    if not fields.get('description') or not '\n'.join(lines[end + 1:]).strip():
        raise SystemExit(f'Missing description or body: {path}')
    return fields

roles = {
    'maestro', 'general', 'brainstormer', 'planner', 'senior-implementer',
    'junior-implementer', 'policy-implementer', 'docs-writer', 'code-reviewer',
    'docs-reviewer-gpt', 'docs-reviewer-claude',
}
for role in roles:
    path = policy / 'agents' / f'{role}.md'
    if metadata(path).get('mode') not in {'primary', 'subagent', 'all'}:
        raise SystemExit(f'Missing or invalid agent mode: {path}')
if (policy / 'agents/docs-reviewer.md').exists():
    raise SystemExit('Obsolete single docs-reviewer agent is still installed')

for name in ('delivery-workflow', 'managed-worktrees', 'opencode-dispatch',
             'opencode-sessions', 'maestro-override'):
    path = policy / 'skills' / name / 'SKILL.md'
    if metadata(path).get('name') != name:
        raise SystemExit(f'Skill name must match discovery directory: {path}')

for filename in ('opencode.json', 'opencode.jsonc'):
    if (root / filename).exists():
        raise SystemExit(f'Unexpected project config overrides global harness: {filename}')
PY
printf 'PASS test_harness_structure\n'
