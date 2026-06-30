#!/usr/bin/env bash
set -euo pipefail

retire_worktree_usage() {
  printf 'usage: retire-worktree [--repo <hub|repo-name>] [--dry-run] [--force --force-token <token>] <lane-id|branch>\n' >&2
}

retire_worktree_require_non_empty() {
  local function_name="$1"
  local arg_name="$2"
  local arg_value="$3"

  if [ -n "$arg_value" ]; then
    return 0
  fi

  printf 'refused: %s requires non-empty %s\n' "$function_name" "$arg_name" >&2
  exit 1
}

retire_worktree_parse_cli() {
  retire_worktree_repo_identity='hub'
  retire_worktree_dry_run='no'
  retire_worktree_force_mode='no'
  retire_worktree_force_token=''
  retire_worktree_target=''

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo)
        shift
        [ "$#" -gt 0 ] || { retire_worktree_usage; exit 2; }
        retire_worktree_repo_identity="$1"
        ;;
      --dry-run)
        retire_worktree_dry_run='yes'
        ;;
      --force)
        retire_worktree_force_mode='yes'
        ;;
      --force-token)
        shift
        [ "$#" -gt 0 ] || { retire_worktree_usage; exit 2; }
        retire_worktree_force_token="$1"
        ;;
      --help|-h)
        retire_worktree_usage
        exit 0
        ;;
      *)
        if [ -n "$retire_worktree_target" ]; then
          retire_worktree_usage
          exit 2
        fi
        retire_worktree_target="$1"
        ;;
    esac
    shift
  done

  if [ -z "$retire_worktree_target" ]; then
    retire_worktree_usage
    exit 2
  fi

  if [ "$retire_worktree_force_mode" = 'yes' ] && [ -z "$retire_worktree_force_token" ]; then
    printf 'refused: --force requires --force-token\n' >&2
    exit 1
  fi
}

retire_worktree_resolve_target_record() {
  local workspace_root="$1"

  retire_worktree_require_non_empty 'retire_worktree_resolve_target_record' 'workspace_root' "$workspace_root"
  retire_worktree_require_non_empty 'retire_worktree_resolve_target_record' 'retire_worktree_repo_identity' "${retire_worktree_repo_identity:-}"
  retire_worktree_require_non_empty 'retire_worktree_resolve_target_record' 'retire_worktree_target' "${retire_worktree_target:-}"

  managed_cleanup_resolve_single_target_record \
    "$workspace_root" \
    "$retire_worktree_repo_identity" \
    "$retire_worktree_target"

  retire_worktree_registry_path="$managed_cleanup_resolved_registry_path"
  retire_worktree_bare_dir="$managed_cleanup_resolved_bare_dir"
  retire_worktree_default_branch="$managed_cleanup_resolved_default_branch"
  retire_worktree_lane_id="$managed_cleanup_resolved_lane_id"
  retire_worktree_branch="$managed_cleanup_resolved_branch"
  retire_worktree_worktree_path="$managed_cleanup_resolved_worktree_path"
  retire_worktree_pointer_path="$managed_cleanup_resolved_pointer_path"
}

retire_worktree_print_target_summary() {
  printf 'repo: %s\n' "$retire_worktree_repo_identity"
  printf 'lane: %s\n' "$retire_worktree_lane_id"
  printf 'branch: %s\n' "$retire_worktree_branch"
  printf 'worktree: %s\n' "$retire_worktree_worktree_path"
}

retire_worktree_assess_risk_and_maybe_refuse() {
  local workspace_root="$1"

  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'workspace_root' "$workspace_root"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_repo_identity' "${retire_worktree_repo_identity:-}"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_lane_id' "${retire_worktree_lane_id:-}"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_branch' "${retire_worktree_branch:-}"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_worktree_path' "${retire_worktree_worktree_path:-}"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_default_branch' "${retire_worktree_default_branch:-}"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_target' "${retire_worktree_target:-}"
  retire_worktree_require_non_empty 'retire_worktree_assess_risk_and_maybe_refuse' 'retire_worktree_force_mode' "${retire_worktree_force_mode:-}"

  managed_cleanup_collect_risk_report \
    "$workspace_root" \
    "$workspace_root/bin/retire-worktree" \
    "$retire_worktree_repo_identity" \
    "$retire_worktree_lane_id" \
    "$retire_worktree_branch" \
    "$retire_worktree_worktree_path" \
    "$retire_worktree_default_branch" \
    "$retire_worktree_target" \
    "$retire_worktree_force_mode" \
    "$retire_worktree_force_token"
}

retire_worktree_execute() {
  retire_worktree_require_non_empty 'retire_worktree_execute' 'retire_worktree_dry_run' "${retire_worktree_dry_run:-}"

  if [ "$retire_worktree_dry_run" = 'yes' ]; then
    printf 'ok: dry-run only, no cleanup performed\n'
    exit 0
  fi

  managed_cleanup_execute_retirement \
    "$retire_worktree_bare_dir" \
    "$retire_worktree_worktree_path" \
    "$retire_worktree_branch" \
    "$retire_worktree_registry_path" \
    "$retire_worktree_pointer_path"

  printf 'ok: retired managed lane %s\n' "$retire_worktree_lane_id"
}
