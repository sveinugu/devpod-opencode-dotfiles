#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
skills_lock="$repo_root/.config/opencode/skills-lock.json"
pr_template="$repo_root/.config/opencode/PULL_REQUEST_TEMPLATE.md"
fail=0

check_fixed() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF -- "$pattern" "$file"; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

check_skill_order() {
    local file="$1" label="$2"
    if python - "$file" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
targets = [
    '- wondelai/pragmatic-programmer',
    '- oc-plugin-karpathy-guidelines',
    '- wondelai/clean-code',
    '- obra/superpowers',
]
positions = []
for target in targets:
    for index, line in enumerate(lines):
        if line.strip() == target:
            positions.append(index)
            break
    else:
        raise SystemExit(1)

raise SystemExit(0 if positions == sorted(positions) else 1)
PY
    then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

check_absent() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF -- "$pattern" "$file"; then
        printf '  FAIL  %s — unexpectedly present in %s\n' "$label" "$file" >&2
        fail=1
    else
        printf '  PASS  %s\n' "$label"
    fi
}

echo "=== Clean Code Policy Contract Test ==="

check_fixed "$agents" '- wondelai/clean-code' 'Skill list includes clean-code'
check_skill_order "$agents" 'Skill list order keeps clean-code at priority 3'
check_fixed "$agents" 'Agents must load the "clean-code" skill before starting any coding task, including implementation, refactoring, code review, and post-implementation review.' 'Coding-task-only clean-code loading rule'
check_absent "$agents" 'Agents must always load the "clean-code" skill!' 'No always-load clean-code rule'
check_fixed "$agents" '### Refactor phase policy' 'Named refactor phase section exists'
check_fixed "$agents" 'The agent may conclude that no refactoring is needed, but the checkpoint itself MUST still happen explicitly.' 'Explicit no-refactor-needed checkpoint allowed'
check_fixed "$agents" 'If `clean-code` conflicts with `pragmatic-programmer`, `pragmatic-programmer` wins.' 'Authority ordering keeps pragmatic-programmer above clean-code'
check_fixed "$agents" '`clean-code` MUST NOT override user instructions, repository policy, approved artifacts, the chosen test level, or the requirement to keep behavior protected by tests.' 'Chosen test level and approved scope stay protected'
check_fixed "$agents" '`red → verify red → green → verify green → refactor → verify green`' 'Short recipe uses explicit post-green refactor flow'
check_fixed "$agents" 'run the pragmatic-programmer quick diagnostic and a clean-code checklist/score review' 'Post-implementation reporting includes both reviews'
check_fixed "$agents" 'pragmatic-programmer score, the clean-code checklist/score outcome' 'PR reporting policy mentions both reporting outputs'

check_fixed "$skills_lock" '"clean-code": {' 'Skills lock includes clean-code entry'
check_fixed "$skills_lock" '"source": "wondelai/skills"' 'Skills lock clean-code source'
check_fixed "$skills_lock" '"sourceType": "github"' 'Skills lock clean-code source type'
check_fixed "$skills_lock" '"skillPath": "clean-code/SKILL.md"' 'Skills lock clean-code path'

if [ -f "$pr_template" ] && rg -q 'clean-code' "$pr_template"; then
    check_fixed "$pr_template" '.config/opencode/AGENTS.md' 'PR template remains subordinate to AGENTS when updated'
fi

if [ -f "$repo_root/opencode.json" ] || [ -f "$repo_root/opencode.jsonc" ]; then
    printf '  FAIL  Unexpected project opencode config file present at repo root\n' >&2
    fail=1
else
    printf '  PASS  No project opencode.json/opencode.jsonc change required\n'
fi

if [ "$fail" -eq 0 ]; then
    printf 'PASS test_clean_code_policy_contract\n'
else
    printf 'FAIL test_clean_code_policy_contract\n' >&2
    exit 1
fi
