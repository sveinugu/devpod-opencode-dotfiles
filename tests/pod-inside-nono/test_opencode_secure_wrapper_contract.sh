#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_secure_wrapper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_opencode_secure_wrapper_contract'

wrapper="$repo_root/.config/opencode/bin/opencode"

[ -f "$wrapper" ] || fail "secure opencode wrapper not found"

grep -F 'source "$secret_helper"' "$wrapper" >/dev/null || fail "wrapper must source nono secret helper"
grep -F 'if [ "${1:-}" = "completion" ]; then' "$wrapper" >/dev/null || fail "wrapper must special-case completion subcommand"
grep -F 'exec "$raw_opencode_binary" "$@"' "$wrapper" >/dev/null || fail "wrapper must execute raw opencode binary directly for completion subcommand"
grep -F 'nono_secret_env_emit_exports' "$wrapper" >/dev/null || fail "wrapper must call nono_secret_env_emit_exports"
grep -F 'exec sudo -n -- "$launch_helper" --setpriv-binary "$setpriv_binary" --nono-binary "$nono_binary" --profile "$profile_path" --agent-uid "$agent_uid" --agent-gid "$agent_gid" --runtime-home "$runtime_home" --runtime-xdg-config-home "$runtime_xdg_config_home" --runtime-xdg-cache-home "$runtime_xdg_cache_home" --runtime-xdg-data-home "$runtime_xdg_data_home" --runtime-xdg-state-home "$runtime_xdg_state_home" --opencode-xdg-state-home "$opencode_xdg_state_home" --runtime-path "$runtime_path" --opencode-config-content "$opencode_provider_runtime_json" --raw-opencode-binary "$raw_opencode_binary" -- "$@"' "$wrapper" >/dev/null || fail "wrapper must launch through constrained helper before setpriv+nono runtime chain"
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
grep -F 'HUB_NONO_GENERATED_PROFILE_WRITER' "$wrapper" >/dev/null || fail "wrapper must support explicit generated nono profile writer contract"
grep -F 'HUB_NONO_GENERATED_PROFILE_DIR' "$wrapper" >/dev/null || fail "wrapper must support explicit generated nono profile output directory contract"
grep -F 'HUB_NONO_LAUNCH_HELPER' "$wrapper" >/dev/null || fail "wrapper must support explicit launch helper path contract"
grep -F 'HUB_NONO_PROFILE_TEMPLATE_PATH' "$wrapper" >/dev/null || fail "wrapper must support explicit profile template path override"
grep -F 'HUB_OPENCODE_RUNTIME_XDG_STATE_HOME' "$wrapper" >/dev/null || fail "wrapper must support explicit opencode runtime XDG state contract"
grep -F 'OPENCODE_PROVIDER_RUNTIME_PATH' "$wrapper" >/dev/null || fail "wrapper must support canonical generated provider runtime path contract"
grep -F 'OPENCODE_RAW_BINARY' "$wrapper" >/dev/null || fail "wrapper must support explicit raw opencode binary contract"
grep -F '$source_root/.config/opencode/provider-runtime.json' "$wrapper" >/dev/null || fail "wrapper must default runtime provider config path to install-branch output"
grep -F '/etc/nono/profiles/devspace-opencode-secure.jsonc' "$wrapper" >/dev/null || fail "wrapper must default profile template path to /etc/nono/profiles"
grep -F '/usr/local/libexec/dotfiles-generate-nono-profile' "$wrapper" >/dev/null || fail "wrapper must default generated profile writer path to root-owned helper"
grep -F '/usr/local/libexec/dotfiles-launch-opencode-nono' "$wrapper" >/dev/null || fail "wrapper must default launch helper path to root-owned helper"
grep -F '/etc/nono/profiles/runtime' "$wrapper" >/dev/null || fail "wrapper must default generated profile output directory to root-owned runtime profile path"
grep -F '/usr/local/bin/nono' "$wrapper" >/dev/null || fail "wrapper must default nono binary path to /usr/local/bin/nono"
grep -F '/usr/local/bin/opencode-raw' "$wrapper" >/dev/null || fail "wrapper must default raw opencode binary path to root-owned /usr/local/bin/opencode-raw"
grep -F 'unset NONO_CAP_FILE NONO_TOOL_SANDBOX_SOCKET NONO_TOOL_SANDBOX_SHIM_DIR NONO_PROXY_TOKEN NONO_NO_PROXY' "$wrapper" >/dev/null || fail "wrapper must scrub inherited nono runtime session environment before nested launch"
grep -F 'sudo -n -- "$launch_helper" --setpriv-binary "$setpriv_binary" --nono-binary "$nono_binary" --profile "$profile_path" --agent-uid "$agent_uid" --agent-gid "$agent_gid" --runtime-home "$runtime_home" --runtime-xdg-config-home "$runtime_xdg_config_home" --runtime-xdg-cache-home "$runtime_xdg_cache_home" --runtime-xdg-data-home "$runtime_xdg_data_home" --runtime-xdg-state-home "$runtime_xdg_state_home" --opencode-xdg-state-home "$opencode_xdg_state_home" --runtime-path "$runtime_path" --opencode-config-content "$opencode_provider_runtime_json" --raw-opencode-binary "$raw_opencode_binary" -- "$@"' "$wrapper" >/dev/null || fail "wrapper must launch nono through constrained launch helper chain"
grep -F 'exec sudo -n -- "$launch_helper" --setpriv-binary "$setpriv_binary" --nono-binary "$nono_binary" --profile "$profile_path" --agent-uid "$agent_uid" --agent-gid "$agent_gid" --runtime-home "$runtime_home" --runtime-xdg-config-home "$runtime_xdg_config_home" --runtime-xdg-cache-home "$runtime_xdg_cache_home" --runtime-xdg-data-home "$runtime_xdg_data_home" --runtime-xdg-state-home "$runtime_xdg_state_home" --opencode-xdg-state-home "$opencode_xdg_state_home" --runtime-path "$runtime_path" --opencode-config-content "$opencode_provider_runtime_json" --raw-opencode-binary "$raw_opencode_binary" -- "$@"' "$wrapper" >/dev/null || fail "wrapper must always append end-of-options marker and argv passthrough"
grep -F 'HUB_NONO_RUNTIME_PATH' "$wrapper" >/dev/null || fail "wrapper must support explicit runtime PATH contract"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_opencode_secure_wrapper_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_opencode_secure_wrapper_contract')"
trap 'rm -rf "$tmp_root"' EXIT

