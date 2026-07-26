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

grep -F 'ARG OPENCODE_VERSION=' "$dockerfile" >/dev/null || fail "Dockerfile must pin an explicit OPENCODE_VERSION build arg"
grep -F 'ARG OPENCODE_LINUX_X64_SHA256=' "$dockerfile" >/dev/null || fail "Dockerfile must pin OPENCODE_LINUX_X64_SHA256 build arg"
grep -F 'ARG OPENCODE_LINUX_ARM64_SHA256=' "$dockerfile" >/dev/null || fail "Dockerfile must pin OPENCODE_LINUX_ARM64_SHA256 build arg"
grep -F 'ARG DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL=0' "$dockerfile" >/dev/null || fail "Dockerfile must default DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL to 0"
grep -E 'apt-get -y install --no-install-recommends .*\bacl\b' "$dockerfile" >/dev/null || fail "Dockerfile must install acl tooling for managed workspace ACL bootstrap"
grep -F 'git config --system --add safe.directory /workspaces/dotfiles/*' "$dockerfile" >/dev/null || fail "Dockerfile must seed system git safe.directory trust for managed workspace paths"
grep -F '/usr/local/bin/opencode-raw' "$dockerfile" >/dev/null || fail "Dockerfile must install root-owned opencode raw binary shim at /usr/local/bin/opencode-raw"
grep -F '/usr/local/libexec/opencode' "$dockerfile" >/dev/null || fail "Dockerfile must install versioned opencode binaries under /usr/local/libexec/opencode"

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
if grep -F 'https://nono.sh/install.sh' "$provision_script" >/dev/null; then
  fail "nono must not be user-installed at provision time"
fi
if grep -F 'https://opencode.ai/install' "$provision_script" >/dev/null; then
  fail "opencode must not be user-installed at provision time"
fi
if grep -F 'opencode.installed' "$provision_script" >/dev/null; then
  fail "provision script must not track opencode install markers when opencode is image-installed"
fi
grep -F 'mkdir -p "$home_dir/.ssh"' "$provision_script" >/dev/null || fail "missing provision-time /home/vscode bootstrap directories"

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
grep -F 'if [ "${DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL:-0}" = "1" ]; then' "$dockerfile" >/dev/null || fail "Dockerfile must branch on DOTFILES_ALLOW_VSCODE_NOPASSWD_ALL for debug sudo mode"
grep -F "'vscode ALL=(ALL) NOPASSWD:ALL'" "$dockerfile" >/dev/null || fail "Dockerfile debug sudo mode must define explicit broad vscode sudoers contract"
grep -F '/etc/sudoers.d/99-dotfiles-vscode-debug' "$dockerfile" >/dev/null || fail "Dockerfile debug sudo mode must manage dedicated debug sudoers file"
grep -F '/usr/local/bin/nono' "$dockerfile" >/dev/null || fail "Dockerfile must manage root-owned /usr/local/bin/nono"
grep -F '/usr/local/libexec/dotfiles-generate-nono-profile' "$dockerfile" >/dev/null || fail "Dockerfile must install root-owned generated profile writer helper"
grep -F '/usr/local/libexec/dotfiles-launch-opencode-nono' "$dockerfile" >/dev/null || fail "Dockerfile must install root-owned launch helper for constrained runtime handoff"
grep -F 'https://nono.sh/install.sh' "$dockerfile" >/dev/null || fail "Dockerfile must install nono at image build time"
grep -F 'COPY .config/nono/profiles/devspace-opencode-secure.jsonc /tmp/devspace-opencode-secure.jsonc' "$dockerfile" >/dev/null || fail "Dockerfile must copy secure nono profile from build context"
grep -F 'COPY scripts/lib/generate-nono-profile.py /tmp/generate-nono-profile.py' "$dockerfile" >/dev/null || fail "Dockerfile must copy generated profile writer from build context"
grep -F 'COPY scripts/lib/launch-opencode-nono.sh /tmp/launch-opencode-nono.sh' "$dockerfile" >/dev/null || fail "Dockerfile must copy launch helper from build context"
grep -F 'sudo rm -f /tmp/generate-nono-profile.py' "$dockerfile" >/dev/null || fail "Dockerfile must remove staged generated profile helper via sudo in sticky /tmp"
grep -F 'sudo rm -f /tmp/launch-opencode-nono.sh' "$dockerfile" >/dev/null || fail "Dockerfile must remove staged launch helper via sudo in sticky /tmp"
grep -F 'sudo rm -f /tmp/devspace-opencode-secure.jsonc' "$dockerfile" >/dev/null || fail "Dockerfile must remove staged secure nono profile via sudo in sticky /tmp"
if grep -F '/workspaces/dotfiles/main/.config/nono/profiles/devspace-opencode-secure.jsonc' "$dockerfile" >/dev/null; then
  fail "Dockerfile must not read secure nono profile from runtime-only /workspaces path during build"
