#!/usr/bin/env bash

# Default to main for v1 bootstrap behavior.
HUB_BOOTSTRAP_BRANCH="${HUB_BOOTSTRAP_BRANCH:-main}"

hub_fail() {
  printf '%s\n' "$1" >&2
  return 1
}

_HRC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_HRC_SCRIPT_DIR/hub-repo-core-source.sh"
source "$_HRC_SCRIPT_DIR/hub-repo-core-bootstrap.sh"
source "$_HRC_SCRIPT_DIR/hub-repo-core-upstream.sh"
unset _HRC_SCRIPT_DIR
