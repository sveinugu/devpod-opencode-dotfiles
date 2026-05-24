#!/usr/bin/env bash
set -euo pipefail

cd /tmp

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/hub-repo-core.sh
source "$script_dir/lib/hub-repo-core.sh"

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
source_repo="${HUB_PROVISION_SOURCE:-https://github.com/sveinugu/devpod-opencode-dotfiles.git}"
source_branch="${HUB_PROVISION_BRANCH:-main}"
home_dir="${HOME:?HOME must be set}"
refresh_tools=false
tool_state_dir="$home_dir/.local/state/workspace-tools"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --refresh-tools)
      refresh_tools=true
      ;;
    *)
      printf 'usage: workspace-provision.sh [--refresh-tools]\n' >&2
      exit 2
      ;;
  esac
  shift
done

run_tool_installer() {
  local marker_path="$1"
  local command="$2"

  if [ "$refresh_tools" = false ] && [ -f "$marker_path" ]; then
    return 0
  fi

  zsh -lc "$command"
  touch "$marker_path"
}

pyenv_install_command="${HUB_PYENV_INSTALL_COMMAND:-curl -fsSL https://pyenv.run | zsh}"
opencode_install_command="${HUB_OPENCODE_INSTALL_COMMAND:-curl -fsSL https://opencode.ai/install | zsh}"

create_bare_hub "$workspace_root" "$source_repo" "$source_branch"

mkdir -p "$home_dir/.ssh" "$home_dir/.local/share/opencode"
mkdir -p "$tool_state_dir"
run_tool_installer "$tool_state_dir/pyenv.installed" "$pyenv_install_command"
run_tool_installer "$tool_state_dir/opencode.installed" "$opencode_install_command"

if [ ! -x "$workspace_root/main/install.sh" ]; then
  chmod +x "$workspace_root/main/install.sh"
fi

"$workspace_root/main/install.sh"

printf 'ok: provisioned top-level workspace at %s\n' "$workspace_root"
