#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_lane_registry_contracts: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
entrypoint="$repo_root/scripts/lib/managed-lane-registry.sh"

[ -f "$entrypoint" ] || fail 'scripts/lib/managed-lane-registry.sh not found'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

caller_dir="$tmpdir/caller"
mkdir -p "$caller_dir"
caller_script="$caller_dir/load-managed-lane-registry.sh"

cat > "$caller_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
script_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd -P)"
source "$entrypoint"
[ "\$script_dir" = "$caller_dir" ] || {
  printf 'restored-script-dir=%s\n' "\$script_dir" >&2
  exit 91
}
EOF
chmod +x "$caller_script"

if ! bash "$caller_script" >"$tmpdir/script-dir.out" 2>"$tmpdir/script-dir.err"; then
  cat "$tmpdir/script-dir.err" >&2
  fail 'sourcing entrypoint should restore caller script_dir'
fi

set +e
missing_output="$(bash -c 'set -euo pipefail; source "$1"; managed_lane_registry_require_non_empty "" workspace_root' _ "$entrypoint" 2>&1)"
missing_rc="$?"
set -e

[ "$missing_rc" = '1' ] || fail 'required-field guard should fail with exit code 1'
printf '%s\n' "$missing_output" | grep -F 'refused: managed lane registry missing required workspace_root' >/dev/null || fail 'required-field guard should preserve exact refusal text'

workspace_root="$tmpdir/workspace"
state_path="$workspace_root/state/hub/work/feature/demo"
mkdir -p "$state_path"

bash -c 'set -euo pipefail; source "$1"; managed_lane_registry_record_binding "$2" hub lane-one feature/demo-a /worktree/one "$3" docs/superpowers/specs/first.md ses_first planner bound active' _ "$entrypoint" "$workspace_root" "$state_path"
bash -c 'set -euo pipefail; source "$1"; managed_lane_registry_record_binding "$2" hub lane-two feature/demo-b /worktree/two "$3" docs/superpowers/specs/second.md ses_second planner bound active' _ "$entrypoint" "$workspace_root" "$state_path"

registry_path="$workspace_root/state/hub/lanes/registry.tsv"
pointer_path="$state_path/lane-binding.env"

[ -f "$registry_path" ] || fail 'registry file should exist after record_binding calls'
[ -f "$pointer_path" ] || fail 'pointer file should exist after record_binding calls'

record_count="$(awk 'END { print NR - 1 }' "$registry_path")"
[ "$record_count" = '1' ] || fail 're-recording the same pointer path should replace the existing registry row'
grep -F $'lane-two\thub\tfeature/demo-b\t/worktree/two\t' "$registry_path" >/dev/null || fail 'registry should keep the replacement row for the repeated pointer path'
if grep -F $'lane-one\thub\tfeature/demo-a\t/worktree/one\t' "$registry_path" >/dev/null; then
  fail 'registry should not retain the superseded row for the repeated pointer path'
fi

expected_pointer_content="$(cat <<EOF
LANE_ID=lane-two
REPO_IDENTITY=hub
BRANCH_NAME=feature/demo-b
WORKTREE_PATH=/worktree/two
STATE_PATH=$state_path
PARENT_ARTIFACT_ANCHORS=docs/superpowers/specs/second.md
SESSION_TASK_ID=ses_second
SESSION_OWNER=planner
ROUTING_STATE=bound
STATUS=active
EOF
)"
actual_pointer_content="$(cat "$pointer_path")"

[ "$actual_pointer_content" = "$expected_pointer_content" ] || fail 'pointer file should preserve key order and replacement values'

printf 'PASS test_managed_lane_registry_contracts\n'
