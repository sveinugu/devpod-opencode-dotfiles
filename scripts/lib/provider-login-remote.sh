#!/usr/bin/env bash
set -euo pipefail

# Pod side of ops/provider-login. The host runs each step through kubectl exec,
# as the workspace user, outside nono. Steps:
#   prepare                  create a private temporary login directory; print its path
#   login <provider> <dir>   run OpenCode's interactive login with its data in <dir>
#   extract <provider> <dir> print the validated session value on stdout
#   cleanup <dir>            remove the login directory
# Only extract prints a credential value, and only to its stdout for the host.

raw_opencode_binary="${OPENCODE_RAW_BINARY:-/usr/local/bin/opencode-raw}"
login_root="${TMPDIR:-/tmp}"
login_prefix='provider-login.'

fail() {
  printf 'refused: %s\n' "$1" >&2
  exit 1
}

# Accept only a directory that prepare made: our prefix, under the login root, owned by us.
require_login_dir() {
  local dir="${1:-}"
  case "$dir" in
    "$login_root/$login_prefix"*) ;;
    *) fail 'not a provider login directory' ;;
  esac
  case "${dir#"$login_root/"}" in
    */*|*..*) fail 'not a provider login directory' ;;
  esac
  [ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ] || fail 'provider login directory is missing or not owned by this user'
}

require_provider() {
  [ "${1:-}" = chatgpt ] || fail "unsupported provider: ${1:-}"
}

step="${1:-}"
shift || true

case "$step" in
  prepare)
    dir="$(mktemp -d "$login_root/${login_prefix}XXXXXXXX")"
    chmod 0700 "$dir"
    printf '%s\n' "$dir"
    ;;
  login)
    require_provider "${1:-}"
    require_login_dir "${2:-}"
    dir="$2"
    mkdir -p "$dir/data" "$dir/config" "$dir/cache" "$dir/state"
    printf 'In the OpenCode login, choose OpenAI, then the ChatGPT Plus/Pro headless method.\n' >&2
    XDG_DATA_HOME="$dir/data" XDG_CONFIG_HOME="$dir/config" XDG_CACHE_HOME="$dir/cache" XDG_STATE_HOME="$dir/state" \
      "$raw_opencode_binary" auth login
    ;;
  extract)
    require_provider "${1:-}"
    require_login_dir "${2:-}"
    python3 -I - "$2/data/opencode/auth.json" <<'PY'
import json
import sys
import time

def refuse(message):
    print(f'refused: {message}', file=sys.stderr)
    sys.exit(1)

def text(value):
    return isinstance(value, str) and value != '' and '\r' not in value and '\n' not in value

try:
    with open(sys.argv[1], encoding='utf-8') as fh:
        entry = json.load(fh).get('openai')
except (OSError, ValueError, AttributeError):
    refuse('the login did not store a ChatGPT session')
if not isinstance(entry, dict) or entry.get('type') != 'oauth':
    refuse('the login did not store a ChatGPT plan session; choose the ChatGPT Plus/Pro method')
expires = entry.get('expires')
if isinstance(expires, bool) or not isinstance(expires, (int, float)):
    refuse('the ChatGPT session has no valid expiry')
if not text(entry.get('access')):
    refuse('the ChatGPT session has no access token')
if not text(entry.get('accountId')):
    refuse('the ChatGPT session has no account ID')
expires_at = int(expires // 1000)
if expires_at <= time.time() + 60:
    refuse('the ChatGPT session is already expired')
# The refresh token is discarded on purpose: this version does not refresh.
print(json.dumps({'access': entry['access'], 'account_id': entry['accountId'], 'expires_at': expires_at}))
PY
    ;;
  cleanup)
    require_login_dir "${1:-}"
    rm -rf -- "$1"
    ;;
  *)
    fail "unsupported step: $step"
    ;;
esac
