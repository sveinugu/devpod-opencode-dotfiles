#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_profile_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
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
python3 - "$profile" <<'PY' || fail "profile should grant /usr/local/bin/opencode-raw as filesystem.allow_file (not directory allow)"
import json
import sys

profile_path = sys.argv[1]
with open(profile_path, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

filesystem = profile.get('filesystem', {})
allow_file = filesystem.get('allow_file', [])
allow_dir = filesystem.get('allow', [])

if '/usr/local/bin/opencode-raw' not in allow_file:
    raise SystemExit(1)

if '/usr/local/bin/opencode-raw' in allow_dir:
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

python3 - "$profile" <<'PY' || fail "profile should grant git helper exec path through command_policies.from.session sandbox"
import json
import sys

profile_path = sys.argv[1]
with open(profile_path, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

command_policies = profile.get('command_policies', {})
commands = command_policies.get('commands', {})
git = commands.get('git', {})

if git.get('executable') != '/usr/local/bin/git':
    raise SystemExit(1)

from_edges = git.get('from', {})
session_edge = from_edges.get('session', {})
sandbox = session_edge.get('sandbox', {})

if not sandbox:
    raise SystemExit(1)

fs_read = sandbox.get('fs_read', [])
fs_write = sandbox.get('fs_write', [])
fs_read_file = sandbox.get('fs_read_file', [])
exec_paths = sandbox.get('exec_paths', [])

for required_read in ('/workspaces/dotfiles', '/usr/local/libexec/git-core'):
    if required_read not in fs_read:
        raise SystemExit(1)

for required_write in ('/workspaces/dotfiles',):
    if required_write not in fs_write:
        raise SystemExit(1)

for required_read_file in ('$HOME/.gitconfig', '/etc/gitconfig'):
    if required_read_file not in fs_read_file:
        raise SystemExit(1)

if '/usr/local/libexec/git-core' not in fs_read:
    raise SystemExit(1)

if '/usr/local/libexec/git-core' not in exec_paths:
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
