#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: resolve-git-identity.sh [--no-prompts]\n' >&2
  exit 2
}

no_prompts=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-prompts)
      no_prompts=true
      ;;
    *)
      usage
      ;;
  esac
  shift
done

github_user_name="${HUB_GITHUB_USER_NAME:-}"
github_user_email="${HUB_GITHUB_USER_EMAIL:-}"
tty_fd=""

emit_identity() {
  if [ -n "$github_user_name" ]; then
    printf 'HUB_GITHUB_USER_NAME=%q\n' "$github_user_name"
  fi
  if [ -n "$github_user_email" ]; then
    printf 'HUB_GITHUB_USER_EMAIL=%q\n' "$github_user_email"
  fi
}

read_global_identity() {
  if [ -z "$github_user_name" ]; then
    github_user_name="$(git config --global --get user.name 2>/dev/null || true)"
  fi
  if [ -z "$github_user_email" ]; then
    github_user_email="$(git config --global --get user.email 2>/dev/null || true)"
  fi
}

prompt_for_missing_fields() {
  if [ -z "$github_user_name" ]; then
    prompt 'Git username: '
    read_prompt github_user_name
  fi
  if [ -z "$github_user_email" ]; then
    prompt 'Git email: '
    read_prompt github_user_email
  fi
}

print_global_identity_confirmation() {
  if [ -n "$github_user_name" ] && [ -n "$github_user_email" ]; then
    prompt "Using global git identity: $github_user_name <$github_user_email>\n"
  fi
}

prompt() {
  local text="$1"
  if [ -n "$tty_fd" ]; then
    printf '%s' "$text" >&"$tty_fd"
  else
    printf '%s' "$text" >&2
  fi
}

read_prompt() {
  local __var_name="$1"
  local __value
  if [ -n "$tty_fd" ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; then
    read -r -u "$tty_fd" __value
  else
    read -r __value
  fi
  printf -v "$__var_name" '%s' "$__value"
}

if [ "$no_prompts" = true ]; then
  emit_identity
  exit 0
fi

if [ -r /dev/tty ] && [ -w /dev/tty ]; then
  exec 3<>/dev/tty
  tty_fd=3
fi

if [ ! -t 0 ] || [ ! -t 1 ]; then
  if [ -z "$tty_fd" ]; then
    emit_identity
    exit 0
  fi
fi

prompt 'Use existing global git username/email? [Y/n]: '
read_prompt use_global

case "$use_global" in
  Y|y|'')
    read_global_identity
    prompt_for_missing_fields
    print_global_identity_confirmation
    ;;
  N|n)
    prompt 'Specify git username/email manually? [y/N]: '
    read_prompt enter_manual
    case "$enter_manual" in
      Y|y)
        prompt_for_missing_fields
        ;;
      *)
        ;;
    esac
    ;;
  *)
    printf 'refused: answer Y or N\n' >&2
    exit 1
    ;;
esac

emit_identity

if [ -n "$tty_fd" ]; then
  exec 3>&-
fi

exit 0
