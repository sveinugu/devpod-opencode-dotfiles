#!/usr/bin/env bash
set -euo pipefail

managed_cleanup_repo_root_for_identity() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  if [ "$repo_identity" = "hub" ]; then
    printf '%s\n' "$workspace_root"
    return 0
  fi
  printf '%s\n' "$workspace_root/repos/$repo_identity"
}

managed_cleanup_bare_dir_for_identity() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local repo_root
  repo_root="$(managed_cleanup_repo_root_for_identity "$workspace_root" "$repo_identity")"
  printf '%s\n' "$repo_root/.bare"
}

managed_cleanup_default_branch_for_identity() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"

  if [ "$repo_identity" = "hub" ]; then
    printf 'main\n'
    return 0
  fi

  local repo_env="$workspace_root/state/repos/$repo_identity/etc/repo.env"
  if [ ! -f "$repo_env" ]; then
    return 1
  fi

  # shellcheck disable=SC1090
  . "$repo_env"
  local default_branch="${DYN_REPO_DEFAULT_BRANCH:-}"
  if [ -z "$default_branch" ]; then
    return 1
  fi

  printf '%s\n' "$default_branch"
}

managed_cleanup_registry_path() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"

  if [ "$repo_identity" = "hub" ]; then
    printf '%s\n' "$workspace_root/state/hub/lanes/registry.tsv"
    return 0
  fi

  printf '%s\n' "$workspace_root/state/repos/$repo_identity/lanes/registry.tsv"
}

managed_cleanup_load_candidates() {
  local registry_path="${1:?registry_path required}"
  local target="${2:?target required}"
  local output_file="${3:?output_file required}"

  : > "$output_file"
  [ -f "$registry_path" ] || return 0

  awk -F '\t' -v target="$target" '
    NR == 1 { next }
    $11 == "active" && ($1 == target || $3 == target) { print }
  ' "$registry_path" > "$output_file"
}

managed_cleanup_count_lines() {
  local file_path="${1:?file_path required}"
  if [ ! -s "$file_path" ]; then
    printf '0\n'
    return 0
  fi
  wc -l < "$file_path" | tr -d ' '
}

managed_cleanup_read_record_field() {
  local record="${1:?record required}"
  local field_index="${2:?field index required}"
  printf '%s\n' "$record" | awk -F '\t' -v idx="$field_index" '{ print $idx }'
}

managed_cleanup_branch_attached_path() {
  local bare_dir="${1:?bare_dir required}"
  local branch="${2:?branch required}"

  git --git-dir="$bare_dir" worktree list --porcelain | awk -v branch="refs/heads/$branch" '
    BEGIN { current_path = "" }
    /^worktree / { current_path = substr($0, 10); next }
    /^branch / {
      if ($2 == branch) {
        print current_path
        exit
      }
    }
  '
}

managed_cleanup_is_canonical_worktree_path() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local worktree_path="${3:?worktree_path required}"
  local workspace_root_canon worktree_path_canon

  workspace_root_canon="$(readlink -f "$workspace_root" 2>/dev/null || true)"
  worktree_path_canon="$(readlink -f "$worktree_path" 2>/dev/null || true)"

  if [ -z "$workspace_root_canon" ] || [ -z "$worktree_path_canon" ]; then
    return 1
  fi

  if [ "$repo_identity" = "hub" ]; then
    case "$worktree_path_canon" in
      "$workspace_root_canon/work/"*)
        return 0
        ;;
    esac
    return 1
  fi

  case "$worktree_path_canon" in
    "$workspace_root_canon/repos/$repo_identity/work/"*)
      return 0
      ;;
  esac

  return 1
}

managed_cleanup_resolve_single_target_record_into() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local target="${3:?target required}"
  local output_prefix="${4:?output_prefix required}"

  local registry_path
  local bare_dir
  local default_branch=''
  local candidates_file=''
  local candidate_count='0'
  local record=''
  local lane_id=''
  local record_repo_identity=''
  local branch=''
  local worktree_path=''
  local state_path=''
  local pointer_path=''
  local attached_path=''

  registry_path="$(managed_cleanup_registry_path "$workspace_root" "$repo_identity")"
  bare_dir="$(managed_cleanup_bare_dir_for_identity "$workspace_root" "$repo_identity")"

  if [ ! -f "$registry_path" ] || [ ! -d "$bare_dir" ]; then
    printf 'refused: target does not resolve to a managed active lane binding\n' >&2
    return 1
  fi

  if ! default_branch="$(managed_cleanup_default_branch_for_identity "$workspace_root" "$repo_identity")"; then
    printf 'refused: managed child default branch metadata is missing or invalid\n' >&2
    return 1
  fi

  if [ "$target" = "$default_branch" ]; then
    printf 'refused: target resolves to default checkout and cannot be retired\n' >&2
    return 1
  fi

  candidates_file="$(mktemp)"
  managed_cleanup_load_candidates "$registry_path" "$target" "$candidates_file"
  candidate_count="$(managed_cleanup_count_lines "$candidates_file")"

  if [ "$candidate_count" = '0' ]; then
    rm -f "$candidates_file"
    printf 'refused: target does not resolve to a managed active lane binding\n' >&2
    return 1
  fi

  if [ "$candidate_count" != '1' ]; then
    rm -f "$candidates_file"
    printf 'refused: target is ambiguous across multiple active lane bindings\n' >&2
    return 1
  fi

  record="$(cat "$candidates_file")"
  rm -f "$candidates_file"

  lane_id="$(managed_cleanup_read_record_field "$record" 1)"
  record_repo_identity="$(managed_cleanup_read_record_field "$record" 2)"
  branch="$(managed_cleanup_read_record_field "$record" 3)"
  worktree_path="$(managed_cleanup_read_record_field "$record" 4)"
  state_path="$(managed_cleanup_read_record_field "$record" 5)"
  pointer_path="$(managed_cleanup_read_record_field "$record" 6)"

  if [ "$record_repo_identity" != "$repo_identity" ]; then
    printf 'refused: target does not resolve to a managed active lane binding\n' >&2
    return 1
  fi

  if [ "$branch" = "$default_branch" ]; then
    printf 'refused: target resolves to default checkout and cannot be retired\n' >&2
    return 1
  fi

  if ! managed_cleanup_is_canonical_worktree_path "$workspace_root" "$repo_identity" "$worktree_path"; then
    printf 'refused: target worktree path is outside managed canonical layout\n' >&2
    return 1
  fi

  attached_path="$(managed_cleanup_branch_attached_path "$bare_dir" "$branch")"
  if [ -z "$attached_path" ] || [ "$attached_path" != "$worktree_path" ]; then
    printf 'refused: branch/worktree attachment mismatch for managed target\n' >&2
    return 1
  fi

  printf -v "${output_prefix}registry_path" '%s' "$registry_path"
  printf -v "${output_prefix}bare_dir" '%s' "$bare_dir"
  printf -v "${output_prefix}default_branch" '%s' "$default_branch"
  printf -v "${output_prefix}lane_id" '%s' "$lane_id"
  printf -v "${output_prefix}record_repo_identity" '%s' "$record_repo_identity"
  printf -v "${output_prefix}branch" '%s' "$branch"
  printf -v "${output_prefix}worktree_path" '%s' "$worktree_path"
  printf -v "${output_prefix}state_path" '%s' "$state_path"
  printf -v "${output_prefix}pointer_path" '%s' "$pointer_path"
}

managed_cleanup_resolve_single_target_record() {
  managed_cleanup_resolve_single_target_record_into "$1" "$2" "$3" 'managed_cleanup_resolve_'
}
