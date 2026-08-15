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
