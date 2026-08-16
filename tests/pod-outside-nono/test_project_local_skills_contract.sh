#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_project_local_skills_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_project_local_skills_contract'

lock_file="$repo_root/skills-lock.json"
skills_root="$repo_root/.agents/skills"
maintenance_skill="$repo_root/.agents/skills/harness-install-maintenance/SKILL.md"
installer_script="$repo_root/scripts/lib/install/install-project-skills.sh"

[ -f "$lock_file" ] || fail 'missing top-level skills-lock.json'
[ -d "$skills_root" ] || fail 'missing top-level .agents/skills directory'
[ -f "$maintenance_skill" ] || fail 'missing maintenance skill under top-level .agents/skills'
[ -f "$installer_script" ] || fail 'missing install-project-skills helper'
[ -f "$skills_root/clean-code/SKILL.md" ] || fail 'missing top-level .agents/skills/clean-code/SKILL.md'
[ -f "$skills_root/pragmatic-programmer/SKILL.md" ] || fail 'missing top-level .agents/skills/pragmatic-programmer/SKILL.md'

grep -F '"clean-code"' "$lock_file" >/dev/null || fail 'skills-lock.json must include clean-code authority'
grep -F '"pragmatic-programmer"' "$lock_file" >/dev/null || fail 'skills-lock.json must include pragmatic-programmer authority'
grep -F 'npx -y skills experimental_install' "$installer_script" >/dev/null || fail 'install-project-skills helper must run experimental_install'
grep -F 'skills-lock.json' "$installer_script" >/dev/null || fail 'install-project-skills helper must validate top-level skills-lock authority'

grep -F 'name: clean-code' "$skills_root/clean-code/SKILL.md" >/dev/null || fail 'clean-code local skill must remain available under .agents/skills'
grep -F 'name: pragmatic-programmer' "$skills_root/pragmatic-programmer/SKILL.md" >/dev/null || fail 'pragmatic-programmer local skill must remain available under .agents/skills'

if grep -F 'skills add wondelai/skills/pragmatic-programmer' "$repo_root/scripts/lib/install/materialize.sh" >/dev/null; then
  fail 'materialize install flow must not use .config/opencode-scoped skills add commands'
fi

if grep -F 'skills add wondelai/skills/clean-code' "$repo_root/scripts/lib/install/materialize.sh" >/dev/null; then
  fail 'materialize install flow must not use .config/opencode-scoped skills add commands'
fi

printf 'PASS test_project_local_skills_contract\n'
