#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
brainstormer="$repo_root/.config/opencode/agents/brainstormer.md"
fail=0

check_fixed() {
    local pattern="$1" label="$2"
    if rg -qF -- "$pattern" "$agents"; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing in %s\n' "$label" "$agents" >&2
        fail=1
    fi
}

check_absent() {
    local pattern="$1" label="$2"
    if rg -qF -- "$pattern" "$agents"; then
        printf '  FAIL  %s — unexpectedly present in %s\n' "$label" "$agents" >&2
        fail=1
    else
        printf '  PASS  %s\n' "$label"
    fi
}

echo "=== Multi-question Interaction Policy Contract Test ==="

check_fixed 'I’m the <subagent> subagent. I’ll work with you directly; I may ask one or more related questions and return control to the Maestro when the scoped work is complete.' 'First message allows one or more related questions'
check_fixed 'For ordinary clarifying or discovery exchanges, subagents SHOULD ask multiple related questions in the same message when that helps the user answer efficiently.' 'Batching default for ordinary clarifying/discovery exchanges'
check_fixed 'Ask at most five questions in one message.' 'Five-question cap'
check_fixed 'If only one meaningful question is needed, ask only one; do not invent filler questions just to force a batch.' 'No filler questions rule'
check_fixed 'If more questions are still pending after the current batch, say so and give a rough estimate of the remaining question count or follow-up rounds.' 'Pending-question disclosure with rough estimate'
check_fixed 'Exact-token or other protocol-sensitive prompts may remain isolated when batching would reduce reliability or make the required reply ambiguous.' 'Protocol-sensitive exemption'
check_fixed 'Repository policy override: when a loaded skill or subagent prompt prefers one-question-at-a-time discovery, subagents in this repository should follow the batching policy above unless a stricter protocol or routing rule in `AGENTS.md` applies.' 'Repository policy override over skill-level one-question guidance'
check_fixed 'When asking the user to choose between options, provide enough background for an informed choice, summarize the main trade-offs, state your recommendation when you have one, and briefly explain why.' 'Choice prompts require background trade-offs recommendation and why'
check_fixed 'Prefer the order: context, options/trade-offs, recommendation, then the actual question or question batch.' 'Choice prompt ordering guidance'
check_fixed 'Do not hide your recommendation inside a rhetorical or loaded question.' 'Loaded or rhetorical framing forbidden'

check_absent 'I will ask one question at a time' 'Retired first-message wording removed'
check_absent 'Ask one clarifying question per message' 'Retired one-question-per-message rule removed'

if rg -qF -- 'Follow the repository interaction policy in `.config/opencode/AGENTS.md`, including its multi-question batching and choice-framing rules.' "$brainstormer"; then
    printf '  PASS  Brainstormer points to repository multi-question policy\n'
else
    printf '  FAIL  Brainstormer points to repository multi-question policy — missing in %s\n' "$brainstormer" >&2
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    printf 'PASS test_multi_question_interaction_policy\n'
else
    printf 'FAIL test_multi_question_interaction_policy\n' >&2
    exit 1
fi
