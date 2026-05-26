#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_full_plan_consistency: %s\n' "$1" >&2
  exit 1
}

plan='docs/superpowers/plans/2026-05-24-full-plan-devspace-bare-hub.md'
[ -f "$plan" ] || fail "full plan not found"

if grep -F 'dd()' "$plan" >/dev/null; then
  fail "full plan must not describe dd compatibility behavior"
fi

if grep -F 'Create: `bin/dhub`' "$plan" >/dev/null; then
  fail "full plan must not require bin/dhub executable"
fi

if grep -F 'origin/master' "$plan" >/dev/null; then
  fail "full plan must not describe origin/master bootstrap fallback"
fi

grep -F 'main-only' "$plan" >/dev/null || fail "full plan should describe main-only top-level bootstrap policy"
grep -F '.config/shell/workspace-navigation.zsh' "$plan" >/dev/null || fail "full plan should map dhub to shell function location"
grep -F 'scripts/lib/resolve-install-target.sh' "$plan" >/dev/null || fail "full plan should map dhub resolver helper"

if grep -F 'scripts/workspace-provision.sh' "$plan" >/dev/null; then
  fail "full plan should reference scripts/provision-workspace.sh"
fi

if grep -F 'scripts/devspace-dev-preflight.sh' "$plan" >/dev/null; then
  fail "full plan should reference scripts/preflight-devspace-dev.sh"
fi

if grep -F 'scripts/lib/validate_install_source_tree`' "$plan" >/dev/null; then
  fail "full plan should reference validate_install_source_tree.sh"
fi

if grep -F 'scripts/lib/validate_hub_repo_root`' "$plan" >/dev/null; then
  fail "full plan should reference validate_hub_repo_root.sh"
fi

printf 'PASS test_devspace_full_plan_consistency\n'
