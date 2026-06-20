#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_install_helper_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
install_script="$repo_root/install.sh"
parse_args_helper="$repo_root/scripts/lib/install/parse-args.sh"
resolve_source_helper="$repo_root/scripts/lib/install/resolve-source.sh"
validate_source_helper="$repo_root/scripts/lib/install/validate-source.sh"
materialize_helper="$repo_root/scripts/lib/install/materialize.sh"

[ -f "$install_script" ] || fail "install.sh not found"
[ -f "$parse_args_helper" ] || fail "scripts/lib/install/parse-args.sh not found"
[ -f "$resolve_source_helper" ] || fail "scripts/lib/install/resolve-source.sh not found"
[ -f "$validate_source_helper" ] || fail "scripts/lib/install/validate-source.sh not found"
[ -f "$materialize_helper" ] || fail "scripts/lib/install/materialize.sh not found"

grep -F 'source "$source_root/scripts/lib/install/parse-args.sh"' "$install_script" >/dev/null || fail "install.sh should source parse-args helper"
grep -F 'source "$source_root/scripts/lib/install/resolve-source.sh"' "$install_script" >/dev/null || fail "install.sh should source resolve-source helper"
grep -F 'source "$source_root/scripts/lib/install/validate-source.sh"' "$install_script" >/dev/null || fail "install.sh should source validate-source helper"
grep -F 'source "$source_root/scripts/lib/install/materialize.sh"' "$install_script" >/dev/null || fail "install.sh should source materialize helper"

grep -F 'install_parse_args "$@"' "$install_script" >/dev/null || fail "install.sh should parse CLI args through the helper"
grep -F 'install_resolve_source_context' "$install_script" >/dev/null || fail "install.sh should resolve source context through the helper"
grep -F 'install_validate_source_context' "$install_script" >/dev/null || fail "install.sh should validate source context through the helper"
grep -F 'install_materialize' "$install_script" >/dev/null || fail "install.sh should materialize through the helper"

grep -F 'if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then' "$materialize_helper" >/dev/null || fail "materialize helper should preserve the file-based oh-my-zsh guard"

printf 'PASS test_install_helper_layout\n'
