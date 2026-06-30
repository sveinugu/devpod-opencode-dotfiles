#!/usr/bin/env bash
set -euo pipefail

managed_cleanup_tracked_patch() {
  local worktree_path="${1:?worktree_path required}"
  local unstaged_patch staged_patch

  unstaged_patch="$(git -C "$worktree_path" diff)"
  staged_patch="$(git -C "$worktree_path" diff --cached)"

  if [ -n "$unstaged_patch" ]; then
    printf '%s\n' "$unstaged_patch"
  fi

  if [ -n "$staged_patch" ]; then
    if [ -n "$unstaged_patch" ]; then
      printf '\n'
    fi
    printf '%s\n' "$staged_patch"
  fi
}

managed_cleanup_untracked_files() {
  local worktree_path="${1:?worktree_path required}"
  git -C "$worktree_path" ls-files --others --exclude-standard
}

managed_cleanup_untracked_fingerprint() {
  local worktree_path="${1:?worktree_path required}"
  local untracked_list="${2-}"
  local relpath=''
  local absolute_path=''
  local digest=''
  local size=''

  while IFS= read -r relpath; do
    [ -n "$relpath" ] || continue
    absolute_path="$worktree_path/$relpath"
    if [ ! -e "$absolute_path" ]; then
      printf '%s\tmissing\t0\n' "$relpath"
      continue
    fi

    digest="$(sha256sum "$absolute_path" | awk '{print $1}')"
    size="$(stat -c '%s' "$absolute_path")"
    printf '%s\t%s\t%s\n' "$relpath" "$digest" "$size"
  done <<< "$untracked_list" | LC_ALL=C sort
}

managed_cleanup_upstream_exists() {
  local worktree_path="${1:?worktree_path required}"
  local branch="${2:?branch required}"
  local upstream_ref="origin/$branch"

  git -C "$worktree_path" rev-parse --verify --quiet "$upstream_ref" >/dev/null
}

managed_cleanup_local_only_commits() {
  local worktree_path="${1:?worktree_path required}"
  local branch="${2:?branch required}"
  local comparison_ref="${3:?comparison_ref required}"

  git -C "$worktree_path" rev-list --no-merges "$comparison_ref..$branch"
}

managed_cleanup_commit_summary() {
  local worktree_path="${1:?worktree_path required}"
  local commit_list_file="${2:?commit_list_file required}"
  [ -s "$commit_list_file" ] || return 0
  git -C "$worktree_path" log --oneline --no-walk $(cat "$commit_list_file")
}

managed_cleanup_commit_patch() {
  local worktree_path="${1:?worktree_path required}"
  local commit_list_file="${2:?commit_list_file required}"
  [ -s "$commit_list_file" ] || return 0
  git -C "$worktree_path" show --patch --pretty=medium $(cat "$commit_list_file")
}

managed_cleanup_file_is_binary() {
  local file_path="${1:?file_path required}"
  python3 - "$file_path" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
print('1' if b'\x00' in data else '0')
PY
}

managed_cleanup_binary_file_evidence() {
  local file_path="${1:?file_path required}"
  local size
  local digest
  size="$(stat -c '%s' "$file_path")"
  digest="$(sha256sum "$file_path" | awk '{print $1}')"
  printf 'path=%s size=%s sha256=%s binary-content-would-be-lost\n' "$file_path" "$size" "$digest"
}

managed_cleanup_hash_report() {
  local report_file="${1:?report_file required}"
  sha256sum "$report_file" | awk '{print $1}'
}

managed_cleanup_render_retry_command() {
  local workspace_root="${1:?workspace_root required}"
  local command_path="${2:?command_path required}"
  local repo_identity="${3:?repo_identity required}"
  local token="${4:?token required}"
  local target="${5:?target required}"
  printf 'retry with: HUB_WORKSPACE_ROOT="%s" bash %s --repo %s --force --force-token %s %s\n' "$workspace_root" "$command_path" "$repo_identity" "$token" "$target"
}

managed_cleanup_collect_tracked_risk() {
  local worktree_path="${1:?worktree_path required}"
  local tracked_patch_var_name="${2:?tracked_patch var name required}"
  local tracked_patch_value=''

  tracked_patch_value="$(managed_cleanup_tracked_patch "$worktree_path")"
  printf -v "$tracked_patch_var_name" '%s' "$tracked_patch_value"

  if [ -z "$tracked_patch_value" ]; then
    return 1
  fi

  printf 'loss check: tracked modifications would be lost\n'
  printf 'loss evidence (tracked patch):\n'
  printf '%s\n' "$tracked_patch_value"
  return 0
}

managed_cleanup_collect_untracked_risk() {
  local worktree_path="${1:?worktree_path required}"
  local untracked_list_var_name="${2:?untracked_list var name required}"
  local untracked_list_value=''
  local relpath=''
  local absolute_path=''

  untracked_list_value="$(managed_cleanup_untracked_files "$worktree_path")"
  printf -v "$untracked_list_var_name" '%s' "$untracked_list_value"

  if [ -z "$untracked_list_value" ]; then
    return 1
  fi

  printf 'loss check: untracked files would be lost\n'
  while IFS= read -r relpath; do
    [ -n "$relpath" ] || continue
    absolute_path="$worktree_path/$relpath"
    if [ ! -e "$absolute_path" ]; then
      continue
    fi
    if [ "$(managed_cleanup_file_is_binary "$absolute_path")" = '1' ]; then
      printf 'loss evidence (binary): %s\n' "$relpath"
      managed_cleanup_binary_file_evidence "$absolute_path"
    else
      printf 'loss evidence (untracked text): %s\n' "$relpath"
      cat "$absolute_path"
    fi
  done <<< "$untracked_list_value"

  return 0
}

