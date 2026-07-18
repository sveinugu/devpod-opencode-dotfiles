#!/usr/bin/env bash
set -euo pipefail

nono_secret_env_emit_exports() {
  local secret_root="${1:-${HUB_NONO_PROVIDER_SECRET_DIR:-/var/run/secrets/nono/providers}}"
  shift || true
  local sudo_contract="${HUB_NONO_SECRET_HELPER_SUDO:-}"
  local enforce_explicit_keys='no'
  local requested_keys=()

  if [ "${1:-}" = '--keys' ]; then
    enforce_explicit_keys='yes'
    shift
  fi

  requested_keys=("$@")

  if [ "$enforce_explicit_keys" = 'no' ] && [ "${#requested_keys[@]}" -eq 0 ]; then
    requested_keys=(openai_api_key anthropic_api_key github_token gpt_uio_yellow_api_key gpt_uio_red_api_key)
  fi

  nono_secret_env_read_file() {
    local file_path="$1"

    sudo -n /bin/cat "$file_path"
  }

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

  for key in "${requested_keys[@]}"; do
    case "$key" in
      openai_api_key|anthropic_api_key|github_token|gpt_uio_yellow_api_key|gpt_uio_red_api_key)
        ;;
      *)
        printf 'refused: unsupported nono provider secret key requested: %s\n' "$key" >&2
        return 1
        ;;
    esac

    if [ ! -f "$secret_root/$key" ]; then
      printf 'refused: missing nono provider secret file: %s/%s\n' "$secret_root" "$key" >&2
      missing=1
    fi
  done

  [ "$missing" -eq 0 ] || return 1

  local value env_name

  for key in "${requested_keys[@]}"; do
    case "$key" in
      openai_api_key) env_name='OPENAI_API_KEY' ;;
      anthropic_api_key) env_name='ANTHROPIC_API_KEY' ;;
      github_token) env_name='GITHUB_TOKEN' ;;
      gpt_uio_yellow_api_key) env_name='GPT_UIO_YELLOW_API_KEY' ;;
      gpt_uio_red_api_key) env_name='GPT_UIO_RED_API_KEY' ;;
      *)
        printf 'refused: unsupported nono provider secret key requested: %s\n' "$key" >&2
        return 1
        ;;
    esac

    if ! value="$(nono_secret_env_read_file "$secret_root/$key")"; then
      printf 'refused: unable to read nono provider secret file via constrained sudo helper: %s/%s\n' "$secret_root" "$key" >&2
      return 1
    fi

    if [ -z "$value" ]; then
      printf 'refused: nono provider secret file is empty under %s\n' "$secret_root" >&2
      return 1
    fi

    printf 'export %s=%q\n' "$env_name" "$value"
  done
}
