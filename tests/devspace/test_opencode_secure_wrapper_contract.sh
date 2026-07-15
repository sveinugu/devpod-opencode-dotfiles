#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_secure_wrapper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
wrapper="$repo_root/.config/opencode/bin/opencode"

[ -f "$wrapper" ] || fail "secure opencode wrapper not found"

grep -F 'source "$secret_helper"' "$wrapper" >/dev/null || fail "wrapper must source nono secret helper"
grep -F 'nono_secret_env_emit_exports' "$wrapper" >/dev/null || fail "wrapper must call nono_secret_env_emit_exports"
grep -F 'exec nono run --profile "$profile_path" -- opencode "$@"' "$wrapper" >/dev/null || fail "wrapper must exec nono run with secure profile"
grep -F 'HUB_NONO_PROVIDER_SECRET_DIR' "$wrapper" >/dev/null || fail "wrapper must honor HUB_NONO_PROVIDER_SECRET_DIR"

tmp_root="$(mktemp -d "$repo_root/.tmp-opencode-wrapper-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

install_root="$tmp_root/install-root"
helper_root="$install_root/scripts/lib"
profile_root="$install_root/.config/nono/profiles"
secret_root="$tmp_root/secrets"
mock_bin="$tmp_root/mock-bin"

mkdir -p "$helper_root" "$profile_root" "$secret_root" "$mock_bin"

cp "$repo_root/scripts/lib/nono-secret-env.sh" "$helper_root/nono-secret-env.sh"
cp "$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$profile_root/devspace-opencode-secure.jsonc"

for key in openai_api_key anthropic_api_key github_token gpt_uio_yellow_api_key gpt_uio_red_api_key; do
  printf '%s-value\n' "$key" >"$secret_root/$key"
done

cat >"$mock_bin/nono" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"${MOCK_NONO_ARG_LOG:?MOCK_NONO_ARG_LOG must be set}"
printf 'OPENAI_API_KEY=%s\n' "${OPENAI_API_KEY:-}" >"${MOCK_NONO_ENV_LOG:?MOCK_NONO_ENV_LOG must be set}"
printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GPT_UIO_YELLOW_API_KEY=%s\n' "${GPT_UIO_YELLOW_API_KEY:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GPT_UIO_RED_API_KEY=%s\n' "${GPT_UIO_RED_API_KEY:-}" >>"$MOCK_NONO_ENV_LOG"
exit 0
EOF
chmod +x "$mock_bin/nono"

arg_log="$tmp_root/nono-args.log"
env_log="$tmp_root/nono-env.log"

PATH="$mock_bin:$PATH" \
HUB_INSTALL_BRANCH_DIR="$install_root" \
HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" \
MOCK_NONO_ARG_LOG="$arg_log" \
MOCK_NONO_ENV_LOG="$env_log" \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should execute with valid helper/profile/secret surfaces"

grep -F -- '--profile' "$arg_log" >/dev/null || fail "wrapper should pass profile argument to nono"
grep -F "$install_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$arg_log" >/dev/null || fail "wrapper should point nono to install-branch secure profile"
grep -F -- '-- opencode --version' "$arg_log" >/dev/null || fail "wrapper should launch opencode through nono"

grep -F 'OPENAI_API_KEY=openai_api_key-value' "$env_log" >/dev/null || fail "wrapper should export OPENAI_API_KEY from mounted secret"
grep -F 'ANTHROPIC_API_KEY=anthropic_api_key-value' "$env_log" >/dev/null || fail "wrapper should export ANTHROPIC_API_KEY from mounted secret"
grep -F 'GITHUB_TOKEN=github_token-value' "$env_log" >/dev/null || fail "wrapper should export GITHUB_TOKEN from mounted secret"
grep -F 'GPT_UIO_YELLOW_API_KEY=gpt_uio_yellow_api_key-value' "$env_log" >/dev/null || fail "wrapper should export yellow key from mounted secret"
grep -F 'GPT_UIO_RED_API_KEY=gpt_uio_red_api_key-value' "$env_log" >/dev/null || fail "wrapper should export red key from mounted secret"

printf 'PASS test_opencode_secure_wrapper_contract\n'
