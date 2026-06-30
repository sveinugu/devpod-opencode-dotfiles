#!/usr/bin/env bash
set -euo pipefail

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

managed_cleanup_execute_retirement() {
  local bare_dir="${1:?bare_dir required}"
  local worktree_path="${2:?worktree_path required}"
  local branch="${3:?branch required}"
  local registry_path="${4:?registry_path required}"
  local pointer_path="${5:?pointer_path required}"

  managed_cleanup_remove_worktree_and_branch "$bare_dir" "$worktree_path" "$branch"
  managed_cleanup_mark_registry_retired "$registry_path" "$pointer_path"
}
