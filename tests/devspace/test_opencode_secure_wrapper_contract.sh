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
grep -F 'if [ "${1:-}" = "completion" ]; then' "$wrapper" >/dev/null || fail "wrapper must special-case completion subcommand"
grep -F 'exec "$raw_opencode_binary" "$@"' "$wrapper" >/dev/null || fail "wrapper must execute raw opencode binary directly for completion subcommand"
grep -F 'nono_secret_env_emit_exports' "$wrapper" >/dev/null || fail "wrapper must call nono_secret_env_emit_exports"
grep -F 'exec sudo -n -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$runtime_xdg_state_home" "$nono_binary" run --profile "$profile_path" -- "$setpriv_binary" --reuid="$agent_uid" --regid="$agent_gid" --clear-groups -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$opencode_xdg_state_home" OPENCODE_CONFIG_CONTENT="$opencode_provider_runtime_json" "$raw_opencode_binary" "$@"' "$wrapper" >/dev/null || fail "wrapper must run nono as root and drop to agent via setpriv inside sandbox"
grep -F 'HUB_NONO_PROVIDER_SECRET_DIR' "$wrapper" >/dev/null || fail "wrapper must honor HUB_NONO_PROVIDER_SECRET_DIR"
grep -F 'HUB_NONO_SECRET_HELPER_SUDO' "$wrapper" >/dev/null || fail "wrapper must require HUB_NONO_SECRET_HELPER_SUDO contract"
grep -F 'HUB_NONO_AGENT_USER' "$wrapper" >/dev/null || fail "wrapper must require HUB_NONO_AGENT_USER contract"
grep -F 'HUB_NONO_BINARY' "$wrapper" >/dev/null || fail "wrapper must support explicit nono binary contract"
grep -F 'HUB_NONO_SET_PRIV_BINARY' "$wrapper" >/dev/null || fail "wrapper must support explicit setpriv binary contract"
grep -F 'HUB_NONO_RUNTIME_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime HOME contract"
grep -F 'HUB_NONO_RUNTIME_XDG_CONFIG_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime XDG config contract"
grep -F 'HUB_NONO_RUNTIME_XDG_CACHE_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime XDG cache contract"
grep -F 'HUB_NONO_RUNTIME_XDG_DATA_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime XDG data contract"
grep -F 'HUB_NONO_RUNTIME_XDG_STATE_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime XDG state contract"
grep -F 'HUB_OPENCODE_RUNTIME_XDG_STATE_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit opencode runtime XDG state contract"
grep -F 'OPENCODE_PROVIDER_RUNTIME_PATH' "$wrapper" >/dev/null || fail "wrapper must support canonical generated provider runtime path contract"
grep -F 'OPENCODE_RAW_BINARY' "$wrapper" >/dev/null || fail "wrapper must support explicit raw opencode binary contract"
grep -F '$source_root/.config/opencode/provider-runtime.json' "$wrapper" >/dev/null || fail "wrapper must default runtime provider config path to install-branch output"
grep -F 'sudo -n -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$runtime_xdg_state_home" "$nono_binary" run --profile "$profile_path"' "$wrapper" >/dev/null || fail "wrapper must launch nono under constrained root sudo path"

tmp_root="$(mktemp -d "$repo_root/.tmp-opencode-wrapper-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

install_root="$tmp_root/install-root"
helper_root="$install_root/scripts/lib"
profile_root="$install_root/.config/nono/profiles"
secret_root="$tmp_root/secrets"
mock_bin="$tmp_root/mock-bin"
provider_runtime="$tmp_root/provider-runtime.json"
raw_binary="$tmp_root/opencode-real"
setpriv_binary="$mock_bin/setpriv"

mkdir -p "$helper_root" "$profile_root" "$secret_root" "$mock_bin"

cp "$repo_root/scripts/lib/nono-secret-env.sh" "$helper_root/nono-secret-env.sh"
cp "$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$profile_root/devspace-opencode-secure.jsonc"

cat >"$raw_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$raw_binary"

printf 'gpt_uio_red_api_key-value\n' >"$secret_root/gpt_uio_red_api_key"

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
printf 'sudo-user=%s cmd=%s\n' "$user" "$*" >"${MOCK_SUDO_LOG:?MOCK_SUDO_LOG must be set}"

if [ "${1:-}" = "--" ]; then
  shift
fi
"$@"
EOF
chmod +x "$mock_bin/sudo"

cat >"$setpriv_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--" ]; then
    shift
    break
  fi
  shift
done
"$@"
EOF
chmod +x "$setpriv_binary"

arg_log="$tmp_root/nono-args.log"
env_log="$tmp_root/nono-env.log"
sudo_log="$tmp_root/sudo.log"

PATH="$mock_bin:$PATH" \
HUB_INSTALL_BRANCH_DIR="$install_root" \
HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" \
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' \
HUB_NONO_AGENT_USER='agent' \
HUB_NONO_BINARY="$mock_bin/nono" \
HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" \
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
HUB_NONO_BINARY="$mock_bin/nono" \
HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" \
OPENCODE_RAW_BINARY="$raw_binary" \
MOCK_NONO_ARG_LOG="$arg_log" \
MOCK_NONO_ENV_LOG="$env_log" \
MOCK_SUDO_LOG="$sudo_log" \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should execute using install-branch default provider runtime output path"

if env -u HUB_NONO_SECRET_HELPER_SUDO PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/no-sudo.err" 2>&1; then
  fail "wrapper should fail when HUB_NONO_SECRET_HELPER_SUDO is missing"
