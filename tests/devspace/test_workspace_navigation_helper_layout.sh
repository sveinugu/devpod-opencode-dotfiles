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
metadata_helper="$repo_root/scripts/lib/managed-repo-metadata.sh"

[ -f "$dre_script" ] || fail 'bin/dre not found'
[ -f "$dwt_script" ] || fail 'bin/dwt not found'
[ -f "$did_you_mean_helper" ] || fail 'scripts/lib/did-you-mean.sh not found'
[ -f "$metadata_helper" ] || fail 'scripts/lib/managed-repo-metadata.sh not found'

grep -F 'source "$script_dir/../scripts/lib/did-you-mean.sh"' "$dre_script" >/dev/null || fail 'dre should source did-you-mean helper'
grep -F 'source "$script_dir/../scripts/lib/did-you-mean.sh"' "$dwt_script" >/dev/null || fail 'dwt should source did-you-mean helper'
grep -F 'source "$script_dir/../scripts/lib/managed-repo-metadata.sh"' "$dre_script" >/dev/null || fail 'dre should source managed-repo-metadata helper'
grep -F 'source "$script_dir/../scripts/lib/managed-repo-metadata.sh"' "$dwt_script" >/dev/null || fail 'dwt should source managed-repo-metadata helper'

if grep -F 'did_you_mean() {' "$dre_script" >/dev/null; then
  fail 'dre should no longer define did_you_mean inline'
fi
if grep -F 'did_you_mean() {' "$dwt_script" >/dev/null; then
  fail 'dwt should no longer define did_you_mean inline'
fi

if grep -F 'metadata_refusal() {' "$dre_script" >/dev/null; then
  fail 'dre should no longer define metadata_refusal inline'
fi
if grep -F 'metadata_repair_hint() {' "$dre_script" >/dev/null; then
  fail 'dre should no longer define metadata_repair_hint inline'
fi
if grep -F 'fail_metadata() {' "$dre_script" >/dev/null; then
  fail 'dre should no longer define fail_metadata inline'
fi

if grep -F 'metadata_refusal() {' "$dwt_script" >/dev/null; then
  fail 'dwt should no longer define metadata_refusal inline'
fi
if grep -F 'metadata_repair_hint() {' "$dwt_script" >/dev/null; then
  fail 'dwt should no longer define metadata_repair_hint inline'
fi
if grep -F 'fail_metadata() {' "$dwt_script" >/dev/null; then
  fail 'dwt should no longer define fail_metadata inline'
fi

grep -F 'did_you_mean() {' "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should define did_you_mean'
grep -F 'suggestion="$(python3 - "$needle" "$@" <<'"'"'PY'"'"'' "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should keep the Python difflib suggestion path'
grep -F "printf 'did you mean: %s\\n' \"\$suggestion\" >&2" "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should preserve exact suggestion output wording'
grep -F 'metadata_refusal() {' "$metadata_helper" >/dev/null || fail 'managed-repo-metadata helper should define metadata_refusal'
grep -F 'metadata_repair_hint() {' "$metadata_helper" >/dev/null || fail 'managed-repo-metadata helper should define metadata_repair_hint'
grep -F 'fail_metadata() {' "$metadata_helper" >/dev/null || fail 'managed-repo-metadata helper should define fail_metadata'
grep -F 'refused: managed child default branch metadata is missing or invalid for "%s"' "$metadata_helper" >/dev/null || fail 'managed-repo-metadata helper should preserve exact refusal text'
grep -F 'to repair, run:' "$metadata_helper" >/dev/null || fail 'managed-repo-metadata helper should preserve exact repair intro'

if grep -F 'script_dir=' "$did_you_mean_helper" >/dev/null; then
  fail 'did-you-mean helper must not assign script_dir'
fi
if grep -F 'script_dir=' "$metadata_helper" >/dev/null; then
  fail 'managed-repo-metadata helper must not assign script_dir'
fi

grep -F 'repo.env' "$dre_script" >/dev/null || fail 'dre should keep inline repo.env loading markers'
grep -F 'DYN_REPO_DEFAULT_BRANCH' "$dre_script" >/dev/null || fail 'dre should keep inline default-branch metadata checks'
grep -F 'DYN_REPO_DEFAULT_DIR' "$dre_script" >/dev/null || fail 'dre should keep inline default-dir metadata checks'
grep -F 'readlink -f' "$dre_script" >/dev/null || fail 'dre should keep inline canonicalization calls'
grep -F 'case "$default_dir_canon" in' "$dre_script" >/dev/null || fail 'dre should keep inline canonicalization case check'

grep -F 'repo.env' "$dwt_script" >/dev/null || fail 'dwt should keep inline repo.env loading markers'
grep -F 'DYN_REPO_DEFAULT_BRANCH' "$dwt_script" >/dev/null || fail 'dwt should keep inline default-branch metadata checks'
grep -F 'DYN_REPO_DEFAULT_DIR' "$dwt_script" >/dev/null || fail 'dwt should keep inline default-dir metadata checks'
grep -F 'readlink -f' "$dwt_script" >/dev/null || fail 'dwt should keep inline canonicalization calls'
grep -F 'case "$default_dir_canon" in' "$dwt_script" >/dev/null || fail 'dwt should keep inline canonicalization case check'

printf 'PASS test_workspace_navigation_helper_layout\n'
