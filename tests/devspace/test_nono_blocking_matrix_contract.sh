#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_blocking_matrix_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
secure_profile_default="$repo_root/.config/nono/profiles/devspace-opencode-secure.jsonc"
secure_profile_path="${HUB_NONO_SECURE_PROFILE_PATH:-$secure_profile_default}"
test_timeout_seconds="${HUB_NONO_TEST_TIMEOUT_SECONDS:-45}"
nono_bin="${HUB_NONO_BIN:-nono}"

require_file() {
  local file_path="$1"
  local description="$2"
  [ -f "$file_path" ] || fail "$description missing: $file_path"
}

run_expect_success() {
  local command_label="$1"
  local output_file="$2"
  shift 2
  if command -v timeout >/dev/null 2>&1; then
    if ! timeout "$test_timeout_seconds" "$@" >"$output_file" 2>&1; then
      fail "$command_label failed unexpectedly: $(tr '\n' ' ' < "$output_file")"
    fi
    return
  fi
  if ! "$@" >"$output_file" 2>&1; then
    fail "$command_label failed unexpectedly: $(tr '\n' ' ' < "$output_file")"
  fi
}

resolve_nono_bin() {
  if command -v "$nono_bin" >/dev/null 2>&1; then
    return 0
  fi
  if [ "$nono_bin" = "nono" ] && [ -x "$HOME/.local/bin/nono" ]; then
    nono_bin="$HOME/.local/bin/nono"
    return 0
  fi
  fail "nono executable is required for matrix checks (set HUB_NONO_BIN or install nono)"
}

run_expect_failure() {
  local command_label="$1"
  local output_file="$2"
  shift 2
  if command -v timeout >/dev/null 2>&1; then
    if timeout "$test_timeout_seconds" "$@" >"$output_file" 2>&1; then
      fail "$command_label succeeded but fail-closed behavior was expected"
    fi
    return
  fi
  if "$@" >"$output_file" 2>&1; then
    fail "$command_label succeeded but fail-closed behavior was expected"
  fi
}

assert_output_contains() {
  local output_file="$1"
  local required_text="$2"
  local description="$3"
  grep -F "$required_text" "$output_file" >/dev/null || fail "$description did not include expected text: $required_text"
}

assert_output_not_contains() {
  local output_file="$1"
  local forbidden_text="$2"
  local description="$3"
  if grep -F "$forbidden_text" "$output_file" >/dev/null; then
    fail "$description leaked forbidden text: $forbidden_text"
  fi
}

blocking_rows=(
  "in-pod-runtime|In-pod install/runtime"
  "kernel-enforcement|Kernel enforcement"
  "fail-closed-behavior|Fail-closed behavior"
  "network-control|Network control"
  "proxy-credential-secrecy|Proxy credential secrecy"
  "opencode-functionality|OpenCode functionality"
  "uio-custom-provider-route|UiO custom provider route"
)

advisory_rows=(
  "built-in-provider-fit|Built-in provider fit"
  "least-privilege-profile|Least-privilege profile"
  "reproducibility|Reproducibility"
)

[ "${#blocking_rows[@]}" -eq 7 ] || fail "expected exactly 7 blocking rows"
[ "${#advisory_rows[@]}" -eq 3 ] || fail "expected exactly 3 advisory rows"

run_row_in_pod_runtime() {
  require_file "$secure_profile_path" "secure nono profile"

  local out_wrapped
  out_wrapped="$(mktemp)"
  trap 'rm -f "$out_wrapped"' RETURN

  run_expect_success "wrapped opencode --version" "$out_wrapped" "$nono_bin" run --profile "$secure_profile_path" -- opencode --version
}

