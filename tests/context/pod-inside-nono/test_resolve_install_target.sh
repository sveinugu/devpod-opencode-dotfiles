#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_resolve_install_target: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/context/lib/context-guards.sh
source "$repo_root/tests/context/lib/context-guards.sh"
require_workspace_pod 'test_resolve_install_target' 'bash tests/context/run.sh pod-inside-nono'
require_inside_nono_sandbox 'test_resolve_install_target' 'bash tests/context/run.sh pod-inside-nono'

resolver="$repo_root/scripts/lib/resolve-install-target.sh"

[ -x "$resolver" ] || fail "scripts/lib/resolve-install-target.sh must exist and be executable"

temp_root="${TEMP:-${TMP:-${TMPDIR:-}}}"
[ -n "$temp_root" ] || fail 'TEMP/TMP/TMPDIR must be set (expected from .envrc)'
case "$temp_root" in
  /*) ;;
  *) fail "TEMP/TMP/TMPDIR must be an absolute path: $temp_root" ;;
esac
test_tmp_root="$temp_root/tests"
mkdir -p "$test_tmp_root"

tmpdir="$(mktemp -d "$test_tmp_root/test_resolve_install_target-XXXXXX")"
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