managed_cleanup_collect_commit_divergence_risk() {
  local worktree_path="${1:?worktree_path required}"
  local branch="${2:?branch required}"
  local default_branch="${3:?default_branch required}"
  local commit_ids_file="${4:?commit_ids_file required}"
  local comparison_ref_var_name="${5:?comparison_ref var name required}"
  local upstream_available_var_name="${6:?upstream_available var name required}"
  local comparison_ref_value=''
  local upstream_available_value='no'
  local risk_found='no'

  if managed_cleanup_upstream_exists "$worktree_path" "$branch"; then
    upstream_available_value='yes'
    comparison_ref_value="origin/$branch"
  elif git -C "$worktree_path" rev-parse --verify --quiet "refs/heads/$default_branch" >/dev/null; then
    comparison_ref_value="$default_branch"
  fi

  if [ "$upstream_available_value" != 'yes' ]; then
    risk_found='yes'
    printf 'loss check: unable to prove upstream safety\n'
  fi

  if [ -n "$comparison_ref_value" ]; then
    managed_cleanup_local_only_commits "$worktree_path" "$branch" "$comparison_ref_value" > "$commit_ids_file"
    if [ -s "$commit_ids_file" ]; then
      risk_found='yes'
      printf 'loss check: local-only commits would become unreachable\n'
      printf 'loss evidence (local-only commits):\n'
      managed_cleanup_commit_summary "$worktree_path" "$commit_ids_file"
      managed_cleanup_commit_patch "$worktree_path" "$commit_ids_file"
    fi
  fi

  printf -v "$comparison_ref_var_name" '%s' "$comparison_ref_value"
  printf -v "$upstream_available_var_name" '%s' "$upstream_available_value"

  [ "$risk_found" = 'yes' ]
}

managed_cleanup_render_risk_report() {
  local workspace_root="${1:?workspace_root required}"
  local report_file="${2:?report_file required}"
  local command_path="${3:?command_path required}"
  local repo_identity="${4:?repo_identity required}"
  local lane_id="${5:?lane_id required}"
  local branch="${6:?branch required}"
  local worktree_path="${7:?worktree_path required}"
  local tracked_patch="${8-}"
  local untracked_list="${9-}"
  local commit_ids_file="${10:?commit_ids_file required}"
  local target="${11:?target required}"
  local current_token_var_name="${12:?current_token var name required}"
  local untracked_fingerprint_value=''
  local current_token_value=''

  untracked_fingerprint_value="$(managed_cleanup_untracked_fingerprint "$worktree_path" "$untracked_list")"

  {
    printf 'repo=%s\n' "$repo_identity"
    printf 'lane=%s\n' "$lane_id"
    printf 'branch=%s\n' "$branch"
    printf 'worktree=%s\n' "$worktree_path"
    printf 'tracked_patch=%s\n' "$tracked_patch"
    printf 'untracked_list=%s\n' "$untracked_list"
    printf 'untracked_fingerprint=%s\n' "$untracked_fingerprint_value"
    if [ -s "$commit_ids_file" ]; then
      printf 'local_only_commits=%s\n' "$(cat "$commit_ids_file")"
    else
      printf 'local_only_commits=\n'
    fi
  } > "$report_file"

  current_token_value="$(managed_cleanup_hash_report "$report_file")"
  printf -v "$current_token_var_name" '%s' "$current_token_value"

  printf 'force-token: %s\n' "$current_token_value"
  managed_cleanup_render_retry_command "$workspace_root" "$command_path" "$repo_identity" "$current_token_value" "$target"
}

managed_cleanup_collect_risk_report() {
  local workspace_root="${1:?workspace_root required}"
  local command_path="${2:?command_path required}"
  local repo_identity="${3:?repo_identity required}"
  local lane_id="${4:?lane_id required}"
  local branch="${5:?branch required}"
  local worktree_path="${6:?worktree_path required}"
  local default_branch="${7:?default_branch required}"
  local target="${8:?target required}"
  local force_mode="${9:?force_mode required}"
  local force_token="${10:-}"

  local risk_found='no'
  local risk_tracked_patch=''
  local risk_untracked_list=''
  local comparison_ref=''
  local upstream_available='no'
  local current_token=''
  local report_file=''
  local commit_ids_file=''

  report_file="$(mktemp)"
  commit_ids_file="$(mktemp)"

  if managed_cleanup_collect_tracked_risk "$worktree_path" risk_tracked_patch; then
    risk_found='yes'
  fi

  if managed_cleanup_collect_untracked_risk "$worktree_path" risk_untracked_list; then
    risk_found='yes'
  fi

  if managed_cleanup_collect_commit_divergence_risk \
    "$worktree_path" \
    "$branch" \
    "$default_branch" \
    "$commit_ids_file" \
    comparison_ref \
    upstream_available; then
    risk_found='yes'
  fi

  if [ "$risk_found" = 'yes' ]; then
    managed_cleanup_render_risk_report \
      "$workspace_root" \
      "$report_file" \
      "$command_path" \
      "$repo_identity" \
      "$lane_id" \
      "$branch" \
      "$worktree_path" \
      "$risk_tracked_patch" \
      "$risk_untracked_list" \
      "$commit_ids_file" \
      "$target" \
      current_token

    if [ "$force_mode" != 'yes' ]; then
      rm -f "$report_file" "$commit_ids_file"
      return 1
    fi

    if [ "$force_token" != "$current_token" ]; then
      rm -f "$report_file" "$commit_ids_file"
      printf 'refused: stale force-token for current risk report\n' >&2
      return 1
    fi
  fi

  rm -f "$report_file" "$commit_ids_file"
}
