#!/usr/bin/env bash

_MLR_PATH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_MLR_PATH_SCRIPT_DIR/managed-lane-registry-common.sh"

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
