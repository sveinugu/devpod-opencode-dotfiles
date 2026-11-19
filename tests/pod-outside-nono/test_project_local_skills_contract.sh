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

if grep -F '"clean-code"' "$lock_file" >/dev/null; then
  fail 'clean-code must not be installed as a project-local skill'
fi

if grep -F '"pragmatic-programmer"' "$lock_file" >/dev/null; then
  fail 'pragmatic-programmer must not be installed as a project-local skill'
fi

grep -F 'npx -y skills experimental_install' "$installer_script" >/dev/null || fail 'install-project-skills helper must run experimental_install'
grep -F 'skills-lock.json' "$installer_script" >/dev/null || fail 'install-project-skills helper must validate top-level skills-lock authority'

git -C "$repo_root" check-ignore -q '.config/opencode/skills/clean-code/SKILL.md' || fail 'globally installed clean-code skill must be ignored by Git'
git -C "$repo_root" check-ignore -q '.config/opencode/skills/pragmatic-programmer/SKILL.md' || fail 'globally installed pragmatic-programmer skill must be ignored by Git'

printf 'PASS test_project_local_skills_contract\n'
