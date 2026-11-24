#!/usr/bin/env bash
# Shared fixture for the ChatGPT gate tests (spec gates S1 and S3).
# Source after context-guards.sh, in a pod-outside-nono test.
#
# The fixture uses only the deployed image and its constrained sudo rules:
# the deployed profile template, generator, launch helper, header helper,
# setpriv, nono and opencode-raw. It changes the template in one place: the
# ChatGPT route points at a local TLS stand-in for chatgpt.com. All credential
# values are synthetic.
#
# Children of the launch helper must be named opencode-raw; gate probes are
# small scripts with that name. They run as the agent user inside nono.

gate_deployed_launch_helper=/usr/local/libexec/dotfiles-launch-opencode-nono
gate_deployed_generator=/usr/local/libexec/dotfiles-generate-nono-profile
gate_deployed_header_helper=/usr/local/libexec/dotfiles-chatgpt-headers
gate_deployed_template=/etc/nono/profiles/devspace-opencode-secure.jsonc
gate_runtime_profile_dir=/etc/nono/profiles/runtime
gate_runtime_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

gate_fail() {
  printf 'FAIL %s: %s\n' "$gate_test_name" "$1" >&2
  exit 1
}

# gate_setup <test name> <hold seconds>: hold > 0 makes each header request
# keep a process with the session alive for that long, so isolation scans are
# deterministic. The held process then runs the deployed header helper.
gate_setup() {
  gate_test_name="$1"
  local hold="$2"
  local path
  for path in "$gate_deployed_launch_helper" "$gate_deployed_generator" "$gate_deployed_header_helper" \
      /usr/local/bin/nono /usr/bin/setpriv /usr/local/bin/opencode-raw; do
    [ -x "$path" ] || gate_fail "deployed $path is missing; rebuild and redeploy the image first"
  done
  [ -r "$gate_deployed_template" ] || gate_fail "deployed profile template is missing"
  command -v openssl >/dev/null || gate_fail "openssl is required"

  gate_agent_uid="$(id -u agent)" && gate_agent_gid="$(id -g agent)" || gate_fail "agent user not found"

  local temp_root
  temp_root="$(context_resolve_temp_root_workspace_or_fail "$gate_test_name")"
  case "$temp_root" in
    /workspaces/dotfiles/*|/tmp/*) ;;
    *) gate_fail "TMPDIR must be under /workspaces/dotfiles or /tmp so the sandbox can reach it" ;;
  esac
  gate_tmp="$(context_make_test_tmpdir "$temp_root" "$gate_test_name")"
  gate_upstream_pid=''
  gate_cleanup_profile=''
  trap gate_cleanup EXIT

  # Agent-writable areas. Everything the agent creates is removed by gate_cleanup.
  chmod 0755 "$gate_tmp"
  mkdir -p "$gate_tmp/work" "$gate_tmp/results" "$gate_tmp/home/.config" "$gate_tmp/home/.cache" \
    "$gate_tmp/home/.local/share" "$gate_tmp/home/.local/state" "$gate_tmp/bin" "$gate_tmp/fixture"
  chmod 0777 "$gate_tmp/work" "$gate_tmp/results" "$gate_tmp/home" "$gate_tmp/home/.config" "$gate_tmp/home/.cache" \
    "$gate_tmp/home/.local" "$gate_tmp/home/.local/share" "$gate_tmp/home/.local/state"
  chmod 0755 "$gate_tmp/bin" "$gate_tmp/fixture"

  gate_real="synthetic-real-$(openssl rand -hex 16)"
  gate_real_re="synthetic-rea[l]-${gate_real#synthetic-real-}"
  gate_account="synthetic-account-$(openssl rand -hex 4)"
  gate_marker="GATE_OK_$(openssl rand -hex 4)"
  gate_log="$gate_tmp/fixture/upstream.jsonl"
  : >"$gate_log"

  local f="$gate_tmp/fixture"
  openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=chatgpt-gate-ca -keyout "$f/ca-key.pem" -out "$f/ca.pem" 2>/dev/null
  openssl req -newkey rsa:2048 -nodes -subj /CN=localhost -keyout "$f/key.pem" -out "$f/leaf.csr" 2>/dev/null
  printf '%s\n' 'basicConstraints=critical,CA:FALSE' 'keyUsage=critical,digitalSignature,keyEncipherment' \
    'extendedKeyUsage=serverAuth' 'subjectAltName=DNS:localhost,IP:127.0.0.1' >"$f/leaf.ext"
  openssl x509 -req -in "$f/leaf.csr" -CA "$f/ca.pem" -CAkey "$f/ca-key.pem" -CAcreateserial \
    -days 1 -sha256 -extfile "$f/leaf.ext" -out "$f/cert.pem" 2>/dev/null
  chmod 0644 "$f/ca.pem"
  chmod 0600 "$f/key.pem" "$f/ca-key.pem"

  local port
  port="$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
  gate_base="https://localhost:$port/backend-api/codex"
  GATE_REAL="$gate_real" GATE_ACCOUNT="$gate_account" GATE_MARKER="$gate_marker" \
    python3 -I "$repo_root/tests/lib/chatgpt_gate_upstream.py" "$port" "$f/cert.pem" "$f/key.pem" "$gate_log" &
  gate_upstream_pid=$!
  sleep 1
  kill -0 "$gate_upstream_pid" 2>/dev/null || gate_fail "local upstream did not start"

  python3 -I - "$gate_deployed_template" "$f/template.json" "$gate_base" "$f/ca.pem" "$hold" "$gate_deployed_header_helper" <<'PY' || gate_fail "could not derive the gate template"
import json
import sys

template, output, base, ca, hold, helper = sys.argv[1:]
with open(template, encoding='utf-8') as fh:
    profile = json.load(fh)
route = profile['network']['custom_credentials']['openai-chatgpt']
route['upstream'] = base
route['tls_ca'] = ca
if float(hold) > 0:
    profile['credential_capture']['openai-chatgpt']['command'] = ['/bin/sh', '-c', f'sleep {hold}; exec {helper}']
with open(output, 'w', encoding='utf-8') as fh:
    json.dump(profile, fh, indent=2)
PY
  printf '{"enabled_providers":["openai-chatgpt"],"provider":{}}\n' >"$f/runtime.json"
  chmod 0644 "$f/template.json" "$f/runtime.json"
  gate_cleanup_profile="$(gate_profile -)"
}

# gate_session <seconds until expiry>: prints a synthetic session value.
gate_session() {
  printf '{"access":"%s","account_id":"%s","expires_at":%s}' "$gate_real" "$gate_account" "$(( $(date +%s) + $1 ))"
}

# gate_profile <session|->: generates a runtime profile through the deployed generator.
gate_profile() {
  if [ "$1" = - ]; then
    env -u OPENAI_CHATGPT_SESSION sudo -n -- "$gate_deployed_generator" --template "$gate_tmp/fixture/template.json" \
      --runtime "$gate_tmp/fixture/runtime.json" --output-dir "$gate_runtime_profile_dir"
  else
    OPENAI_CHATGPT_SESSION="$1" sudo -n -- "$gate_deployed_generator" --template "$gate_tmp/fixture/template.json" \
      --runtime "$gate_tmp/fixture/runtime.json" --output-dir "$gate_runtime_profile_dir"
  fi
}

# gate_probe <name> <script>: installs a probe as an opencode-raw executable; prints its path.
gate_probe() {
  mkdir -p "$gate_tmp/bin/$1"
  chmod 0755 "$gate_tmp/bin/$1"
  printf '%s\n' "$2" >"$gate_tmp/bin/$1/opencode-raw"
  chmod 0755 "$gate_tmp/bin/$1/opencode-raw"
  printf '%s\n' "$gate_tmp/bin/$1/opencode-raw"
}

# gate_launch <session|-> <profile> <raw binary> <config content> <stdout> <stderr> [args...]
# Launches through the deployed launch helper, exactly as the wrapper does.
gate_launch() {
  local session="$1" profile="$2" raw="$3" config="$4" out="$5" err="$6"
  shift 6
  local h="$gate_tmp/home"
  local session_env=(env -u OPENAI_CHATGPT_SESSION)
  [ "$session" = - ] || session_env=(env OPENAI_CHATGPT_SESSION="$session")
  (cd "$gate_tmp/work" && timeout -k 5 240 "${session_env[@]}" sudo -n -- "$gate_deployed_launch_helper" \
    --setpriv-binary /usr/bin/setpriv --nono-binary /usr/local/bin/nono --profile "$profile" \
    --agent-uid "$gate_agent_uid" --agent-gid "$gate_agent_gid" \
    --runtime-home "$h" --runtime-xdg-config-home "$h/.config" --runtime-xdg-cache-home "$h/.cache" \
    --runtime-xdg-data-home "$h/.local/share" --runtime-xdg-state-home "$h/.local/state" \
    --opencode-xdg-state-home "$h/.local/state" --runtime-path "$gate_runtime_path" \
    --runtime-bash-env "$repo_root/.config/opencode/bash_env.sh" --opencode-config-content "$config" \
    --raw-opencode-binary "$raw" -- "$@" </dev/null >"$out" 2>"$err")
}

gate_hits() { wc -l <"$gate_log" | tr -d ' '; }
gate_count() { grep -c "$1" "$gate_log" || true; }

gate_check_count=0
gate_check() {
  if [ "$2" = "$3" ]; then
    printf 'PASS %s (%s)\n' "$1" "$3"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$1" "$2" "$3"
    gate_check_count=$((gate_check_count + 1))
  fi
}

# Fails the test when the real token reached any file under the test tree outside the fixture.
gate_check_no_leak() {
  local leaks
  leaks="$(grep -rlF -- "$gate_real" "$gate_tmp/work" "$gate_tmp/results" "$gate_tmp/home" "$gate_tmp"/*.out "$gate_tmp"/*.err 2>/dev/null | wc -l | tr -d ' ')"
  gate_check "real token absent from sandbox-visible files and outputs" 0 "$leaks"
}

gate_finish() {
  if [ "$gate_check_count" -eq 0 ]; then
    printf 'PASS %s\n' "$gate_test_name"
  else
    printf 'FAIL %s: %s check(s) failed\n' "$gate_test_name" "$gate_check_count" >&2
    exit 1
  fi
}

# Files the agent created can only be removed as the agent, so cleanup runs one
# more launch whose child removes them.
gate_cleanup() {
  [ -z "${gate_upstream_pid:-}" ] || kill "$gate_upstream_pid" 2>/dev/null || true
  if [ -n "${gate_cleanup_profile:-}" ] && [ -d "${gate_tmp:-}" ]; then
    local remover
    remover="$(gate_probe cleanup '#!/bin/sh
rm -rf -- "$@"')"
    gate_launch - "$gate_cleanup_profile" "$remover" '{}' /dev/null /dev/null \
      "$gate_tmp/work" "$gate_tmp/results" "$gate_tmp/home" >/dev/null 2>&1 || true
  fi
  if [ -n "${gate_tmp:-}" ]; then
    rm -rf "$gate_tmp" 2>/dev/null || printf 'warning: could not remove %s\n' "$gate_tmp" >&2
  fi
}