install_root="$tmp_root/install-root"
helper_root="$install_root/scripts/lib"
launch_helper="$helper_root/launch-opencode-nono.sh"
profile_root="$install_root/.config/nono/profiles"
secret_root="$tmp_root/secrets"
mock_bin="$tmp_root/mock-bin"
provider_runtime="$tmp_root/provider-runtime.json"
raw_binary="$tmp_root/opencode-raw"
setpriv_binary="$mock_bin/setpriv"
generated_profile_dir="$tmp_root/generated-profiles"
generated_profile_writer="$tmp_root/generate-nono-profile"
mock_passwd="$tmp_root/passwd"

mkdir -p "$helper_root" "$profile_root" "$secret_root" "$mock_bin" "$generated_profile_dir"

cp "$repo_root/scripts/lib/nono-secret-env.sh" "$helper_root/nono-secret-env.sh"
cp "$repo_root/scripts/lib/launch-opencode-nono.sh" "$launch_helper"
chmod +x "$launch_helper"
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

if [ "${MOCK_NONO_FAIL_ON_STALE_CAP:-0}" = "1" ] && [ -n "${NONO_CAP_FILE:-}" ]; then
  serialized_stdin_path="$({
    python3 - "$NONO_CAP_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    cap = json.load(fh)

for entry in cap.get('fs', []):
    if entry.get('original') == '/dev/stdin':
        path = entry.get('path', '')
        if isinstance(path, str):
            print(path)
        break
PY
  } || true)"
  current_stdin_path="$({
    python3 - <<'PY'
from pathlib import Path

try:
    print(Path('/proc/self/fd/0').readlink())
