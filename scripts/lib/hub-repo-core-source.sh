#!/usr/bin/env bash

hub_git_non_interactive() {
  GIT_TERMINAL_PROMPT=0 \
  GIT_ASKPASS=/bin/false \
  SSH_ASKPASS=/bin/false \
  git "$@"
}

hub_is_non_interactive_access_failure() {
  local output="$1"

  printf '%s' "$output" | grep -Eqi \
    'could not read username|terminal prompts disabled|authentication failed|repository not found|access denied|permission denied|could not resolve host|unable to access'
}

hub_source_default_branch() {
  local source="$1"
  local output=''
  local branch_name=''
  local rc=0

  if [ -d "$source/.git" ] || [ -d "$source/objects" ]; then
    branch_name="$(git -C "$source" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    branch_name="${branch_name#origin/}"
    if [ -z "$branch_name" ]; then
      branch_name="$(git -C "$source" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    fi
    if [ -n "$branch_name" ]; then
      printf '%s\n' "$branch_name"
      return 0
    fi
    return 1
  fi

  if output="$(hub_git_non_interactive ls-remote --symref "$source" HEAD 2>&1)"; then
    branch_name="$(printf '%s\n' "$output" | awk '/^ref:/ { print $2 }' | sed -n 's#refs/heads/##p' | head -n1)"
    if [ -n "$branch_name" ]; then
      printf '%s\n' "$branch_name"
      return 0
    fi
  else
    rc=$?
    if [ "$rc" != "0" ] && hub_is_non_interactive_access_failure "$output"; then
      return 20
    fi
  fi

  return 1
}

hub_source_has_branch() {
  local source="$1"
  local branch="$2"
  local output=''
  local rc=0

  if [ -d "$source/.git" ] || [ -d "$source/objects" ]; then
    if git -C "$source" show-ref --verify --quiet "refs/heads/$branch"; then
      return 0
    fi

    return 10
  fi

  if output="$(hub_git_non_interactive ls-remote --exit-code --heads "$source" "$branch" 2>&1)"; then
    return 0
  else
    rc=$?
  fi

  if [ "$rc" = "2" ]; then
    return 10
  fi

  if hub_is_non_interactive_access_failure "$output"; then
    return 20
  fi

  return 20
}
