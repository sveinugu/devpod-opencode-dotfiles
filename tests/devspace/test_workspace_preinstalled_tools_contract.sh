#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_preinstalled_tools_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
deployment="$repo_root/k8s/devspace-bare-hub/workspace-deployment.yaml"
dockerfile="$repo_root/Dockerfile"
provision_script="$repo_root/scripts/provision-workspace.sh"

[ -f "$deployment" ] || fail "workspace-deployment.yaml not found"
[ -f "$dockerfile" ] || fail "Dockerfile not found"
[ -f "$provision_script" ] || fail "provision-workspace.sh not found"

grep -Eq '^\s*mountPath:\s*/home/vscode\s*$' "$deployment" || fail "missing /home/vscode mount from PVC"
grep -Eq '^\s*subPath:\s*home-vscode\s*$' "$deployment" || fail "missing home-vscode PVC subPath"

if grep -F 'curl https://pyenv.run | zsh' "$dockerfile" >/dev/null; then
  fail "pyenv must not be image-installed; install at provision time"
fi

if grep -F 'curl -fsSL https://opencode.ai/install | zsh' "$dockerfile" >/dev/null; then
  fail "opencode must not be image-installed; install at provision time"
fi

if grep -F 'mkdir -p /home/vscode/.ssh' "$dockerfile" >/dev/null; then
  fail "/home/vscode setup must not happen in Dockerfile; PVC mount hides it"
fi

if grep -F 'mkdir -p /home/vscode/.local/share/opencode' "$dockerfile" >/dev/null; then
  fail "/home/vscode/.local/share/opencode setup must not happen in Dockerfile"
fi

if grep -F 'mkdir -p /home/vscode/.config/opencode' "$dockerfile" >/dev/null; then
  fail "/home/vscode/.config/opencode setup must not happen in Dockerfile"
fi

grep -F -- '--refresh-tools' "$provision_script" >/dev/null || fail "missing --refresh-tools contract in provision script"
grep -F 'https://pyenv.run' "$provision_script" >/dev/null || fail "missing pyenv provision installer"
grep -F 'https://nono.sh/install.sh' "$provision_script" >/dev/null || fail "missing nono provision installer"
grep -F 'https://opencode.ai/install' "$provision_script" >/dev/null || fail "missing opencode provision installer"
grep -F 'mkdir -p "$home_dir/.ssh" "$home_dir/.local/share/opencode"' "$provision_script" >/dev/null || fail "missing provision-time /home/vscode bootstrap directories"

grep -E 'useradd .*\bagent\b' "$dockerfile" >/dev/null || fail "Dockerfile must create dedicated non-sudo agent user"
if grep -E 'usermod\s+.*\bagent\b.*\bsudo\b|usermod\s+.*\bsudo\b.*\bagent\b|useradd\s+.*\bagent\b.*-G\s*.*\bsudo\b|adduser\s+\bagent\b\s+sudo' "$dockerfile" >/dev/null; then
  fail "Dockerfile must not grant sudo group membership to agent user"
fi

useradd_line="$(grep -nE 'useradd .*\bagent\b' "$dockerfile" | head -n1 | cut -d: -f1)"
user_vscode_line="$(grep -nE '^\s*USER\s+vscode\s*$' "$dockerfile" | head -n1 | cut -d: -f1)"

[ -n "$useradd_line" ] || fail "unable to locate agent useradd line in Dockerfile"
[ -n "$user_vscode_line" ] || fail "unable to locate USER vscode line in Dockerfile"

if [ "$useradd_line" -gt "$user_vscode_line" ]; then
  fail "agent useradd must run as root before USER vscode is set"
fi

grep -F '/etc/sudoers.d/99-dotfiles-nono' "$dockerfile" >/dev/null || fail "Dockerfile must install constrained sudoers contract for non-interactive agent-run helper path"
grep -F '/bin/cat /var/run/secrets/nono/providers/' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must constrain provider secret reads to fixed mount path"
grep -F '/usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* /home/vscode/.local/bin/nono run --profile * -- /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* OPENCODE_CONFIG_CONTENT=' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow runtime wrapper handoff through nono as agent with pinned runtime env"
grep -F '/home/vscode/.opencode/bin/opencode' "$dockerfile" >/dev/null || fail "Dockerfile sudoers runtime rule must pin exact raw opencode binary path"

printf 'PASS test_workspace_preinstalled_tools_contract\n'