except OSError:
    print('/dev/null')
PY
  } || true)"
  if [ -n "$serialized_stdin_path" ] && [ "$serialized_stdin_path" != "$current_stdin_path" ]; then
    printf "nono: Configuration parse error: sandbox state path drifted at reload: serialized resolved=%s, actual resolved=%s\n" "$serialized_stdin_path" "$current_stdin_path" >&2
    exit 1
  fi
fi

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
# Skip known nono runtime flags appended by the launch helper
while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow-cwd|--no-rollback-prompt) shift ;;
    --) shift; break ;;
    *) break ;;
  esac
done
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
printf 'NONO_CAP_FILE=%s\n' "${NONO_CAP_FILE:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'NONO_TOOL_SANDBOX_SOCKET=%s\n' "${NONO_TOOL_SANDBOX_SOCKET:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'NONO_TOOL_SANDBOX_SHIM_DIR=%s\n' "${NONO_TOOL_SANDBOX_SHIM_DIR:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'NONO_PROXY_TOKEN=%s\n' "${NONO_PROXY_TOKEN:-}" >>"$MOCK_NONO_ENV_LOG"
printf 'NONO_NO_PROXY=%s\n' "${NONO_NO_PROXY:-}" >>"$MOCK_NONO_ENV_LOG"
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
printf 'sudo-user=%s cmd=%s\n' "$user" "$*" >>"${MOCK_SUDO_LOG:?MOCK_SUDO_LOG must be set}"

if [ "${1:-}" = "--" ]; then
  shift
fi
"$@"
EOF
chmod +x "$mock_bin/sudo"

cat >"$mock_bin/id" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -eq 2 ] && [ "$1" = "-u" ] && [ "$2" = "agent" ]; then
  printf '1001\n'
  exit 0
fi
if [ "$#" -eq 2 ] && [ "$1" = "-g" ] && [ "$2" = "agent" ]; then
  printf '1001\n'
  exit 0
fi
/usr/bin/id "$@"
EOF
chmod +x "$mock_bin/id"

cat >"$setpriv_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'setpriv-cmd=%s\n' "$*" >>"${MOCK_SETPRIV_LOG:?MOCK_SETPRIV_LOG must be set}"
printf 'HOME=%s\n' "${HOME:-}" >>"$MOCK_SETPRIV_LOG"
printf 'XDG_CONFIG_HOME=%s\n' "${XDG_CONFIG_HOME:-}" >>"$MOCK_SETPRIV_LOG"
printf 'XDG_STATE_HOME=%s\n' "${XDG_STATE_HOME:-}" >>"$MOCK_SETPRIV_LOG"
printf 'PATH=%s\n' "${PATH:-}" >>"$MOCK_SETPRIV_LOG"
printf 'LD_PRELOAD=%s\n' "${LD_PRELOAD:-}" >>"$MOCK_SETPRIV_LOG"
printf 'LD_LIBRARY_PATH=%s\n' "${LD_LIBRARY_PATH:-}" >>"$MOCK_SETPRIV_LOG"
printf 'PYTHONPATH=%s\n' "${PYTHONPATH:-}" >>"$MOCK_SETPRIV_LOG"
printf 'DYLD_INSERT_LIBRARIES=%s\n' "${DYLD_INSERT_LIBRARIES:-}" >>"$MOCK_SETPRIV_LOG"
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

cat >"$generated_profile_writer" <<'EOF'
#!/usr/bin/env python3
import argparse
import json
import os
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--template', required=True)
parser.add_argument('--runtime', required=True)
parser.add_argument('--output-dir', required=True)
args = parser.parse_args()

