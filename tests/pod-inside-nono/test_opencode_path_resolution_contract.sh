#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_path_resolution_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=tests/lib/context-guards.sh
source "$repo_root/tests/lib/context-guards.sh"
require_pod_inside_nono_test 'test_opencode_path_resolution_contract'

zshrc="$repo_root/.zshrc"

[ -f "$zshrc" ] || fail ".zshrc not found"

grep -F 'export PATH=$HOME/.config/opencode/bin:/usr/local/bin:$PATH' "$zshrc" >/dev/null || fail "zshrc must prepend wrapped opencode bin before /usr/local/bin"

temp_root="$(context_resolve_temp_root_workspace_or_fail 'test_opencode_path_resolution_contract')"
tmp_root="$(context_make_test_tmpdir "$temp_root" 'test_opencode_path_resolution_contract')"
trap 'rm -rf "$tmp_root"' EXIT

home_dir="$tmp_root/home"
mkdir -p "$home_dir/.config/opencode/bin" "$tmp_root/usr-local-bin"

cat >"$home_dir/.config/opencode/bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'wrapped-opencode\n'
EOF
chmod +x "$home_dir/.config/opencode/bin/opencode"

cat >"$home_dir/.config/opencode/bin/nono-why" <<'EOF'
#!/usr/bin/env bash
printf 'wrapped-nono-why\n'
EOF
chmod +x "$home_dir/.config/opencode/bin/nono-why"

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

HOME="$home_dir" PATH="$home_dir/.config/opencode/bin:$tmp_root/usr-local-bin:/usr/bin:/bin" \
  zsh -fc 'command -v nono-why; type -a nono-why' >"$tmp_root/shell-nono-why.out" 2>&1 || fail "zsh nono-why command-v/type-a probe should succeed"

first_nono_why_line="$(sed -n '1p' "$tmp_root/shell-nono-why.out")"
[ "$first_nono_why_line" = "$home_dir/.config/opencode/bin/nono-why" ] || fail "command -v nono-why should resolve to wrapped executable first"

grep -F "$home_dir/.config/opencode/bin/nono-why" "$tmp_root/shell-nono-why.out" >/dev/null || fail "type -a should list wrapped nono-why executable"

raw_out="$tmp_root/raw.out"
"$tmp_root/usr-local-bin/opencode-raw" >"$raw_out" 2>&1 || fail "raw absolute-path opencode should remain runnable"
grep -F 'raw-opencode' "$raw_out" >/dev/null || fail "raw absolute-path opencode output mismatch"

printf 'PASS test_opencode_path_resolution_contract\n'
