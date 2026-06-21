#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_helper_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
dre_script="$repo_root/bin/dre"
dwt_script="$repo_root/bin/dwt"
did_you_mean_helper="$repo_root/scripts/lib/did-you-mean.sh"

[ -f "$dre_script" ] || fail 'bin/dre not found'
[ -f "$dwt_script" ] || fail 'bin/dwt not found'
[ -f "$did_you_mean_helper" ] || fail 'scripts/lib/did-you-mean.sh not found'

grep -F 'source "$script_dir/../scripts/lib/did-you-mean.sh"' "$dre_script" >/dev/null || fail 'dre should source did-you-mean helper'
grep -F 'source "$script_dir/../scripts/lib/did-you-mean.sh"' "$dwt_script" >/dev/null || fail 'dwt should source did-you-mean helper'

if grep -F 'did_you_mean() {' "$dre_script" >/dev/null; then
  fail 'dre should no longer define did_you_mean inline'
fi
if grep -F 'did_you_mean() {' "$dwt_script" >/dev/null; then
  fail 'dwt should no longer define did_you_mean inline'
fi

grep -F 'did_you_mean() {' "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should define did_you_mean'
grep -F 'suggestion="$(python3 - "$needle" "$@" <<'"'"'PY'"'"'' "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should keep the Python difflib suggestion path'
grep -F "printf 'did you mean: %s\\n' \"\$suggestion\" >&2" "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should preserve exact suggestion output wording'
if grep -F 'script_dir=' "$did_you_mean_helper" >/dev/null; then
  fail 'did-you-mean helper must not assign script_dir'
fi

printf 'PASS test_workspace_navigation_helper_layout\n'
