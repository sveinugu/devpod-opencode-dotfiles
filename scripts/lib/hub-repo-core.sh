#!/usr/bin/env bash

# Default to main for v1 bootstrap behavior.
HUB_BOOTSTRAP_BRANCH="${HUB_BOOTSTRAP_BRANCH:-main}"

hub_fail() {
  printf '%s\n' "$1" >&2
  return 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/hub-repo-core-source.sh"
source "$script_dir/hub-repo-core-bootstrap.sh"
source "$script_dir/hub-repo-core-upstream.sh"
if [ -n "${BASH_SOURCE[1]:-}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd -P)"
else
  unset script_dir
fi
