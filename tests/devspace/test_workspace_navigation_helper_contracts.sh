#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_helper_contracts: %s\n' "$1" >&2
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

set +e
dre_usage_output="$(bash "$dre_script" 2>&1)"
dre_usage_rc="$?"
set -e

[ "$dre_usage_rc" = '2' ] || fail 'dre should exit 2 for wrong arg count'
[ "$dre_usage_output" = 'usage: dre <repo>' ] || fail 'dre should print exact usage text for wrong arg count'

set +e
dwt_usage_output="$(bash "$dwt_script" one two 2>&1)"
dwt_usage_rc="$?"
set -e

[ "$dwt_usage_rc" = '2' ] || fail 'dwt should exit 2 for too many args'
[ "$dwt_usage_output" = 'usage: dwt [name]' ] || fail 'dwt should print exact usage text for too many args'

suggestion_output="$(bash -c 'set -euo pipefail; source "$1"; did_you_mean alpa alpha beta' _ "$did_you_mean_helper" 2>&1)"
[ "$suggestion_output" = 'did you mean: alpha' ] || fail 'did_you_mean should preserve exact suggestion output for close matches'

no_match_output="$(bash -c 'set -euo pipefail; source "$1"; did_you_mean zzz alpha beta' _ "$did_you_mean_helper" 2>&1)"
[ -z "$no_match_output" ] || fail 'did_you_mean should stay silent when no suggestion exists'

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

workspace_root_main="$tmp_root/workspace-main"
repo_root_main="$workspace_root_main/repos/beta"
mkdir -p "$workspace_root_main/main" "$repo_root_main"

set +e
metadata_main_output="$(bash -c 'set -euo pipefail; source "$1"; fail_metadata beta "$4" "$2" "$3"' _ \
  "$metadata_helper" \
  "$workspace_root_main" \
  "$repo_root/bin" \
  "$repo_root_main" 2>&1)"
metadata_main_rc="$?"
set -e

[ "$metadata_main_rc" = '1' ] || fail 'fail_metadata should exit 1 when metadata is invalid (main case)'
expected_main_output="$(printf 'refused: managed child default branch metadata is missing or invalid for "%s"\nto repair, run:\n  HUB_WORKSPACE_ROOT="%s" bash %s "%s" "%s" "%s"\n' \
  'beta' \
  "$workspace_root_main" \
  "$repo_root/scripts/lib/write-managed-repo-env.sh" \
  'beta' \
  'main' \
  "$repo_root_main/main")"
[ "$metadata_main_output" = "$expected_main_output" ] || fail 'fail_metadata should preserve exact refusal and repair output (main case)'

workspace_root_master="$tmp_root/workspace-master"
repo_root_master="$workspace_root_master/repos/beta"
mkdir -p "$repo_root_master/master"

set +e
metadata_master_output="$(bash -c 'set -euo pipefail; source "$1"; fail_metadata beta "$4" "$2" "$3"' _ \
  "$metadata_helper" \
  "$workspace_root_master" \
  "$repo_root/bin" \
  "$repo_root_master" 2>&1)"
metadata_master_rc="$?"
set -e

[ "$metadata_master_rc" = '1' ] || fail 'fail_metadata should exit 1 when metadata is invalid (master case)'
expected_master_output="$(printf 'refused: managed child default branch metadata is missing or invalid for "%s"\nto repair, run:\n  HUB_WORKSPACE_ROOT="%s" bash %s "%s" "%s" "%s"\n' \
  'beta' \
  "$workspace_root_master" \
  "$repo_root/scripts/lib/write-managed-repo-env.sh" \
  'beta' \
  'master' \
  "$repo_root_master/master")"
[ "$metadata_master_output" = "$expected_master_output" ] || fail 'fail_metadata should preserve exact refusal and repair output (master fallback case)'

set +e
metadata_missing_repo_name_output="$(bash -c 'set -euo pipefail; source "$1"; fail_metadata "" "$2" "$3" "$4"' _ \
  "$metadata_helper" \
  "$repo_root_master" \
  "$workspace_root_master" \
  "$repo_root/bin" 2>&1)"
