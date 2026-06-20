#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_commands: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
dre_script="$repo_root/bin/dre"
dwt_script="$repo_root/bin/dwt"
resolver_script="$repo_root/scripts/lib/resolve-install-target.sh"

[ -f "$dre_script" ] || fail "bin/dre not found"
[ -f "$dwt_script" ] || fail "bin/dwt not found"
[ -x "$resolver_script" ] || fail "scripts/lib/resolve-install-target.sh must exist and be executable"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

workspace_root="$tmpdir/workspace"
mkdir -p "$workspace_root/main" "$workspace_root/work/feature-top" "$workspace_root/work/main" "$workspace_root/repos"

mkdir -p "$workspace_root/repos/alpha/.bare" "$workspace_root/repos/alpha/master" "$workspace_root/repos/alpha/work/feature-child" "$workspace_root/repos/alpha/work/master"
mkdir -p "$workspace_root/repos/beta/.bare" "$workspace_root/repos/beta/main"
mkdir -p "$workspace_root/repos/gamma/.bare" "$workspace_root/repos/gamma/main"
mkdir -p "$workspace_root/repos/delta/.bare" "$workspace_root/repos/delta/main"
mkdir -p "$workspace_root/repos/escape"
mkdir -p "$workspace_root/state/repos/alpha/etc"
cat > "$workspace_root/state/repos/alpha/etc/repo.env" <<EOF
export DYN_REPO_DEFAULT_BRANCH=master
export DYN_REPO_DEFAULT_DIR=$workspace_root/repos/alpha/master
EOF

mkdir -p "$workspace_root/state/repos/gamma/etc"
cat > "$workspace_root/state/repos/gamma/etc/repo.env" <<EOF
export DYN_REPO_DEFAULT_BRANCH=main
export DYN_REPO_DEFAULT_DIR=$workspace_root/repos/gamma/../escape
EOF

mkdir -p "$workspace_root/state/repos/delta/etc"
cat > "$workspace_root/state/repos/delta/etc/repo.env" <<EOF
export DYN_REPO_DEFAULT_BRANCH="main
export DYN_REPO_DEFAULT_DIR=$workspace_root/repos/delta/main
EOF

mkdir -p "$workspace_root/state/hub/etc"
cat > "$workspace_root/state/hub/etc/install.env" <<EOF
export HUB_INSTALL_BRANCH=feature-top
export HUB_INSTALL_BRANCH_DIR=$workspace_root/work/feature-top
EOF

resolved_hub="$(HUB_INSTALL_ENV_FILE="$workspace_root/state/hub/etc/install.env" bash "$resolver_script")"
[ "$resolved_hub" = "$workspace_root/work/feature-top" ] || fail "resolver should print install checkout"

dre_alpha="$(HUB_WORKSPACE_ROOT="$workspace_root" bash "$dre_script" alpha)"
[ "$dre_alpha" = "$workspace_root/repos/alpha/master" ] || fail "dre should resolve repos/<repo>/<default-branch>"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" bash "$dre_script" gamma >"$tmpdir/dre-gamma-escape.out" 2>&1
dre_gamma_escape_rc="$?"
set -e
[ "$dre_gamma_escape_rc" = "1" ] || fail "dre should fail when default dir escapes managed child root"
grep -F 'refused: managed child default branch metadata is missing or invalid for "gamma"' "$tmpdir/dre-gamma-escape.out" >/dev/null || fail "dre should reject escaped child metadata"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" bash "$dre_script" beta >"$tmpdir/dre-metadata.out" 2>&1
dre_metadata_rc="$?"
set -e
[ "$dre_metadata_rc" = "1" ] || fail "dre should fail when child metadata is missing"
grep -F 'refused: managed child default branch metadata is missing or invalid for "beta"' "$tmpdir/dre-metadata.out" >/dev/null || fail "dre should explain missing child metadata with repo context"
grep -F 'to repair, run:' "$tmpdir/dre-metadata.out" >/dev/null || fail "dre should include human-readable repair intro"
grep -F "  HUB_WORKSPACE_ROOT=\"$workspace_root\" bash /workspaces/dotfiles/main/scripts/lib/write-managed-repo-env.sh \"beta\" \"main\" \"$workspace_root/repos/beta/main\"" "$tmpdir/dre-metadata.out" >/dev/null || fail "dre should print exact runnable metadata repair command on its own line"

set +e
(
  cd "$workspace_root/repos/beta/main"
  HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script"
) >"$tmpdir/dwt-metadata.out" 2>&1
dwt_metadata_rc="$?"
set -e
[ "$dwt_metadata_rc" = "1" ] || fail "dwt should fail when child metadata is missing"
grep -F 'refused: managed child default branch metadata is missing or invalid for "beta"' "$tmpdir/dwt-metadata.out" >/dev/null || fail "dwt should explain missing child metadata with repo context"
grep -F 'to repair, run:' "$tmpdir/dwt-metadata.out" >/dev/null || fail "dwt should include human-readable repair intro"
grep -F "  HUB_WORKSPACE_ROOT=\"$workspace_root\" bash /workspaces/dotfiles/main/scripts/lib/write-managed-repo-env.sh \"beta\" \"main\" \"$workspace_root/repos/beta/main\"" "$tmpdir/dwt-metadata.out" >/dev/null || fail "dwt should print exact runnable metadata repair command on its own line"

