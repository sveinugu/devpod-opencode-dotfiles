#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_lane_registry: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
new_worktree_script="$repo_root/bin/new-worktree"
clone_repo_script="$repo_root/bin/clone-repo"

[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'
[ -f "$clone_repo_script" ] || fail 'bin/clone-repo not found'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
home_dir="$tmpdir/home"
mkdir -p "$workspace_root/repos" "$workspace_root/state/repos" "$workspace_root/tmp/repos" "$home_dir"

top_source="$tmpdir/top-source"
git init "$top_source" >/dev/null 2>&1
(
  cd "$top_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'top\n' > README.md
  printf '#!/usr/bin/env bash\nset -euo pipefail\n' > install.sh
  chmod +x install.sh
  mkdir -p .config/opencode
  printf '{}\n' > .config/opencode/opencode.json
  git add README.md install.sh .config/opencode/opencode.json
  git commit -m 'top fixture' >/dev/null 2>&1
)

git clone --bare "$top_source" "$workspace_root/.bare" >/dev/null 2>&1
git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null 2>&1

mkdir -p "$workspace_root/state/hub/etc"
printf 'export HUB_INSTALL_BRANCH=main\n' > "$workspace_root/state/hub/etc/install.env"
printf 'export HUB_INSTALL_BRANCH_DIR=%s\n' "$workspace_root/main" >> "$workspace_root/state/hub/etc/install.env"

child_source="$tmpdir/child-source"
git init "$child_source" >/dev/null 2>&1
(
  cd "$child_source"
  git config user.name 'Test User'
  git config user.email 'test@example.com'
  git branch -M main
  printf 'child\n' > README.md
  git add README.md
  git commit -m 'child fixture' >/dev/null 2>&1
)

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$clone_repo_script" "$child_source" >/dev/null

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_ID='lane-hub-explicit' bash "$new_worktree_script" --repo hub feature/hub-explicit >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_PARENT_ARTIFACTS='docs/superpowers/specs/parent-anchor.md' bash "$new_worktree_script" --repo hub feature/hub-sibling-a >/dev/null
HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_PARENT_ARTIFACTS='docs/superpowers/specs/parent-anchor.md' bash "$new_worktree_script" --repo hub feature/hub-sibling-b >/dev/null

HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" MANAGED_LANE_PARENT_ARTIFACTS='docs/superpowers/specs/child-parent.md' MANAGED_LANE_SESSION_TASK_ID='ses_child123' MANAGED_LANE_SESSION_OWNER='senior-implementer' MANAGED_LANE_ROUTING_STATE='bound' bash "$new_worktree_script" --repo child-source feature/child-lane >/dev/null

hub_registry="$workspace_root/state/hub/lanes/registry.tsv"
child_registry="$workspace_root/state/repos/child-source/lanes/registry.tsv"

[ -f "$hub_registry" ] || fail 'missing hub lane registry file'
[ -f "$child_registry" ] || fail 'missing child lane registry file'

hub_header='lane_id	repo_identity	branch	worktree_path	state_path	pointer_path	parent_artifact_anchors	session_task_id	session_owner	routing_state	status'
grep -F "$hub_header" "$hub_registry" >/dev/null || fail 'hub lane registry header should match v1 shape'
grep -F "$hub_header" "$child_registry" >/dev/null || fail 'child lane registry header should match v1 shape'

grep -F $'lane-hub-explicit\thub\tfeature/hub-explicit\t' "$hub_registry" >/dev/null || fail 'hub registry should keep lane id separate from branch identity'
grep -F $'feature/hub-sibling-a\thub\tfeature/hub-sibling-a\t' "$hub_registry" >/dev/null || fail 'hub registry should include sibling lane A binding'
grep -F $'feature/hub-sibling-b\thub\tfeature/hub-sibling-b\t' "$hub_registry" >/dev/null || fail 'hub registry should include sibling lane B binding'
grep -F $'docs/superpowers/specs/parent-anchor.md\t\t\tunbound\tactive' "$hub_registry" >/dev/null || fail 'hub registry should record parent artifact anchors with explicit unbound session fields when absent'

hub_sibling_count="$(grep -F 'docs/superpowers/specs/parent-anchor.md' "$hub_registry" | wc -l | tr -d ' ')"
[ "$hub_sibling_count" = '2' ] || fail 'hub sibling lanes under one parent artifact should remain distinct bindings'

grep -F $'feature/child-lane\tchild-source\tfeature/child-lane\t' "$child_registry" >/dev/null || fail 'child registry should include child lane binding with explicit repo identity'
grep -F $'docs/superpowers/specs/child-parent.md\tses_child123\tsenior-implementer\tbound\tactive' "$child_registry" >/dev/null || fail 'child registry should record parent artifact and bound session linkage fields'

hub_pointer="$workspace_root/state/hub/work/feature/hub-explicit/lane-binding.env"
hub_sibling_pointer="$workspace_root/state/hub/work/feature/hub-sibling-a/lane-binding.env"
child_pointer="$workspace_root/state/repos/child-source/work/feature/child-lane/lane-binding.env"

[ -f "$hub_pointer" ] || fail 'missing hub per-worktree lane pointer'
[ -f "$hub_sibling_pointer" ] || fail 'missing hub sibling per-worktree lane pointer'
[ -f "$child_pointer" ] || fail 'missing child per-worktree lane pointer'

grep -F 'LANE_ID=lane-hub-explicit' "$hub_pointer" >/dev/null || fail 'hub pointer should expose lane id'
grep -F 'BRANCH_NAME=feature/hub-explicit' "$hub_pointer" >/dev/null || fail 'hub pointer should expose branch name separately'
grep -F 'REPO_IDENTITY=hub' "$hub_pointer" >/dev/null || fail 'hub pointer should expose hub repo identity'
grep -F 'PARENT_ARTIFACT_ANCHORS=' "$hub_pointer" >/dev/null || fail 'hub pointer should keep explicit empty parent artifact anchors when absent'
grep -F 'SESSION_TASK_ID=' "$hub_pointer" >/dev/null || fail 'hub pointer should keep explicit empty session task id when absent'
grep -F 'SESSION_OWNER=' "$hub_pointer" >/dev/null || fail 'hub pointer should keep explicit empty session owner when absent'
grep -F 'ROUTING_STATE=unbound' "$hub_pointer" >/dev/null || fail 'hub pointer should mark unbound routing state when no session linkage exists'
grep -F 'STATUS=active' "$hub_pointer" >/dev/null || fail 'hub pointer should default status to active'

grep -F 'LANE_ID=feature/hub-sibling-a' "$hub_sibling_pointer" >/dev/null || fail 'hub sibling pointer should use default lane id when no override supplied'
grep -F 'PARENT_ARTIFACT_ANCHORS=docs/superpowers/specs/parent-anchor.md' "$hub_sibling_pointer" >/dev/null || fail 'hub sibling pointer should keep parent artifact anchor'

grep -F 'LANE_ID=feature/child-lane' "$child_pointer" >/dev/null || fail 'child pointer should expose lane id'
grep -F 'REPO_IDENTITY=child-source' "$child_pointer" >/dev/null || fail 'child pointer should expose child repo identity'
grep -F 'PARENT_ARTIFACT_ANCHORS=docs/superpowers/specs/child-parent.md' "$child_pointer" >/dev/null || fail 'child pointer should expose parent artifact anchors'
grep -F 'SESSION_TASK_ID=ses_child123' "$child_pointer" >/dev/null || fail 'child pointer should expose session task id'
grep -F 'SESSION_OWNER=senior-implementer' "$child_pointer" >/dev/null || fail 'child pointer should expose session owner'
grep -F 'ROUTING_STATE=bound' "$child_pointer" >/dev/null || fail 'child pointer should expose bound routing state'
grep -F 'STATUS=active' "$child_pointer" >/dev/null || fail 'child pointer should expose active status'

printf 'PASS test_managed_lane_registry\n'
