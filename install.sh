#!/usr/bin/env bash
set -euo pipefail

# Installs the dotfiles from the checkout that contains this script.
# High-level flow:
# 1. Resolve the install source/worktree and refuse hub-root execution.
# 2. Validate the source tree and persist install-branch state.
# 3. Link shell/OpenCode config into $HOME and install required tooling.
# Start with README.md for orientation, then see:
# - docs/superpowers/runbooks/devspace-bare-hub-usage.md
# - docs/superpowers/runbooks/devspace-workspace-lifecycle.md

script_path="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source_root="$(dirname "$script_path")"

source "$source_root/scripts/lib/install/parse-args.sh"
source "$source_root/scripts/lib/install/resolve-source.sh"
source "$source_root/scripts/lib/install/validate-source.sh"
source "$source_root/scripts/lib/install/materialize.sh"

install_parse_args "$@"
install_resolve_source_context
install_validate_source_context
install_materialize
