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

[ -f "$dre_script" ] || fail 'bin/dre not found'
[ -f "$dwt_script" ] || fail 'bin/dwt not found'
[ -f "$did_you_mean_helper" ] || fail 'scripts/lib/did-you-mean.sh not found'

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

printf 'PASS test_workspace_navigation_helper_contracts\n'
