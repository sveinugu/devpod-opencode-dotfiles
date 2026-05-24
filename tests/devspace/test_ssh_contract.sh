#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_ssh_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cfg="$repo_root/devspace.yaml"

[ -f "$cfg" ] || fail "devspace.yaml not found"

# Task-1/Task-3 SSH static contract.
# This test validates that DevSpace SSH is configured statically in devspace.yaml
# and records host-side acceptance steps for live verification.

grep -Eq '^\s*ssh:\s*$' "$cfg" || fail "missing ssh section"
grep -Eq '^\s*enabled:\s*true\s*$' "$cfg" || fail "missing ssh.enabled: true"
grep -Eq '^\s*useInclude:\s*true\s*$' "$cfg" || fail "missing ssh.useInclude: true"

cat <<'EOF'
Task 1/3 SSH acceptance contract (host-side completion required):
- expected key path: $HOME/.devspace/ssh/id_devspace_rsa
- expected host alias: workspace.dotfiles.devspace
- SSH must use DevSpace-managed localhost tunnel/port-forward
- SSH must not depend on cluster-exposed network reachability
- No Kubernetes Service/NodePort/LoadBalancer for SSH

Host-side acceptance steps for Task 3:
1. devspace run-pipeline provision
2. devspace dev
3. verify key and alias in ~/.devspace/ssh and ~/.ssh/devspace_config (or ~/.ssh/config)
4. ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
5. ssh -o BatchMode=yes workspace.dotfiles.devspace 'test -d /workspaces/dotfiles/main && printf ok\n'

Expected outcomes:
- key handling path documented
- alias present
- tunnel/port-forward path used
- pwd prints /workspaces/dotfiles/main
- directory check prints ok
- no standalone SSH Service exists
EOF

printf 'PASS test_ssh_contract\n'
