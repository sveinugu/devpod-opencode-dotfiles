#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_path_resolution_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/context/lib/context-guards.sh
source "$repo_root/tests/context/lib/context-guards.sh"
require_workspace_pod 'test_opencode_path_resolution_contract' 'bash tests/context/run.sh pod-inside-nono'
require_inside_nono_sandbox 'test_opencode_path_resolution_contract' 'bash tests/context/run.sh pod-inside-nono'

zshrc="$repo_root/.zshrc"

[ -f "$zshrc" ] || fail ".zshrc not found"

grep -F 'export PATH=$HOME/.config/opencode/bin:/usr/local/bin:$PATH' "$zshrc" >/dev/null || fail "zshrc must prepend wrapped opencode bin before /usr/local/bin"

temp_root="${TEMP:-${TMP:-${TMPDIR:-}}}"
[ -n "$temp_root" ] || fail 'TEMP/TMP/TMPDIR must be set (expected from .envrc)'
case "$temp_root" in
  /*) ;;
  *) fail "TEMP/TMP/TMPDIR must be an absolute path: $temp_root" ;;
esac
test_tmp_root="$temp_root/tests"
mkdir -p "$test_tmp_root"

tmp_root="$(mktemp -d "$test_tmp_root/test_opencode_path_resolution_contract-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

home_dir="$tmp_root/home"
mkdir -p "$home_dir/.config/opencode/bin" "$tmp_root/usr-local-bin"

cat >"$home_dir/.config/opencode/bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'wrapped-opencode\n'
EOF
chmod +x "$home_dir/.config/opencode/bin/opencode"

cat >"$tmp_root/usr-local-bin/opencode-raw" <<'EOF'
#!/usr/bin/env bash
printf 'raw-opencode\n'
EOF
chmod +x "$tmp_root/usr-local-bin/opencode-raw"

shell_out="$tmp_root/shell.out"

HOME="$home_dir" PATH="$home_dir/.config/opencode/bin:$tmp_root/usr-local-bin:/usr/bin:/bin" \
  zsh -fc 'command -v opencode; type -a opencode' >"$shell_out" 2>&1 || fail "zsh command-v/type-a probe should succeed"

first_line="$(sed -n '1p' "$shell_out")"
[ "$first_line" = "$home_dir/.config/opencode/bin/opencode" ] || fail "command -v opencode should resolve to wrapped executable first"

grep -F "$home_dir/.config/opencode/bin/opencode" "$shell_out" >/dev/null || fail "type -a should list wrapped executable"

raw_out="$tmp_root/raw.out"
"$tmp_root/usr-local-bin/opencode-raw" >"$raw_out" 2>&1 || fail "raw absolute-path opencode should remain runnable"
grep -F 'raw-opencode' "$raw_out" >/dev/null || fail "raw absolute-path opencode output mismatch"

printf 'PASS test_opencode_path_resolution_contract\n'
