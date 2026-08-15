#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/context/lib/context-guards.sh
source "$repo_root/tests/context/lib/context-guards.sh"
require_workspace_pod 'test_install_validate_source' 'bash tests/context/run.sh pod-outside-nono'
require_outside_nono_sandbox 'test_install_validate_source' 'bash tests/context/run.sh pod-outside-nono'

temp_root="${TEMP:-${TMP:-${TMPDIR:-}}}"
[ -n "$temp_root" ] || {
  printf 'FAIL test_install_validate_source: TEMP/TMP/TMPDIR must be set (expected from .envrc)\n' >&2
  exit 1
}
case "$temp_root" in
  /*) ;;
  *)
    printf 'FAIL test_install_validate_source: TEMP/TMP/TMPDIR must be an absolute path: %s\n' "$temp_root" >&2
    exit 1
    ;;
esac
test_tmp_root="$temp_root/tests"
mkdir -p "$test_tmp_root"

tmpdir="$(mktemp -d "$test_tmp_root/test_install_validate_source-XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

source_root="$tmpdir/source"
mkdir -p "$source_root"
printf 'ok\n' > "$source_root/install.sh"

"$repo_root/scripts/lib/validate_install_source_tree.sh" "$source_root" "$source_root/install.sh" >"$tmpdir/ok.out"
grep -F "ok: validated source path" "$tmpdir/ok.out" >/dev/null

ln -snf /etc/passwd "$source_root/escape"
if "$repo_root/scripts/lib/validate_install_source_tree.sh" "$source_root" "$source_root/escape" >"$tmpdir/escape.out" 2>&1; then
  printf 'expected escape path to fail\n' >&2
  exit 1
fi
grep -F "refused: symlink escapes source root" "$tmpdir/escape.out" >/dev/null

printf 'gitdir: /etc\n' > "$source_root/.git"
if "$repo_root/scripts/lib/validate_install_source_tree.sh" "$source_root" "$source_root/install.sh" >"$tmpdir/gitdir.out" 2>&1; then
  printf 'expected gitdir validation to fail\n' >&2
  exit 1
fi
grep -F "refused: gitdir outside /workspaces/dotfiles" "$tmpdir/gitdir.out" >/dev/null

printf 'PASS test_install_validate_source\n'
