#!/usr/bin/env bash
set -euo pipefail

is_inside_nono_sandbox() {
  [ -n "${NONO_CAP_FILE:-}" ] || [ -n "${NONO_TOOL_SANDBOX_SOCKET:-}" ] || [ -n "${NONO_TOOL_SANDBOX_SHIM_DIR:-}" ]
}

require_inside_nono_sandbox() {
  local test_name="$1"
  local hint="${2:-bash tests/run.sh pod-inside-nono}"

  if ! is_inside_nono_sandbox; then
    printf 'FAIL %s: test must run inside nono sandbox (hint: %s)\n' "$test_name" "$hint" >&2
    exit 1
  fi
}

require_outside_nono_sandbox() {
  local test_name="$1"
  local hint="${2:-bash tests/run.sh pod-outside-nono}"

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
  local hint="${2:-bash tests/run.sh host}"

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
  require_host_shell "$test_name" 'bash tests/run.sh host'
}

require_pod_outside_nono_test() {
  local test_name="$1"
  require_workspace_pod "$test_name" 'bash tests/run.sh pod-outside-nono'
  require_outside_nono_sandbox "$test_name" 'bash tests/run.sh pod-outside-nono'
}

require_pod_inside_nono_test() {
  local test_name="$1"
  require_workspace_pod "$test_name" 'bash tests/run.sh pod-inside-nono'
  require_inside_nono_sandbox "$test_name" 'bash tests/run.sh pod-inside-nono'
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

  while [ "$temp_root" != '/' ] && [ "${temp_root%/}" != "$temp_root" ]; do
    temp_root="${temp_root%/}"
  done

  if [ -z "$temp_root" ]; then
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

context_stat_mode() {
  local path="$1"
  local mode=''

  if mode="$(stat -c '%a' "$path" 2>/dev/null)"; then
    printf '%s\n' "$mode"
    return 0
  fi

  if mode="$(stat -f '%Lp' "$path" 2>/dev/null)"; then
    printf '%s\n' "$mode"
    return 0
  fi

  return 1
}

context_has_script_dash_c() {
  script -q -e -c 'true' /dev/null >/dev/null 2>&1
}

context_run_interactive_script() {
  local input="$1"
  local output_path="$2"
  local command="$3"
  local pty_runner=''
  local rc=0

  # Prefer python PTY runner for deterministic cross-platform behavior.
  if command -v python3 >/dev/null 2>&1; then
    pty_runner="$(mktemp "${TMPDIR:-/tmp}/context-pty-runner-XXXXXX.py")"
    cat >"$pty_runner" <<'PY'
import fcntl
import os
import pty
import select
import shutil
import subprocess
import sys
import termios
import time

output_path = sys.argv[1]
command = os.environ.get("INTERACTIVE_COMMAND", "")
input_data = sys.stdin.buffer.read()

shell = shutil.which("bash") or shutil.which("sh") or "/bin/sh"
master_fd, slave_fd = pty.openpty()

def preexec() -> None:
    os.setsid()
    fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)

proc = subprocess.Popen(
    [shell, "-c", command],
    stdin=slave_fd,
    stdout=slave_fd,
    stderr=slave_fd,
    close_fds=True,
    preexec_fn=preexec,
)
os.close(slave_fd)

captured = bytearray()
offset = 0
deadline = time.time() + 20.0
timed_out = False

while True:
    readable, _, _ = select.select([master_fd], [], [], 0.05)
    if readable:
        try:
            chunk = os.read(master_fd, 4096)
        except OSError:
            chunk = b""
        if chunk:
            captured.extend(chunk)

    if offset < len(input_data):
        try:
            written = os.write(master_fd, input_data[offset:])
        except OSError:
            written = 0
        offset += written

    if proc.poll() is not None:
        while True:
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                chunk = b""
            if not chunk:
                break
            captured.extend(chunk)
        break

    if time.time() > deadline:
        timed_out = True
        try:
            proc.kill()
        except OSError:
            pass
        captured.extend(b"\n[context_run_interactive_script timeout]\n")
        break

os.close(master_fd)

with open(output_path, "wb") as fh:
    fh.write(captured)

sys.stdout.buffer.write(captured)
if timed_out:
    sys.exit(124)

sys.exit(proc.returncode if proc.returncode is not None else 1)
PY

    if ! printf '%b' "$input" | INTERACTIVE_COMMAND="$command" python3 "$pty_runner" "$output_path"; then
      rc=$?
    fi
    rm -f "$pty_runner"
    return "$rc"
  fi

  # Fallback: GNU/util-linux script(1) with -c.
  if context_has_script_dash_c; then
    printf '%b' "$input" | script -q -e -c "$command" /dev/null >"$output_path"
    return
  fi

  printf 'FAIL context_run_interactive_script: no compatible pseudo-tty runner (python3 missing and script -c unavailable)\n' >&2
  exit 1
}

context_canonical_dir() {
  local path="$1"
  (
    cd "$path"
    pwd -P
  )
}

context_git_common_dir_abs() {
  local repo_dir="$1"
  local common_dir=''

  common_dir="$(git -C "$repo_dir" rev-parse --git-common-dir 2>/dev/null || true)"
  [ -n "$common_dir" ] || return 1

  case "$common_dir" in
    /*)
      context_canonical_dir "$common_dir"
      ;;
    *)
      (
        cd "$repo_dir"
        cd "$common_dir"
        pwd -P
      )
      ;;
  esac
}
