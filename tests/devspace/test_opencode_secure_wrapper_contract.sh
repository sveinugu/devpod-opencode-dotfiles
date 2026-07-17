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
grep -F 'exec nono run --profile "$profile_path" -- sudo -n -u "$agent_user" -- env OPENCODE_CONFIG_CONTENT="$opencode_provider_runtime_json" "$raw_opencode_binary" "$@"' "$wrapper" >/dev/null || fail "wrapper must exec nono run with secure profile and runtime provider config injection"
grep -F 'HUB_NONO_PROVIDER_SECRET_DIR' "$wrapper" >/dev/null || fail "wrapper must honor HUB_NONO_PROVIDER_SECRET_DIR"
grep -F 'HUB_NONO_SECRET_HELPER_SUDO' "$wrapper" >/dev/null || fail "wrapper must require HUB_NONO_SECRET_HELPER_SUDO contract"
grep -F 'HUB_NONO_AGENT_USER' "$wrapper" >/dev/null || fail "wrapper must require HUB_NONO_AGENT_USER contract"
grep -F 'OPENCODE_PROVIDER_RUNTIME_PATH' "$wrapper" >/dev/null || fail "wrapper must support canonical generated provider runtime path contract"
grep -F 'OPENCODE_RAW_BINARY' "$wrapper" >/dev/null || fail "wrapper must support explicit raw opencode binary contract"
grep -F '$source_root/.config/opencode/provider-runtime.json' "$wrapper" >/dev/null || fail "wrapper must default runtime provider config path to install-branch output"
grep -F 'sudo -n -u "$agent_user" -- env OPENCODE_CONFIG_CONTENT="$opencode_provider_runtime_json" "$raw_opencode_binary" "$@"' "$wrapper" >/dev/null || fail "wrapper must execute opencode as non-sudo agent user"

tmp_root="$(mktemp -d "$repo_root/.tmp-opencode-wrapper-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

install_root="$tmp_root/install-root"
helper_root="$install_root/scripts/lib"
profile_root="$install_root/.config/nono/profiles"
secret_root="$tmp_root/secrets"
mock_bin="$tmp_root/mock-bin"
provider_runtime="$tmp_root/provider-runtime.json"
raw_binary="$tmp_root/opencode-real"

mkdir -p "$helper_root" "$profile_root" "$secret_root" "$mock_bin"

cp "$repo_root/scripts/lib/nono-secret-env.sh" "$helper_root/nono-secret-env.sh"
cp "$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$profile_root/devspace-opencode-secure.jsonc"

cat >"$raw_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$raw_binary"

for key in openai_api_key anthropic_api_key github_token gpt_uio_yellow_api_key gpt_uio_red_api_key; do
  printf '%s-value\n' "$key" >"$secret_root/$key"
done

cat >"$provider_runtime" <<'JSON'
{
  "enabled_providers": [
    "gpt-uio-red",
    "openai"
  ],
  "provider": {
    "gpt-uio-red": {
      "api": "openai",
      "options": {
        "baseURL": "https://gpt.uio.no/api/v1"
      },
      "models": {
        "gpt-oss-120b": {
          "id": "gpt-oss-120b",
          "name": "GPT-OSS 120B"
        }
      }
    }
  }
}
JSON

mkdir -p "$install_root/.config/opencode"
cp "$provider_runtime" "$install_root/.config/opencode/provider-runtime.json"

cat >"$mock_bin/nono" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"${MOCK_NONO_ARG_LOG:?MOCK_NONO_ARG_LOG must be set}"
if [ "$1" = "run" ]; then
  shift
fi
if [ "$1" = "--profile" ]; then
  shift 2
fi
if [ "$1" = "--" ]; then
  shift
fi
"$@"
printf 'OPENAI_API_KEY=%s\n' "${OPENAI_API_KEY:-}" >"${MOCK_NONO_ENV_LOG:?MOCK_NONO_ENV_LOG must be set}"
printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GPT_UIO_YELLOW_API_KEY=%s\n' "${GPT_UIO_YELLOW_API_KEY:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GPT_UIO_RED_API_KEY=%s\n' "${GPT_UIO_RED_API_KEY:-}" >>"$MOCK_NONO_ENV_LOG"
exit 0
EOF
chmod +x "$mock_bin/nono"

cat >"$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = "-n" ] && [ "${2:-}" = "-u" ]; then
  user="$3"
  shift 3
elif [ "$1" = "-n" ]; then
  user='root'
  shift
else
  exit 64
fi
printf 'sudo-user=%s\n' "$user" >"${MOCK_SUDO_LOG:?MOCK_SUDO_LOG must be set}"
if [ "${1:-}" = "--" ]; then
  shift
fi
"$@"
EOF
chmod +x "$mock_bin/sudo"

arg_log="$tmp_root/nono-args.log"
env_log="$tmp_root/nono-env.log"
sudo_log="$tmp_root/sudo.log"

