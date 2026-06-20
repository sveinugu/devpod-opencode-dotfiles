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

if [ "\$repo" = "beta" ]; then
  printf 'refused: managed child default branch metadata is missing or invalid for \"%s\"\n' "\$repo" >&2
  printf 'to repair, run:\n' >&2
  printf '  HUB_WORKSPACE_ROOT=\"$workspace_root\" bash /workspaces/dotfiles/main/scripts/lib/write-managed-repo-env.sh \"%s\" \"main\" \"$workspace_root/repos/%s/main\"\n' "\$repo" "\$repo" >&2
  exit 1
fi

printf '%s/repos/%s/master\n' "$workspace_root" "\$repo"
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
[ "$zsh_dre_ok" = "$workspace_root/repos/alpha/master" ] || fail "dre shell wrapper should cd to child default checkout path"

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

set +e
PATH="$mock_bin:$PATH" WORKSPACE_NAV_SCRIPT="$nav_script" zsh -fc '
  source "$WORKSPACE_NAV_SCRIPT"
  cd "'$workspace_root/main'"
  dre beta
' >"$tmpdir/dre-shell-metadata.out" 2>&1
dre_shell_metadata_rc="$?"
set -e
[ "$dre_shell_metadata_rc" = "1" ] || fail "dre wrapper should return non-zero for missing child metadata"
grep -F 'refused: managed child default branch metadata is missing or invalid for "beta"' "$tmpdir/dre-shell-metadata.out" >/dev/null || fail "dre wrapper should forward child metadata refusal with repo context"
grep -F 'to repair, run:' "$tmpdir/dre-shell-metadata.out" >/dev/null || fail "dre wrapper should forward human-readable repair intro"
grep -F "  HUB_WORKSPACE_ROOT=\"$workspace_root\" bash /workspaces/dotfiles/main/scripts/lib/write-managed-repo-env.sh \"beta\" \"main\" \"$workspace_root/repos/beta/main\"" "$tmpdir/dre-shell-metadata.out" >/dev/null || fail "dre wrapper should forward exact runnable metadata repair command on its own line"

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
grep -F '_workspace_nav_compadd_with_prefix' "$nav_script" >/dev/null || fail "nav script should define shared prefix-aware compadd helper"
grep -F 'compdef _workspace_nav_complete_repos dre' "$nav_script" >/dev/null || fail "dre completion should be registered"
grep -F 'compdef _workspace_nav_complete_dwt dwt' "$nav_script" >/dev/null || fail "dwt completion should be registered"
grep -F 'compdef _workspace_nav_complete_dhub dhub' "$nav_script" >/dev/null || fail "dhub completion should be registered"

shared_compadd_count="$(grep -F 'compadd -Q -U -S ' "$nav_script" | wc -l | tr -d ' ')"
[ "$shared_compadd_count" = "1" ] || fail "nav script should centralize compadd suffix-control logic in one helper"

cat > "$tmpdir/mock-resolve-repo-root.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$workspace_root/repos/alpha"
EOF
chmod +x "$tmpdir/mock-resolve-repo-root.sh"

if grep -F '_path_files -W "$repo_root/work" -/' "$nav_script" >/dev/null; then
  fail "dwt completion should use direct worktree-name candidates, not _path_files path completion"
fi

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

dwt_nested_worktree_completion="$({
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  HUB_WORKSPACE_ROOT="$workspace_root" \
  WORKSPACE_NAV_REPO_ROOT_RESOLVER="$tmpdir/mock-resolve-repo-root.sh" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    _path_files() {
      printf "UNEXPECTED_PATH_FILES\n"
    }
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
    PREFIX="spec/lim"
    _workspace_nav_complete_dwt
  '
} 2>/dev/null)"
if printf '%s\n' "$dwt_nested_worktree_completion" | grep -Fx 'UNEXPECTED_PATH_FILES' >/dev/null; then
  fail "dwt completion should not call _path_files for nested worktree names"
fi
printf '%s\n' "$dwt_nested_worktree_completion" | grep -Fx 'spec/limit-peek-elements-design' >/dev/null || fail "dwt completion should include full slash-containing worktree names as direct candidates"

