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
grep -F '"$WORKDIR/.zshrc"' "$profile" >/dev/null || fail "profile should declare explicit .zshrc path exception"
grep -F '"$WORKDIR/.zprofile"' "$profile" >/dev/null || fail "profile should declare explicit .zprofile path exception"
grep -F '"$WORKDIR/../.bare"' "$profile" >/dev/null || fail "profile should allow shared bare repo path for default-branch worktree contexts"
grep -F '"$WORKDIR/../../.bare"' "$profile" >/dev/null || fail "profile should allow shared bare repo path for nested worktree contexts"

for credential in '"openai"' '"anthropic"' '"github-copilot"' '"gpt-uio-yellow"' '"gpt-uio-red"'; do
  grep -F "$credential" "$profile" >/dev/null || fail "profile missing required credential route $credential"
done

grep -F '"$HOME/.gitconfig"' "$profile" >/dev/null || fail "profile should allow read-only access to home git config for safe.directory trust"
grep -F '"$HOME/.local/state/opencode"' "$profile" >/dev/null || fail "profile should allow explicit opencode runtime state root path for nested state writes"
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

python3 - "$profile" <<'PY' || fail "profile should grant shared bare repo paths as read+write"
import json
import sys

profile_path = sys.argv[1]
with open(profile_path, 'r', encoding='utf-8') as fh:
    profile = json.load(fh)

filesystem = profile.get('filesystem', {})
read_paths = filesystem.get('read', [])
allow_paths = filesystem.get('allow', [])

required_readwrite = ['$WORKDIR/../.bare', '$WORKDIR/../../.bare']

for path in required_readwrite:
    if path not in allow_paths:
        raise SystemExit(1)
    if path in read_paths:
        raise SystemExit(1)

if '$HOME/.gitconfig' not in read_paths:
    raise SystemExit(1)
if '$HOME/.gitconfig' in allow_paths:
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
