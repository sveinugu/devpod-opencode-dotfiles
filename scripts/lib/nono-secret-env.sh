#!/usr/bin/env bash
set -euo pipefail

nono_secret_env_emit_exports() {
  local secret_root="${1:-${HUB_NONO_PROVIDER_SECRET_DIR:-/var/run/secrets/nono/providers}}"
  local sudo_contract="${HUB_NONO_SECRET_HELPER_SUDO:-}"

  if [ -z "$sudo_contract" ]; then
    printf 'refused: HUB_NONO_SECRET_HELPER_SUDO must be set to constrained non-interactive sudo invocation\n' >&2
    return 1
  fi

  if [ "$sudo_contract" != 'sudo -n' ]; then
    printf 'refused: HUB_NONO_SECRET_HELPER_SUDO must equal "sudo -n" (got: %s)\n' "$sudo_contract" >&2
    return 1
  fi

  if [ ! -d "$secret_root" ]; then
    printf 'refused: nono provider secret directory not found: %s\n' "$secret_root" >&2
    return 1
  fi

  local missing=0
  local key

  for key in openai_api_key anthropic_api_key github_token gpt_uio_yellow_api_key gpt_uio_red_api_key; do
    if [ ! -f "$secret_root/$key" ]; then
      printf 'refused: missing nono provider secret file: %s/%s\n' "$secret_root" "$key" >&2
      missing=1
    fi
  done

  [ "$missing" -eq 0 ] || return 1

  local openai anthropic github yellow red
  openai="$(<"$secret_root/openai_api_key")"
  anthropic="$(<"$secret_root/anthropic_api_key")"
  github="$(<"$secret_root/github_token")"
  yellow="$(<"$secret_root/gpt_uio_yellow_api_key")"
  red="$(<"$secret_root/gpt_uio_red_api_key")"

  for value in "$openai" "$anthropic" "$github" "$yellow" "$red"; do
    if [ -z "$value" ]; then
      printf 'refused: nono provider secret file is empty under %s\n' "$secret_root" >&2
      return 1
    fi
  done

  printf 'export OPENAI_API_KEY=%q\n' "$openai"
  printf 'export ANTHROPIC_API_KEY=%q\n' "$anthropic"
  printf 'export GITHUB_TOKEN=%q\n' "$github"
  printf 'export GPT_UIO_YELLOW_API_KEY=%q\n' "$yellow"
  printf 'export GPT_UIO_RED_API_KEY=%q\n' "$red"
}
