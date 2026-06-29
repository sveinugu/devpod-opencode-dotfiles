#!/usr/bin/env bash

_MLR_MUTATIONS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_MLR_MUTATIONS_SCRIPT_DIR/managed-lane-registry-common.sh"

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
