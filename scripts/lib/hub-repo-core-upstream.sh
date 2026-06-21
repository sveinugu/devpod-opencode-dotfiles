#!/usr/bin/env bash

hub_set_branch_upstream() {
  local bare_dir="$1"
  local local_branch="$2"
  local remote_name="${3:-origin}"
  local remote_branch="${4:-$local_branch}"

  git --git-dir="$bare_dir" config "branch.$local_branch.remote" "$remote_name"
  git --git-dir="$bare_dir" config "branch.$local_branch.merge" "refs/heads/$remote_branch"
}

hub_ensure_bare_excludes() {
  local bare_dir="$1"
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  local helper="$script_dir/ensure-bare-excludes.sh"

  if [ ! -f "$helper" ]; then
    hub_fail 'refused: missing bare exclude helper'
    return 1
  fi

  if ! bash "$helper" "$bare_dir"; then
    hub_fail 'refused: unable to configure bare exclude patterns'
    return 1
  fi
}
