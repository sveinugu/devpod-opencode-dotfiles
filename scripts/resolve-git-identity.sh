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
    printf 'Git username: ' >&2
    read -r github_user_name
  fi
  if [ -z "$github_user_email" ]; then
    printf 'Git email: ' >&2
    read -r github_user_email
  fi
}

if [ "$no_prompts" = true ]; then
  emit_identity
  exit 0
fi

if [ ! -t 0 ] && [ -r /dev/tty ]; then
  exec </dev/tty
fi

if [ ! -t 1 ] && [ -w /dev/tty ]; then
  exec >/dev/tty
fi

if [ ! -t 0 ] || [ ! -t 1 ]; then
  emit_identity
  exit 0
fi

printf 'Use existing global git username/email? [Y/n]: ' >&2
read -r use_global

case "$use_global" in
  Y|y|'')
    read_global_identity
    prompt_for_missing_fields
    ;;
  N|n)
    printf 'Specify git username/email manually? [y/N]: ' >&2
    read -r enter_manual
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
