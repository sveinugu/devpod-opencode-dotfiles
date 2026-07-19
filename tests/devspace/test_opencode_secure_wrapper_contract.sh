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
grep -F 'exec sudo -n -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$runtime_xdg_state_home" PATH="$runtime_path" LD_PRELOAD= LD_LIBRARY_PATH= PYTHONPATH= DYLD_INSERT_LIBRARIES= "$setpriv_binary" --reuid="$agent_uid" --regid="$agent_gid" --clear-groups --inh-caps=-all --ambient-caps=-all --bounding-set=-all --nnp "$nono_binary" run --profile "$profile_path" -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$opencode_xdg_state_home" OPENCODE_CONFIG_CONTENT="$opencode_provider_runtime_json" "$raw_opencode_binary" "$@"' "$wrapper" >/dev/null || fail "wrapper must drop to agent with setpriv before nono launch"
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
grep -F 'HUB_NONO_PROFILE_TEMPLATE_PATH' "$wrapper" >/dev/null || fail "wrapper must support explicit profile template path override"
grep -F 'HUB_OPENCODE_RUNTIME_XDG_STATE_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit opencode runtime XDG state contract"
grep -F 'OPENCODE_PROVIDER_RUNTIME_PATH' "$wrapper" >/dev/null || fail "wrapper must support canonical generated provider runtime path contract"
grep -F 'OPENCODE_RAW_BINARY' "$wrapper" >/dev/null || fail "wrapper must support explicit raw opencode binary contract"
grep -F '$source_root/.config/opencode/provider-runtime.json' "$wrapper" >/dev/null || fail "wrapper must default runtime provider config path to install-branch output"
grep -F '/etc/nono/profiles/devspace-opencode-secure.jsonc' "$wrapper" >/dev/null || fail "wrapper must default profile template path to /etc/nono/profiles"
grep -F '/usr/local/bin/nono' "$wrapper" >/dev/null || fail "wrapper must default nono binary path to /usr/local/bin/nono"
grep -F 'sudo -n -- /usr/bin/env HOME="$runtime_home" XDG_CONFIG_HOME="$runtime_xdg_config_home" XDG_CACHE_HOME="$runtime_xdg_cache_home" XDG_DATA_HOME="$runtime_xdg_data_home" XDG_STATE_HOME="$runtime_xdg_state_home" PATH="$runtime_path" LD_PRELOAD= LD_LIBRARY_PATH= PYTHONPATH= DYLD_INSERT_LIBRARIES= "$setpriv_binary" --reuid="$agent_uid" --regid="$agent_gid" --clear-groups --inh-caps=-all --ambient-caps=-all --bounding-set=-all --nnp "$nono_binary" run --profile "$profile_path"' "$wrapper" >/dev/null || fail "wrapper must launch nono through setpriv-before-nono chain"
grep -F 'HUB_NONO_RUNTIME_PATH' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime PATH contract"

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
printf 'gpt_uio_yellow_api_key-value\n' >"$secret_root/gpt_uio_yellow_api_key"

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
if [ -n "${MOCK_NONO_INTERCEPT_CA_PATH:-}" ]; then
  export SSL_CERT_FILE="$MOCK_NONO_INTERCEPT_CA_PATH"
  export REQUESTS_CA_BUNDLE="$MOCK_NONO_INTERCEPT_CA_PATH"
  export NODE_EXTRA_CA_CERTS="$MOCK_NONO_INTERCEPT_CA_PATH"
  export CURL_CA_BUNDLE="$MOCK_NONO_INTERCEPT_CA_PATH"
  export GIT_SSL_CAINFO="$MOCK_NONO_INTERCEPT_CA_PATH"