metadata_missing_repo_name_rc="$?"
set -e

[ "$metadata_missing_repo_name_rc" = '1' ] || fail 'fail_metadata should exit 1 when repo_name is empty'
[ "$metadata_missing_repo_name_output" = 'refused: fail_metadata requires non-empty repo_name' ] || fail 'fail_metadata should fail fast with a clear repo_name guard message'

set +e
metadata_missing_repo_root_output="$(bash -c 'set -euo pipefail; source "$1"; fail_metadata beta "" "$2" "$3"' _ \
  "$metadata_helper" \
  "$workspace_root_master" \
  "$repo_root/bin" 2>&1)"
metadata_missing_repo_root_rc="$?"
set -e

[ "$metadata_missing_repo_root_rc" = '1' ] || fail 'fail_metadata should exit 1 when repo_root is empty'
[ "$metadata_missing_repo_root_output" = 'refused: fail_metadata requires non-empty repo_root' ] || fail 'fail_metadata should fail fast with a clear repo_root guard message'

set +e
metadata_missing_workspace_output="$(bash -c 'set -euo pipefail; source "$1"; fail_metadata beta "$2" "" "$3"' _ \
  "$metadata_helper" \
  "$repo_root_master" \
  "$repo_root/bin" 2>&1)"
metadata_missing_workspace_rc="$?"
set -e

[ "$metadata_missing_workspace_rc" = '1' ] || fail 'fail_metadata should exit 1 when workspace_root is empty'
[ "$metadata_missing_workspace_output" = 'refused: fail_metadata requires non-empty workspace_root' ] || fail 'fail_metadata should fail fast with a clear workspace_root guard message'

set +e
metadata_hint_missing_script_dir_output="$(bash -c 'set -euo pipefail; source "$1"; metadata_repair_hint beta "$2" "$3" ""' _ \
  "$metadata_helper" \
  "$repo_root_master" \
  "$workspace_root_master" 2>&1)"
metadata_hint_missing_script_dir_rc="$?"
set -e

[ "$metadata_hint_missing_script_dir_rc" = '1' ] || fail 'metadata_repair_hint should exit 1 when script_dir is empty'
[ "$metadata_hint_missing_script_dir_output" = 'refused: metadata_repair_hint requires non-empty script_dir' ] || fail 'metadata_repair_hint should fail fast with a clear script_dir guard message'

set +e
metadata_hint_missing_repo_name_output="$(bash -c 'set -euo pipefail; source "$1"; metadata_repair_hint "" "$2" "$3" "$4"' _ \
  "$metadata_helper" \
  "$repo_root_master" \
  "$workspace_root_master" \
  "$repo_root/bin" 2>&1)"
metadata_hint_missing_repo_name_rc="$?"
set -e

[ "$metadata_hint_missing_repo_name_rc" = '1' ] || fail 'metadata_repair_hint should exit 1 when repo_name is empty'
[ "$metadata_hint_missing_repo_name_output" = 'refused: metadata_repair_hint requires non-empty repo_name' ] || fail 'metadata_repair_hint should fail fast with a clear repo_name guard message'

set +e
metadata_hint_missing_repo_root_output="$(bash -c 'set -euo pipefail; source "$1"; metadata_repair_hint beta "" "$2" "$3"' _ \
  "$metadata_helper" \
  "$workspace_root_master" \
  "$repo_root/bin" 2>&1)"
metadata_hint_missing_repo_root_rc="$?"
set -e

[ "$metadata_hint_missing_repo_root_rc" = '1' ] || fail 'metadata_repair_hint should exit 1 when repo_root is empty'
[ "$metadata_hint_missing_repo_root_output" = 'refused: metadata_repair_hint requires non-empty repo_root' ] || fail 'metadata_repair_hint should fail fast with a clear repo_root guard message'

printf 'PASS test_workspace_navigation_helper_contracts\n'
