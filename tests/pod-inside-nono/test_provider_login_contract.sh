#!/usr/bin/env bash
set -euo pipefail

# ops/provider-login with the ChatGPT, Copilot and UiO adapters, using synthetic logins.
# Doubles, and why:
# - kubectl: a real Secret patch and pod exec are out of scope for automated
#   tests. The fake runs `exec ... -- <command>` locally, so the real pod-side
#   steps run, and it records every other call with its standard input, so the
#   test can check exactly what would reach the cluster.
# - opencode-raw: a real login needs a real account. The fake writes an
#   auth.json in the shape OpenCode 1.19.6 uses. Gate R1 checks the real shape.
#   For Copilot it asks the deployment-type question first, so the pseudo-
#   terminal answer is exercised.
# - Copilot and UiO test calls: a local HTTP server stands in for the provider
#   and accepts only the synthetic good credential.

fail() {
  printf 'FAIL test_provider_login_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_provider_login_contract'

command="$repo_root/ops/provider-login"
[ -f "$command" ] || fail "ops/provider-login not found"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_provider_login_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_provider_login_contract')"
check_pid=''
trap '[ -z "$check_pid" ] || kill "$check_pid" 2>/dev/null; rm -rf "$tmp_root"' EXIT

mock_bin="$tmp_root/mock-bin"
logs="$tmp_root/logs"
pod_tmp="$tmp_root/pod-tmp"
mkdir -p "$mock_bin" "$logs" "$pod_tmp"

cat >"$mock_bin/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
n="$(ls "$MOCK_LOGS" | grep -c '^call-' || true)"
call="$MOCK_LOGS/call-$(printf '%03d' "$n")"
printf '%s\n' "$@" >"$call.args"
if [ "${1:-}" = exec ]; then
  if [ -n "${MOCK_EXEC_FAIL:-}" ]; then
    printf 'Error from server (NotFound): deployments.apps "dotfiles-workspace" not found\n' >&2
    exit 1
  fi
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do shift; done
  shift
  # A pod checkout's pod-side script runs as the repository copy; the requested path is recorded.
  case "$1" in
    /workspaces/dotfiles/*/scripts/lib/provider-login-remote.sh)
      printf '%s\n' "$1" >>"$MOCK_LOGS/remote_path"
      set -- "$MOCK_REPO_REMOTE" "${@:2}"
      ;;
  esac
  exec "$@"
fi
cat >"$call.stdin"
case "${1:-}" in
  patch|get) exit 0 ;;
  *) printf 'mock kubectl: unexpected subcommand %s\n' "${1:-}" >&2; exit 99 ;;
esac
EOF

cat >"$mock_bin/opencode-raw" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "${XDG_DATA_HOME:-unset}" >"$MOCK_LOGS/login_data_home"
store="${XDG_DATA_HOME:?}/opencode"
mkdir -p "$store"
if [ "$*" = 'auth login --provider github-copilot --method Login with GitHub Copilot' ]; then
  [ -t 0 ] || { printf 'mock opencode: Copilot login needs a terminal\n' >&2; exit 97; }
  printf '\033[36m\xe2\x97\x86\033[39m  Select\033[1CGitHub\033[1Cdeployment\033[1Ctype\n'
  IFS= read -r -t 5 _ || { printf 'mock opencode: deployment type not answered\n' >&2; exit 96; }
  : >"$MOCK_LOGS/deployment_answered"
  case "$MOCK_LOGIN" in
    ok|rejected) printf '{"github-copilot":{"type":"oauth","refresh":"%s","access":"%s","expires":0}}' "$MOCK_GH_TOKEN" "$MOCK_GH_TOKEN" >"$store/auth.json" ;;
    enterprise) printf '{"github-copilot":{"type":"oauth","refresh":"%s","access":"%s","expires":0,"enterpriseUrl":"ghe.example"}}' "$MOCK_GH_TOKEN" "$MOCK_GH_TOKEN" >"$store/auth.json" ;;
    failed) exit 1 ;;
  esac
  exit 0
fi
[ "$*" = 'auth login --provider openai --method ChatGPT Pro/Plus (headless)' ] || { printf 'mock opencode: unexpected %s\n' "$*" >&2; exit 98; }
expires_ms=$(( ($(date +%s) + 10 * 86400) * 1000 ))
case "$MOCK_LOGIN" in
  ok) printf '{"openai":{"type":"oauth","access":"%s","refresh":"%s","expires":%s,"accountId":"%s"}}' "$MOCK_TOKEN" "$MOCK_REFRESH" "$expires_ms" "$MOCK_ACCOUNT" >"$store/auth.json" ;;
  expired) printf '{"openai":{"type":"oauth","access":"%s","refresh":"%s","expires":1000,"accountId":"%s"}}' "$MOCK_TOKEN" "$MOCK_REFRESH" "$MOCK_ACCOUNT" >"$store/auth.json" ;;
  api) printf '{"openai":{"type":"api","key":"%s"}}' "$MOCK_TOKEN" >"$store/auth.json" ;;
  no-account) printf '{"openai":{"type":"oauth","access":"%s","refresh":"%s","expires":%s}}' "$MOCK_TOKEN" "$MOCK_REFRESH" "$expires_ms" >"$store/auth.json" ;;
  failed) exit 1 ;;
  wait) : >"$MOCK_LOGS/login_started"; while :; do sleep 0.1; done ;;
esac
EOF
chmod +x "$mock_bin"/*

token='synthetic-access-0b9e'
refresh='synthetic-refresh-6a2d'
account='synthetic-account-e81f'
gh_good='gho_synthetic-good-7c1a'
gh_bad='gho_synthetic-bad-4d2e'
uio_good='sk-synthetic-uio-good-93f0'
uio_bad='sk-synthetic-uio-bad-1b7c'

# Stand-in provider endpoint: 200 for the good credentials, 401 otherwise.
python3 -I - "$tmp_root/check-port" "$tmp_root/check-requests" "$gh_good" "$uio_good" <<'PY' &
import http.server
import json
import sys

port_file, request_log, *good = sys.argv[1:]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(request_log, 'a', encoding='utf-8') as fh:
            fh.write(json.dumps({'path': self.path, 'headers': dict(self.headers)}) + '\n')
        ok = self.headers.get('Authorization') in {f'Bearer {g}' for g in good}
        self.send_response(200 if ok else 401)
        self.end_headers()

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
with open(port_file, 'w', encoding='utf-8') as fh:
    fh.write(str(server.server_port))
server.serve_forever()
PY
check_pid=$!
for _ in $(seq 1 100); do [ -s "$tmp_root/check-port" ] && break; sleep 0.05; done
[ -s "$tmp_root/check-port" ] || fail "stand-in provider endpoint did not start"
check_url="http://127.0.0.1:$(cat "$tmp_root/check-port")"

run_env=(
  PATH="$mock_bin:$PATH"
  MOCK_LOGS="$logs"
  MOCK_TOKEN="$token"
  MOCK_REFRESH="$refresh"
  MOCK_ACCOUNT="$account"
  MOCK_GH_TOKEN="$gh_good"
  HUB_PROVIDER_LOGIN_COPILOT_CHECK_URL="$check_url/copilot/models"
  HUB_PROVIDER_LOGIN_UIO_CHECK_URL="$check_url/uio/models"
  TMPDIR="$pod_tmp"
  KUBECTL_BIN=kubectl
  DEVSPACE_NAMESPACE=testing
  OPENCODE_RAW_BINARY="$mock_bin/opencode-raw"
  MOCK_REPO_REMOTE="$repo_root/scripts/lib/provider-login-remote.sh"
  HUB_PROVIDER_LOGIN_REMOTE="$repo_root/scripts/lib/provider-login-remote.sh"
)

# login <scenario> [args...]: runs the command and prints its exit status.
login() {
  local scenario="$1"
  shift
  rm -rf "$logs" && mkdir -p "$logs"
  local status=0
  env "${run_env[@]}" MOCK_LOGIN="$scenario" bash "$command" "$@" </dev/null >"$tmp_root/out" 2>&1 || status=$?
  printf '%s' "$status"
}

# login_input <input> <scenario> [args...]: like login, with <input> on stdin.
login_input() {
  local input="$1" scenario="$2"
  shift 2
  rm -rf "$logs" && mkdir -p "$logs"
  local status=0
  printf '%s\n' "$input" | env "${run_env[@]}" MOCK_LOGIN="$scenario" bash "$command" "$@" >"$tmp_root/out" 2>&1 || status=$?
  printf '%s' "$status"
}

# check_key_patch <key> <expected plain value|null>: exactly one patch that sets only <key>.
check_key_patch() {
  local found
  found="$(patches)"
  [ "$(printf '%s\n' "$found" | grep -c .)" = 1 ] || fail "expected exactly one patch call"
  grep -Fx 'dotfiles-nono-provider-credentials' "$found.args" >/dev/null || fail "patch must target the provider Secret"
  python3 - "$found.stdin" "$1" "$2" <<'PY'
import base64
import json
import sys

path, key, expected = sys.argv[1:]
with open(path, encoding='utf-8') as fh:
    patch = json.load(fh)
if set(patch) != {'data'} or set(patch['data']) != {key}:
    raise SystemExit(f'patch must change only data.{key}')
value = patch['data'][key]
if expected == 'null':
    if value is not None:
        raise SystemExit('reset must remove the key')
elif base64.b64decode(value).decode() != expected:
    raise SystemExit(f'{key} does not hold the expected value')
PY
}

assert_secret_quiet() {
  local label="$1" secret="$2"
  grep -F "$secret" "$tmp_root/out" >/dev/null && fail "$label: output must not contain the credential"
  cat "$logs"/call-*.args 2>/dev/null | grep -F "$secret" >/dev/null && fail "$label: kubectl arguments must not contain the credential"
  return 0
}

patches() { grep -lx patch "$logs"/call-*.args 2>/dev/null | sed 's/\.args$//' || true; }

assert_quiet() {
  local label="$1"
  if grep -F -e "$token" -e "$refresh" -e "$account" "$tmp_root/out" >/dev/null; then
    fail "$label: output must not contain the token, refresh token or account ID"
  fi
  if cat "$logs"/call-*.args 2>/dev/null | grep -F -e "$token" -e "$refresh" -e "$account" >/dev/null; then
    fail "$label: kubectl arguments must not contain credential values"
  fi
  if grep -lx -e apply -e create -e replace -e delete -e edit "$logs"/call-*.args >/dev/null 2>&1; then
    fail "$label: only patch may change the cluster"
  fi
}

assert_clean() {
  local label="$1"
  [ -z "$(ls -A "$pod_tmp")" ] || fail "$label: temporary login files must be removed"
}

# check_patch <expected value: session|null>
check_patch() {
  local found
  found="$(patches)"
  [ "$(printf '%s\n' "$found" | grep -c .)" = 1 ] || fail "expected exactly one patch call"
  grep -Fx 'dotfiles-nono-provider-credentials' "$found.args" >/dev/null || fail "patch must target the provider Secret"
  grep -Fx 'testing' "$found.args" >/dev/null || fail "patch must use the configured namespace"
  python3 - "$found.stdin" "$1" "$token" "$account" "$refresh" <<'PY'
import base64
import json
import sys
import time

path, expected, token, account, refresh = sys.argv[1:]
with open(path, encoding='utf-8') as fh:
    patch = json.load(fh)
if set(patch) != {'data'} or set(patch['data']) != {'openai_chatgpt_session'}:
    raise SystemExit('patch must change only data.openai_chatgpt_session')
value = patch['data']['openai_chatgpt_session']
if expected == 'null':
    if value is not None:
        raise SystemExit('reset must remove the key')
    raise SystemExit(0)
raw = base64.b64decode(value).decode()
if refresh in raw:
    raise SystemExit('the refresh token must be discarded')
session = json.loads(raw)
if set(session) != {'access', 'account_id', 'expires_at'}:
    raise SystemExit(f'unexpected session fields: {sorted(session)}')
if session['access'] != token or session['account_id'] != account:
    raise SystemExit('session values do not match the login')
if not (time.time() + 9 * 86400 < session['expires_at'] < time.time() + 11 * 86400):
    raise SystemExit('expires_at must be the login expiry in seconds')
PY
}

# Successful login.
[ "$(login ok chatgpt)" = 0 ] || fail "login should succeed: $(cat "$tmp_root/out")"
check_patch session || fail "login should patch only the session key with a validated value"
assert_quiet ok
assert_clean ok
data_home="$(cat "$logs/login_data_home")"
case "$data_home" in
  "$pod_tmp"/*) ;;
  *) fail "OpenCode login must use a temporary data directory, not the user's own" ;;
esac

# Invalid login results never reach the Secret.
for scenario in failed expired api no-account; do
  [ "$(login "$scenario" chatgpt)" != 0 ] || fail "$scenario: command must fail"
  [ -z "$(patches)" ] || fail "$scenario: the Secret must not change"
  assert_quiet "$scenario"
  assert_clean "$scenario"
done

# Interrupt during login.
for signal in INT TERM; do
  rm -rf "$logs" && mkdir -p "$logs"
  set -m
  env "${run_env[@]}" MOCK_LOGIN=wait bash "$command" chatgpt </dev/null >"$tmp_root/out" 2>&1 &
  pid=$!
  set +m
  for _ in $(seq 1 100); do [ -e "$logs/login_started" ] && break; sleep 0.05; done
  [ -e "$logs/login_started" ] || { kill -KILL -- "-$pid" 2>/dev/null || true; fail "$signal: login did not start"; }
  kill -"$signal" -- "-$pid"
  status=0
  wait "$pid" || status=$?
  [ "$status" != 0 ] || fail "$signal: interrupted command must fail"
  [ -z "$(patches)" ] || fail "$signal: the Secret must not change"
  assert_clean "$signal"
done

# Reset removes only the key and runs no login.
[ "$(login ok chatgpt --reset)" = 0 ] || fail "reset should succeed: $(cat "$tmp_root/out")"
check_patch null || fail "reset should remove only the session key"
[ ! -e "$logs/login_data_home" ] || fail "reset must not start a login"

# Without an override, the pod-side steps come from the pod's install branch.
install_env="$tmp_root/install.env"
run_env+=(HUB_PROVIDER_LOGIN_REMOTE= HUB_PROVIDER_LOGIN_INSTALL_ENV="$install_env")
remote_used() { sort -u "$logs/remote_path" 2>/dev/null; }

printf 'export HUB_INSTALL_BRANCH=feature/x\nexport HUB_INSTALL_BRANCH_DIR=/workspaces/dotfiles/work/feature/x\n' >"$install_env"
[ "$(login ok chatgpt)" = 0 ] || fail "work checkout: login should succeed: $(cat "$tmp_root/out")"
[ "$(remote_used)" = /workspaces/dotfiles/work/feature/x/scripts/lib/provider-login-remote.sh ] || fail "work checkout: pod-side steps must come from the install branch"
check_patch session || fail "work checkout: login should patch the session key"

rm -f "$install_env"
[ "$(login ok chatgpt)" = 0 ] || fail "no install.env: login should succeed"
[ "$(remote_used)" = /workspaces/dotfiles/main/scripts/lib/provider-login-remote.sh ] || fail "no install.env: pod-side steps must come from main"

rm -f "$install_env"
[ "$(MOCK_EXEC_FAIL=1 login ok chatgpt)" != 0 ] || fail "failed pod exec must be refused, not treated as main"
grep -F 'in namespace testing' "$tmp_root/out" >/dev/null || fail "failed pod exec must name the namespace"
[ -z "$(remote_used)" ] || fail "failed pod exec: no pod-side step may run"
[ -z "$(patches)" ] || fail "failed pod exec: the Secret must not change"

# Without DEVSPACE_NAMESPACE (set by devspace pipelines), nothing reaches the cluster.
saved_run_env=("${run_env[@]}")
run_env+=(DEVSPACE_NAMESPACE=)
for args in chatgpt 'chatgpt --reset'; do
  # shellcheck disable=SC2086
  [ "$(login ok $args)" != 0 ] || fail "no namespace ($args): must be refused"
  grep -F 'devspace run-pipeline login --provider chatgpt' "$tmp_root/out" >/dev/null || fail "no namespace ($args): must name the pipeline"
  [ -z "$(ls "$logs" | grep '^call-' || true)" ] || fail "no namespace ($args): kubectl must not be called"
done
run_env=("${saved_run_env[@]}")

for bad in /tmp/evil /workspaces/dotfiles/work/../../tmp/evil /workspaces/dotfiles/repos/other '/workspaces/dotfiles/work/x;y'; do
  printf 'HUB_INSTALL_BRANCH_DIR=%s\n' "$bad" >"$install_env"
  [ "$(login ok chatgpt)" != 0 ] || fail "install branch $bad must be refused"
  [ -z "$(remote_used)" ] || fail "install branch $bad: no pod-side step may run"
  [ -z "$(patches)" ] || fail "install branch $bad: the Secret must not change"
done

# Unknown providers are refused before any cluster call.
[ "$(login ok does-not-exist)" != 0 ] || fail "unknown provider must be refused"
if ls "$logs"/call-* >/dev/null 2>&1; then
  fail "unknown provider: kubectl must not be called"
fi

rm -f "$install_env"

# Copilot: the login answers the deployment question itself, and the token is
# stored only after the test call succeeds.
[ "$(login ok copilot)" = 0 ] || fail "copilot: login should succeed: $(cat "$tmp_root/out")"
[ -e "$logs/deployment_answered" ] || fail "copilot: the deployment type must be answered"
check_key_patch github_token "$gh_good" || fail "copilot: login should store the token in github_token"
assert_secret_quiet copilot "$gh_good"
assert_clean copilot
tail -n1 "$tmp_root/check-requests" | grep -F '"path": "/copilot/models"' | grep -F 'Copilot-Integration-Id' >/dev/null || fail "copilot: the test call must reach the Copilot check endpoint"

for scenario in enterprise failed; do
  [ "$(login "$scenario" copilot)" != 0 ] || fail "copilot $scenario: command must fail"
  [ -z "$(patches)" ] || fail "copilot $scenario: the Secret must not change"
  assert_clean "copilot $scenario"
done
run_env+=(MOCK_GH_TOKEN="$gh_bad")
[ "$(login rejected copilot)" != 0 ] || fail "copilot: a token the test call rejects must be refused"
grep -F 'Copilot test call' "$tmp_root/out" >/dev/null || fail "copilot: refusal must name the failed test call"
[ -z "$(patches)" ] || fail "copilot rejected: the Secret must not change"
assert_secret_quiet 'copilot rejected' "$gh_bad"

[ "$(login ok copilot --reset)" = 0 ] || fail "copilot reset should succeed"
check_key_patch github_token null || fail "copilot reset should remove only github_token"

# UiO: the key comes from the prompt (stdin here), is tested, then stored.
for variant in yellow red; do
  [ "$(login_input "  $uio_good  " ok "uio-$variant")" = 0 ] || fail "uio-$variant: login should succeed: $(cat "$tmp_root/out")"
  check_key_patch "gpt_uio_${variant}_api_key" "$uio_good" || fail "uio-$variant: login should store the trimmed key"
  assert_secret_quiet "uio-$variant" "$uio_good"
  if ls "$logs"/call-* >/dev/null 2>&1 && grep -lx exec "$logs"/call-*.args >/dev/null 2>&1; then
    fail "uio-$variant: no pod step may run"
  fi
done
[ "$(login_input "$uio_bad" ok uio-yellow)" != 0 ] || fail "uio: a rejected key must be refused"
[ -z "$(patches)" ] || fail "uio rejected: the Secret must not change"
assert_secret_quiet 'uio rejected' "$uio_bad"
for bad_input in '' 'two words'; do
  [ "$(login_input "$bad_input" ok uio-red)" != 0 ] || fail "uio: key '$bad_input' must be refused"
  [ -z "$(patches)" ] || fail "uio '$bad_input': the Secret must not change"
done
[ "$(login ok uio-red --reset)" = 0 ] || fail "uio reset should succeed"
check_key_patch gpt_uio_red_api_key null || fail "uio reset should remove only gpt_uio_red_api_key"

printf 'PASS test_provider_login_contract\n'
