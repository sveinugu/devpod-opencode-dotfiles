#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(git rev-parse --show-toplevel)}"
skills_lock="$repo_root/skills-lock.json"

if [ ! -f "$skills_lock" ]; then
  printf 'refused: top-level skills-lock.json is missing at %s\n' "$skills_lock" >&2
  exit 1
fi

if [ "${DRY_RUN:-false}" = 'true' ]; then
  printf 'DRY-RUN (cd %s && npx -y skills experimental_install "%s")\n' "$repo_root" "$skills_lock"
  exit 0
fi

(
  cd "$repo_root"
  npx -y skills experimental_install "$skills_lock"
)