with open(args.template, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

with open(args.runtime, 'r', encoding='utf-8') as fh:
    runtime = json.load(fh)

enabled = runtime.get('enabled_providers')
if not isinstance(enabled, list):
    raise SystemExit('refused: generated provider runtime output must define enabled_providers as a list')

provider_to_credential = {
    'openai': 'openai',
    'anthropic': 'anthropic',
    'github-copilot': 'github-copilot',
    'gpt-uio-yellow': 'gpt-uio-yellow',
    'gpt-uio-red': 'gpt-uio-red',
}
managed_credential_names = set(provider_to_credential.values())
enabled_credential_names = {
    provider_to_credential[p]
    for p in enabled
    if p in provider_to_credential
}

network = profile.get('network')
credentials = network.get('credentials', [])
custom_credentials = network.get('custom_credentials', {})

network['credentials'] = [
    route for route in credentials
    if route not in managed_credential_names or route in enabled_credential_names
]
network['custom_credentials'] = {
    route: cfg
    for route, cfg in custom_credentials.items()
    if route not in managed_credential_names or route in enabled_credential_names
}

os.makedirs(args.output_dir, exist_ok=True)
fd, generated_path = tempfile.mkstemp(prefix='opencode-nono-profile-', suffix='.json', dir=args.output_dir)
os.close(fd)
with open(generated_path, 'w', encoding='utf-8') as fh:
    json.dump(profile, fh, indent=2)
    fh.write('\n')

os.chmod(generated_path, 0o644)
print(generated_path)
EOF
chmod +x "$generated_profile_writer"

arg_log="$tmp_root/nono-args.log"
env_log="$tmp_root/nono-env.log"
sudo_log="$tmp_root/sudo.log"
setpriv_log="$tmp_root/setpriv.log"

export HUB_NONO_GENERATED_PROFILE_DIR="$generated_profile_dir"
export HUB_NONO_GENERATED_PROFILE_WRITER="$generated_profile_writer"
export HUB_NONO_LAUNCH_HELPER="$launch_helper"
export MOCK_SETPRIV_LOG="$setpriv_log"

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
grep -F "$launch_helper" "$sudo_log" >/dev/null || fail "wrapper should invoke launch helper through constrained root sudo path"
grep -F -- '--setpriv-binary' "$sudo_log" >/dev/null || fail "wrapper should pass setpriv binary through launch helper contract"
grep -F -- '--nono-binary' "$sudo_log" >/dev/null || fail "wrapper should pass nono binary through launch helper contract"
grep -F -- '--reuid=' "$setpriv_log" >/dev/null || fail "launch helper should set setpriv reuid before nono launch"
grep -F -- '--regid=' "$setpriv_log" >/dev/null || fail "launch helper should set setpriv regid before nono launch"
grep -F -- '--clear-groups --inh-caps=-all --ambient-caps=-all --bounding-set=-all --nnp' "$setpriv_log" >/dev/null || fail "launch helper should apply kernel-level setpriv drop flags before nono launch"
grep -F -- ' run --profile ' "$setpriv_log" >/dev/null || fail "launch helper should include nono launch in setpriv command chain"
if grep -F -- '--silent' "$setpriv_log" >/dev/null; then
  fail "launch helper should not pass --silent to nono"
fi
grep -F -- '-- /usr/bin/env HOME=/home/agent XDG_CONFIG_HOME=/home/agent/.config XDG_CACHE_HOME=/home/agent/.cache XDG_DATA_HOME=/home/agent/.local/share XDG_STATE_HOME=/home/agent/.local/state OPENCODE_CONFIG_CONTENT=' "$arg_log" >/dev/null || fail "wrapper should inject pinned runtime HOME/XDG and provider config into opencode process"
grep -F -- "$raw_binary --version" "$arg_log" >/dev/null || fail "wrapper should launch configured raw opencode binary through nono"
grep -F 'sudo-user=root' "$sudo_log" >/dev/null || fail "wrapper should run sudo as root only for setpriv handoff"
grep -F 'HOME=/home/agent' "$setpriv_log" >/dev/null || fail "launch helper should pin HOME during setpriv handoff"
grep -F 'XDG_CONFIG_HOME=/home/agent/.config' "$setpriv_log" >/dev/null || fail "launch helper should pin XDG config home during setpriv handoff"
grep -F 'XDG_STATE_HOME=/home/agent/.local/state' "$setpriv_log" >/dev/null || fail "launch helper should pin runtime XDG state home during setpriv handoff"
grep -F 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "$setpriv_log" >/dev/null || fail "launch helper should pin PATH during setpriv handoff"
grep -F 'LD_PRELOAD=' "$setpriv_log" >/dev/null || fail "launch helper should clear LD_PRELOAD before setpriv handoff"
grep -F 'LD_LIBRARY_PATH=' "$setpriv_log" >/dev/null || fail "launch helper should clear LD_LIBRARY_PATH before setpriv handoff"
grep -F 'PYTHONPATH=' "$setpriv_log" >/dev/null || fail "launch helper should clear PYTHONPATH before setpriv handoff"
grep -F 'DYLD_INSERT_LIBRARIES=' "$setpriv_log" >/dev/null || fail "launch helper should clear DYLD_INSERT_LIBRARIES before setpriv handoff"

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

case "$profile_used" in
  "$generated_profile_dir"/*) ;;
  *) fail "wrapper should generate nono profile under HUB_NONO_GENERATED_PROFILE_DIR instead of /tmp" ;;
esac

profile_mode="$(python3 - "$profile_used" <<'PY'
import os
import stat
import sys

mode = stat.S_IMODE(os.stat(sys.argv[1]).st_mode)
print(oct(mode))
PY
)"

[ "$profile_mode" = "0o644" ] || fail "wrapper should chmod generated nono profile to 0644 so setpriv agent can read it"
grep -E -- "${generated_profile_writer//\//\\/} --template ${profile_root//\//\\/}/devspace-opencode-secure\.jsonc --runtime .* --output-dir ${generated_profile_dir//\//\\/}" "$sudo_log" >/dev/null || fail "wrapper should invoke generated profile writer through constrained sudo contract"

grep -F '"gpt-uio-yellow"' "$profile_used" >/dev/null || fail "generated profile should keep yellow credential route when yellow provider is enabled"
if grep -F '"gpt-uio-red"' "$profile_used" >/dev/null; then
  fail "generated profile should remove red credential route when red provider is disabled"
fi

grep -F 'GPT_UIO_YELLOW_API_KEY=gpt_uio_yellow_api_key-value' "$env_log" >/dev/null || fail "wrapper should export yellow key from mounted secret when gpt-uio-yellow is enabled"
grep -F 'GPT_UIO_RED_API_KEY=' "$env_log" >/dev/null || fail "wrapper should not require red key when gpt-uio-red provider is disabled"

cat >"$tmp_root/stale-nono-cap.json" <<'JSON'
{
  "fs": [
    {
      "original": "/dev/stdin",
      "path": "/dev/pts/2"
    }
  ]
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
MOCK_NONO_FAIL_ON_STALE_CAP='1' \
NONO_CAP_FILE="$tmp_root/stale-nono-cap.json" \
NONO_TOOL_SANDBOX_SOCKET='/tmp/stale-supervisor.sock' \
NONO_TOOL_SANDBOX_SHIM_DIR='/tmp/stale-shims' \
NONO_PROXY_TOKEN='stale-token' \
NONO_NO_PROXY='stale-no-proxy' \
bash "$wrapper" --version >/dev/null 2>&1 || fail "wrapper should scrub inherited nono session env to avoid stale --self state drift failures"

grep -F 'NONO_CAP_FILE=' "$env_log" >/dev/null || fail "wrapper should clear NONO_CAP_FILE before nested nono launch"
grep -F 'NONO_TOOL_SANDBOX_SOCKET=' "$env_log" >/dev/null || fail "wrapper should clear NONO_TOOL_SANDBOX_SOCKET before nested nono launch"
grep -F 'NONO_TOOL_SANDBOX_SHIM_DIR=' "$env_log" >/dev/null || fail "wrapper should clear NONO_TOOL_SANDBOX_SHIM_DIR before nested nono launch"
grep -F 'NONO_PROXY_TOKEN=' "$env_log" >/dev/null || fail "wrapper should clear NONO_PROXY_TOKEN before nested nono launch"
grep -F 'NONO_NO_PROXY=' "$env_log" >/dev/null || fail "wrapper should clear NONO_NO_PROXY before nested nono launch"

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
