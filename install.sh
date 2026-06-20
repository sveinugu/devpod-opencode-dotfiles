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


dry_run=false
assume_yes=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    -y|--yes)
      assume_yes=true
      ;;
    *)
      printf 'usage: install.sh [--dry-run] [-y|--yes]\n' >&2
      exit 1
      ;;
  esac
  shift
done

script_path="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source_root="$(dirname "$script_path")"
workspace_root="${WORKSPACE_ROOT:-/workspaces/dotfiles}"
home_dir="${HOME:?HOME must be set}"
validator="$source_root/scripts/lib/validate_install_source_tree.sh"

if [ "$source_root" = "$workspace_root/main" ]; then
  install_branch="main"
elif [ "${source_root#"$workspace_root/work/"}" != "$source_root" ]; then
  install_branch="${source_root#"$workspace_root/work/"}"
else
  current_branch=''
  if current_branch="$(git -C "$source_root" rev-parse --abbrev-ref HEAD 2>/dev/null)"; then
    :
  fi
  if [ -n "$current_branch" ] && [ "$current_branch" != "HEAD" ]; then
    install_branch="$current_branch"
  else
    install_branch="main"
  fi
fi

install_branch_dir="$source_root"
install_env_dir="$workspace_root/state/hub/etc"
install_env_file="$install_env_dir/install.env"

if [ "$source_root" = "$workspace_root" ]; then
  printf 'Refused — hub-root CWD detected. Provide explicit worktree path.\n' >&2
  exit 1
fi

if [ ! -x "$validator" ]; then
  printf 'missing validator: %s\n' "$validator" >&2
  exit 1
fi

"$validator" "$source_root" "$source_root/.zshrc" >/dev/null
"$validator" "$source_root" "$source_root/.config/opencode" >/dev/null

if [ -f "$install_env_file" ]; then
  install_env_values="$(set +u; source "$install_env_file"; printf '%s\n%s\n' "${HUB_INSTALL_BRANCH:-}" "${HUB_INSTALL_BRANCH_DIR:-}")"
  install_env_branch="$(printf '%s' "$install_env_values" | sed -n '1p')"
  install_env_branch_dir="$(printf '%s' "$install_env_values" | sed -n '2p')"

  if [ -n "${HUB_INSTALL_BRANCH:-}" ] && [ "$HUB_INSTALL_BRANCH" = "$install_env_branch" ]; then
    unset HUB_INSTALL_BRANCH
  fi

  if [ -n "${HUB_INSTALL_BRANCH_DIR:-}" ] && [ "$HUB_INSTALL_BRANCH_DIR" = "$install_env_branch_dir" ]; then
    unset HUB_INSTALL_BRANCH_DIR
  fi
fi

if [ -n "${HUB_INSTALL_BRANCH:-}" ] && [ "$HUB_INSTALL_BRANCH" != "$install_branch" ]; then
  printf 'refused: HUB_INSTALL_BRANCH does not match install source (expected %s, got %s)\n' "$install_branch" "$HUB_INSTALL_BRANCH" >&2
  exit 1
fi

if [ -n "${HUB_INSTALL_BRANCH_DIR:-}" ] && [ "$HUB_INSTALL_BRANCH_DIR" != "$install_branch_dir" ]; then
  printf 'refused: HUB_INSTALL_BRANCH_DIR does not match install source (expected %s, got %s)\n' "$install_branch_dir" "$HUB_INSTALL_BRANCH_DIR" >&2
  exit 1
fi

export HUB_INSTALL_BRANCH="$install_branch"
export HUB_INSTALL_BRANCH_DIR="$install_branch_dir"

mkdir -p "$install_env_dir"
cat > "$install_env_file" <<EOF
export HUB_INSTALL_BRANCH=$(printf '%q' "$HUB_INSTALL_BRANCH")
export HUB_INSTALL_BRANCH_DIR=$(printf '%q' "$HUB_INSTALL_BRANCH_DIR")
EOF

if ! declare -F dhub >/dev/null 2>&1; then
  cat >&2 <<EOF
note: shell helper dhub() was not detected. Add this snippet to your shell config for quick navigation:
dhub() {
  local resolver="$source_root/scripts/lib/resolve-install-target.sh"
  local target
  if ! target="\$(HUB_INSTALL_ENV_FILE=\"$install_env_file\" bash \"\$resolver\")"; then
    return 1
  fi
  printf 'cd -> %s\n' "\$target"
  cd "\$target"
}
EOF
fi

zsh_custom="${ZSH_CUSTOM:-$home_dir/.oh-my-zsh/custom}"

# Install oh-my-zsh if not already present
oh_my_zsh_dir="$home_dir/.oh-my-zsh"
if [ ! -f "$oh_my_zsh_dir/oh-my-zsh.sh" ]; then
  if [ -d "$oh_my_zsh_dir" ]; then rm -rf "$oh_my_zsh_dir"; fi
  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN install oh-my-zsh to %s\n' "$oh_my_zsh_dir"
  else
    printf 'installing oh-my-zsh...\n'
    tmp_installer="$(mktemp)"
    if ! curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$tmp_installer"; then
      printf 'failed to download oh-my-zsh installer\n' >&2
      rm -f "$tmp_installer"
      exit 1
    fi
    zsh "$tmp_installer" "" --unattended --skip-chsh
    rm -f "$tmp_installer"
  fi
fi

link_path() {
  local source_path="$1"
  local target_path="$2"

  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN ln -sfn %s %s\n' "$source_path" "$target_path"
    return 0
  fi

  if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
    rm -rf "$target_path"
  fi

  mkdir -p "$(dirname "$target_path")"
  ln -sfn "$source_path" "$target_path"
}

install_plugin() {
  local repo_url="$1"
  local dest_path="$2"

  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN git clone %s %s\n' "$repo_url" "$dest_path"
    return 0
  fi

  if [ ! -d "$dest_path" ]; then
    git clone "$repo_url" "$dest_path"
  else
    printf '%s already installed, skipping.\n' "$(basename "$dest_path")"
  fi
}

run_opencode_command() {
  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN (cd %s && %s)\n' "$home_dir/.config/opencode" "$*"
    return 0
  fi

  (
    cd "$home_dir/.config/opencode"
    "$@"
  )
}

mkdir -p "$home_dir/.config"
mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"

link_path "$source_root/.zshrc" "$home_dir/.zshrc"
link_path "$source_root/.zprofile" "$home_dir/.zprofile"

printf 'installing workspace navigation package...\n'
link_path "$source_root/.config/shell/workspace-navigation.zsh" "$home_dir/.config/shell/workspace-navigation.zsh"

install_plugin "https://github.com/reobin/typewritten" "$zsh_custom/themes/typewritten"
install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$zsh_custom/plugins/zsh-syntax-highlighting"
install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$zsh_custom/plugins/zsh-autosuggestions"

link_path "$source_root/.config/opencode" "$home_dir/.config/opencode"

run_opencode_command npx -y skills add wondelai/skills/pragmatic-programmer -g -y
run_opencode_command npx -y skills add wondelai/skills/clean-code -g -y
run_opencode_command npx -y @bybrawe/opencode-loop

if [ "$assume_yes" = true ] && [ "$dry_run" = true ]; then
  :
fi

printf 'ok: dotfiles applied from %s\n' "$source_root"