dwt_completion_suffix_flags="$({
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  HUB_WORKSPACE_ROOT="$workspace_root" \
  WORKSPACE_NAV_REPO_ROOT_RESOLVER="$tmpdir/mock-resolve-repo-root.sh" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    typeset -gi SAW_SUFFIX_EMPTY=0
    compadd() {
      local i=1
      while (( i <= $# )); do
        if [ "${@[i]}" = "-S" ] && (( i < $# )) && [ "${@[i+1]}" = "" ]; then
          SAW_SUFFIX_EMPTY=1
        fi
        (( i++ ))
      done
    }
    CURRENT=2
    PREFIX="spec/lim"
    _workspace_nav_complete_dwt
    printf "s_empty=%s\n" "$SAW_SUFFIX_EMPTY"
  '
} 2>/dev/null)"
printf '%s\n' "$dwt_completion_suffix_flags" | grep -Fx 's_empty=1' >/dev/null || fail "dwt completion should avoid appending suffix separators/spaces"

completion_repos="$({
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  HUB_WORKSPACE_ROOT="$workspace_root" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
    typeset -gi SAW_Q=0
    typeset -gi SAW_U=0
    typeset -gi SAW_SUFFIX_EMPTY=0
    compadd() {
      local i=1
      local arg
      for arg in "$@"; do
        if [ "$arg" = "-Q" ]; then
          SAW_Q=1
        fi
        if [ "$arg" = "-U" ]; then
          SAW_U=1
        fi
        if [ "$arg" = "-S" ] && (( i < $# )) && [ "${@[i+1]}" = "" ]; then
          SAW_SUFFIX_EMPTY=1
        fi
        (( i++ ))
      done
    }
    _workspace_nav_complete_repos
    printf "q=%s\n" "$SAW_Q"
    printf "u=%s\n" "$SAW_U"
    printf "s_empty=%s\n" "$SAW_SUFFIX_EMPTY"
  '
} 2>/dev/null)"
printf '%s\n' "$completion_repos" | grep -Fx 'q=1' >/dev/null || fail "repo completion should use compadd -Q"
printf '%s\n' "$completion_repos" | grep -Fx 'u=1' >/dev/null || fail "repo completion should use compadd -U"
printf '%s\n' "$completion_repos" | grep -Fx 's_empty=1' >/dev/null || fail "repo completion should avoid appending suffix separators/spaces"

repos_prefix_nomatch="$({
  PATH="$mock_bin:$PATH" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  HUB_WORKSPACE_ROOT="$workspace_root" \
  zsh -fc '
    source "$WORKSPACE_NAV_SCRIPT"
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
    PREFIX="zz"
    _workspace_nav_complete_repos
  '
} 2>/dev/null)"
[ -z "$repos_prefix_nomatch" ] || fail "repo completion should keep typed prefixes by filtering non-matching candidates"

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

dwt_no_match_transcript="$tmpdir/dwt-no-match.transcript"
printf 'export HUB_WORKSPACE_ROOT="%s"\nexport HUB_INSTALL_BRANCH_DIR="%s"\nautoload -Uz compinit\ncompinit\nsource "%s"\ncd "%s/repos/alpha/master"\ndwt spec/nope\t\nexit\n' \
  "$workspace_root" \
  "$repo_root" \
  "$nav_script" \
  "$workspace_root" \
  | script -q -c 'zsh -fi' "$dwt_no_match_transcript" >/dev/null

grep -F 'refused: worktree "spec/nope" not found' "$dwt_no_match_transcript" >/dev/null || fail "dwt no-match completion should preserve typed prefix"
if grep -F 'usage: dwt [name]' "$dwt_no_match_transcript" >/dev/null; then
  fail "dwt no-match completion should keep refinement in one token"
fi

dwt_refinement_transcript="$tmpdir/dwt-refinement.transcript"
printf 'export HUB_WORKSPACE_ROOT="%s"\nexport HUB_INSTALL_BRANCH_DIR="%s"\nautoload -Uz compinit\ncompinit\nsource "%s"\ncd "%s/repos/alpha/master"\ndwt spec/lim\tx\t\nexit\n' \
  "$workspace_root" \
  "$repo_root" \
  "$nav_script" \
  "$workspace_root" \
  | script -q -c 'zsh -fi' "$dwt_refinement_transcript" >/dev/null

if grep -F 'usage: dwt [name]' "$dwt_refinement_transcript" >/dev/null; then
  fail "dwt refinement should stay in the same token after completion"
fi

dre_completion_transcript="$tmpdir/dre-completion.transcript"
printf 'export HUB_WORKSPACE_ROOT="%s"\nexport HUB_INSTALL_BRANCH_DIR="%s"\nautoload -Uz compinit\ncompinit\nsource "%s"\ncd "%s/main"\ndre a\t\t\t\nexit\n' \
  "$workspace_root" \
  "$repo_root" \
  "$nav_script" \
  "$workspace_root" \
  | script -q -c 'zsh -fi' "$dre_completion_transcript" >/dev/null

grep -F "cd -> $workspace_root/repos/alpha/master" "$dre_completion_transcript" >/dev/null || fail "dre tab completion should complete unique repo names to child default checkout"
if grep -F 'usage: dre <repo>' "$dre_completion_transcript" >/dev/null; then
  fail "dre interactive completion should not duplicate completed argument"
fi

printf 'PASS test_workspace_navigation_shell\n'
