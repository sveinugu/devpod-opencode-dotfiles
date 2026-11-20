#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# Read-only repository configuration check; no runtime context is required.

python3 - "$repo_root/.config/opencode/agents" <<'PY'
import pathlib
import sys

agents = pathlib.Path(sys.argv[1])

def permission_lines(name):
    frontmatter = (agents / f"{name}.md").read_text().split("---", 2)[1]
    lines = frontmatter.splitlines()
    start = lines.index("permission:") + 1
    permissions = []
    for line in lines[start:]:
        if line and not line.startswith(" "):
            break
        if line.strip():
            permissions.append(line.strip())
    return permissions

general = permission_lines("general")
senior = permission_lines("senior-implementer")
if general != senior or general != ["bash: allow"]:
    raise SystemExit(f"general must match senior tool permissions: general={general!r}, senior={senior!r}")
PY

printf 'PASS test_general_agent_permissions_contract\n'
