#!/usr/bin/env bash
set -euo pipefail

managed_lane_registry_require_non_empty() {
  local value="${1:-}"
  local field_name="${2:-value}"
  if [ -z "$value" ]; then
    printf 'refused: managed lane registry missing required %s\n' "$field_name" >&2
    return 1
  fi
}

managed_lane_registry_resolve_state_root() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"

  if [ "$repo_identity" = "hub" ]; then
    printf '%s\n' "$workspace_root/state/hub"
    return 0
  fi

  printf '%s\n' "$workspace_root/state/repos/$repo_identity"
}

managed_lane_registry_registry_path() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local state_root
  state_root="$(managed_lane_registry_resolve_state_root "$workspace_root" "$repo_identity")"
  printf '%s\n' "$state_root/lanes/registry.tsv"
}

managed_lane_registry_pointer_path() {
  local state_dir="${1:?state_dir required}"
  printf '%s\n' "$state_dir/lane-binding.env"
}

managed_lane_registry_escape_tsv() {
  local value="${1-}"
  value="${value//\\/\\\\}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

managed_lane_registry_ensure_header() {
  local registry_path="${1:?registry_path required}"
  local registry_dir
  registry_dir="$(dirname "$registry_path")"
  mkdir -p "$registry_dir"

  if [ ! -f "$registry_path" ]; then
    printf 'lane_id\trepo_identity\tbranch\tworktree_path\tstate_path\tpointer_path\tparent_artifact_anchors\tsession_task_id\tsession_owner\trouting_state\tstatus\n' > "$registry_path"
  fi
}

managed_lane_registry_write_pointer() {
  local pointer_path="${1:?pointer_path required}"
  local lane_id="${2:?lane_id required}"
  local repo_identity="${3:?repo_identity required}"
  local branch="${4:?branch required}"
  local worktree_path="${5:?worktree_path required}"
  local state_path="${6:?state_path required}"
  local parent_artifact_anchors="${7-}"
  local session_task_id="${8-}"
  local session_owner="${9-}"
  local routing_state="${10:-unbound}"
  local status="${11:-active}"

  mkdir -p "$(dirname "$pointer_path")"
  cat > "$pointer_path" <<EOF
LANE_ID=$(printf '%q' "$lane_id")
REPO_IDENTITY=$(printf '%q' "$repo_identity")
BRANCH_NAME=$(printf '%q' "$branch")
WORKTREE_PATH=$(printf '%q' "$worktree_path")
STATE_PATH=$(printf '%q' "$state_path")
PARENT_ARTIFACT_ANCHORS=$(printf '%q' "$parent_artifact_anchors")
SESSION_TASK_ID=$(printf '%q' "$session_task_id")
SESSION_OWNER=$(printf '%q' "$session_owner")
ROUTING_STATE=$(printf '%q' "$routing_state")
STATUS=$(printf '%q' "$status")
EOF
}

managed_lane_registry_remove_existing_for_pointer() {
  local registry_path="${1:?registry_path required}"
  local pointer_path="${2:?pointer_path required}"
  local escaped_pointer
  escaped_pointer="$(managed_lane_registry_escape_tsv "$pointer_path")"
  local tmp_file
  tmp_file="${registry_path}.tmp.$$"

  awk -F '\t' -v pointer="$escaped_pointer" 'NR==1 || $6 != pointer { print }' "$registry_path" > "$tmp_file"
  mv "$tmp_file" "$registry_path"
}

managed_lane_registry_append_record() {
  local registry_path="${1:?registry_path required}"
  local lane_id="${2:?lane_id required}"
  local repo_identity="${3:?repo_identity required}"
  local branch="${4:?branch required}"
  local worktree_path="${5:?worktree_path required}"
  local state_path="${6:?state_path required}"
  local pointer_path="${7:?pointer_path required}"
  local parent_artifact_anchors="${8-}"
  local session_task_id="${9-}"
  local session_owner="${10-}"
  local routing_state="${11:-unbound}"
  local status="${12:-active}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(managed_lane_registry_escape_tsv "$lane_id")" \
    "$(managed_lane_registry_escape_tsv "$repo_identity")" \
    "$(managed_lane_registry_escape_tsv "$branch")" \
    "$(managed_lane_registry_escape_tsv "$worktree_path")" \
    "$(managed_lane_registry_escape_tsv "$state_path")" \
    "$(managed_lane_registry_escape_tsv "$pointer_path")" \
    "$(managed_lane_registry_escape_tsv "$parent_artifact_anchors")" \
    "$(managed_lane_registry_escape_tsv "$session_task_id")" \
    "$(managed_lane_registry_escape_tsv "$session_owner")" \
    "$(managed_lane_registry_escape_tsv "$routing_state")" \
    "$(managed_lane_registry_escape_tsv "$status")" \
    >> "$registry_path"
}

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
