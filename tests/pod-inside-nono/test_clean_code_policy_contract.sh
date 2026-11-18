#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_clean_code_policy_contract'

policy="$repo_root/.config/opencode"
workflow="$policy/skills/delivery-workflow/SKILL.md"
rg -qF 'delivery-workflow' "$policy/AGENTS.md"
rg -qF 'For coding, refactoring and code review, load `pragmatic-programmer`, `karpathy-guidelines` and `clean-code`' "$policy/AGENTS.md"
for rule in 'red → verify red → green → verify green → refactor → verify green' \
    'cleanup or why none was needed' 'pragmatic-programmer diagnostic and clean-code review' \
    'score below 8' 'reasons for deferral'; do
  rg -qF -- "$rule" "$workflow" || { echo "Missing delivery rule: $rule" >&2; exit 1; }
done
rg -qF '.config/opencode/AGENTS.md' "$policy/PULL_REQUEST_TEMPLATE.md"
test ! -f "$repo_root/opencode.json"
test ! -f "$repo_root/opencode.jsonc"

printf 'PASS test_clean_code_policy_contract\n'