run_row_kernel_enforcement() {
  local sandbox_tmp allowed_dir denied_dir probe_script probe_output
  sandbox_tmp="$(mktemp -d "$repo_root/.tmp-nono-kernel-XXXXXX")"
  trap 'rm -rf "$sandbox_tmp"' RETURN
  allowed_dir="$sandbox_tmp/allowed"
  denied_dir="$sandbox_tmp/denied"
  mkdir -p "$allowed_dir" "$denied_dir"
  printf 'allowed-read\n' > "$allowed_dir/read.txt"
  printf 'denied-read\n' > "$denied_dir/secret.txt"

  probe_script="$allowed_dir/kernel-probe.sh"
  cat > "$probe_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
allowed_read="$1"
denied_read="$2"
allowed_write="$3"
denied_write="$4"
cat "$allowed_read" >/dev/null
printf 'kernel-check:allowed-read-ok\n'
if cat "$denied_read" >/dev/null 2>&1; then
  printf 'kernel-check:denied-read-allowed\n'
  exit 31
fi
printf 'kernel-check:denied-read-blocked\n'
printf 'allowed-write\n' > "$allowed_write"
printf 'kernel-check:allowed-write-ok\n'
if printf 'denied-write\n' > "$denied_write" 2>/dev/null; then
  printf 'kernel-check:denied-write-allowed\n'
  exit 32
fi
printf 'kernel-check:denied-write-blocked\n'
EOF
  chmod +x "$probe_script"

  probe_output="$(mktemp)"
  trap 'rm -rf "$sandbox_tmp" "$probe_output"' RETURN

  run_expect_success \
    "kernel enforcement probe" \
    "$probe_output" \
    "$nono_bin" run --allow "$allowed_dir" -- "$probe_script" "$allowed_dir/read.txt" "$denied_dir/secret.txt" "$allowed_dir/write.txt" "$denied_dir/write.txt"

  assert_output_contains "$probe_output" "kernel-check:allowed-read-ok" "kernel enforcement output"
  assert_output_contains "$probe_output" "kernel-check:denied-read-blocked" "kernel enforcement output"
  assert_output_contains "$probe_output" "kernel-check:allowed-write-ok" "kernel enforcement output"
  assert_output_contains "$probe_output" "kernel-check:denied-write-blocked" "kernel enforcement output"
}

