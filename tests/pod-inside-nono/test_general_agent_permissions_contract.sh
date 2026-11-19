#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_general_agent_permissions_contract'

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

rg -qF 'Follow the shared policy and applicable skills.' "$repo_root/.config/opencode/agents/general.md"
rg -qF 'Harness agents do not have permission to execute work designated `pod-outside-nono` or to run as the `vscode` user.' "$repo_root/.config/opencode/AGENTS.md"
printf 'PASS test_general_agent_permissions_contract\n'
