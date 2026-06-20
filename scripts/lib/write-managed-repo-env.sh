#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: write-managed-repo-env.sh <repo-name> <default-branch> <default-dir>\n' >&2
}

if [ "$#" -ne 3 ]; then
  usage
  exit 2
fi

repo_name="$1"
default_branch="$2"
default_dir="$3"
workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
child_root="$workspace_root/repos/$repo_name"

if [ -z "$repo_name" ] || [ "$repo_name" = "." ] || [ "$repo_name" = ".." ]; then
  printf 'refused: invalid managed repo name\n' >&2
  exit 1
fi

if [ ! -d "$child_root/.bare" ]; then
  printf 'refused: managed child repo is missing bare metadata\n' >&2
  exit 1
fi

if [ -z "$default_branch" ]; then
  printf 'refused: managed child default branch metadata is missing or invalid\n' >&2
  exit 1
fi

if [ -z "$default_dir" ] || [ ! -d "$default_dir" ]; then
  printf 'refused: managed child default branch metadata is missing or invalid\n' >&2
  exit 1
fi

case "$default_dir" in
  "$child_root"/*) ;;
  *)
    printf 'refused: managed child default branch metadata is missing or invalid\n' >&2
    exit 1
    ;;
esac

repo_env_dir="$workspace_root/state/repos/$repo_name/etc"
mkdir -p "$repo_env_dir"
repo_env_file="$repo_env_dir/repo.env"

cat > "$repo_env_file" <<EOF
export DYN_REPO_DEFAULT_BRANCH=$(printf '%q' "$default_branch")
export DYN_REPO_DEFAULT_DIR=$(printf '%q' "$default_dir")
EOF
