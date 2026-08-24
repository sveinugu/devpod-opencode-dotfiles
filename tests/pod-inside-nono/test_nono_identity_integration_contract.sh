#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_identity_integration_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_nono_identity_integration_contract'

wrapper="$repo_root/.config/opencode/bin/opencode"
helper="$repo_root/scripts/lib/nono-secret-env.sh"
dockerfile="$repo_root/Dockerfile"

[ -f "$wrapper" ] || fail "secure opencode wrapper not found"
[ -f "$helper" ] || fail "nono secret helper not found"
[ -f "$dockerfile" ] || fail "Dockerfile not found"

grep -F 'sudo -n /bin/cat' "$helper" >/dev/null || fail "helper must perform privileged reads via sudo -n /bin/cat"
grep -F 'sudo -n -- "$launch_helper" --setpriv-binary "$setpriv_binary" --nono-binary "$nono_binary" --profile "$profile_path" --agent-uid "$agent_uid" --agent-gid "$agent_gid" --runtime-home "$runtime_home" --runtime-xdg-config-home "$runtime_xdg_config_home" --runtime-xdg-cache-home "$runtime_xdg_cache_home" --runtime-xdg-data-home "$runtime_xdg_data_home" --runtime-xdg-state-home "$runtime_xdg_state_home" --opencode-xdg-state-home "$opencode_xdg_state_home" --runtime-path "$runtime_path" --runtime-bash-env "$runtime_bash_env" --opencode-config-content "$opencode_provider_runtime_json" --raw-opencode-binary "$raw_opencode_binary" -- "$@"' "$wrapper" >/dev/null || fail "wrapper must launch through constrained helper before setpriv+nono runtime chain"

grep -F 'NOPASSWD: /bin/cat /var/run/secrets/nono/providers/*' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for mounted provider secret reads"
grep -F 'NOPASSWD: /usr/bin/mkdir -p /home/agent/.config' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for agent config dir bootstrap"
grep -F 'NOPASSWD: /usr/bin/rm -rf /home/agent/.config/opencode' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for replacing stale agent opencode config target"
grep -F 'NOPASSWD: /usr/bin/ln -sfn /workspaces/dotfiles/main/.config/opencode /home/agent/.config/opencode' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for main install-branch agent config symlink"
grep -F 'NOPASSWD: /usr/bin/ln -sfn /workspaces/dotfiles/work/*/.config/opencode /home/agent/.config/opencode' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for worktree install-branch agent config symlink"
grep -F 'NOPASSWD: /usr/local/libexec/dotfiles-launch-opencode-nono --setpriv-binary * --nono-binary * --profile * --agent-uid * --agent-gid * --runtime-home * --runtime-xdg-config-home * --runtime-xdg-cache-home * --runtime-xdg-data-home * --runtime-xdg-state-home * --opencode-xdg-state-home * --runtime-path * --runtime-bash-env * --opencode-config-content * --raw-opencode-binary * -- *' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for launch-helper runtime chain"
grep -F 'NOPASSWD: /usr/local/libexec/dotfiles-launch-opencode-nono --setpriv-binary * --nono-binary * --profile * --agent-uid * --agent-gid * --runtime-home * --runtime-xdg-config-home * --runtime-xdg-cache-home * --runtime-xdg-data-home * --runtime-xdg-state-home * --opencode-xdg-state-home * --runtime-path * --runtime-bash-env * --opencode-config-content * --raw-opencode-binary * --' "$dockerfile" >/dev/null || fail "Dockerfile must include constrained sudoers rule for launch-helper invocations without trailing argv"
grep -F 'Defaults:vscode env_keep += "OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN GPT_UIO_YELLOW_API_KEY GPT_UIO_RED_API_KEY"' "$dockerfile" >/dev/null || fail "Dockerfile must preserve provider secret env vars across constrained sudo user switch"
grep -F 'if [ "${HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL:-0}" = "1" ]; then' "$dockerfile" >/dev/null || fail "Dockerfile must branch on HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL for debug sudo mode"
grep -F "'vscode ALL=(ALL) NOPASSWD:ALL'" "$dockerfile" >/dev/null || fail "Dockerfile debug sudo mode must install explicit broad vscode sudoers contract"
grep -F 'sudo install -o root -g root -m 0440 /tmp/99-dotfiles-vscode-debug /etc/sudoers.d/99-dotfiles-vscode-debug' "$dockerfile" >/dev/null || fail "Dockerfile debug sudo mode must install root-owned debug sudoers file"
grep -F 'sudo visudo -cf /etc/sudoers.d/99-dotfiles-vscode-debug' "$dockerfile" >/dev/null || fail "Dockerfile debug sudo mode must validate debug sudoers file"

python3 - "$wrapper" "$dockerfile" <<'PY'
import re
import sys

wrapper_path, dockerfile_path = sys.argv[1:]

with open(wrapper_path, 'r', encoding='utf-8') as fh:
    wrapper = fh.read()

with open(dockerfile_path, 'r', encoding='utf-8') as fh:
    dockerfile = fh.read()

if '/usr/local/libexec/dotfiles-launch-opencode-nono --setpriv-binary * --nono-binary * --profile * --agent-uid * --agent-gid * --runtime-home * --runtime-xdg-config-home * --runtime-xdg-cache-home * --runtime-xdg-data-home * --runtime-xdg-state-home * --opencode-xdg-state-home * --runtime-path * --runtime-bash-env * --opencode-config-content * --raw-opencode-binary * -- *' not in dockerfile:
    raise SystemExit('dockerfile sudoers rule does not match launch-helper contract')

if 'launch_helper="${HUB_NONO_LAUNCH_HELPER:-/usr/local/libexec/dotfiles-launch-opencode-nono}"' not in wrapper:
    raise SystemExit('wrapper missing default root-owned launch helper contract')
PY

if grep -F '/etc/sudoers.d/vscode' "$dockerfile" | grep -v 'rm -f' | grep -v 'HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL' >/dev/null; then
  fail "Dockerfile must not keep or recreate /etc/sudoers.d/vscode broad sudoers grant"
fi

printf 'PASS test_nono_identity_integration_contract\n'
