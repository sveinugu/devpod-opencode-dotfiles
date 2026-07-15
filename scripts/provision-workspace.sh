#!/usr/bin/env bash
set -euo pipefail

cd /tmp

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/lib/hub-repo-core.sh
source "$script_dir/lib/hub-repo-core.sh"

workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"
source_repo="${HUB_PROVISION_SOURCE:-https://github.com/sveinugu/devpod-opencode-dotfiles.git}"
install_branch="${HUB_INSTALL_BRANCH:-main}"
home_dir="${HOME:?HOME must be set}"
refresh_tools=false
tool_state_dir="$home_dir/.local/state/workspace-tools"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --refresh-tools)
      refresh_tools=true
      ;;
    *)
      printf 'usage: provision-workspace.sh [--refresh-tools]\n' >&2
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

  zsh -lc "set -o pipefail; $command"
  touch "$marker_path"
}

configure_git_identity() {
  local bare_dir="$1"
  local github_user_name="${HUB_GITHUB_USER_NAME:-}"
  local github_user_email="${HUB_GITHUB_USER_EMAIL:-}"

  if [ -n "$github_user_name" ]; then
    git --git-dir="$bare_dir" config user.name "$github_user_name"
  fi

  if [ -n "$github_user_email" ]; then
    git --git-dir="$bare_dir" config user.email "$github_user_email"
  fi
}

pyenv_install_command="${HUB_PYENV_INSTALL_COMMAND:-curl -fsSL https://pyenv.run | zsh}"
nono_install_command="${HUB_NONO_INSTALL_COMMAND:-curl -fsSL https://nono.sh/install.sh | sh}"
opencode_install_command="${HUB_OPENCODE_INSTALL_COMMAND:-curl -fsSL https://opencode.ai/install | zsh}"

if [ -d "$workspace_root" ] && [ "$(stat -c '%u' "$workspace_root" 2>/dev/null)" != "$(id -u)" ]; then
  sudo chown "$(id -u):$(id -g)" "$workspace_root"
fi

create_bare_hub "$workspace_root" "$source_repo" main
configure_git_identity "$workspace_root/.bare"

if [ ! -e "$workspace_root/main/.envrc" ]; then
  "$script_dir/lib/worktree-env.sh" "$workspace_root/main" hub >/dev/null
fi

mkdir -p "$home_dir/.ssh" "$home_dir/.local/share/opencode"
mkdir -p "$tool_state_dir"
run_tool_installer "$tool_state_dir/pyenv.installed" "$pyenv_install_command"
run_tool_installer "$tool_state_dir/nono.installed" "$nono_install_command"
run_tool_installer "$tool_state_dir/opencode.installed" "$opencode_install_command"

if [ "$install_branch" = "main" ]; then
  install_dir="$workspace_root/main"
else
  install_dir="$workspace_root/work/$install_branch"
  if ! GIT_TERMINAL_PROMPT=0 \
      GIT_ASKPASS=/bin/false \
      SSH_ASKPASS=/bin/false \
      git --git-dir="$workspace_root/.bare" fetch origin "refs/heads/$install_branch:refs/remotes/origin/$install_branch" >/dev/null 2>&1; then
    printf 'refused: unable to access source repo non-interactively (verify public HTTPS URL and repository visibility)\n' >&2
    exit 1
  fi
  if ! git --git-dir="$workspace_root/.bare" show-ref --verify --quiet "refs/heads/$install_branch" && \
     git --git-dir="$workspace_root/.bare" show-ref --verify --quiet "refs/remotes/origin/$install_branch"; then
    git --git-dir="$workspace_root/.bare" branch "$install_branch" "origin/$install_branch" >/dev/null 2>&1 || true
  fi
  if ! git --git-dir="$workspace_root/.bare" show-ref --verify --quiet "refs/heads/$install_branch"; then
    printf 'refused: origin/%s is required for bootstrap\n' "$install_branch" >&2
    exit 1
  fi
  if git --git-dir="$workspace_root/.bare" worktree list --porcelain | grep -F "worktree $install_dir" >/dev/null 2>&1; then
    :
  else
    mkdir -p "$(dirname "$install_dir")"
    git --git-dir="$workspace_root/.bare" worktree add "$install_dir" "$install_branch" >/dev/null
  fi
  mkdir -p "$workspace_root/state/hub/work/$install_branch" "$workspace_root/tmp/hub/work/$install_branch"
  if [ ! -e "$install_dir/.envrc" ]; then
    "$script_dir/lib/worktree-env.sh" "$install_dir" hub >/dev/null
  fi
fi

if [ ! -x "$install_dir/install.sh" ]; then
  chmod +x "$install_dir/install.sh"
fi

HUB_INSTALL_BRANCH="$install_branch" HUB_INSTALL_BRANCH_DIR="$install_dir" "$install_dir/install.sh"

printf 'ok: provisioned top-level workspace at %s\n' "$workspace_root"