fi

grep -F 'refused: HUB_NONO_SECRET_HELPER_SUDO must be set to constrained non-interactive sudo invocation' "$tmp_root/no-sudo.err" >/dev/null || fail "wrapper should surface missing HUB_NONO_SECRET_HELPER_SUDO contract"

if env -u HUB_NONO_AGENT_USER PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/no-agent.err" 2>&1; then
  fail "wrapper should fail when HUB_NONO_AGENT_USER is missing"
fi

grep -F 'refused: HUB_NONO_AGENT_USER must be set to non-sudo agent username' "$tmp_root/no-agent.err" >/dev/null || fail "wrapper should surface missing HUB_NONO_AGENT_USER contract"

grep -F 'sudo-user=root' "$sudo_log" >/dev/null || fail "wrapper should run nono as root via constrained sudo path"

grep -F -- '--profile' "$arg_log" >/dev/null || fail "wrapper should pass profile argument to nono"
grep -F "$install_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$arg_log" >/dev/null || fail "wrapper should point nono to install-branch secure profile"
grep -F -- '--reuid=' "$arg_log" >/dev/null || fail "wrapper should include setpriv reuid drop inside nono command"
grep -F -- '--regid=' "$arg_log" >/dev/null || fail "wrapper should include setpriv regid drop inside nono command"
grep -F -- '--clear-groups -- /usr/bin/env' "$arg_log" >/dev/null || fail "wrapper should clear groups before launching opencode inside nono sandbox"
grep -F -- '-- /usr/bin/env HOME=/home/vscode XDG_CONFIG_HOME=/tmp XDG_CACHE_HOME=/tmp XDG_DATA_HOME=/tmp XDG_STATE_HOME=/tmp OPENCODE_CONFIG_CONTENT=' "$arg_log" >/dev/null || fail "wrapper should inject pinned runtime HOME/XDG and provider config into opencode process"
grep -F -- "$raw_binary --version" "$arg_log" >/dev/null || fail "wrapper should launch configured raw opencode binary through nono"
grep -F 'sudo-user=root' "$sudo_log" >/dev/null || fail "wrapper should run nono/opencode command as root before dropping with setpriv"
grep -F 'HOME=/home/vscode' "$sudo_log" >/dev/null || fail "wrapper should pin HOME during sudo user-switch command"
grep -F 'XDG_CONFIG_HOME=/tmp' "$sudo_log" >/dev/null || fail "wrapper should pin XDG config home during sudo user-switch command"
grep -F 'XDG_STATE_HOME=/home/agent/.local/state' "$sudo_log" >/dev/null || fail "wrapper should pin nono XDG state home during sudo user-switch command"

cat >"$tmp_root/provider-runtime-invalid.json" <<'JSON'
{
  "enabled_providers": ["openai"],
  "provider": "invalid"
}
JSON

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-invalid.json" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/invalid-runtime.err" 2>&1; then
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

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-invalid-key.json" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/invalid-runtime-key.err" 2>&1; then
  fail "wrapper should fail when generated provider runtime output contains unsupported keys"
fi

grep -F 'refused: generated provider runtime output contains unsupported keys' "$tmp_root/invalid-runtime-key.err" >/dev/null || fail "wrapper should explain unsupported runtime key failure"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$tmp_root/not-executable-opencode" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/raw-binary.err" 2>&1; then
  fail "wrapper should fail when OPENCODE_RAW_BINARY is not executable"
fi

grep -F 'refused: raw opencode binary not executable at' "$tmp_root/raw-binary.err" >/dev/null || fail "wrapper should explain raw opencode binary executable contract failure"

grep -F 'GPT_UIO_RED_API_KEY=gpt_uio_red_api_key-value' "$env_log" >/dev/null || fail "wrapper should export red key from mounted secret when gpt-uio-red is enabled"
grep -F 'OPENAI_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require openai key when openai has no runtime provider payload entry"
grep -F 'ANTHROPIC_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require anthropic key when anthropic provider is disabled"
grep -F 'GITHUB_TOKEN=' "$env_log" >/dev/null || fail "wrapper should not require github token when github-copilot provider is disabled"
grep -F 'GPT_UIO_YELLOW_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require yellow key when gpt-uio-yellow provider is disabled"

rm -f "$secret_root/gpt_uio_red_api_key"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/missing-enabled-secret.err" 2>&1; then
  fail "wrapper should fail when an enabled provider secret is missing"
fi

grep -F 'refused: missing nono provider secret file:' "$tmp_root/missing-enabled-secret.err" >/dev/null || fail "wrapper should report missing secret file for enabled provider"

completion_log="$tmp_root/completion.log"
rm -f "$completion_log"

cat >"$tmp_root/opencode-completion-raw" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'RAW-COMPLETION:%s\n' "$*"
EOF
chmod +x "$tmp_root/opencode-completion-raw"

if ! PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$tmp_root/opencode-completion-raw" MOCK_NONO_ARG_LOG="$completion_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" completion zsh >"$tmp_root/completion.out" 2>&1; then
  fail "wrapper should execute completion subcommand directly through raw opencode binary"
fi

grep -F 'RAW-COMPLETION:completion zsh' "$tmp_root/completion.out" >/dev/null || fail "wrapper should emit raw completion output"

if [ -s "$completion_log" ]; then
  fail "wrapper completion subcommand should bypass nono invocation"
fi

printf 'PASS test_opencode_secure_wrapper_contract\n'