fi
grep -F 'Defaults:vscode env_keep += "OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN GPT_UIO_YELLOW_API_KEY GPT_UIO_RED_API_KEY"' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must preserve provider secret env vars for constrained agent launch path"
grep -F '/bin/cat /var/run/secrets/nono/providers/' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must constrain provider secret reads to fixed mount path"
grep -F 'vscode ALL=(agent) NOPASSWD: /usr/bin/mkdir -p /home/agent/.config' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow agent-home config dir bootstrap"
grep -F 'vscode ALL=(agent) NOPASSWD: /usr/bin/rm -rf /home/agent/.config/opencode' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow replacing stale agent opencode config target"
grep -F 'vscode ALL=(agent) NOPASSWD: /usr/bin/ln -sfn /workspaces/dotfiles/main/.config/opencode /home/agent/.config/opencode' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow linking main install-branch opencode config into agent home"
grep -F 'vscode ALL=(agent) NOPASSWD: /usr/bin/ln -sfn /workspaces/dotfiles/work/*/.config/opencode /home/agent/.config/opencode' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow linking worktree install-branch opencode config into agent home"
grep -F 'vscode ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-generate-nono-profile --template * --runtime * --output-dir /etc/nono/profiles/runtime' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow fixed generated profile writer helper path"
grep -F 'sudo install -o root -g root -m 0440 /tmp/99-dotfiles-nono /etc/sudoers.d/99-dotfiles-nono' "$dockerfile" >/dev/null || fail "Dockerfile should install sudoers contract atomically with root ownership + mode"
grep -F 'sudo visudo -cf /etc/sudoers.d/99-dotfiles-nono' "$dockerfile" >/dev/null || fail "Dockerfile should validate constrained sudoers contract before cleanup/toggles"
grep -F 'sudo rm -f /tmp/99-dotfiles-nono' "$dockerfile" >/dev/null || fail "Dockerfile should remove staged sudoers file after installation"
grep -F 'vscode ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-launch-opencode-nono --setpriv-binary * --nono-binary * --profile * --agent-uid * --agent-gid * --runtime-home * --runtime-xdg-config-home * --runtime-xdg-cache-home * --runtime-xdg-data-home * --runtime-xdg-state-home * --opencode-xdg-state-home * --runtime-path * --opencode-config-content * --raw-opencode-binary * -- *' "$dockerfile" >/dev/null || fail "Dockerfile sudoers contract must allow runtime wrapper handoff through constrained launch helper"
grep -F '/usr/local/bin/opencode-raw' "$dockerfile" >/dev/null || fail "Dockerfile sudoers runtime rule must pin exact raw opencode binary path"

[ -x "$repo_root/bin/update-opencode-version" ] || fail "bin/update-opencode-version must exist and be executable"
grep -F -- '--latest' "$repo_root/bin/update-opencode-version" >/dev/null || fail "update-opencode-version must support --latest"
grep -F -- '--version <vX.Y.Z|X.Y.Z>' "$repo_root/bin/update-opencode-version" >/dev/null || fail "update-opencode-version must document pinned-version argument"

run_steps="$(grep -Ec '^RUN ' "$dockerfile")"
if [ "$run_steps" -lt 5 ]; then
  fail "Dockerfile should use 5+ RUN layers so slow nono install and profile setup are naturally cacheable"
fi

printf 'PASS test_workspace_preinstalled_tools_contract\n'
