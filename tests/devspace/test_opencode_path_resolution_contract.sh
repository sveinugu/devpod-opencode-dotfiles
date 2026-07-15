#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_opencode_path_resolution_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
zshrc="$repo_root/.zshrc"

[ -f "$zshrc" ] || fail ".zshrc not found"

grep -F 'export PATH=$HOME/.config/opencode/bin:$HOME/.opencode/bin:$PATH' "$zshrc" >/dev/null || fail "zshrc must prepend wrapped opencode bin before raw opencode bin"

tmp_root="$(mktemp -d "$repo_root/.tmp-opencode-path-contract-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

home_dir="$tmp_root/home"
mkdir -p "$home_dir/.config/opencode/bin" "$home_dir/.opencode/bin"

cat >"$home_dir/.config/opencode/bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'wrapped-opencode\n'
EOF
chmod +x "$home_dir/.config/opencode/bin/opencode"

cat >"$home_dir/.opencode/bin/opencode" <<'EOF'
#!/usr/bin/env bash
printf 'raw-opencode\n'
EOF
chmod +x "$home_dir/.opencode/bin/opencode"

shell_out="$tmp_root/shell.out"

HOME="$home_dir" PATH="$home_dir/.config/opencode/bin:$home_dir/.opencode/bin:/usr/bin:/bin" \
  zsh -fc 'command -v opencode; type -a opencode' >"$shell_out" 2>&1 || fail "zsh command-v/type-a probe should succeed"

first_line="$(sed -n '1p' "$shell_out")"
[ "$first_line" = "$home_dir/.config/opencode/bin/opencode" ] || fail "command -v opencode should resolve to wrapped executable first"

grep -F "$home_dir/.config/opencode/bin/opencode" "$shell_out" >/dev/null || fail "type -a should list wrapped executable"
grep -F "$home_dir/.opencode/bin/opencode" "$shell_out" >/dev/null || fail "type -a should list raw executable"

raw_out="$tmp_root/raw.out"
"$home_dir/.opencode/bin/opencode" >"$raw_out" 2>&1 || fail "raw absolute-path opencode should remain runnable"
grep -F 'raw-opencode' "$raw_out" >/dev/null || fail "raw absolute-path opencode output mismatch"

printf 'PASS test_opencode_path_resolution_contract\n'
