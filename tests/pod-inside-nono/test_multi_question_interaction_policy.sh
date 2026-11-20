#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_multi_question_interaction_policy'

policy="$repo_root/.config/opencode/AGENTS.md"
for rule in 'group related questions' 'up to five' 'estimate remaining rounds' \
    'trade-offs and your recommendation' 'exact-token prompts separate' \
    'This batching policy overrides skill or subagent preferences for one-question-at-a-time discovery, except where a stricter routing or protocol rule applies.' \
    'Do not hide recommendations in rhetorical or loaded questions.'; do
  rg -qF -- "$rule" "$policy" || { echo "Missing interaction rule: $rule" >&2; exit 1; }
done

printf 'PASS test_multi_question_interaction_policy\n'
