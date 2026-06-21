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
metadata_main_output="$(bash -c 'set -euo pipefail; workspace_root="$2"; script_dir="$3"; source "$1"; fail_metadata beta "$4"' _ \
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
metadata_master_output="$(bash -c 'set -euo pipefail; workspace_root="$2"; script_dir="$3"; source "$1"; fail_metadata beta "$4"' _ \
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

printf 'PASS test_workspace_navigation_helper_contracts\n'
