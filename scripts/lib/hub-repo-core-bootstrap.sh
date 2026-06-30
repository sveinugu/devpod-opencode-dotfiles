#!/usr/bin/env bash

hub_is_valid_worktree() {
  local workspace_root="$1"
  local branch="$2"
  local branch_name=''

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
  local branch="${3:-$HUB_BOOTSTRAP_BRANCH}"
  local allow_default_branch_fallback="${4:-no}"
  local verbose="${5:-no}"
  local requested_branch="$branch"
  local resolved_branch="$branch"
  local detected_branch=''
  local branch_check_rc=0
  local created_bare_repo='no'
  local hub_workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"

  if hub_source_has_branch "$source" "$branch"; then
    branch_check_rc=0
  else
    branch_check_rc="$?"
    if [ "$allow_default_branch_fallback" = "yes" ] && [ "$branch_check_rc" = "10" ] && [ "$branch" = "$HUB_BOOTSTRAP_BRANCH" ]; then
      detected_branch="$(hub_source_default_branch "$source" 2>/dev/null || true)"
      if [ -n "$detected_branch" ]; then
        branch="$detected_branch"
        resolved_branch="$branch"
        if hub_source_has_branch "$source" "$branch"; then
          branch_check_rc=0
        else
          branch_check_rc="$?"
        fi
      fi
    fi
  fi
  case "$branch_check_rc" in
    0)
      ;;
    10)
      hub_fail "refused: origin/$requested_branch is required for bootstrap"
      return
      ;;
    *)
      hub_fail 'refused: unable to access source repo non-interactively (verify public HTTPS URL and repository visibility)'
      return
      ;;
  esac

  mkdir -p "$workspace_root"

  hub_remove_empty_non_git_main_dir "$workspace_root"

  if [ -e "$workspace_root/main" ] && [ ! -d "$workspace_root/.bare" ]; then
    hub_fail 'refused: existing main path is detached or invalid'
    return
  fi

  if [ ! -d "$workspace_root/.bare" ]; then
    if [ "$verbose" = "yes" ]; then
      if ! hub_git_non_interactive clone --bare --progress "$source" "$workspace_root/.bare" >/dev/null; then
        hub_fail 'refused: unable to access source repo non-interactively (verify public HTTPS URL and repository visibility)'
        return
      fi
    elif ! hub_git_non_interactive clone --bare "$source" "$workspace_root/.bare" >/dev/null 2>&1; then
      hub_fail 'refused: unable to access source repo non-interactively (verify public HTTPS URL and repository visibility)'
      return
    fi
    created_bare_repo='yes'
  fi

  if ! git --git-dir="$workspace_root/.bare" rev-parse --is-bare-repository >/dev/null 2>&1; then
    hub_fail 'refused: existing .bare path is invalid'
    return
  fi

  if [ "$created_bare_repo" = 'yes' ]; then
    if ! hub_ensure_bare_excludes "$workspace_root/.bare"; then
      return
    fi
  elif [ "$workspace_root" = "$hub_workspace_root" ]; then
    if ! hub_ensure_bare_excludes "$workspace_root/.bare"; then
      return
    fi
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

  hub_set_branch_upstream "$workspace_root/.bare" "$branch"

  HUB_REPO_RESOLVED_BRANCH="$resolved_branch"
}
