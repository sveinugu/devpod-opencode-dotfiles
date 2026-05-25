#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_devspace_destroy: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/ops/destroy-workspace.sh"
cfg="$repo_root/devspace.yaml"

[ -f "$script" ] || fail "ops/destroy-workspace.sh not found"
[ -f "$cfg" ] || fail "devspace.yaml not found"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mock_bin="$tmpdir/bin"
mkdir -p "$mock_bin"

cat > "$mock_bin/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${KUBECTL_LOG:?KUBECTL_LOG must be set}"
exit 0
EOF

chmod +x "$mock_bin/kubectl"

kubectl_log="$tmpdir/kubectl.log"
PATH="$mock_bin:$PATH" KUBECTL_BIN=kubectl KUBECTL_LOG="$kubectl_log" DEVSPACE_NAMESPACE=testing bash "$script" >"$tmpdir/destroy.out" 2>&1 || fail "destroy should succeed when resources exist"

grep -F 'delete deployment dotfiles-workspace --ignore-not-found=true -n testing' "$kubectl_log" >/dev/null || fail "destroy should delete deployment"
grep -F 'delete deployment dotfiles-workspace-devspace --ignore-not-found=true -n testing' "$kubectl_log" >/dev/null || fail "destroy should delete DevSpace-managed deployment"
grep -F 'delete pvc dotfiles-workspace --ignore-not-found=true -n testing' "$kubectl_log" >/dev/null || fail "destroy should delete pvc"

PATH="$mock_bin:$PATH" KUBECTL_BIN=kubectl KUBECTL_LOG="$kubectl_log" DEVSPACE_NAMESPACE=testing bash "$script" >/dev/null 2>&1 || fail "destroy should also succeed when resources are already absent"

grep -Eq '^\s{2}destroy:\s*\|-\s*$' "$cfg" || fail "devspace destroy pipeline must be present"
grep -F 'ops/destroy-workspace.sh' "$cfg" >/dev/null || fail "destroy pipeline should invoke ops/destroy-workspace.sh"

printf 'PASS test_devspace_destroy\n'
