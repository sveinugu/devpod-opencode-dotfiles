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
mkdir -p "$workspace_root/repos/alpha/.bare" "$workspace_root/repos/alpha/master" "$workspace_root/repos/alpha/work/feature-child"
mkdir -p "$workspace_root/repos/alpha/work/spec/limit-peek-elements-design"
touch "$workspace_root/repos/alpha/work/spec/limit-peek-elements-design/.git"
mkdir -p "$workspace_root/state/repos/alpha/etc"
cat > "$workspace_root/state/repos/alpha/etc/repo.env" <<EOF
export DYN_REPO_DEFAULT_BRANCH=master
export DYN_REPO_DEFAULT_DIR=$workspace_root/repos/alpha/master
EOF

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

if [ "\$#" -gt 1 ]; then
  printf 'usage: dwt [name]\n' >&2
  exit 2
fi

if [ "\$#" -eq 0 ]; then
  printf '%s/repos/alpha/master\n' "$workspace_root"
  exit 0
fi

name="\$1"
if [ "\$name" = "master" ]; then
  printf '%s/repos/alpha/master\n' "$workspace_root"
  exit 0
fi
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
    cd "'$workspace_root/repos/alpha/master'"
    dwt feature-child >/tmp/ignore2.out
    printf "%s\n" "$PWD"
  '
)"
[ "$zsh_dwt_ok" = "$workspace_root/repos/alpha/work/feature-child" ] || fail "dwt shell wrapper should cd to resolver path"

zsh_dwt_default_noarg="$(
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    cd "'$workspace_root/repos/alpha/work/feature-child'"
    dwt >/tmp/ignore2-default.out
    printf "%s\n" "$PWD"
  '
)"
[ "$zsh_dwt_default_noarg" = "$workspace_root/repos/alpha/master" ] || fail "dwt shell wrapper should support no-arg default-checkout shortcut"

zsh_dwt_default_alias="$(
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    cd "'$workspace_root/repos/alpha/work/feature-child'"
    dwt master >/tmp/ignore2-default-alias.out
    printf "%s\n" "$PWD"
  '
)"
[ "$zsh_dwt_default_alias" = "$workspace_root/repos/alpha/master" ] || fail "dwt shell wrapper should support default-branch-name shortcut"

set +e
PATH="$mock_bin:$PATH" WORKSPACE_NAV_SCRIPT="$nav_script" zsh -fc '
  source "$WORKSPACE_NAV_SCRIPT"
  cd "'$workspace_root/repos/alpha/master'"
  dwt feature-chiild
' >"$tmpdir/dwt-shell-hint.out" 2>&1
dwt_shell_hint_rc="$?"
set -e
[ "$dwt_shell_hint_rc" = "1" ] || fail "dwt wrapper should return non-zero when resolver fails"
grep -F 'did you mean: feature-child' "$tmpdir/dwt-shell-hint.out" >/dev/null || fail "dwt wrapper should forward did-you-mean hint"

grep -F '_workspace_nav_complete_repos' "$nav_script" >/dev/null || fail "nav script should define repo completion function"
grep -F '_workspace_nav_complete_dwt' "$nav_script" >/dev/null || fail "nav script should define dwt completion function"
grep -F 'compdef _workspace_nav_complete_repos dre' "$nav_script" >/dev/null || fail "dre completion should be registered"
grep -F 'compdef _workspace_nav_complete_dwt dwt' "$nav_script" >/dev/null || fail "dwt completion should be registered"
grep -F 'compdef _workspace_nav_complete_dhub dhub' "$nav_script" >/dev/null || fail "dhub completion should be registered"

cat > "$tmpdir/mock-resolve-repo-root.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$workspace_root/repos/alpha"
EOF
chmod +x "$tmpdir/mock-resolve-repo-root.sh"

grep -F '_path_files -W "$repo_root/work" -/' "$nav_script" >/dev/null || fail "dwt completion should use _path_files path completion"

dwt_default_alias_completion="$({
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  HUB_WORKSPACE_ROOT="$workspace_root" \
  WORKSPACE_NAV_REPO_ROOT_RESOLVER="$tmpdir/mock-resolve-repo-root.sh" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    _path_files() { :; }
    compadd() {
      local arg
      for arg in "$@"; do
        case "$arg" in
          -*) ;;
          *) printf "%s\n" "$arg" ;;
        esac
      done
    }
    CURRENT=2
    _workspace_nav_complete_dwt
  '
} 2>/dev/null)"
printf '%s\n' "$dwt_default_alias_completion" | grep -Fx 'master' >/dev/null || fail "dwt completion should include repo default-branch alias"

completion_repos="$({
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  HUB_WORKSPACE_ROOT="$workspace_root" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    typeset -gi SAW_Q=0
    typeset -gi SAW_U=0
    compadd() {
      local arg
      for arg in "$@"; do
        if [ "$arg" = "-Q" ]; then
          SAW_Q=1
        fi
        if [ "$arg" = "-U" ]; then
          SAW_U=1
        fi
      done
    }
    _workspace_nav_complete_repos
    printf "q=%s\n" "$SAW_Q"
    printf "u=%s\n" "$SAW_U"
  '
} 2>/dev/null)"
printf '%s\n' "$completion_repos" | grep -Fx 'q=1' >/dev/null || fail "repo completion should use compadd -Q"
printf '%s\n' "$completion_repos" | grep -Fx 'u=1' >/dev/null || fail "repo completion should use compadd -U"

dwt_completion_transcript="$tmpdir/dwt-completion.transcript"
printf 'export HUB_WORKSPACE_ROOT="%s"\nexport HUB_INSTALL_BRANCH_DIR="%s"\nautoload -Uz compinit\ncompinit\nsource "%s"\ncd "%s/repos/alpha/master"\ndwt spec/lim\t\nexit\n' \
  "$workspace_root" \
  "$repo_root" \
  "$nav_script" \
  "$workspace_root" \
  | script -q -c 'zsh -fi' "$dwt_completion_transcript" >/dev/null

grep -F "cd -> $workspace_root/repos/alpha/work/spec/limit-peek-elements-design" "$dwt_completion_transcript" >/dev/null || fail "dwt tab completion should complete nested worktree names in interactive zsh"
if grep -F 'refused: worktree "spec/lim" not found' "$dwt_completion_transcript" >/dev/null; then
  fail "dwt interactive completion should not leave unresolved partial worktree"
fi

dre_completion_transcript="$tmpdir/dre-completion.transcript"
printf 'export HUB_WORKSPACE_ROOT="%s"\nexport HUB_INSTALL_BRANCH_DIR="%s"\nautoload -Uz compinit\ncompinit\nsource "%s"\ncd "%s/main"\ndre a\t\t\t\nexit\n' \
  "$workspace_root" \
  "$repo_root" \
  "$nav_script" \
  "$workspace_root" \
  | script -q -c 'zsh -fi' "$dre_completion_transcript" >/dev/null

grep -F "cd -> $workspace_root/repos/alpha" "$dre_completion_transcript" >/dev/null || fail "dre tab completion should complete unique repo names in interactive zsh"
if grep -F 'usage: dre <repo>' "$dre_completion_transcript" >/dev/null; then
  fail "dre interactive completion should not duplicate completed argument"
fi

printf 'PASS test_workspace_navigation_shell\n'
