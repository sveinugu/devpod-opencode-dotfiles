#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_path_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
nav_script="$repo_root/.config/shell/workspace-navigation.zsh"

[ -f "$nav_script" ] || fail "workspace-navigation.zsh not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

branch_dir="$tmpdir/work/feature-path"
branch_bin="$branch_dir/bin"
mkdir -p "$branch_bin"

cat > "$branch_bin/branch-tool" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$branch_bin/branch-tool"

base_path="/usr/bin:/bin"

path_after_insert="$(
  PATH="$base_path" \
  HUB_INSTALL_BRANCH_DIR="$branch_dir" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; printf "%s\n" "$PATH"'
)"

case ":$path_after_insert:" in
  *":$branch_bin:"*) ;;
  *) fail "expected PATH to include branch bin when it exists" ;;
esac

resolved_tool="$(
  PATH="$base_path" \
  HUB_INSTALL_BRANCH_DIR="$branch_dir" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; command -v branch-tool'
)"

[ "$resolved_tool" = "$branch_bin/branch-tool" ] || fail "expected branch-tool to resolve from branch bin"

missing_branch_dir="$tmpdir/work/feature-no-bin"
mkdir -p "$missing_branch_dir"

path_without_bin="$(
  PATH="$base_path" \
  HUB_INSTALL_BRANCH_DIR="$missing_branch_dir" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; printf "%s\n" "$PATH"'
)"

[ "$path_without_bin" = "$base_path" ] || fail "expected PATH unchanged when branch bin is missing"

path_after_repeat="$(
  PATH="$base_path" \
  HUB_INSTALL_BRANCH_DIR="$branch_dir" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; . "$WORKSPACE_NAV_SCRIPT"; printf "%s\n" "$PATH"'
)"

branch_count="$(printf '%s' "$path_after_repeat" | tr ':' '\n' | grep -Fx "$branch_bin" | wc -l | tr -d ' ')"
[ "$branch_count" = "1" ] || fail "expected branch bin to appear exactly once after repeated initialization"

path_without_env="$(
  PATH="$base_path" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; printf "%s\n" "$PATH"'
)"

[ "$path_without_env" = "$base_path" ] || fail "expected PATH unchanged when HUB_INSTALL_BRANCH_DIR is unset"

mock_bin="$tmpdir/mock-bin"
mkdir -p "$mock_bin"
mock_target="$tmpdir/mock-dhub-target"
mkdir -p "$mock_target"
cat > "$mock_bin/dhub" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$mock_target"
EOF
chmod +x "$mock_bin/dhub"

dhub_output="$(PATH="$mock_bin:$base_path" WORKSPACE_NAV_SCRIPT="$nav_script" zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; dhub')"
grep -F 'cd -> ' <<<"$dhub_output" >/dev/null || fail "dhub should print destination before changing directory"

dd_output="$(PATH="$mock_bin:$base_path" WORKSPACE_NAV_SCRIPT="$nav_script" zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; dd')"
[ "$dd_output" = "$dhub_output" ] || fail "dd should behave as temporary alias to dhub"

printf 'PASS test_workspace_navigation_path_contract\n'
