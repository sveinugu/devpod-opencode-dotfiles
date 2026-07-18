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
grep -F 'kubectl create secret generic dotfiles-nono-provider-credentials' "$lifecycle" >/dev/null || fail "lifecycle runbook must document provider credential secret creation command"
grep -F 'openai_api_key' "$lifecycle" >/dev/null || fail "lifecycle runbook must list openai_api_key secret key"
grep -F 'anthropic_api_key' "$lifecycle" >/dev/null || fail "lifecycle runbook must list anthropic_api_key secret key"
grep -F 'github_token' "$lifecycle" >/dev/null || fail "lifecycle runbook must list github_token secret key"
grep -F 'gpt_uio_yellow_api_key' "$lifecycle" >/dev/null || fail "lifecycle runbook must list gpt_uio_yellow_api_key secret key"
grep -F 'gpt_uio_red_api_key' "$lifecycle" >/dev/null || fail "lifecycle runbook must list gpt_uio_red_api_key secret key"
grep -F 'Create this secret before deploying the workspace' "$lifecycle" >/dev/null || fail "lifecycle runbook must require secret creation before deploy"
grep -F 'same namespace as the workspace Deployment/Pod' "$lifecycle" >/dev/null || fail "lifecycle runbook must state namespace scope for provider secret"
grep -F 'pod may need a restart or you may need to re-apply the deployment' "$lifecycle" >/dev/null || fail "lifecycle runbook must document restart/re-apply follow-up after secret creation"
grep -F 'single source of truth for provider enablement' "$lifecycle" >/dev/null || fail "lifecycle runbook must describe single-source-of-truth contract"
grep -F 'generated runtime configuration and verification output must both match this manifest exactly' "$lifecycle" >/dev/null || fail "lifecycle runbook must require generated runtime + verification parity with enablement manifest"
grep -F '/workspaces/dotfiles/state/hub/etc/provider-runtime.json' "$lifecycle" >/dev/null || fail "lifecycle runbook must define canonical generated runtime output path"
grep -F '/workspaces/dotfiles/state/hub/etc/provider-verification.json' "$lifecycle" >/dev/null || fail "lifecycle runbook must define canonical generated verification output path"
grep -F 'bin/sync-provider-enablement' "$lifecycle" >/dev/null || fail "lifecycle runbook must reference provider enablement sync command"
grep -F '/workspaces/dotfiles/main/.config/opencode/provider-runtime.json' "$lifecycle" >/dev/null || fail "lifecycle runbook must define install-branch generated runtime output path"
grep -F '/workspaces/dotfiles/main/.config/opencode/provider-verification.json' "$lifecycle" >/dev/null || fail "lifecycle runbook must define install-branch generated verification output path"
grep -F 'provider-enablement.seed.json' "$lifecycle" >/dev/null || fail "lifecycle runbook must document provider enablement seed manifest bootstrap guardrail"

grep -F '/workspaces/dotfiles/state/hub/etc/provider-enablement.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must reference canonical provider enablement manifest path"
grep -F 'kubectl create secret generic dotfiles-nono-provider-credentials' "$bare_hub" >/dev/null || fail "bare-hub runbook must document provider credential secret creation command"
grep -F 'openai_api_key' "$bare_hub" >/dev/null || fail "bare-hub runbook must list openai_api_key secret key"
grep -F 'anthropic_api_key' "$bare_hub" >/dev/null || fail "bare-hub runbook must list anthropic_api_key secret key"
grep -F 'github_token' "$bare_hub" >/dev/null || fail "bare-hub runbook must list github_token secret key"
grep -F 'gpt_uio_yellow_api_key' "$bare_hub" >/dev/null || fail "bare-hub runbook must list gpt_uio_yellow_api_key secret key"
grep -F 'gpt_uio_red_api_key' "$bare_hub" >/dev/null || fail "bare-hub runbook must list gpt_uio_red_api_key secret key"
grep -F 'Create this secret before deploying the workspace' "$bare_hub" >/dev/null || fail "bare-hub runbook must require secret creation before deploy"
grep -F 'same namespace as the workspace Deployment/Pod' "$bare_hub" >/dev/null || fail "bare-hub runbook must state namespace scope for provider secret"
grep -F 'pod may need a restart or you may need to re-apply the deployment' "$bare_hub" >/dev/null || fail "bare-hub runbook must document restart/re-apply follow-up after secret creation"
grep -F 'provider-policy.jsonc' "$bare_hub" >/dev/null || fail "bare-hub runbook must connect provider policy file to enablement workflow"
grep -F 'openai/anthropic with `all` mode' "$bare_hub" >/dev/null || fail "bare-hub runbook must document openai/anthropic all-mode policy"
grep -F 'provider-runtime.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must document generated runtime output artifact"
grep -F 'provider-verification.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must document generated verification output artifact"
grep -F '/workspaces/dotfiles/main/.config/opencode/provider-runtime.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must document install-branch generated runtime output artifact"
grep -F '/workspaces/dotfiles/main/.config/opencode/provider-verification.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must document install-branch generated verification output artifact"
grep -F 'provider-enablement.seed.json' "$bare_hub" >/dev/null || fail "bare-hub runbook must document provider enablement seed manifest bootstrap guardrail"

printf 'PASS test_devspace_enablement_manifest_contract\n'
