#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_install_oh_my_zsh_failure_surface: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
install_script="$repo_root/install.sh"
validator_script="$repo_root/scripts/lib/validate_install_source_tree.sh"

[ -f "$install_script" ] || fail "install.sh not found"
[ -f "$validator_script" ] || fail "scripts/lib/validate_install_source_tree.sh not found"

if grep -F '2>/dev/null || true' "$install_script" >/dev/null; then
  fail "oh-my-zsh install path must not swallow errors"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspaces/dotfiles"
source_root="$workspace_root/main"
home_dir="$tmpdir/home"
bin_dir="$tmpdir/bin"

mkdir -p "$source_root/.config/opencode" "$source_root/scripts/lib/install" "$home_dir" "$bin_dir"

cp "$install_script" "$source_root/install.sh"
cp "$validator_script" "$source_root/scripts/lib/validate_install_source_tree.sh"
cp "$repo_root/scripts/lib/install/parse-args.sh" "$source_root/scripts/lib/install/parse-args.sh"
cp "$repo_root/scripts/lib/install/resolve-source.sh" "$source_root/scripts/lib/install/resolve-source.sh"
cp "$repo_root/scripts/lib/install/validate-source.sh" "$source_root/scripts/lib/install/validate-source.sh"
cp "$repo_root/scripts/lib/install/materialize.sh" "$source_root/scripts/lib/install/materialize.sh"
chmod +x \
  "$source_root/install.sh" \
  "$source_root/scripts/lib/validate_install_source_tree.sh" \
  "$source_root/scripts/lib/install/parse-args.sh" \
  "$source_root/scripts/lib/install/resolve-source.sh" \
  "$source_root/scripts/lib/install/validate-source.sh" \
  "$source_root/scripts/lib/install/materialize.sh"

printf 'export TEST_ZSHRC=1\n' > "$source_root/.zshrc"
printf 'source "$HOME/.zshrc"\n' > "$source_root/.zprofile"
printf '{"name":"test"}\n' > "$source_root/.config/opencode/opencode.jsonc"

cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    out="$1"
    shift
    continue
  fi
  shift
done

[ -n "$out" ]

cat > "$out" <<'SCRIPT'
printf 'intentional-ohmyzsh-failure\n' >&2
exit 37
SCRIPT
EOF
chmod +x "$bin_dir/curl"

cat > "$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" = "clone" ]; then
  mkdir -p "$3"
  exit 0
fi
command git "$@"
EOF
chmod +x "$bin_dir/git"

cat > "$bin_dir/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$bin_dir/npx"

if env -u HUB_INSTALL_BRANCH -u HUB_INSTALL_BRANCH_DIR \
  PATH="$bin_dir:$PATH" HOME="$home_dir" WORKSPACE_ROOT="$workspace_root" \
  bash "$source_root/install.sh" >"$tmpdir/out.log" 2>"$tmpdir/err.log"; then
  fail "install.sh should fail when oh-my-zsh installer fails"
fi

grep -F 'intentional-ohmyzsh-failure' "$tmpdir/err.log" >/dev/null || fail "expected oh-my-zsh installer error on stderr"

rm -rf "$home_dir/.oh-my-zsh"

cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'intentional-curl-fetch-failure\n' >&2
exit 55
EOF
chmod +x "$bin_dir/curl"

if env -u HUB_INSTALL_BRANCH -u HUB_INSTALL_BRANCH_DIR \
  PATH="$bin_dir:$PATH" HOME="$home_dir" WORKSPACE_ROOT="$workspace_root" \
  bash "$source_root/install.sh" >"$tmpdir/out2.log" 2>"$tmpdir/err2.log"; then
  fail "install.sh should fail when oh-my-zsh curl fetch fails"
fi

grep -F 'failed to download oh-my-zsh installer' "$tmpdir/err2.log" >/dev/null || fail "expected explicit curl fetch failure message"

printf 'PASS test_install_oh_my_zsh_failure_surface\n'
