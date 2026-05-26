#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_resolve_install_target: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
resolver="$repo_root/scripts/lib/resolve-install-target.sh"

[ -x "$resolver" ] || fail "scripts/lib/resolve-install-target.sh must exist and be executable"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

target="$tmpdir/work/main"
mkdir -p "$target"

install_env="$tmpdir/install.env"
cat > "$install_env" <<EOF
export HUB_INSTALL_BRANCH=main
export HUB_INSTALL_BRANCH_DIR=$target
EOF

resolved="$(HUB_INSTALL_ENV_FILE="$install_env" bash "$resolver")"
[ "$resolved" = "$target" ] || fail "resolver should print HUB_INSTALL_BRANCH_DIR from install state"

set +e
HUB_INSTALL_ENV_FILE="$tmpdir/missing.env" bash "$resolver" >"$tmpdir/missing.out" 2>&1
missing_rc="$?"
set -e

[ "$missing_rc" = "1" ] || fail "resolver should fail when install state is missing"
grep -F 'refused: install branch state is missing' "$tmpdir/missing.out" >/dev/null || fail "missing-state failure message mismatch"

invalid_env="$tmpdir/invalid.env"
cat > "$invalid_env" <<EOF
export HUB_INSTALL_BRANCH=main
export HUB_INSTALL_BRANCH_DIR=$tmpdir/not-a-dir
EOF

set +e
HUB_INSTALL_ENV_FILE="$invalid_env" bash "$resolver" >"$tmpdir/invalid.out" 2>&1
invalid_rc="$?"
set -e

[ "$invalid_rc" = "1" ] || fail "resolver should fail when install target directory is invalid"
grep -F 'refused: install branch directory is missing or invalid' "$tmpdir/invalid.out" >/dev/null || fail "invalid-target failure message mismatch"

printf 'PASS test_resolve_install_target\n'
