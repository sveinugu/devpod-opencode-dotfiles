#!/usr/bin/env bash
set -euo pipefail

_MLR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_MLR_SCRIPT_DIR/managed-lane-registry-common.sh"
source "$_MLR_SCRIPT_DIR/managed-lane-registry-path.sh"
source "$_MLR_SCRIPT_DIR/managed-lane-registry-mutations.sh"

managed_lane_registry_record_binding() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local lane_id="${3:?lane_id required}"
  local branch="${4:?branch required}"
  local worktree_path="${5:?worktree_path required}"
  local state_path="${6:?state_path required}"
  local parent_artifact_anchors="${7-}"
  local session_task_id="${8-}"
  local session_owner="${9-}"
  local routing_state="${10:-unbound}"
  local status="${11:-active}"

  managed_lane_registry_require_non_empty "$workspace_root" 'workspace_root'
  managed_lane_registry_require_non_empty "$repo_identity" 'repo_identity'
  managed_lane_registry_require_non_empty "$lane_id" 'lane_id'
  managed_lane_registry_require_non_empty "$branch" 'branch'
  managed_lane_registry_require_non_empty "$worktree_path" 'worktree_path'
  managed_lane_registry_require_non_empty "$state_path" 'state_path'

  local registry_path pointer_path
  registry_path="$(managed_lane_registry_registry_path "$workspace_root" "$repo_identity")"
  pointer_path="$(managed_lane_registry_pointer_path "$state_path")"

  managed_lane_registry_ensure_header "$registry_path"
  managed_lane_registry_write_pointer \
    "$pointer_path" \
    "$lane_id" \
    "$repo_identity" \
    "$branch" \
    "$worktree_path" \
    "$state_path" \
    "$parent_artifact_anchors" \
    "$session_task_id" \
    "$session_owner" \
    "$routing_state" \
    "$status"

  managed_lane_registry_remove_existing_for_pointer "$registry_path" "$pointer_path"
  managed_lane_registry_append_record \
    "$registry_path" \
    "$lane_id" \
    "$repo_identity" \
    "$branch" \
    "$worktree_path" \
    "$state_path" \
    "$pointer_path" \
    "$parent_artifact_anchors" \
    "$session_task_id" \
    "$session_owner" \
    "$routing_state" \
    "$status"
}
