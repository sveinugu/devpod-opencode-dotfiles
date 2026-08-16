#!/usr/bin/env bash
set -euo pipefail

context_materialize_bare_repo_from_local() {
  local source_repo="$1"
  local bare_repo="$2"

  if [ -d "$source_repo/.git" ]; then
    cp -R "$source_repo/.git" "$bare_repo"
  elif [ -d "$source_repo/objects" ]; then
    cp -R "$source_repo" "$bare_repo"
  else
    printf 'refused: source repo is not a local git checkout: %s\n' "$source_repo" >&2
    return 1
  fi

  git --git-dir="$bare_repo" config core.bare true
  git --git-dir="$bare_repo" config --unset core.worktree >/dev/null 2>&1 || true
}
