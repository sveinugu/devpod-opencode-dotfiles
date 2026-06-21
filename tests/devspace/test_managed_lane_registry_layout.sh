#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_lane_registry_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
entrypoint="$repo_root/scripts/lib/managed-lane-registry.sh"
path_helper="$repo_root/scripts/lib/managed-lane-registry-path.sh"
mutation_helper="$repo_root/scripts/lib/managed-lane-registry-mutations.sh"

[ -f "$entrypoint" ] || fail 'scripts/lib/managed-lane-registry.sh not found'
[ -f "$path_helper" ] || fail 'scripts/lib/managed-lane-registry-path.sh not found'
[ -f "$mutation_helper" ] || fail 'scripts/lib/managed-lane-registry-mutations.sh not found'

grep -F 'source "$script_dir/managed-lane-registry-path.sh"' "$entrypoint" >/dev/null || fail 'entrypoint should source managed-lane-registry-path.sh'
grep -F 'source "$script_dir/managed-lane-registry-mutations.sh"' "$entrypoint" >/dev/null || fail 'entrypoint should source managed-lane-registry-mutations.sh'
grep -F 'if [ -n "${BASH_SOURCE[1]:-}" ]; then' "$entrypoint" >/dev/null || fail 'entrypoint should restore caller sourcing state when sourced'
grep -F 'script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd -P)"' "$entrypoint" >/dev/null || fail 'entrypoint should restore caller script_dir after sourcing helpers'
grep -F 'unset script_dir' "$entrypoint" >/dev/null || fail 'entrypoint should unset script_dir when no caller exists'
grep -F 'managed_lane_registry_record_binding() {' "$entrypoint" >/dev/null || fail 'entrypoint should keep managed_lane_registry_record_binding public API'
grep -F 'managed_lane_registry_ensure_header "$registry_path"' "$entrypoint" >/dev/null || fail 'entrypoint should orchestrate header creation through mutation helper'
grep -F 'managed_lane_registry_write_pointer \' "$entrypoint" >/dev/null || fail 'entrypoint should orchestrate pointer writes through mutation helper'
grep -F 'managed_lane_registry_remove_existing_for_pointer "$registry_path" "$pointer_path"' "$entrypoint" >/dev/null || fail 'entrypoint should preserve pointer de-duplication call'
grep -F 'managed_lane_registry_append_record \' "$entrypoint" >/dev/null || fail 'entrypoint should append through mutation helper'

grep -F 'managed_lane_registry_require_non_empty() {' "$path_helper" >/dev/null || fail 'path helper should own required-field guard'
grep -F 'managed_lane_registry_resolve_state_root() {' "$path_helper" >/dev/null || fail 'path helper should own state-root resolution'
grep -F 'managed_lane_registry_registry_path() {' "$path_helper" >/dev/null || fail 'path helper should own registry path resolution'
grep -F 'managed_lane_registry_pointer_path() {' "$path_helper" >/dev/null || fail 'path helper should own pointer path resolution'
grep -F 'managed_lane_registry_escape_tsv() {' "$path_helper" >/dev/null || fail 'path helper should own TSV escaping'

grep -F 'managed_lane_registry_ensure_header() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own header creation'
grep -F 'managed_lane_registry_write_pointer() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own pointer writes'
grep -F 'managed_lane_registry_remove_existing_for_pointer() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own pointer de-duplication'
grep -F 'managed_lane_registry_append_record() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own record appends'

printf 'PASS test_managed_lane_registry_layout\n'
