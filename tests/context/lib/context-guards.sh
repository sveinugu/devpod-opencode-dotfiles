#!/usr/bin/env bash
set -euo pipefail

is_inside_nono_sandbox() {
  [ -n "${NONO_CAP_FILE:-}" ] || [ -n "${NONO_TOOL_SANDBOX_SOCKET:-}" ] || [ -n "${NONO_TOOL_SANDBOX_SHIM_DIR:-}" ]
}

require_inside_nono_sandbox() {
  local test_name="$1"
  local hint="${2:-bash tests/context/run.sh pod-inside-nono}"

  if ! is_inside_nono_sandbox; then
    printf 'FAIL %s: test must run inside nono sandbox (hint: %s)\n' "$test_name" "$hint" >&2
    exit 1
  fi
}

require_outside_nono_sandbox() {
  local test_name="$1"
  local hint="${2:-bash tests/context/run.sh pod-outside-nono}"

  if is_inside_nono_sandbox; then
    printf 'FAIL %s: test must run outside nono sandbox (hint: %s)\n' "$test_name" "$hint" >&2
    exit 1
  fi
}

require_workspace_pod() {
  local test_name="$1"
  local hint="${2:-run from workspace/pod shell}"

  if [ ! -d /workspaces/dotfiles ]; then
    printf 'FAIL %s: test must run in workspace/pod environment (missing /workspaces/dotfiles; hint: %s)\n' "$test_name" "$hint" >&2
    exit 1
  fi
}

require_host_shell() {
  local test_name="$1"
  local hint="${2:-bash tests/context/run.sh host}"

  if is_inside_nono_sandbox; then
    printf 'FAIL %s: test must run outside nono sandbox (hint: %s)\n' "$test_name" "$hint" >&2
    exit 1
  fi

  if [ -d /workspaces/dotfiles ]; then
    printf 'FAIL %s: test must run on host shell (workspace pod path detected: /workspaces/dotfiles; hint: %s)\n' "$test_name" "$hint" >&2
    exit 1
  fi
}

require_host_test() {
  local test_name="$1"
  require_host_shell "$test_name" 'bash tests/context/run.sh host'
}

require_pod_outside_nono_test() {
  local test_name="$1"
  require_workspace_pod "$test_name" 'bash tests/context/run.sh pod-outside-nono'
  require_outside_nono_sandbox "$test_name" 'bash tests/context/run.sh pod-outside-nono'
}

require_pod_inside_nono_test() {
  local test_name="$1"
  require_workspace_pod "$test_name" 'bash tests/context/run.sh pod-inside-nono'
  require_inside_nono_sandbox "$test_name" 'bash tests/context/run.sh pod-inside-nono'
}

skip_if_wrong_context() {
  local expected_context="$1"
  local test_name="$2"
  local hint="$3"

  case "$expected_context" in
    pod-inside-nono)
      if ! is_inside_nono_sandbox; then
        printf 'SKIP %s: wrong context (expected pod-inside-nono; hint: %s)\n' "$test_name" "$hint" >&2
        exit 0
      fi
      ;;
    pod-outside-nono)
      if is_inside_nono_sandbox; then
        printf 'SKIP %s: wrong context (expected pod-outside-nono; hint: %s)\n' "$test_name" "$hint" >&2
        exit 0
      fi
      ;;
    host)
      if is_inside_nono_sandbox || [ -d /workspaces/dotfiles ]; then
        printf 'SKIP %s: wrong context (expected host; hint: %s)\n' "$test_name" "$hint" >&2
        exit 0
      fi
      ;;
    *)
      printf 'FAIL %s: unknown context passed to skip_if_wrong_context: %s\n' "$test_name" "$expected_context" >&2
      exit 1
      ;;
  esac
}

context_resolve_temp_root_host() {
  local temp_root="${TEMP:-${TMP:-${TMPDIR:-/tmp}}}"

  if [[ "$temp_root" != /* ]]; then
    temp_root='/tmp'
  fi

  printf '%s\n' "$temp_root"
}

context_resolve_temp_root_workspace_or_fail() {
  local test_name="${1:-$(basename "${BASH_SOURCE[1]:-context-test}" .sh)}"
  local temp_root="${TEMP:-${TMP:-${TMPDIR:-}}}"

  if [ -z "$temp_root" ]; then
    printf 'FAIL %s: TEMP/TMP/TMPDIR must be set (expected from .envrc)\n' "$test_name" >&2
    exit 1
  fi

  case "$temp_root" in
    /*) ;;
    *)
      printf 'FAIL %s: TEMP/TMP/TMPDIR must be an absolute path: %s\n' "$test_name" "$temp_root" >&2
      exit 1
      ;;
  esac

  printf '%s\n' "$temp_root"
}

context_make_test_tmpdir() {
  local temp_root="$1"
  local test_slug="$2"
  local test_tmp_root="$temp_root/tests"

  mkdir -p "$test_tmp_root"
  mktemp -d "$test_tmp_root/${test_slug}-XXXXXX"
}
