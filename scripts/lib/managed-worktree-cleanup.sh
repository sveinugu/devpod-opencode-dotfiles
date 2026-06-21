#!/usr/bin/env bash
set -euo pipefail

managed_cleanup_fail() {
  printf '%s\n' "$1" >&2
}

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
  local command_path="${1:?command_path required}"
  local repo_identity="${2:?repo_identity required}"
  local token="${3:?token required}"
  local target="${4:?target required}"
  printf 'retry with: HUB_WORKSPACE_ROOT="%s" bash %s --repo %s --force --force-token %s %s\n' "${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}" "$command_path" "$repo_identity" "$token" "$target"
}

managed_cleanup_remove_worktree_and_branch() {
  local bare_dir="${1:?bare_dir required}"
  local worktree_path="${2:?worktree_path required}"
  local branch="${3:?branch required}"

  git --git-dir="$bare_dir" worktree remove --force "$worktree_path" >/dev/null
  git --git-dir="$bare_dir" branch -D "$branch" >/dev/null
}

managed_cleanup_mark_registry_retired() {
  local registry_path="${1:?registry_path required}"
  local pointer_path="${2:?pointer_path required}"
  local tmp_file
  tmp_file="${registry_path}.tmp.$$"

  awk -F '\t' -v OFS='\t' -v pointer="$pointer_path" '
    NR == 1 { print; next }
    {
      if ($6 == pointer) {
        $11 = "retired"
      }
      print
    }
  ' "$registry_path" > "$tmp_file"

  mv "$tmp_file" "$registry_path"
}

managed_cleanup_resolve_single_target_record() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local target="${3:?target required}"

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

  managed_cleanup_resolved_registry_path="$registry_path"
  managed_cleanup_resolved_bare_dir="$bare_dir"
  managed_cleanup_resolved_default_branch="$default_branch"
  managed_cleanup_resolved_lane_id="$lane_id"
  managed_cleanup_resolved_record_repo_identity="$record_repo_identity"
  managed_cleanup_resolved_branch="$branch"
  managed_cleanup_resolved_worktree_path="$worktree_path"
  managed_cleanup_resolved_state_path="$state_path"
  managed_cleanup_resolved_pointer_path="$pointer_path"
}

managed_cleanup_collect_risk_report() {
  local command_path="${1:?command_path required}"
  local repo_identity="${2:?repo_identity required}"
  local lane_id="${3:?lane_id required}"
  local branch="${4:?branch required}"
  local worktree_path="${5:?worktree_path required}"
  local default_branch="${6:?default_branch required}"
  local target="${7:?target required}"
  local force_mode="${8:?force_mode required}"
  local force_token="${9:-}"

  local risk_found='no'
  local tracked_patch=''
  local untracked_list=''
  local comparison_ref=''
  local upstream_available='no'
  local untracked_fingerprint=''
  local current_token=''
  local report_file=''
  local commit_ids_file=''

  report_file="$(mktemp)"
  commit_ids_file="$(mktemp)"

  tracked_patch="$(managed_cleanup_tracked_patch "$worktree_path")"
  if [ -n "$tracked_patch" ]; then
    risk_found='yes'
    printf 'loss check: tracked modifications would be lost\n'
    printf 'loss evidence (tracked patch):\n'
    printf '%s\n' "$tracked_patch"
  fi

  untracked_list="$(managed_cleanup_untracked_files "$worktree_path")"
  if [ -n "$untracked_list" ]; then
    risk_found='yes'
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
    done <<< "$untracked_list"
  fi

  if managed_cleanup_upstream_exists "$worktree_path" "$branch"; then
    upstream_available='yes'
    comparison_ref="origin/$branch"
  elif git -C "$worktree_path" rev-parse --verify --quiet "refs/heads/$default_branch" >/dev/null; then
    comparison_ref="$default_branch"
  fi

  if [ "$upstream_available" != 'yes' ]; then
    risk_found='yes'
    printf 'loss check: unable to prove upstream safety\n'
  fi

  if [ -n "$comparison_ref" ]; then
    managed_cleanup_local_only_commits "$worktree_path" "$branch" "$comparison_ref" > "$commit_ids_file"
    if [ -s "$commit_ids_file" ]; then
      risk_found='yes'
      printf 'loss check: local-only commits would become unreachable\n'
      printf 'loss evidence (local-only commits):\n'
      managed_cleanup_commit_summary "$worktree_path" "$commit_ids_file"
      managed_cleanup_commit_patch "$worktree_path" "$commit_ids_file"
    fi
  fi

  if [ "$risk_found" = 'yes' ]; then
    untracked_fingerprint="$(managed_cleanup_untracked_fingerprint "$worktree_path" "$untracked_list")"

    {
      printf 'repo=%s\n' "$repo_identity"
      printf 'lane=%s\n' "$lane_id"
      printf 'branch=%s\n' "$branch"
      printf 'worktree=%s\n' "$worktree_path"
      printf 'tracked_patch=%s\n' "$tracked_patch"
      printf 'untracked_list=%s\n' "$untracked_list"
      printf 'untracked_fingerprint=%s\n' "$untracked_fingerprint"
      if [ -s "$commit_ids_file" ]; then
        printf 'local_only_commits=%s\n' "$(cat "$commit_ids_file")"
      else
        printf 'local_only_commits=\n'
      fi
    } > "$report_file"

    current_token="$(managed_cleanup_hash_report "$report_file")"
    printf 'force-token: %s\n' "$current_token"
    managed_cleanup_render_retry_command "$command_path" "$repo_identity" "$current_token" "$target"

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

managed_cleanup_execute_retirement() {
  local bare_dir="${1:?bare_dir required}"
  local worktree_path="${2:?worktree_path required}"
  local branch="${3:?branch required}"
  local registry_path="${4:?registry_path required}"
  local pointer_path="${5:?pointer_path required}"

  managed_cleanup_remove_worktree_and_branch "$bare_dir" "$worktree_path" "$branch"
  managed_cleanup_mark_registry_retired "$registry_path" "$pointer_path"
}
