#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_credential_phasing_security_contract: %s\n' "$1" >&2
  exit 1
}

spec='docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md'
plan='docs/superpowers/plans/2026-07-14-devspace-model-credential-phasing.md'

[ -f "$spec" ] || fail "design spec not found"
[ -f "$plan" ] || fail "implementation plan not found"

grep -F 'Verification-matrix classification for this design is fixed at: 8 Blocking rows and 2 Advisory rows.' "$spec" >/dev/null || fail "spec should declare 8/2 matrix classification explicitly"
grep -F 'Verification-matrix classification for this plan is fixed at: 8 Blocking rows and 2 Advisory rows.' "$plan" >/dev/null || fail "plan should declare 8/2 matrix classification explicitly"

grep -F 'Kubernetes secret delivery surface is fixed to the read-only mount path `/var/run/secrets/nono/providers`.' "$spec" >/dev/null || fail "spec should define concrete Kubernetes secret mount path"
grep -F 'Before sandbox entry, raw secret-file reads are performed only by a constrained non-interactive privileged helper invocation (`sudo -n`) initiated by `vscode`.' "$spec" >/dev/null || fail "spec should define exact pre-sandbox principal/surface"
grep -F 'That helper invocation runs with effective UID 0 (root) only for the secret-read handoff step.' "$spec" >/dev/null || fail "spec should identify root helper principal for secret reads"
grep -F 'Direct interactive-shell reads of raw secret files by `vscode` are forbidden for the supported path.' "$spec" >/dev/null || fail "spec should forbid direct interactive vscode secret reads"

grep -F 'Implement the fixed pre-sandbox credential surface: read-only mount `/var/run/secrets/nono/providers` plus constrained non-interactive `sudo -n` helper handoff from `vscode`.' "$plan" >/dev/null || fail "plan should define fixed secret surface and handoff path"
grep -F 'For this plan, the secret-reading helper principal is effective UID 0 (root) invoked non-interactively via `sudo -n` by `vscode` only for pre-sandbox handoff.' "$plan" >/dev/null || fail "plan should identify root helper principal for secret reads"
grep -F 'Verify that direct interactive-shell reads of `/var/run/secrets/nono/providers/*` by `vscode` are blocked for the supported path contract.' "$plan" >/dev/null || fail "plan should require blocked interactive vscode secret reads"

grep -F 'Provider verification failure stop rule (mandatory):' "$spec" >/dev/null || fail "spec should include provider failure stop rule section"
grep -F 'On any supported-provider verification failure, stop shipment for the current slice immediately.' "$spec" >/dev/null || fail "spec should require immediate stop on provider failure"
grep -F 'resume only after explicit user re-approval of the updated supported-provider contract' "$spec" >/dev/null || fail "spec should require explicit re-approval on provider contract changes"

grep -F 'Provider failure handling (mandatory stop rule):' "$plan" >/dev/null || fail "plan should include provider failure handling section"
grep -F 'pause implementation and request explicit user re-approval before continuing' "$plan" >/dev/null || fail "plan should require explicit re-approval before continuing after provider failure"

grep -F 'This design does **not** prevent misuse of already-authorized provider access through the local proxy route.' "$spec" >/dev/null || fail "spec should explicitly state proxy-misuse non-protection"
grep -F 'This plan does **not** treat local-proxy-authorized provider usage as a misuse-prevention control surface.' "$plan" >/dev/null || fail "plan should explicitly state proxy-misuse non-protection"

grep -F 'For this contract, "shell-escape bypass attempts" means launching privileged shells from agent runtime (for example: `sudo -n /bin/sh`, `sudo -n /bin/bash`, `su -l vscode`).' "$spec" >/dev/null || fail "spec should concretize shell-escape bypass term"
grep -F 'For this contract, "auxiliary endpoints strictly required" means explicit `<scheme>://<host>:<port>` entries recorded in repo policy + verification evidence; wildcard hosts and broad CIDR allowances are forbidden.' "$spec" >/dev/null || fail "spec should concretize auxiliary endpoint requirement"

if grep -F 'Choose and implement one approved pre-sandbox credential delivery surface that matches the spec’s allowed boundary.' "$plan" >/dev/null; then
  fail "plan must not treat pre-sandbox credential delivery surface as open-ended"
fi

printf 'PASS test_devspace_credential_phasing_security_contract\n'
