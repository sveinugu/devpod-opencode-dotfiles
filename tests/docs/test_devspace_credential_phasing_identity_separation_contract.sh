#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_credential_phasing_identity_separation_contract: %s\n' "$1" >&2
  exit 1
}

spec='docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md'
plan='docs/superpowers/plans/2026-07-14-devspace-model-credential-phasing.md'

[ -f "$spec" ] || fail "design spec not found"
[ -f "$plan" ] || fail "implementation plan not found"

grep -F '### Privilege separation and `sudo` handling (security-hardening add-on)' "$spec" >/dev/null || fail "spec should define privilege-separation and sudo hardening section"
grep -F 'owner/operator user' "$spec" >/dev/null || fail "spec should name owner/operator user"
grep -F 'agent runtime user' "$spec" >/dev/null || fail "spec should name agent runtime user"
grep -F '`sudo` behavior must be treated as **verification-required**' "$spec" >/dev/null || fail "spec should require explicit sudo-behavior verification"
grep -F 'Chosen direction: **mandatory two-user split**' "$spec" >/dev/null || fail "spec should lock mandatory two-user split direction"
grep -F 'Single-user strict-wrapper-only direction is rejected for this slice.' "$spec" >/dev/null || fail "spec should reject single-user wrapper-only direction"
grep -F 'agent runtime user-switch attempts to owner/operator identity are blocked in the supported path' "$spec" >/dev/null || fail "spec should require blocked user-switch escalation from agent runtime"
grep -F 'shell-escape paths that attempt to bypass the agent-runtime boundary are blocked in the supported path' "$spec" >/dev/null || fail "spec should require blocked shell-escape bypass paths"
grep -F 'owner/operator identity is the main sudo-capable workspace user: `vscode`.' "$spec" >/dev/null || fail "spec should state owner/operator is the main sudo user vscode"
grep -F 'owner/operator `sudo` is a trusted maintenance path for this slice and is not treated as an escalation failure by itself.' "$spec" >/dev/null || fail "spec should define trusted owner/operator sudo path semantics"

grep -F 'Task 2.5: Add owner/agent runtime identity separation hardening' "$plan" >/dev/null || fail "plan should include Task 2.5 for owner/agent separation"
grep -F 'Verify `sudo` behavior under the wrapped secure path' "$plan" >/dev/null || fail "plan should require sudo-behavior verification in secure path"
grep -F 'privilege-separation + escalation-blocking add-on is implemented with passing contract evidence and dedicated security review sign-off' "$plan" >/dev/null || fail "plan acceptance criteria should require implemented escalation-blocking add-on"
grep -F 'Two-user split is mandatory for this plan slice.' "$plan" >/dev/null || fail "plan should explicitly lock mandatory two-user split"
grep -F 'Single-user wrapper-only fallback is out of scope for this plan.' "$plan" >/dev/null || fail "plan should reject single-user fallback"
grep -F 'Docs Review Gate: do not begin Task 2.5 runtime implementation until the user approves this docs clarification.' "$plan" >/dev/null || fail "plan should include docs review gate before implementation"
grep -F 'Verify `sudo` behavior under the wrapped secure path with explicit contract evidence that the trusted owner/operator `sudo` path remains constrained and that agent runtime escalation paths stay blocked.' "$plan" >/dev/null || fail "plan should require constrained trusted owner path plus blocked agent escalation evidence"
grep -F 'Owner/operator identity for this slice is the main sudo-capable workspace user: `vscode`.' "$plan" >/dev/null || fail "plan should state owner/operator is the main sudo user vscode"
grep -F 'Owner/operator `sudo` use by `vscode` remains a trusted maintenance path and is not itself classified as escalation failure for this slice.' "$plan" >/dev/null || fail "plan should define trusted owner/operator sudo path semantics"
grep -F 'Sequencing note: Task 2.5 may complete identity and secret-boundary hardening before wrapper-path binding exists; if `.config/opencode/bin/opencode` is not present yet, finalize wrapper integration in Task 5.' "$plan" >/dev/null || fail "plan should clarify Task 2.5/Task 5 wrapper sequencing"
grep -F 'one focused verification command or test file proving owner-vs-agent identity separation and escalation blocking (`sudo`, user-switch, and shell-escape bypass attempts) for the supported path' "$plan" >/dev/null || fail "plan verification section should include explicit identity/escalation verification bullet"

if grep -F 'or explicitly marked deferred with reviewer-approved risk notes' "$plan" >/dev/null; then
  fail "plan must not allow deferring a mandatory two-user split add-on"
fi

if grep -F 'or explicitly marked deferred with reviewer-approved risk notes' "$spec" >/dev/null; then
  fail "spec must not allow deferring a mandatory two-user split add-on"
fi

printf 'PASS test_devspace_credential_phasing_identity_separation_contract\n'
