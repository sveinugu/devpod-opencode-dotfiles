#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_lane_registry_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
entrypoint="$repo_root/scripts/lib/managed-lane-registry.sh"
common_helper="$repo_root/scripts/lib/managed-lane-registry-common.sh"
path_helper="$repo_root/scripts/lib/managed-lane-registry-path.sh"
mutation_helper="$repo_root/scripts/lib/managed-lane-registry-mutations.sh"

[ -f "$entrypoint" ] || fail 'scripts/lib/managed-lane-registry.sh not found'
[ -f "$common_helper" ] || fail 'scripts/lib/managed-lane-registry-common.sh not found'
[ -f "$path_helper" ] || fail 'scripts/lib/managed-lane-registry-path.sh not found'
[ -f "$mutation_helper" ] || fail 'scripts/lib/managed-lane-registry-mutations.sh not found'

common_source_line="$(grep -nF 'source "$_MLR_SCRIPT_DIR/managed-lane-registry-common.sh"' "$entrypoint" | cut -d: -f1)"
path_source_line="$(grep -nF 'source "$_MLR_SCRIPT_DIR/managed-lane-registry-path.sh"' "$entrypoint" | cut -d: -f1)"
mutation_source_line="$(grep -nF 'source "$_MLR_SCRIPT_DIR/managed-lane-registry-mutations.sh"' "$entrypoint" | cut -d: -f1)"

[ "$common_source_line" -lt "$path_source_line" ] || fail 'entrypoint should source common helper before path helper'
[ "$path_source_line" -lt "$mutation_source_line" ] || fail 'entrypoint should source path helper before mutation helper'

grep -F 'managed_lane_registry_require_non_empty() {' "$common_helper" >/dev/null || fail 'common helper should own required-field guard'
grep -F 'managed_lane_registry_escape_tsv() {' "$common_helper" >/dev/null || fail 'common helper should own TSV escaping'

grep -F 'source "$_MLR_SCRIPT_DIR/managed-lane-registry-path.sh"' "$entrypoint" >/dev/null || fail 'entrypoint should source managed-lane-registry-path.sh through a private script dir variable'
grep -F 'source "$_MLR_SCRIPT_DIR/managed-lane-registry-mutations.sh"' "$entrypoint" >/dev/null || fail 'entrypoint should source managed-lane-registry-mutations.sh through a private script dir variable'
if grep -F 'BASH_SOURCE[1]' "$entrypoint" >/dev/null; then
  fail 'entrypoint should not rely on caller stack depth for script-dir restoration'
fi
if grep -F 'script_dir=' "$entrypoint" >/dev/null; then
  fail 'entrypoint should not assign caller script_dir'
fi
if grep -F 'unset script_dir' "$entrypoint" >/dev/null; then
  fail 'entrypoint should not unset caller script_dir'
fi
grep -F 'managed_lane_registry_record_binding() {' "$entrypoint" >/dev/null || fail 'entrypoint should keep managed_lane_registry_record_binding public API'
grep -F 'managed_lane_registry_ensure_header "$registry_path"' "$entrypoint" >/dev/null || fail 'entrypoint should orchestrate header creation through mutation helper'
grep -F 'managed_lane_registry_write_pointer \' "$entrypoint" >/dev/null || fail 'entrypoint should orchestrate pointer writes through mutation helper'
grep -F 'managed_lane_registry_remove_existing_for_pointer "$registry_path" "$pointer_path"' "$entrypoint" >/dev/null || fail 'entrypoint should preserve pointer de-duplication call'
grep -F 'managed_lane_registry_append_record \' "$entrypoint" >/dev/null || fail 'entrypoint should append through mutation helper'

grep -F 'source "$_MLR_PATH_SCRIPT_DIR/managed-lane-registry-common.sh"' "$path_helper" >/dev/null || fail 'path helper should source managed-lane-registry-common.sh through a private script dir variable'
grep -F 'managed_lane_registry_resolve_state_root() {' "$path_helper" >/dev/null || fail 'path helper should own state-root resolution'
grep -F 'managed_lane_registry_registry_path() {' "$path_helper" >/dev/null || fail 'path helper should own registry path resolution'
grep -F 'managed_lane_registry_pointer_path() {' "$path_helper" >/dev/null || fail 'path helper should own pointer path resolution'
if grep -F 'managed_lane_registry_require_non_empty() {' "$path_helper" >/dev/null; then
  fail 'path helper should not redefine required-field guard'
fi
if grep -F 'managed_lane_registry_escape_tsv() {' "$path_helper" >/dev/null; then
  fail 'path helper should not redefine TSV escaping'
fi

grep -F 'source "$_MLR_MUTATIONS_SCRIPT_DIR/managed-lane-registry-common.sh"' "$mutation_helper" >/dev/null || fail 'mutation helper should source managed-lane-registry-common.sh through a private script dir variable'
grep -F 'managed_lane_registry_ensure_header() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own header creation'
grep -F 'managed_lane_registry_write_pointer() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own pointer writes'
grep -F 'managed_lane_registry_remove_existing_for_pointer() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own pointer de-duplication'
grep -F 'managed_lane_registry_append_record() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own record appends'

printf 'PASS test_managed_lane_registry_layout\n'
