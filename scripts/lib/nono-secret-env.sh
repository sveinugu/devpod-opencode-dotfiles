#!/usr/bin/env bash
set -euo pipefail

# Prints the environment variable for a supported provider secret key.
nono_secret_env_name() {
  case "$1" in
    openai_chatgpt_session) printf 'OPENAI_CHATGPT_SESSION\n' ;;
    anthropic_api_key) printf 'ANTHROPIC_API_KEY\n' ;;
    github_token) printf 'GITHUB_TOKEN\n' ;;
    gpt_uio_yellow_api_key) printf 'GPT_UIO_YELLOW_API_KEY\n' ;;
    gpt_uio_red_api_key) printf 'GPT_UIO_RED_API_KEY\n' ;;
    *)
      printf 'refused: unsupported nono provider secret key requested: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

nono_secret_env_emit_exports() {
  local secret_root="${1:-${HUB_NONO_PROVIDER_SECRET_DIR:-/var/run/secrets/nono/providers}}"
  shift || true
  local sudo_contract="${HUB_NONO_SECRET_HELPER_SUDO:-}"
  local enforce_explicit_keys='no'
  local requested_keys=()
  local optional_keys=()

  if [ "${1:-}" = '--keys' ]; then
    enforce_explicit_keys='yes'
    shift
  fi

  # Keys after --optional-keys may be absent or empty; they are then not exported.
  while [ "$#" -gt 0 ] && [ "$1" != '--optional-keys' ]; do
    requested_keys+=("$1")
    shift
  done
  if [ "${1:-}" = '--optional-keys' ]; then
    enforce_explicit_keys='yes'
    shift
    optional_keys=("$@")
  fi

  if [ "$enforce_explicit_keys" = 'no' ] && [ "${#requested_keys[@]}" -eq 0 ]; then
    requested_keys=(anthropic_api_key github_token gpt_uio_yellow_api_key gpt_uio_red_api_key)
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

  for key in "${requested_keys[@]}" "${optional_keys[@]}"; do
    nono_secret_env_name "$key" >/dev/null || return 1
  done

  for key in "${requested_keys[@]}"; do
    if [ ! -f "$secret_root/$key" ]; then
      printf 'refused: missing nono provider secret file: %s/%s\n' "$secret_root" "$key" >&2
      missing=1
    fi
  done

  [ "$missing" -eq 0 ] || return 1

  local value env_name

  for key in "${optional_keys[@]}"; do
    [ -f "$secret_root/$key" ] || continue
    env_name="$(nono_secret_env_name "$key")"
    if ! value="$(nono_secret_env_read_file "$secret_root/$key")"; then
      printf 'refused: unable to read nono provider secret file via constrained sudo helper: %s/%s\n' "$secret_root" "$key" >&2
      return 1
    fi
    [ -n "$value" ] || continue
    printf 'export %s=%q\n' "$env_name" "$value"
  done

  for key in "${requested_keys[@]}"; do
    env_name="$(nono_secret_env_name "$key")"

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
