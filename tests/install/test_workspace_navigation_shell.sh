#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_shell: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
nav_script="$repo_root/.config/shell/workspace-navigation.zsh"

[ -f "$nav_script" ] || fail "workspace-navigation.zsh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
mkdir -p "$workspace_root/main" "$workspace_root/work/feature-top" "$workspace_root/repos"
mkdir -p "$workspace_root/repos/alpha/.bare" "$workspace_root/repos/alpha/main" "$workspace_root/repos/alpha/work/feature-child"

mock_bin="$tmpdir/mock-bin"
mkdir -p "$mock_bin"

cat > "$mock_bin/dre" <<EOF
#!/usr/bin/env bash
set -euo pipefail
repo=''

if [ "\$#" -ne 1 ]; then
  printf 'usage: dre <repo>\n' >&2
  exit 2
fi

repo="\$1"
if [ "\$repo" = "alpa" ]; then
  printf 'refused: repo \"%s\" not found\n' "\$repo" >&2
  printf 'did you mean: alpha\n' >&2
  exit 1
fi

printf '%s/repos/%s\n' "$workspace_root" "\$repo"
EOF
chmod +x "$mock_bin/dre"

cat > "$mock_bin/dwt" <<EOF
#!/usr/bin/env bash
set -euo pipefail
name=''

if [ "\$#" -ne 1 ]; then
  printf 'usage: dwt <name>\n' >&2
  exit 2
fi

name="\$1"
if [ "\$name" = "feature-chiild" ]; then
  printf 'refused: worktree \"%s\" not found\n' "\$name" >&2
  printf 'did you mean: feature-child\n' >&2
  exit 1
fi

printf '%s/repos/alpha/work/%s\n' "$workspace_root" "\$name"
EOF
chmod +x "$mock_bin/dwt"

zsh_dre_ok="$(
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  WORKSPACE_NAV_LIBEXEC_DIR="$repo_root/scripts/lib" \
  HUB_INSTALL_ENV_FILE="$workspace_root/state/hub/etc/install.env" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    mkdir -p "$PWD"
    cd "'$workspace_root/main'"
    dre alpha >/tmp/ignore.out
    printf "%s\n" "$PWD"
  '
)"
[ "$zsh_dre_ok" = "$workspace_root/repos/alpha" ] || fail "dre shell wrapper should cd to resolver path"

set +e
PATH="$mock_bin:$PATH" WORKSPACE_NAV_SCRIPT="$nav_script" zsh -fc '
  source "$WORKSPACE_NAV_SCRIPT"
  cd "'$workspace_root/main'"
  dre alpa
' >"$tmpdir/dre-shell-hint.out" 2>&1
dre_shell_hint_rc="$?"
set -e
[ "$dre_shell_hint_rc" = "1" ] || fail "dre wrapper should return non-zero when resolver fails"
grep -F 'did you mean: alpha' "$tmpdir/dre-shell-hint.out" >/dev/null || fail "dre wrapper should forward did-you-mean hint"

zsh_dwt_ok="$(
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    cd "'$workspace_root/repos/alpha/main'"
    dwt feature-child >/tmp/ignore2.out
    printf "%s\n" "$PWD"
  '
)"
[ "$zsh_dwt_ok" = "$workspace_root/repos/alpha/work/feature-child" ] || fail "dwt shell wrapper should cd to resolver path"

set +e
PATH="$mock_bin:$PATH" WORKSPACE_NAV_SCRIPT="$nav_script" zsh -fc '
  source "$WORKSPACE_NAV_SCRIPT"
  cd "'$workspace_root/repos/alpha/main'"
  dwt feature-chiild
' >"$tmpdir/dwt-shell-hint.out" 2>&1
dwt_shell_hint_rc="$?"
set -e
[ "$dwt_shell_hint_rc" = "1" ] || fail "dwt wrapper should return non-zero when resolver fails"
grep -F 'did you mean: feature-child' "$tmpdir/dwt-shell-hint.out" >/dev/null || fail "dwt wrapper should forward did-you-mean hint"

grep -F '_workspace_nav_complete_repos' "$nav_script" >/dev/null || fail "nav script should define repo completion function"
grep -F '_workspace_nav_complete_worktrees' "$nav_script" >/dev/null || fail "nav script should define worktree completion function"
grep -F 'compdef _workspace_nav_complete_repos dre' "$nav_script" >/dev/null || fail "dre completion should be registered"
grep -F 'compdef _workspace_nav_complete_worktrees dwt' "$nav_script" >/dev/null || fail "dwt completion should be registered"
grep -F 'compdef _workspace_nav_complete_dhub dhub' "$nav_script" >/dev/null || fail "dhub completion should be registered"

printf 'PASS test_workspace_navigation_shell\n'
