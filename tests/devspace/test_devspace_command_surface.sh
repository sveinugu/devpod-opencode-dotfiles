#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_command_surface: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cfg="$repo_root/devspace.yaml"

[ -f "$cfg" ] || fail "devspace.yaml not found"

grep -Eq '^dev:\s*$' "$cfg" || fail "missing dev section"
grep -Eq '^\s{2}workspace:\s*$' "$cfg" || fail "missing dev workspace entry"

grep -Eq '^\s{2}provision:\s*' "$cfg" || fail "missing provision pipeline"
grep -Eq '^\s{2}doctor:\s*' "$cfg" || fail "missing doctor pipeline"
grep -Eq '^\s{2}repair:\s*' "$cfg" || fail "missing repair pipeline"
grep -Eq '^\s{2}destroy:\s*' "$cfg" || fail "missing destroy pipeline"

if grep -Eq '^\s{2}staging:\s*' "$cfg"; then
  fail "staging pipeline must not exist in phase 1"
fi

if grep -Eq '^\s{2}backup:\s*' "$cfg"; then
  fail "backup pipeline must not exist in phase 1"
fi

printf 'PASS test_devspace_command_surface\n'
