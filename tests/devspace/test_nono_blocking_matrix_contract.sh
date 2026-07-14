#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_blocking_matrix_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
matrix_runner="$repo_root/scripts/devspace/verify-nono-matrix-row.sh"

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

blocking_failures=0
advisory_failures=0

run_row_check() {
  local class="$1"
  local row_id="$2"
  local row_label="$3"

  local output_file
  output_file="$(mktemp)"
  trap 'rm -f "$output_file"' RETURN

  if [ ! -x "$matrix_runner" ]; then
    printf 'row=%s class=%s status=fail reason=missing-runner runner=%s\n' "$row_id" "$class" "$matrix_runner"
    if [ "$class" = "blocking" ]; then
      blocking_failures=$((blocking_failures + 1))
    else
      advisory_failures=$((advisory_failures + 1))
    fi
    return
  fi

  local rc
  set +e
  HUB_NONO_CREDENTIAL_MODE="dummy" \
    HUB_NONO_DUMMY_OPENAI_KEY="dummy-openai-key" \
    HUB_NONO_DUMMY_ANTHROPIC_KEY="dummy-anthropic-key" \
    HUB_NONO_DUMMY_GITHUB_TOKEN="dummy-github-token" \
    HUB_NONO_DUMMY_UIO_YELLOW_KEY="dummy-uio-yellow-key" \
    HUB_NONO_DUMMY_UIO_RED_KEY="dummy-uio-red-key" \
    "$matrix_runner" --row "$row_id" --class "$class" --credential-mode dummy >"$output_file" 2>&1
  rc="$?"
  set -e

  if [ "$rc" -ne 0 ]; then
    printf 'row=%s class=%s status=fail rc=%s detail=%s\n' "$row_id" "$class" "$rc" "$(tr '\n' ' ' < "$output_file")"
    if [ "$class" = "blocking" ]; then
      blocking_failures=$((blocking_failures + 1))
    else
      advisory_failures=$((advisory_failures + 1))
    fi
    return
  fi

  if ! grep -F "row=$row_id" "$output_file" >/dev/null; then
    printf 'row=%s class=%s status=fail reason=missing-row-marker detail=%s\n' "$row_id" "$class" "$(tr '\n' ' ' < "$output_file")"
    if [ "$class" = "blocking" ]; then
      blocking_failures=$((blocking_failures + 1))
    else
      advisory_failures=$((advisory_failures + 1))
    fi
    return
  fi

  printf 'row=%s class=%s status=pass label=%s\n' "$row_id" "$class" "$row_label"
}

for row in "${blocking_rows[@]}"; do
  IFS='|' read -r row_id row_label <<<"$row"
  run_row_check "blocking" "$row_id" "$row_label"
done

for row in "${advisory_rows[@]}"; do
  IFS='|' read -r row_id row_label <<<"$row"
  run_row_check "advisory" "$row_id" "$row_label"
done

if [ "$advisory_failures" -gt 0 ]; then
  printf 'advisory_rows_pending=%s\n' "$advisory_failures"
fi

[ "$blocking_failures" -eq 0 ] || fail "blocking nono matrix has $blocking_failures failing row(s)"

printf 'PASS test_nono_blocking_matrix_contract\n'
