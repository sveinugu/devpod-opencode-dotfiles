#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_path_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
nav_script="$repo_root/.config/shell/workspace-navigation.zsh"

[ -f "$nav_script" ] || fail "workspace-navigation.zsh not found"
grep -F 'local libexec_dir="${WORKSPACE_NAV_LIBEXEC_DIR:-/workspaces/dotfiles/scripts/lib}"' "$nav_script" >/dev/null || fail "dhub default resolver path should use hub root scripts/lib"

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
cat > "$mock_bin/resolve-install-target.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$mock_target"
EOF
chmod +x "$mock_bin/resolve-install-target.sh"

dhub_output="$(PATH="$mock_bin:$base_path" WORKSPACE_NAV_SCRIPT="$nav_script" WORKSPACE_NAV_LIBEXEC_DIR="$mock_bin" zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; dhub')"
grep -F 'cd -> ' <<<"$dhub_output" >/dev/null || fail "dhub should print destination before changing directory"

dd_function="$(PATH="$mock_bin:$base_path" WORKSPACE_NAV_SCRIPT="$nav_script" WORKSPACE_NAV_LIBEXEC_DIR="$mock_bin" zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; typeset -f dd || true')"
[ -z "$dd_function" ] || fail "dd helper function should not be defined"

install_env="$tmpdir/install.env"
feature_target="$tmpdir/work/retrofit-devspace-bare-hub"
mkdir -p "$feature_target"
cat > "$install_env" <<EOF
export HUB_INSTALL_BRANCH=work/retrofit-devspace-bare-hub
export HUB_INSTALL_BRANCH_DIR=$feature_target
EOF

feature_pwd="$(
  PATH="$base_path" \
  HUB_INSTALL_ENV_FILE="$install_env" \
  WORKSPACE_NAV_SCRIPT="$nav_script" \
  WORKSPACE_NAV_LIBEXEC_DIR="$repo_root/scripts/lib" \
  zsh -fc '. "$WORKSPACE_NAV_SCRIPT"; dhub >/tmp/ignore-dhub-feature.out; printf "%s\n" "$PWD"'
)"
[ "$feature_pwd" = "$feature_target" ] || fail "dhub should navigate to non-main HUB_INSTALL_BRANCH_DIR"

printf 'PASS test_workspace_navigation_path_contract\n'
