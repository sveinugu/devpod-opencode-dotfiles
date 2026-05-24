#!/usr/bin/env bash
set -euo pipefail

source_root="${1:?usage: scripts/install-validate-source.sh SOURCE_ROOT CANDIDATE_PATH}"
candidate_path="${2:?usage: scripts/install-validate-source.sh SOURCE_ROOT CANDIDATE_PATH}"

source_root_abs="$(readlink -f "$source_root")"
candidate_abs="$(readlink -f "$candidate_path")"

case "$candidate_abs" in
  "$source_root_abs"|"$source_root_abs"/*) ;;
  *)
    printf 'refused: symlink escapes source root\n' >&2
    exit 1
    ;;
esac

git_file="$source_root_abs/.git"
if [ -f "$git_file" ]; then
  IFS= read -r gitdir_line < "$git_file"
  case "$gitdir_line" in
    gitdir:*)
      gitdir_path="${gitdir_line#gitdir: }"
      case "$gitdir_path" in
        /*) gitdir_abs="$(readlink -f "$gitdir_path" 2>/dev/null || true)" ;;
        *) gitdir_abs="$(readlink -f "$source_root_abs/$gitdir_path" 2>/dev/null || true)" ;;
      esac
      case "$gitdir_abs" in
        /workspaces/dotfiles/*|/home/vscode/dotfiles/*) ;;
        *)
          printf 'refused: gitdir outside /workspaces/dotfiles\n' >&2
          exit 1
          ;;
      esac
      ;;
  esac
fi

printf 'ok: validated source path %s\n' "$candidate_abs"
