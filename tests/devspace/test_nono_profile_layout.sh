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
grep -F '"deny_shell_configs"' "$profile" >/dev/null || fail "profile should exclude deny_shell_configs to avoid allow-cwd startup overlap refusal"

for credential in '"openai"' '"anthropic"' '"github-copilot"' '"gpt-uio-yellow"' '"gpt-uio-red"'; do
  grep -F "$credential" "$profile" >/dev/null || fail "profile missing required credential route $credential"
done

grep -F '"$XDG_STATE_HOME/opencode"' "$profile" >/dev/null || fail "profile should allow state-home opencode runtime path for agent launch"
grep -F '"upstream": "https://gpt.uio.no/api/v1"' "$profile" >/dev/null || fail "profile should route UiO providers to gpt.uio.no/api/v1"
grep -F '"credential_key": "env://GITHUB_TOKEN"' "$profile" >/dev/null || fail "profile should source github-copilot token from env://GITHUB_TOKEN"

printf 'PASS test_nono_profile_layout\n'