set +e
(
  cd "$workspace_root/repos/gamma/main"
  HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script"
) >"$tmpdir/dwt-gamma-escape.out" 2>&1
dwt_gamma_escape_rc="$?"
set -e
[ "$dwt_gamma_escape_rc" = "1" ] || fail "dwt should fail when default dir escapes managed child root"
grep -F 'refused: managed child default branch metadata is missing or invalid for "gamma"' "$tmpdir/dwt-gamma-escape.out" >/dev/null || fail "dwt should reject escaped child metadata"

set +e
(
  cd "$workspace_root/repos/delta/main"
  HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script"
) >"$tmpdir/dwt-delta-malformed.out" 2>&1
dwt_delta_malformed_rc="$?"
set -e
[ "$dwt_delta_malformed_rc" = "1" ] || fail "dwt should fail cleanly for malformed child metadata"
grep -F 'refused: managed child default branch metadata is missing or invalid for "delta"' "$tmpdir/dwt-delta-malformed.out" >/dev/null || fail "dwt should report metadata refusal for malformed repo.env"
if grep -E 'unexpected EOF|unexpected end of file|syntax error' "$tmpdir/dwt-delta-malformed.out" >/dev/null; then
  fail "dwt should avoid leaking raw shell parse errors for malformed repo.env"
fi

set +e
HUB_WORKSPACE_ROOT="$workspace_root" bash "$dre_script" hub >"$tmpdir/dre-hub.out" 2>&1
dre_hub_rc="$?"
set -e
[ "$dre_hub_rc" = "1" ] || fail "dre should refuse top-level hub aliases"
grep -F 'refused: top-level hub root is not a valid dre target' "$tmpdir/dre-hub.out" >/dev/null || fail "dre should explain top-level refusal"

set +e
HUB_WORKSPACE_ROOT="$workspace_root" bash "$dre_script" alpa >"$tmpdir/dre-hint.out" 2>&1
dre_hint_rc="$?"
set -e
[ "$dre_hint_rc" = "1" ] || fail "dre should fail for unknown repo"
grep -F 'did you mean: alpha' "$tmpdir/dre-hint.out" >/dev/null || fail "dre should print did-you-mean hint"

mock_bin="$tmpdir/mock-bin"
mkdir -p "$mock_bin"
cat > "$mock_bin/python3" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$mock_bin/python3"

set +e
PATH="$mock_bin:$PATH" HUB_WORKSPACE_ROOT="$workspace_root" bash "$dre_script" alpa >"$tmpdir/dre-python-fail.out" 2>&1
dre_python_fail_rc="$?"
set -e
[ "$dre_python_fail_rc" = "1" ] || fail "dre should still fail cleanly when python3 helper fails"
if grep -F ') || true)' "$tmpdir/dre-python-fail.out" >/dev/null; then
  fail "dre should not print malformed fallback literal when python3 fails"
fi

dwt_top_default="$(
  (
    cd "$workspace_root/main"
    HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script"
  )
)"
[ "$dwt_top_default" = "$workspace_root/main" ] || fail "dwt with no argument should resolve top-level default checkout"

dwt_top_alias="$(
  (
    cd "$workspace_root/main"
    HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script" main
  )
)"
[ "$dwt_top_alias" = "$workspace_root/main" ] || fail "dwt <default-branch-name> should resolve top-level default checkout"

dwt_top_feature="$(
  (
    cd "$workspace_root/main"
    HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script" feature-top
  )
)"
[ "$dwt_top_feature" = "$workspace_root/work/feature-top" ] || fail "dwt should resolve top-level work/<name> from main context"

dwt_child_default="$(
  (
    cd "$workspace_root/repos/alpha/master"
    HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script"
  )
)"
[ "$dwt_child_default" = "$workspace_root/repos/alpha/master" ] || fail "dwt with no argument should resolve child default checkout"

dwt_child_alias="$(
  (
    cd "$workspace_root/repos/alpha/master"
    HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script" master
  )
)"
[ "$dwt_child_alias" = "$workspace_root/repos/alpha/master" ] || fail "dwt <default-branch-name> should resolve child default checkout"

dwt_child="$(
  (
    cd "$workspace_root/repos/alpha/master"
    HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script" feature-child
  )
)"
[ "$dwt_child" = "$workspace_root/repos/alpha/work/feature-child" ] || fail "dwt should resolve child work/<name> from child context"

set +e
(
  cd "$workspace_root"
  HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script" feature-top >"$tmpdir/dwt-outside.out" 2>&1
)
dwt_outside_rc="$?"
set -e
[ "$dwt_outside_rc" = "1" ] || fail "dwt should refuse outside managed repo context"
grep -F 'refused: dwt requires a managed repo checkout context' "$tmpdir/dwt-outside.out" >/dev/null || fail "dwt should explain managed context refusal"

set +e
(
  cd "$workspace_root/repos/alpha/master"
  HUB_WORKSPACE_ROOT="$workspace_root" bash "$dwt_script" feature-chiild >"$tmpdir/dwt-hint.out" 2>&1
)
dwt_hint_rc="$?"
set -e
[ "$dwt_hint_rc" = "1" ] || fail "dwt should fail for unknown worktree"
grep -F 'did you mean: feature-child' "$tmpdir/dwt-hint.out" >/dev/null || fail "dwt should print did-you-mean hint"

printf 'PASS test_workspace_navigation_commands\n'
