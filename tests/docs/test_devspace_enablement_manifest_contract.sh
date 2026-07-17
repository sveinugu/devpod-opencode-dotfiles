#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_enablement_manifest_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
lifecycle="$repo_root/docs/superpowers/runbooks/devspace-workspace-lifecycle.md"
bare_hub="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"

[ -f "$lifecycle" ] || fail "devspace-workspace-lifecycle runbook not found"
[ -f "$bare_hub" ] || fail "devspace-bare-hub-usage runbook not found"

grep -F '/workspaces/dotfiles/state/hub/etc/provider-enablement.json' "$lifecycle" >/dev/null || fail "lifecycle runbook must define canonical host-local provider enablement manifest path"
grep -F 'single source of truth for provider enablement' "$lifecycle" >/dev/null || fail "lifecycle runbook must describe single-source-of-truth contract"
grep -F 'generated runtime configuration and verification output must both match this manifest exactly' "$lifecycle" >/dev/null || fail "lifecycle runbook must require generated runtime + verification parity with enablement manifest"

grep -F '/workspaces/dotfiles/state/hub/etc/provider-enablement.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must reference canonical provider enablement manifest path"
grep -F 'provider-policy.jsonc' "$bare_hub" >/dev/null || fail "bare-hub runbook must connect provider policy file to enablement workflow"
grep -F 'openai/anthropic with `all` mode' "$bare_hub" >/dev/null || fail "bare-hub runbook must document openai/anthropic all-mode policy"

printf 'PASS test_devspace_enablement_manifest_contract\n'
