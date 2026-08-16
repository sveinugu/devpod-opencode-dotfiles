#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_generated_output_ignore_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_outside_nono_test 'test_generated_output_ignore_contract'

[ -f "$repo_root/.gitignore" ] || fail 'missing top-level .gitignore'
[ -f "$repo_root/.config/opencode/.gitignore" ] || fail 'missing .config/opencode/.gitignore'

git -C "$repo_root" check-ignore -q '.config/opencode/plugins/opencode-loop.js' || fail 'generated opencode-loop plugin output must be git-ignored'
git -C "$repo_root" check-ignore -q '.config/opencode/commands/loop-help.md' || fail 'generated loop-help output must be git-ignored'
git -C "$repo_root" check-ignore -q '.config/opencode/commands/loop.md' || fail 'generated loop output must be git-ignored'

if git -C "$repo_root" check-ignore -q 'skills-lock.json'; then
  fail 'top-level skills-lock.json authority file must remain committed, not ignored'
fi

if git -C "$repo_root" check-ignore -q 'harness-installs.jsonc'; then
  fail 'top-level harness-installs.jsonc authority file must remain committed, not ignored'
fi

if grep -Fx 'package.json' "$repo_root/.config/opencode/.gitignore" >/dev/null; then
  fail '.config/opencode/package.json must be commit-visible for secondary dependency-surface clarity'
fi

if grep -Fx 'package-lock.json' "$repo_root/.config/opencode/.gitignore" >/dev/null; then
  fail '.config/opencode/package-lock.json must be commit-visible for secondary dependency-surface clarity'
fi

grep -F 'runtime plugin authority remains in opencode.jsonc' "$repo_root/.config/opencode/package.json" >/dev/null || fail '.config/opencode/package.json should explicitly document secondary dependency role'

printf 'PASS test_generated_output_ignore_contract\n'
