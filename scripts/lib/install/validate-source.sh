#!/usr/bin/env bash
set -euo pipefail

install_unset_stale_inherited_env() {
  local install_env_values=''
  local install_env_branch=''
  local install_env_branch_dir=''

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
}

install_validate_branch_identity() {
  if [ -n "${HUB_INSTALL_BRANCH:-}" ] && [ "$HUB_INSTALL_BRANCH" != "$install_branch" ]; then
    printf 'refused: HUB_INSTALL_BRANCH does not match install source (expected %s, got %s)\n' "$install_branch" "$HUB_INSTALL_BRANCH" >&2
    exit 1
  fi

  if [ -n "${HUB_INSTALL_BRANCH_DIR:-}" ] && [ "$HUB_INSTALL_BRANCH_DIR" != "$install_branch_dir" ]; then
    printf 'refused: HUB_INSTALL_BRANCH_DIR does not match install source (expected %s, got %s)\n' "$install_branch_dir" "$HUB_INSTALL_BRANCH_DIR" >&2
    exit 1
  fi
}

install_publish_install_env() {
  export HUB_INSTALL_BRANCH="$install_branch"
  export HUB_INSTALL_BRANCH_DIR="$install_branch_dir"

  mkdir -p "$install_env_dir"
  cat > "$install_env_file" <<EOF
export HUB_INSTALL_BRANCH=$(printf '%q' "$HUB_INSTALL_BRANCH")
export HUB_INSTALL_BRANCH_DIR=$(printf '%q' "$HUB_INSTALL_BRANCH_DIR")
EOF
}

install_print_dhub_note() {
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
}

install_validate_source_context() {
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

  install_unset_stale_inherited_env
  install_validate_branch_identity
  install_publish_install_env
  install_print_dhub_note
}
