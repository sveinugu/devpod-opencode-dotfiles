#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_why_wrapper_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_nono_why_wrapper_contract'

wrapper="$repo_root/.config/opencode/bin/nono-why"

[ -x "$wrapper" ] || fail "nono-why wrapper not found or not executable"
grep -F 'NONO_CAP_FILE' "$wrapper" >/dev/null || fail "nono-why wrapper must handle NONO_CAP_FILE rebasing for --self"
grep -F '/dev/stdin' "$wrapper" >/dev/null || fail "nono-why wrapper must repair /dev/stdin state path"
grep -F '/proc/self' "$wrapper" >/dev/null || fail "nono-why wrapper must repair /proc/self state path"
grep -F '/dev/fd' "$wrapper" >/dev/null || fail "nono-why wrapper must repair /dev/fd state path"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_nono_why_wrapper_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_nono_why_wrapper_contract')"
trap 'rm -rf "$tmp_root"' EXIT

mock_bin="$tmp_root/mock-bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/nono" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ "${1:-}" = "why" ] || {
  printf 'expected first arg to be why, got: %s\n' "${1:-}" >&2
  exit 64
}
shift

wants_self='no'
for arg in "$@"; do
  if [ "$arg" = '--self' ]; then
    wants_self='yes'
    break
  fi
done

if [ "$wants_self" = 'yes' ]; then
  expected_stdin="$(readlink /proc/self/fd/0 2>/dev/null || printf '/dev/null')"
  expected_pid="$$"
  python3 - "${NONO_CAP_FILE:?NONO_CAP_FILE must be set}" "$expected_stdin" "$expected_pid" <<'PY'
import json
import sys

cap_path, expected_stdin, expected_pid = sys.argv[1:4]
with open(cap_path, 'r', encoding='utf-8') as fh:
    cap = json.load(fh)

by_original = {}
for entry in cap.get('fs', []):
    original = entry.get('original')
    if isinstance(original, str):
        by_original[original] = entry.get('path')

expected = {
    '/dev/stdin': expected_stdin,
    '/proc/self': f'/proc/{expected_pid}',
    '/dev/fd': f'/proc/{expected_pid}/fd',
}

for key, expected_path in expected.items():
    actual = by_original.get(key)
    if actual != expected_path:
        raise SystemExit(
            f'drift not repaired for {key}: expected {expected_path!r}, got {actual!r}'
        )
PY
  printf 'ALLOWED\n'
  exit 0
fi

printf 'PASSTHROUGH:%s\n' "$*"
EOF
chmod +x "$mock_bin/nono"

cat >"$tmp_root/stale-cap.json" <<'JSON'
{
  "fs": [
    {
      "original": "/dev/stdin",
      "path": "/dev/pts/2"
    },
    {
      "original": "/proc/self",
      "path": "/proc/999999"
    },
    {
      "original": "/dev/fd",
      "path": "/proc/999999/fd"
    }
  ]
}
JSON

HUB_NONO_BINARY="$mock_bin/nono" \
NONO_CAP_FILE="$tmp_root/stale-cap.json" \
bash "$wrapper" --self --path /tmp --op read >"$tmp_root/self.out" 2>"$tmp_root/self.err" || fail "nono-why should repair stale NONO_CAP_FILE paths before --self query"

grep -F 'ALLOWED' "$tmp_root/self.out" >/dev/null || fail "nono-why should keep --self query green after repairing cap-file paths"

HUB_NONO_BINARY="$mock_bin/nono" \
NONO_CAP_FILE="$tmp_root/stale-cap.json" \
bash "$wrapper" --path /tmp --op read >"$tmp_root/no-self.out" 2>"$tmp_root/no-self.err" || fail "nono-why should pass through non-self queries"

grep -F 'PASSTHROUGH:--path /tmp --op read' "$tmp_root/no-self.out" >/dev/null || fail "nono-why should preserve non-self argv passthrough"

printf 'PASS test_nono_why_wrapper_contract\n'
