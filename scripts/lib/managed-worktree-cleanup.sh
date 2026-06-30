#!/usr/bin/env bash
set -euo pipefail

_mwc_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$_mwc_script_dir/managed-worktree-cleanup-resolve.sh"
source "$_mwc_script_dir/managed-worktree-cleanup-risk.sh"
source "$_mwc_script_dir/managed-worktree-cleanup-mutation.sh"
unset _mwc_script_dir