PATH="$mock_bin:$PATH" \
HUB_INSTALL_BRANCH_DIR="$install_root" \
HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" \
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' \
HUB_NONO_AGENT_USER='agent' \
OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" \
OPENCODE_RAW_BINARY="$raw_binary" \
MOCK_NONO_ARG_LOG="$arg_log" \
MOCK_NONO_ENV_LOG="$env_log" \
MOCK_SUDO_LOG="$sudo_log" \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should execute with valid helper/profile/secret surfaces"

PATH="$mock_bin:$PATH" \
HUB_INSTALL_BRANCH_DIR="$install_root" \
HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" \
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' \
HUB_NONO_AGENT_USER='agent' \
OPENCODE_RAW_BINARY="$raw_binary" \
MOCK_NONO_ARG_LOG="$arg_log" \
MOCK_NONO_ENV_LOG="$env_log" \
MOCK_SUDO_LOG="$sudo_log" \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should execute using install-branch default provider runtime output path"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_AGENT_USER='agent' OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/no-sudo.err" 2>&1; then
  fail "wrapper should fail when HUB_NONO_SECRET_HELPER_SUDO is missing"
fi

grep -F 'refused: HUB_NONO_SECRET_HELPER_SUDO must be set to constrained non-interactive sudo invocation' "$tmp_root/no-sudo.err" >/dev/null || fail "wrapper should surface missing HUB_NONO_SECRET_HELPER_SUDO contract"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/no-agent.err" 2>&1; then
  fail "wrapper should fail when HUB_NONO_AGENT_USER is missing"
fi

grep -F 'refused: HUB_NONO_AGENT_USER must be set to non-sudo agent username' "$tmp_root/no-agent.err" >/dev/null || fail "wrapper should surface missing HUB_NONO_AGENT_USER contract"

grep -F 'sudo-user=agent' "$sudo_log" >/dev/null || fail "wrapper should run opencode command as agent user"

grep -F -- '--profile' "$arg_log" >/dev/null || fail "wrapper should pass profile argument to nono"
grep -F "$install_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$arg_log" >/dev/null || fail "wrapper should point nono to install-branch secure profile"
grep -F -- '-- sudo -n -u agent -- env OPENCODE_CONFIG_CONTENT=' "$arg_log" >/dev/null || fail "wrapper should inject runtime provider config into opencode process"
grep -F -- "$raw_binary --version" "$arg_log" >/dev/null || fail "wrapper should launch configured raw opencode binary through nono"

cat >"$tmp_root/provider-runtime-invalid.json" <<'JSON'
{
  "enabled_providers": ["openai"],
  "provider": "invalid"
}
JSON

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-invalid.json" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/invalid-runtime.err" 2>&1; then
  fail "wrapper should fail when generated provider runtime output is malformed"
fi

grep -F 'refused: generated provider runtime output must define provider as an object' "$tmp_root/invalid-runtime.err" >/dev/null || fail "wrapper should explain malformed provider runtime output"

cat >"$tmp_root/provider-runtime-invalid-key.json" <<'JSON'
{
  "enabled_providers": ["openai"],
  "provider": {},
  "unexpected": true
}
JSON

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-invalid-key.json" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/invalid-runtime-key.err" 2>&1; then
  fail "wrapper should fail when generated provider runtime output contains unsupported keys"
fi

grep -F 'refused: generated provider runtime output contains unsupported keys' "$tmp_root/invalid-runtime-key.err" >/dev/null || fail "wrapper should explain unsupported runtime key failure"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$tmp_root/not-executable-opencode" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/raw-binary.err" 2>&1; then
  fail "wrapper should fail when OPENCODE_RAW_BINARY is not executable"
fi

grep -F 'refused: raw opencode binary not executable at' "$tmp_root/raw-binary.err" >/dev/null || fail "wrapper should explain raw opencode binary executable contract failure"

grep -F 'OPENAI_API_KEY=openai_api_key-value' "$env_log" >/dev/null || fail "wrapper should export OPENAI_API_KEY from mounted secret"
grep -F 'ANTHROPIC_API_KEY=anthropic_api_key-value' "$env_log" >/dev/null || fail "wrapper should export ANTHROPIC_API_KEY from mounted secret"
grep -F 'GITHUB_TOKEN=github_token-value' "$env_log" >/dev/null || fail "wrapper should export GITHUB_TOKEN from mounted secret"
grep -F 'GPT_UIO_YELLOW_API_KEY=gpt_uio_yellow_api_key-value' "$env_log" >/dev/null || fail "wrapper should export yellow key from mounted secret"
grep -F 'GPT_UIO_RED_API_KEY=gpt_uio_red_api_key-value' "$env_log" >/dev/null || fail "wrapper should export red key from mounted secret"

printf 'PASS test_opencode_secure_wrapper_contract\n'
