#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
readme="$repo_root/README.md"
devspace="$repo_root/devspace.yaml"
install="$repo_root/install.sh"
fail=0

check_fixed() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF -- "$pattern" "$file" 2>/dev/null; then
        printf '  PASS  %s\n' "$label"
    else
        printf '  FAIL  %s — missing in %s\n' "$label" "$file" >&2
        fail=1
    fi
}

echo "=== P1 Docs Orientation Contract Test ==="

check_fixed "$readme" '# DevPod OpenCode Dotfiles' 'README title'
check_fixed "$readme" 'Dotfiles, bootstrap scripts, and agent policy for a DevSpace-managed bare-git workspace hub.' 'README repo description'
check_fixed "$readme" '## Start here' 'README start-here section'
check_fixed "$readme" '## Main runbooks' 'README runbooks section'
check_fixed "$readme" '## Key commands' 'README key commands section'
check_fixed "$readme" '## Agent docs' 'README agent docs section'
check_fixed "$readme" 'devspace run-pipeline provision' 'README provision command'
check_fixed "$readme" 'bash install.sh' 'README install command'
check_fixed "$readme" 'dhub' 'README dhub command'
check_fixed "$readme" 'bin/new-worktree --repo hub feature/example' 'README new-worktree command'
check_fixed "$readme" 'Never work directly from \`/workspaces/dotfiles\`' 'README hub-root warning'
check_fixed "$readme" '[DevSpace Bare Hub Usage](docs/superpowers/runbooks/devspace-bare-hub-usage.md)' 'README bare-hub runbook link'
check_fixed "$readme" '[DevSpace Workspace Lifecycle](docs/superpowers/runbooks/devspace-workspace-lifecycle.md)' 'README lifecycle runbook link'
check_fixed "$readme" '[Host Bare-Hub Bootstrap](docs/superpowers/runbooks/host-bare-hub-bootstrap.md)' 'README host bootstrap runbook link'
check_fixed "$readme" '[Canonical policy: `.config/opencode/AGENTS.md`](.config/opencode/AGENTS.md)' 'README AGENTS link'
check_fixed "$readme" '[Maestro orchestrator: `.config/opencode/agents/maestro.md`](.config/opencode/agents/maestro.md)' 'README Maestro link'

check_fixed "$devspace" '# Start here: README.md explains the repo, audiences, and first commands.' 'devspace orientation comment'
check_fixed "$devspace" '# For lifecycle behavior, see docs/superpowers/runbooks/devspace-workspace-lifecycle.md.' 'devspace lifecycle link comment'
check_fixed "$devspace" '# For host bootstrap context, see docs/superpowers/runbooks/host-bare-hub-bootstrap.md.' 'devspace bootstrap link comment'

check_fixed "$install" '# Installs the dotfiles from the checkout that contains this script.' 'install purpose comment'
check_fixed "$install" '# High-level flow:' 'install flow heading'
check_fixed "$install" '# 1. Resolve the install source/worktree and refuse hub-root execution.' 'install flow step 1'
check_fixed "$install" '# 2. Validate the source tree and persist install-branch state.' 'install flow step 2'
check_fixed "$install" '# 3. Link shell/OpenCode config into $HOME and install required tooling.' 'install flow step 3'
check_fixed "$install" '# Start with README.md for orientation, then see:' 'install orientation link heading'
check_fixed "$install" '# - docs/superpowers/runbooks/devspace-bare-hub-usage.md' 'install bare-hub link comment'
check_fixed "$install" '# - docs/superpowers/runbooks/devspace-workspace-lifecycle.md' 'install lifecycle link comment'

if [ "$fail" -eq 0 ]; then
    printf 'PASS test_p1_docs_orientation\n'
else
    printf 'FAIL test_p1_docs_orientation\n' >&2
    exit 1
fi
