#!/usr/bin/env bash
set -euo pipefail

install_link_path() {
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

install_run_opencode_command() {
  if [ "$dry_run" = true ]; then
    printf 'DRY-RUN (cd %s && %s)\n' "$home_dir/.config/opencode" "$*"
    return 0
  fi

  (
    cd "$home_dir/.config/opencode"
    "$@"
  )
}

install_ensure_oh_my_zsh() {
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
}

install_materialize() {
  install_ensure_oh_my_zsh

  mkdir -p "$home_dir/.config"
  mkdir -p "$zsh_custom/themes" "$zsh_custom/plugins"

  install_link_path "$source_root/.zshrc" "$home_dir/.zshrc"
  install_link_path "$source_root/.zprofile" "$home_dir/.zprofile"

  printf 'installing workspace navigation package...\n'
  install_link_path "$source_root/.config/shell/workspace-navigation.zsh" "$home_dir/.config/shell/workspace-navigation.zsh"

  install_plugin "https://github.com/reobin/typewritten" "$zsh_custom/themes/typewritten"
  install_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "$zsh_custom/plugins/zsh-syntax-highlighting"
  install_plugin "https://github.com/zsh-users/zsh-autosuggestions" "$zsh_custom/plugins/zsh-autosuggestions"

  install_link_path "$source_root/.config/opencode" "$home_dir/.config/opencode"
  install_link_path "$source_root/.config/nono" "$home_dir/.config/nono"

  install_run_opencode_command npx -y skills add wondelai/skills/pragmatic-programmer -y
  install_run_opencode_command npx -y skills add wondelai/skills/clean-code -y
  install_run_opencode_command npx -y @bybrawe/opencode-loop

  printf 'ok: dotfiles applied from %s\n' "$source_root"
}
