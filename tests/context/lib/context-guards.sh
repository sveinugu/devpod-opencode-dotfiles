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
