#!/usr/bin/env bash

# Default to main for v1; can be overridden via env for dev/testing
HUB_PROVISION_BRANCH="${HUB_PROVISION_BRANCH:-main}"

hub_fail() {
  printf '%s\n' "$1" >&2
  return 1
}

hub_source_has_branch() {
  local source="$1"
  local branch="$2"

  if [ -d "$source/.git" ] || [ -d "$source/objects" ]; then
    git -C "$source" show-ref --verify --quiet "refs/heads/$branch"
    return
  fi

  git ls-remote --exit-code --heads "$source" "$branch" >/dev/null 2>&1
}

hub_is_valid_worktree() {
  local workspace_root="$1"
  local branch="$2"

  branch_name="$(git -C "$workspace_root/main" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  [ "$branch_name" = "$branch" ] || return 1

  git --git-dir="$workspace_root/.bare" worktree list --porcelain | grep -F "worktree $workspace_root/main" >/dev/null 2>&1
}

hub_remove_empty_non_git_main_dir() {
  local workspace_root="$1"
  local main_path="$workspace_root/main"

  [ -d "$main_path" ] || return 0

  if [ -e "$main_path/.git" ]; then
    return 0
  fi

  rmdir "$main_path" >/dev/null 2>&1 || true
}

create_bare_hub() {
  local workspace_root="$1"
  local source="$2"
  local branch="${3:-$HUB_PROVISION_BRANCH}"

  if ! hub_source_has_branch "$source" "$branch"; then
    hub_fail "refused: origin/$branch is required for bootstrap"
    return
  fi

  mkdir -p "$workspace_root"

  hub_remove_empty_non_git_main_dir "$workspace_root"

  if [ -e "$workspace_root/main" ] && [ ! -d "$workspace_root/.bare" ]; then
    hub_fail 'refused: existing main path is detached or invalid'
    return
  fi

  if [ ! -d "$workspace_root/.bare" ]; then
    git clone --bare "$source" "$workspace_root/.bare" >/dev/null
  fi

  if ! git --git-dir="$workspace_root/.bare" rev-parse --is-bare-repository >/dev/null 2>&1; then
    hub_fail 'refused: existing .bare path is invalid'
    return
  fi

  # Set location of bare clone for top-level dir
  printf 'gitdir: ./.bare\n' > "$workspace_root/.git"

  # Fix "git fetch" for all worktrees
  git --git-dir="$workspace_root/.bare" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  mkdir -p \
    "$workspace_root/work" \
    "$workspace_root/repos" \
    "$workspace_root/state" \
    "$workspace_root/tmp"

  if git --git-dir="$workspace_root/.bare" worktree list --porcelain | grep -F "worktree $workspace_root/main" >/dev/null 2>&1; then
    if ! hub_is_valid_worktree "$workspace_root" "$branch"; then
      hub_fail 'refused: existing main path is detached or invalid'
      return
    fi
  else
    hub_remove_empty_non_git_main_dir "$workspace_root"

    if [ -e "$workspace_root/main" ]; then
      hub_fail 'refused: existing main path is detached or invalid'
      return
    fi

    if ! git --git-dir="$workspace_root/.bare" show-ref --verify --quiet "refs/heads/$branch"; then
      hub_fail "refused: origin/$branch is required for bootstrap"
      return
    fi

    git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" "$branch" >/dev/null
  fi

  mkdir -p "$workspace_root/state/hub/main" "$workspace_root/tmp/hub/main"
}
