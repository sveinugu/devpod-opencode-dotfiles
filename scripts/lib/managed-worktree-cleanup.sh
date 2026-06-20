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
