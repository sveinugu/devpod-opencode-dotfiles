#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_read_install_env: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/context/lib/context-guards.sh
source "$repo_root/tests/context/lib/context-guards.sh"
require_workspace_pod 'test_read_install_env' 'bash tests/context/run.sh pod-inside-nono'
require_inside_nono_sandbox 'test_read_install_env' 'bash tests/context/run.sh pod-inside-nono'

script="$repo_root/scripts/lib/read-install-env.sh"

[ -f "$script" ] || fail "scripts/lib/read-install-env.sh not found"

temp_root="${TEMP:-${TMP:-${TMPDIR:-}}}"
[ -n "$temp_root" ] || fail 'TEMP/TMP/TMPDIR must be set (expected from .envrc)'
case "$temp_root" in
  /*) ;;
  *) fail "TEMP/TMP/TMPDIR must be an absolute path: $temp_root" ;;
esac
test_tmp_root="$temp_root/tests"
mkdir -p "$test_tmp_root"

tmpdir="$(mktemp -d "$test_tmp_root/test_read_install_env-XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

plain_env="$tmpdir/plain.env"
cat > "$plain_env" <<'EOF'
HUB_INSTALL_BRANCH=feature/plain
HUB_INSTALL_BRANCH_DIR=/workspaces/dotfiles/work/feature/plain
EOF

plain_out="$(bash "$script" "$plain_env")"
plain_branch=""
plain_dir=""
eval "$plain_out"

[ "${HUB_INSTALL_BRANCH:-}" = "feature/plain" ] || fail "expected plain format branch parsing"
[ "${HUB_INSTALL_BRANCH_DIR:-}" = "/workspaces/dotfiles/work/feature/plain" ] || fail "expected plain format directory parsing"

export_env="$tmpdir/export.env"
cat > "$export_env" <<'EOF'
export HUB_INSTALL_BRANCH=feature/exported
export HUB_INSTALL_BRANCH_DIR=/workspaces/dotfiles/work/feature/exported
EOF

unset HUB_INSTALL_BRANCH HUB_INSTALL_BRANCH_DIR
export_out="$(bash "$script" "$export_env")"
eval "$export_out"

[ "${HUB_INSTALL_BRANCH:-}" = "feature/exported" ] || fail "expected export format branch parsing"
[ "${HUB_INSTALL_BRANCH_DIR:-}" = "/workspaces/dotfiles/work/feature/exported" ] || fail "expected export format directory parsing"

missing_out="$(bash "$script" "$tmpdir/missing.env")"
[ -z "$missing_out" ] || fail "expected empty output for missing install.env"

printf 'PASS test_read_install_env\n'
