#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_execution_boundary_policy_contract'

policy="$repo_root/.config/opencode/AGENTS.md"
for rule in \
  'Harness agents do not have permission to execute work designated `pod-outside-nono` or to run as the `vscode` user.' \
  'Changing HOME/XDG variables does not change execution identity or grant permission.' \
  'Do not bypass context guards, clear sandbox variables, switch users, or reproduce the underlying operations directly to evade this boundary.' \
  'Ask the human to run outside-nono or vscode-only commands in their own shell and return the output.' \
  'Distinguish human-provided verification from checks run by the agent; a sandboxed reproduction is not evidence for the vscode execution context.'; do
  rg -qF -- "$rule" "$policy" || {
    printf 'FAIL test_execution_boundary_policy_contract: missing rule: %s\n' "$rule" >&2
    exit 1
  }
done

rg -qF 'Harness agents must not execute `pod-outside-nono` tests or commands as `vscode`' "$repo_root/tests/README.md"
printf 'PASS test_execution_boundary_policy_contract\n'
