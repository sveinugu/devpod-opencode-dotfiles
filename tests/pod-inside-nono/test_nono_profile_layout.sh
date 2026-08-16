#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_profile_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_nono_profile_layout'

profile="$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc"

[ -f "$profile" ] || fail "devspace nono secure profile missing"

grep -F '"name": "devspace-opencode-secure"' "$profile" >/dev/null || fail "profile should declare devspace-opencode-secure meta name"
if grep -F '"extends": "nolabs-ai/opencode"' "$profile" >/dev/null; then
  fail "profile should not rely on remote pack inheritance; secure path must stay repo-contained"
fi

grep -F '"groups"' "$profile" >/dev/null || fail "profile should declare explicit group exclusions for incompatible startup command blocking"
grep -F '"exclude"' "$profile" >/dev/null || fail "profile should define group exclusion list"
grep -F '"dangerous_commands"' "$profile" >/dev/null || fail "profile should exclude dangerous_commands to permit constrained startup sudo launch"
grep -F '"dangerous_commands_linux"' "$profile" >/dev/null || fail "profile should exclude dangerous_commands_linux to permit constrained startup sudo launch"
if grep -F '"deny_shell_configs"' "$profile" >/dev/null; then
  fail "profile must not exclude required deny_shell_configs group"
fi
grep -F '"bypass_protection"' "$profile" >/dev/null || fail "profile should use bypass_protection for explicit shell config exceptions"
grep -F '"/workspaces/dotfiles/**/.zshrc"' "$profile" >/dev/null || fail "profile should declare explicit recursive .zshrc path exception under workspace root"
grep -F '"/workspaces/dotfiles/**/.zprofile"' "$profile" >/dev/null || fail "profile should declare explicit recursive .zprofile path exception under workspace root"

for credential in '"openai"' '"anthropic"' '"github-copilot"' '"gpt-uio-yellow"' '"gpt-uio-red"'; do
  grep -F "$credential" "$profile" >/dev/null || fail "profile missing required credential route $credential"
done

grep -F '"$HOME/.gitconfig"' "$profile" >/dev/null || fail "profile should allow read-only access to home git config for safe.directory trust"
grep -F '"/etc/gitconfig"' "$profile" >/dev/null || fail "profile should allow read-only access to system git config for safe.directory trust"
grep -F '"$HOME/.local/state/opencode"' "$profile" >/dev/null || fail "profile should allow explicit opencode runtime state root path for nested state writes"
grep -F '"$HOME/.local/share/direnv"' "$profile" >/dev/null || fail "profile should allow explicit $HOME/.local/share/direnv writes for direnv allow-list"
python3 - "$profile" <<'PY' || fail "profile should grant pinned git/opencode binaries as filesystem.allow_file (not directory allow)"
import json
import sys

profile_path = sys.argv[1]
with open(profile_path, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

filesystem = profile.get('filesystem', {})
allow_file = filesystem.get('allow_file', [])
allow_dir = filesystem.get('allow', [])

required_allow_file = {
    '/usr/local/bin/opencode-raw',
    '/usr/local/bin/git',
    '/usr/local/bin/git-upload-pack',
    '/usr/local/bin/git-receive-pack',
    '/usr/local/bin/git-upload-archive',
}

for required_path in required_allow_file:
    if required_path not in allow_file:
        raise SystemExit(1)

for required_path in required_allow_file:
    if required_path in allow_dir:
        raise SystemExit(1)
PY

python3 - "$profile" <<'PY' || fail "profile should grant workspace root as read+write"
import json
import sys

profile_path = sys.argv[1]
with open(profile_path, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

filesystem = profile.get('filesystem', {})
read_paths = filesystem.get('read', [])
allow_paths = filesystem.get('allow', [])

if '/workspaces/dotfiles' not in allow_paths:
    raise SystemExit(1)

if '/workspaces/dotfiles' in read_paths:
    raise SystemExit(1)

if '$HOME/.gitconfig' not in read_paths:
    raise SystemExit(1)
if '/etc/gitconfig' not in read_paths:
    raise SystemExit(1)
if '$HOME/.gitconfig' in allow_paths:
    raise SystemExit(1)
if '/etc/gitconfig' in allow_paths:
    raise SystemExit(1)
PY

python3 - "$profile" <<'PY' || fail "profile should rely on filesystem path grants (without command_policies) for git helper execution"
import json
import sys

profile_path = sys.argv[1]
with open(profile_path, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

if 'command_policies' in profile:
    raise SystemExit(1)

filesystem = profile.get('filesystem', {})
allow_paths = filesystem.get('allow', [])

required_allow = {
    '/usr/local/libexec/git-core',
    '/usr/local/share/git-core',
    '/workspaces/dotfiles',
    '/tmp',
}

for required_path in required_allow:
    if required_path not in allow_paths:
        raise SystemExit(1)
PY

grep -F '"upstream": "https://gpt.uio.no/api/v1"' "$profile" >/dev/null || fail "profile should route UiO providers to gpt.uio.no/api/v1"
grep -F '"credential_key": "env://GITHUB_TOKEN"' "$profile" >/dev/null || fail "profile should source github-copilot token from env://GITHUB_TOKEN"
grep -F '"upstream": "https://api.githubcopilot.com"' "$profile" >/dev/null || fail "profile should route github-copilot credential injection to api.githubcopilot.com"
grep -F '"credential_format": "Bearer {}"' "$profile" >/dev/null || fail "profile should send github-copilot credentials as Bearer token"
if grep -F '"upstream": "https://api.github.com"' "$profile" >/dev/null; then
  fail "profile must not route github-copilot credential injection to api.github.com"
fi
grep -F '"tls_intercept"' "$profile" >/dev/null || fail "profile should configure tls_intercept for generated intercept CA trust propagation"
grep -F '"ca_env_vars"' "$profile" >/dev/null || fail "profile should configure tls_intercept ca_env_vars"

for ca_var in '"SSL_CERT_FILE"' '"REQUESTS_CA_BUNDLE"' '"NODE_EXTRA_CA_CERTS"' '"CURL_CA_BUNDLE"' '"GIT_SSL_CAINFO"'; do
  grep -F "$ca_var" "$profile" >/dev/null || fail "profile should include $ca_var in tls_intercept.ca_env_vars"
done

printf 'PASS test_nono_profile_layout\n'
