#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/hub-repo-core.sh
source "$script_dir/lib/hub-repo-core.sh"

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
source_repo="${HUB_PROVISION_SOURCE:-https://github.com/joaomdmoura/dotfiles.git}"

create_bare_hub "$workspace_root" "$source_repo"

if [ ! -x "$workspace_root/main/install.sh" ]; then
  chmod +x "$workspace_root/main/install.sh"
fi

"$workspace_root/main/install.sh"

printf 'ok: provisioned top-level workspace at %s\n' "$workspace_root"
