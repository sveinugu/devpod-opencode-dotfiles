#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: scripts/setup-host-bare-hub.sh --hub-root /absolute/path\n' >&2
  exit 1
}

hub_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hub-root)
      shift
      hub_root="${1:-}"
      ;;
    *)
      usage
      ;;
  esac
  shift || true
done

[ -n "$hub_root" ] || usage

case "$hub_root" in
  /*) ;;
  *)
    printf 'refused: --hub-root must be absolute\n' >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_checkout="$(cd "$script_dir/.." && pwd -P)"
default_branch="$(git -C "$source_checkout" symbolic-ref --quiet --short HEAD || git -C "$source_checkout" rev-parse --abbrev-ref HEAD)"

mkdir -p "$hub_root"

if [ ! -d "$hub_root/.bare" ]; then
  git clone --bare "$source_checkout" "$hub_root/.bare" >/dev/null
fi

mkdir -p \
  "$hub_root/work" \
  "$hub_root/repos" \
  "$hub_root/state/opencode/exported_sessions" \
  "$hub_root/tmp"

chmod 700 \
  "$hub_root/state" \
  "$hub_root/state/opencode" \
  "$hub_root/state/opencode/exported_sessions"

if ! git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null 2>&1; then
  rm -rf "$hub_root/main"
  git --git-dir="$hub_root/.bare" worktree add "$hub_root/main" "$default_branch" >/dev/null
fi

printf 'ok: ensured host bare-hub layout at %s\n' "$hub_root"
