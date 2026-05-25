#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_dev_preflight: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/scripts/preflight-devspace-dev.sh"

[ -f "$script" ] || fail "scripts/preflight-devspace-dev.sh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_missing="$tmpdir/missing"
mkdir -p "$workspace_missing"

if HUB_WORKSPACE_ROOT="$workspace_missing" bash "$script" >"$tmpdir/missing.out" 2>&1; then
  fail "expected preflight to fail when .bare or main missing"
fi

grep -F 'run devspace run-pipeline provision' "$tmpdir/missing.out" >/dev/null || fail "missing guidance message when unprovisioned"

workspace_ok="$tmpdir/provisioned"
mkdir -p "$workspace_ok/.bare" "$workspace_ok/main"

HUB_WORKSPACE_ROOT="$workspace_ok" bash "$script" >"$tmpdir/provisioned.out" 2>&1 || fail "expected preflight to pass when provisioned"

printf 'PASS test_devspace_dev_preflight\n'
