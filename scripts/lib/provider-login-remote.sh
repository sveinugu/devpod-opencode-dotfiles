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
  case "${1:-}" in
    chatgpt|copilot) ;;
    *) fail "unsupported provider: ${1:-}" ;;
  esac
}

# Run OpenCode's Copilot login in a pseudo-terminal and answer its one question,
# the GitHub deployment type, with the default (GitHub.com). The login then only
# prints a URL and code and waits, so no keyboard input reaches it.
copilot_login() {
  python3 -I - "$raw_opencode_binary" <<'PY'
import fcntl
import os
import pty
import re
import struct
import sys
import termios

argv = [sys.argv[1], 'auth', 'login', '--provider', 'github-copilot', '--method', 'Login with GitHub Copilot']
pid, fd = pty.fork()
if pid == 0:
    os.execv(argv[0], argv)
# A new pseudo-terminal is 0x0, and the prompt draws nothing at that size.
try:
    size = fcntl.ioctl(sys.stdin.fileno(), termios.TIOCGWINSZ, b'\0' * 8)
    if struct.unpack('HHHH', size)[1] == 0:
        raise OSError
except OSError:
    size = struct.pack('HHHH', 24, 80, 0, 0)
fcntl.ioctl(fd, termios.TIOCSWINSZ, size)

seen, answered = '', False
while True:
    try:
        data = os.read(fd, 4096)
    except OSError:
        break
    if not data:
        break
    os.write(1, data)
    if not answered:
        # Spaces are drawn as cursor moves, so compare without escapes and whitespace.
        seen = (seen + re.sub(r'\x1b\[[0-9;?]*[A-Za-z]|\s', '', data.decode('utf-8', 'replace')))[-4096:]
        if 'SelectGitHubdeploymenttype' in seen:
            os.write(fd, b'\r')
            answered = True
_, status = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(status))
PY
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
    export XDG_DATA_HOME="$dir/data" XDG_CONFIG_HOME="$dir/config" XDG_CACHE_HOME="$dir/cache" XDG_STATE_HOME="$dir/state"
    # Provider and method are fixed, so the login asks no questions: it prints a
    # URL and code to open in a browser and waits. Method labels are OpenCode's own.
    if [ "$1" = copilot ]; then
      printf 'Open the URL below in a browser and enter the code to log in with GitHub Copilot.\n' >&2
      copilot_login
    else
      printf 'Open the URL below in a browser and enter the code to log in with ChatGPT Plus/Pro.\n' >&2
      "$raw_opencode_binary" auth login --provider openai --method 'ChatGPT Pro/Plus (headless)'
    fi
    ;;
  extract)
    require_provider "${1:-}"
    require_login_dir "${2:-}"
    if [ "$1" = copilot ]; then
      python3 -I - "$2/data/opencode/auth.json" <<'PY'
import json
import sys

def refuse(message):
    print(f'refused: {message}', file=sys.stderr)
    sys.exit(1)

try:
    with open(sys.argv[1], encoding='utf-8') as fh:
        entry = json.load(fh).get('github-copilot')
except (OSError, ValueError, AttributeError):
    refuse('the login did not store a GitHub Copilot token')
if not isinstance(entry, dict) or entry.get('type') != 'oauth':
    refuse('the login did not store a GitHub Copilot OAuth token')
if entry.get('enterpriseUrl'):
    refuse('only GitHub.com is supported, not GitHub Enterprise')
token = entry.get('refresh')
if not isinstance(token, str) or not token or any(c.isspace() for c in token):
    refuse('the GitHub Copilot login has no usable token')
# The long-lived GitHub OAuth token; nono sends it as the Copilot bearer token.
sys.stdout.write(token)
PY
      exit
    fi
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