fi
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
printf 'SSL_CERT_FILE=%s\n' "${SSL_CERT_FILE:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'REQUESTS_CA_BUNDLE=%s\n' "${REQUESTS_CA_BUNDLE:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'NODE_EXTRA_CA_CERTS=%s\n' "${NODE_EXTRA_CA_CERTS:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'CURL_CA_BUNDLE=%s\n' "${CURL_CA_BUNDLE:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'GIT_SSL_CAINFO=%s\n' "${GIT_SSL_CAINFO:-}" >>"$MOCK_NONO_ENV_LOG"
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
  if [[ "$1" == --reuid=* ]] || [[ "$1" == --regid=* ]] || [[ "$1" == --clear-groups ]] || [[ "$1" == --inh-caps=* ]] || [[ "$1" == --ambient-caps=* ]] || [[ "$1" == --bounding-set=* ]] || [[ "$1" == --nnp ]]; then
    shift
    continue
  fi
  break
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
HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" \
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
HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" \
OPENCODE_RAW_BINARY="$raw_binary" \
MOCK_NONO_ARG_LOG="$arg_log" \
MOCK_NONO_ENV_LOG="$env_log" \
MOCK_SUDO_LOG="$sudo_log" \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should execute using install-branch default provider runtime output path"

if env -u HUB_NONO_SECRET_HELPER_SUDO PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/no-sudo.err" 2>&1; then
  fail "wrapper should fail when HUB_NONO_SECRET_HELPER_SUDO is missing"
fi

grep -F 'refused: HUB_NONO_SECRET_HELPER_SUDO must be set to constrained non-interactive sudo invocation' "$tmp_root/no-sudo.err" >/dev/null || fail "wrapper should surface missing HUB_NONO_SECRET_HELPER_SUDO contract"

if env -u HUB_NONO_AGENT_USER PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/no-agent.err" 2>&1; then
  fail "wrapper should fail when HUB_NONO_AGENT_USER is missing"
fi

grep -F 'refused: HUB_NONO_AGENT_USER must be set to non-sudo agent username' "$tmp_root/no-agent.err" >/dev/null || fail "wrapper should surface missing HUB_NONO_AGENT_USER contract"

grep -F 'sudo-user=root' "$sudo_log" >/dev/null || fail "wrapper should run setpriv chain through constrained root sudo path"

grep -F -- '--profile' "$arg_log" >/dev/null || fail "wrapper should pass profile argument to nono"
if grep -F "$install_root/.config/nono/profiles/devspace-opencode-secure.jsonc" "$arg_log" >/dev/null; then
  fail "wrapper should use a generated nono profile filtered by enabled providers"
fi
grep -F -- '--reuid=' "$sudo_log" >/dev/null || fail "wrapper should set setpriv reuid before nono launch"
grep -F -- '--regid=' "$sudo_log" >/dev/null || fail "wrapper should set setpriv regid before nono launch"
grep -F -- '--clear-groups --inh-caps=-all --ambient-caps=-all --bounding-set=-all --nnp' "$sudo_log" >/dev/null || fail "wrapper should apply kernel-level setpriv drop flags before nono launch"
grep -F -- 'setpriv --reuid=' "$sudo_log" >/dev/null || fail "wrapper should invoke setpriv in sudo command chain"
grep -F -- ' run --profile ' "$sudo_log" >/dev/null || fail "wrapper should include nono launch in sudo command chain"
grep -F -- '-- /usr/bin/env HOME=/home/vscode XDG_CONFIG_HOME=/tmp XDG_CACHE_HOME=/tmp XDG_DATA_HOME=/tmp XDG_STATE_HOME=/tmp OPENCODE_CONFIG_CONTENT=' "$arg_log" >/dev/null || fail "wrapper should inject pinned runtime HOME/XDG and provider config into opencode process"
grep -F -- "$raw_binary --version" "$arg_log" >/dev/null || fail "wrapper should launch configured raw opencode binary through nono"
grep -F 'sudo-user=root' "$sudo_log" >/dev/null || fail "wrapper should run sudo as root only for setpriv handoff"
grep -F 'HOME=/home/vscode' "$sudo_log" >/dev/null || fail "wrapper should pin HOME during sudo user-switch command"
grep -F 'XDG_CONFIG_HOME=/tmp' "$sudo_log" >/dev/null || fail "wrapper should pin XDG config home during sudo user-switch command"
grep -F 'XDG_STATE_HOME=/var/lib/nono/state' "$sudo_log" >/dev/null || fail "wrapper should pin nono XDG state home during sudo user-switch command"
grep -F 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$sudo_log" >/dev/null || fail "wrapper should pin PATH during root-to-agent setpriv handoff"
grep -F 'LD_PRELOAD=' "$sudo_log" >/dev/null || fail "wrapper should clear LD_PRELOAD before setpriv handoff"
grep -F 'LD_LIBRARY_PATH=' "$sudo_log" >/dev/null || fail "wrapper should clear LD_LIBRARY_PATH before setpriv handoff"
grep -F 'PYTHONPATH=' "$sudo_log" >/dev/null || fail "wrapper should clear PYTHONPATH before setpriv handoff"
grep -F 'DYLD_INSERT_LIBRARIES=' "$sudo_log" >/dev/null || fail "wrapper should clear DYLD_INSERT_LIBRARIES before setpriv handoff"

cat >"$tmp_root/provider-runtime-invalid.json" <<'JSON'
{
  "enabled_providers": ["openai"],
  "provider": "invalid"
}
JSON

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-invalid.json" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/invalid-runtime.err" 2>&1; then
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

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-invalid-key.json" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/invalid-runtime-key.err" 2>&1; then
  fail "wrapper should fail when generated provider runtime output contains unsupported keys"
fi

grep -F 'refused: generated provider runtime output contains unsupported keys' "$tmp_root/invalid-runtime-key.err" >/dev/null || fail "wrapper should explain unsupported runtime key failure"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$tmp_root/not-executable-opencode" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/raw-binary.err" 2>&1; then
  fail "wrapper should fail when OPENCODE_RAW_BINARY is not executable"
fi

grep -F 'refused: raw opencode binary not executable at' "$tmp_root/raw-binary.err" >/dev/null || fail "wrapper should explain raw opencode binary executable contract failure"

grep -F 'GPT_UIO_RED_API_KEY=gpt_uio_red_api_key-value' "$env_log" >/dev/null || fail "wrapper should export red key from mounted secret when gpt-uio-red is enabled"
grep -F 'OPENAI_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require openai key when openai has no runtime provider payload entry"
grep -F 'ANTHROPIC_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require anthropic key when anthropic provider is disabled"
grep -F 'GITHUB_TOKEN=' "$env_log" >/dev/null || fail "wrapper should not require github token when github-copilot provider is disabled"
grep -F 'GPT_UIO_YELLOW_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require yellow key when gpt-uio-yellow provider is disabled"

cat >"$tmp_root/provider-runtime-yellow-only.json" <<'JSON'
{
  "enabled_providers": [
    "gpt-uio-yellow",
    "openai"
  ],
  "provider": {
    "gpt-uio-yellow": {
      "api": "openai",
      "options": {
        "baseURL": "https://gpt.uio.no/api/v1"
      },
      "models": {
        "gpt-5-mini": {
          "id": "gpt-5-mini",
          "name": "GPT-5 mini"
        }
      }
    }
  }
}
JSON

PATH="$mock_bin:$PATH" \
HUB_INSTALL_BRANCH_DIR="$install_root" \
HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" \
HUB_NONO_SECRET_HELPER_SUDO='sudo -n' \
HUB_NONO_AGENT_USER='agent' \
HUB_NONO_BINARY="$mock_bin/nono" \
HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" \
HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" \
OPENCODE_PROVIDER_RUNTIME_PATH="$tmp_root/provider-runtime-yellow-only.json" \
OPENCODE_RAW_BINARY="$raw_binary" \
MOCK_NONO_ARG_LOG="$arg_log" \
MOCK_NONO_ENV_LOG="$env_log" \
MOCK_SUDO_LOG="$sudo_log" \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should execute when red provider is disabled and yellow provider is enabled"

profile_used="$(python3 - "$arg_log" <<'PY'
import shlex
import sys

parts = shlex.split(open(sys.argv[1], 'r', encoding='utf-8').read().strip())
for index, token in enumerate(parts[:-1]):
    if token == '--profile':
        print(parts[index + 1])
        break
else:
    raise SystemExit('')
PY
)"

[ -n "$profile_used" ] || fail "wrapper should pass a generated nono profile path"
[ -f "$profile_used" ] || fail "wrapper should generate profile file for enabled provider set"

grep -F '"gpt-uio-yellow"' "$profile_used" >/dev/null || fail "generated profile should keep yellow credential route when yellow provider is enabled"
if grep -F '"gpt-uio-red"' "$profile_used" >/dev/null; then
  fail "generated profile should remove red credential route when red provider is disabled"
fi

grep -F 'GPT_UIO_YELLOW_API_KEY=gpt_uio_yellow_api_key-value' "$env_log" >/dev/null || fail "wrapper should export yellow key from mounted secret when gpt-uio-yellow is enabled"
grep -F 'GPT_UIO_RED_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require red key when gpt-uio-red provider is disabled"

rm -f "$secret_root/gpt_uio_red_api_key"

if PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$raw_binary" MOCK_NONO_ARG_LOG="$arg_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" --version >"$tmp_root/missing-enabled-secret.err" 2>&1; then
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

if ! PATH="$mock_bin:$PATH" HUB_INSTALL_BRANCH_DIR="$install_root" HUB_NONO_PROVIDER_SECRET_DIR="$secret_root" HUB_NONO_SECRET_HELPER_SUDO='sudo -n' HUB_NONO_AGENT_USER='agent' HUB_NONO_BINARY="$mock_bin/nono" HUB_NONO_SET_PRIV_BINARY="$setpriv_binary" HUB_NONO_PROFILE_TEMPLATE_PATH="$profile_root/devspace-opencode-secure.jsonc" OPENCODE_PROVIDER_RUNTIME_PATH="$provider_runtime" OPENCODE_RAW_BINARY="$tmp_root/opencode-completion-raw" MOCK_NONO_ARG_LOG="$completion_log" MOCK_NONO_ENV_LOG="$env_log" MOCK_SUDO_LOG="$sudo_log" bash "$wrapper" completion zsh >"$tmp_root/completion.out" 2>&1; then
  fail "wrapper should execute completion subcommand directly through raw opencode binary"
fi

grep -F 'RAW-COMPLETION:completion zsh' "$tmp_root/completion.out" >/dev/null || fail "wrapper should emit raw completion output"

if [ -s "$completion_log" ]; then
  fail "wrapper completion subcommand should bypass nono invocation"
fi

printf 'PASS test_opencode_secure_wrapper_contract\n'