run_row_fail_closed_behavior() {
  local tmp_root invalid_json_profile insecure_upstream_profile out_missing_credential
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' RETURN
  invalid_json_profile="$tmp_root/invalid-json.jsonc"
  insecure_upstream_profile="$tmp_root/insecure-upstream.jsonc"

  cat > "$invalid_json_profile" <<'EOF'
{ "meta": { "name": "broken-json" },
EOF

  cat > "$insecure_upstream_profile" <<'EOF'
{
  "meta": { "name": "insecure-upstream" },
  "workdir": { "access": "readwrite" },
  "network": {
    "credentials": ["bad_upstream"],
    "custom_credentials": {
      "bad_upstream": {
        "upstream": "http://example.com",
        "credential_key": "env://HUB_NONO_TEST_TOKEN",
        "env_var": "HUB_NONO_TEST_TOKEN"
      }
    }
  }
}
EOF

  local out_invalid_json out_insecure_upstream
  out_invalid_json="$(mktemp)"
  out_insecure_upstream="$(mktemp)"
  out_missing_credential="$(mktemp)"
  trap 'rm -rf "$tmp_root" "$out_invalid_json" "$out_insecure_upstream" "$out_missing_credential"' RETURN

  run_expect_failure "invalid JSON profile" "$out_invalid_json" "$nono_bin" run --profile "$invalid_json_profile" -- true
  run_expect_failure "insecure upstream profile" "$out_insecure_upstream" "$nono_bin" run --profile "$insecure_upstream_profile" -- true
  run_expect_failure "missing env credential source" "$out_missing_credential" "$nono_bin" run --allow-cwd --env-credential HUB_NONO_MISSING_ENV_TOKEN -- true
}

run_row_network_control() {
  local out_allowlisted out_blocked
  out_allowlisted="$(mktemp)"
  out_blocked="$(mktemp)"
  trap 'rm -f "$out_allowlisted" "$out_blocked"' RETURN

  run_expect_success \
    "allowlisted host reachability" \
    "$out_allowlisted" \
    "$nono_bin" run --allow-cwd --allow-domain example.com -- curl -m 10 -fsS https://example.com

  run_expect_failure \
    "non-allowlisted host blocked" \
    "$out_blocked" \
    "$nono_bin" run --allow-cwd --allow-domain example.com -- curl -m 10 -fsS https://example.org
}

run_row_proxy_credential_secrecy() {
  local tmp_root probe_script probe_output real_token
  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' RETURN
  probe_script="$tmp_root/proxy-secrecy-probe.sh"
  probe_output="$(mktemp)"
  trap 'rm -rf "$tmp_root" "$probe_output"' RETURN

  cat > "$probe_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
real_token="$1"
if env | grep -F "$real_token" >/dev/null; then
  printf 'proxy-secrecy:real-token-visible-in-env\n'
  exit 41
fi
if [ "${GITHUB_TOKEN:-}" = "$real_token" ]; then
  printf 'proxy-secrecy:real-token-visible-in-github-token-var\n'
  exit 42
fi
if tr '\0' '\n' < /proc/self/environ | grep -F "$real_token" >/dev/null; then
  printf 'proxy-secrecy:real-token-visible-in-proc-environ\n'
  exit 43
fi
printf 'proxy-secrecy:real-token-not-visible\n'
EOF
  chmod +x "$probe_script"

  real_token='REAL_GITHUB_TOKEN_SHOULD_NEVER_LEAK_IN_SANDBOX'
  run_expect_success \
    "proxy credential secrecy probe" \
    "$probe_output" \
    env GITHUB_TOKEN="$real_token" "$nono_bin" run --allow "$tmp_root" --credential github -- "$probe_script" "$real_token"

  assert_output_contains "$probe_output" "proxy-secrecy:real-token-not-visible" "proxy secrecy output"
  assert_output_not_contains "$probe_output" "$real_token" "proxy secrecy output"
}

run_row_opencode_functionality() {
  require_file "$secure_profile_path" "secure nono profile"

  local out_version out_help
  out_version="$(mktemp)"
  out_help="$(mktemp)"
  trap 'rm -f "$out_version" "$out_help"' RETURN

  run_expect_success "wrapped opencode --version" "$out_version" "$nono_bin" run --profile "$secure_profile_path" -- opencode --version
  run_expect_success "wrapped opencode --help" "$out_help" "$nono_bin" run --profile "$secure_profile_path" -- opencode --help

  assert_output_contains "$out_help" "opencode" "opencode help output"
}

run_row_uio_custom_provider_route() {
  require_file "$secure_profile_path" "secure nono profile"

  grep -F 'gpt-uio-yellow' "$secure_profile_path" >/dev/null || fail "secure profile missing gpt-uio-yellow route"
  grep -F 'gpt-uio-red' "$secure_profile_path" >/dev/null || fail "secure profile missing gpt-uio-red route"
  grep -F 'https://gpt.uio.no/api/v1' "$secure_profile_path" >/dev/null || fail "secure profile missing UiO upstream URL"
}

run_row_check() {
  local class="$1"
  local row_id="$2"
  local row_label="$3"

  local output_file
  output_file="$(mktemp)"
  trap 'rm -f "$output_file"' RETURN

  set +e
  case "$row_id" in
    in-pod-runtime)
      ( run_row_in_pod_runtime ) >"$output_file" 2>&1
      ;;
    kernel-enforcement)
      ( run_row_kernel_enforcement ) >"$output_file" 2>&1
      ;;
    fail-closed-behavior)
      ( run_row_fail_closed_behavior ) >"$output_file" 2>&1
      ;;
    network-control)
      ( run_row_network_control ) >"$output_file" 2>&1
      ;;
    proxy-credential-secrecy)
      ( run_row_proxy_credential_secrecy ) >"$output_file" 2>&1
      ;;
    opencode-functionality)
      ( run_row_opencode_functionality ) >"$output_file" 2>&1
      ;;
    uio-custom-provider-route)
      ( run_row_uio_custom_provider_route ) >"$output_file" 2>&1
      ;;
    built-in-provider-fit)
      printf 'advisory-row:pending built-in provider fit checks\n' >"$output_file"
      ;;
    least-privilege-profile)
      printf 'advisory-row:pending least-privilege profile minimization checks\n' >"$output_file"
      ;;
    reproducibility)
      printf 'advisory-row:pending reproducibility checks across pod restarts\n' >"$output_file"
      ;;
    *)
      printf 'unknown row id: %s\n' "$row_id" >"$output_file"
      set -e
      return 1
      ;;
  esac
  local rc="$?"
  set -e

  if [ "$rc" -ne 0 ]; then
    printf 'row=%s class=%s status=fail label=%s detail=%s\n' "$row_id" "$class" "$row_label" "$(tr '\n' ' ' < "$output_file")"
    return 1
  fi

  printf 'row=%s class=%s status=pass label=%s detail=%s\n' "$row_id" "$class" "$row_label" "$(tr '\n' ' ' < "$output_file")"
}

blocking_failures=0
advisory_failures=0

resolve_nono_bin

for row in "${blocking_rows[@]}"; do
  IFS='|' read -r row_id row_label <<<"$row"
  if ! run_row_check "blocking" "$row_id" "$row_label"; then
    blocking_failures=$((blocking_failures + 1))
  fi
done

for row in "${advisory_rows[@]}"; do
  IFS='|' read -r row_id row_label <<<"$row"
  if ! run_row_check "advisory" "$row_id" "$row_label"; then
    advisory_failures=$((advisory_failures + 1))
  fi
done

if [ "$advisory_failures" -gt 0 ]; then
  printf 'advisory_rows_pending=%s\n' "$advisory_failures"
fi

[ "$blocking_failures" -eq 0 ] || fail "blocking nono matrix has $blocking_failures failing row(s)"

printf 'PASS test_nono_blocking_matrix_contract\n'
