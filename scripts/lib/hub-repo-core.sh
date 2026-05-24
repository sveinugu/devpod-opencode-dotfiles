#!/usr/bin/env bash

hub_fail() {
  printf '%s\n' "$1" >&2
  return 1
}

hub_source_has_main() {
  local source="$1"

  if [ -d "$source/.git" ] || [ -d "$source/objects" ]; then
    git -C "$source" show-ref --verify --quiet refs/heads/main
    return
  fi

  git ls-remote --exit-code --heads "$source" main >/dev/null 2>&1
}

hub_is_valid_main_worktree() {
  local workspace_root="$1"
  local branch

  branch="$(git -C "$workspace_root/main" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  [ "$branch" = "main" ] || return 1

  git --git-dir="$workspace_root/.bare" worktree list --porcelain | grep -F "worktree $workspace_root/main" >/dev/null 2>&1
}

create_bare_hub() {
  local workspace_root="$1"
  local source="$2"

  if ! hub_source_has_main "$source"; then
    hub_fail 'refused: origin/main is required for bootstrap'
    return
  fi

  mkdir -p "$workspace_root"

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

  printf 'gitdir: ./.bare\n' > "$workspace_root/.git"

  mkdir -p \
    "$workspace_root/work" \
    "$workspace_root/repos" \
    "$workspace_root/state" \
    "$workspace_root/tmp"

  if git --git-dir="$workspace_root/.bare" worktree list --porcelain | grep -F "worktree $workspace_root/main" >/dev/null 2>&1; then
    if ! hub_is_valid_main_worktree "$workspace_root"; then
      hub_fail 'refused: existing main path is detached or invalid'
      return
    fi
  else
    if [ -e "$workspace_root/main" ]; then
      hub_fail 'refused: existing main path is detached or invalid'
      return
    fi

    if ! git --git-dir="$workspace_root/.bare" show-ref --verify --quiet refs/heads/main; then
      hub_fail 'refused: origin/main is required for bootstrap'
      return
    fi

    git --git-dir="$workspace_root/.bare" worktree add "$workspace_root/main" main >/dev/null
  fi

  mkdir -p "$workspace_root/state/hub/main" "$workspace_root/tmp/hub/main"
}
