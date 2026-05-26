#!/usr/bin/env bash
set -euo pipefail

grep -F '`/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Agents MUST treat `/workspaces/dotfiles/main` or another explicit worktree path as the editable repository root.' .config/opencode/AGENTS.md >/dev/null
grep -F "Child repos under \`repos/\` follow the same pattern; use each repo's detected default-branch checkout at \`repos/<repo>/<default-branch>\` and worktrees under \`repos/<repo>/work/<branch>\`." .config/opencode/AGENTS.md >/dev/null
grep -F 'Refused — hub-root CWD detected. Provide explicit worktree path.' .config/opencode/AGENTS.md >/dev/null
grep -F '> What changed for implementers:' .config/opencode/AGENTS.md >/dev/null

grep -F 'Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/agents/maestro.md >/dev/null
grep -F 'Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/agents/senior-implementer.md >/dev/null
grep -F '> What changed for implementers:' .config/opencode/agents/maestro.md >/dev/null
grep -F '> What changed for implementers:' .config/opencode/agents/senior-implementer.md >/dev/null

grep -F 'devspace run-pipeline provision' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bash /workspaces/dotfiles/main/install.sh --dry-run -y' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'ssh -o BatchMode=yes workspace.dotfiles.devspace' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'devspace run-pipeline verify-ssh' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'HUB_PROVISION_ARGS' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bin/clone-repo' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bin/new-worktree' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'dhub' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'dre <repo>' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'dwt <name>' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
if grep -F 'temporary compatibility alias to `dhub`' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null; then
  printf 'FAIL test_bare_hub_guardrails: runbook must not describe dd compatibility alias\n' >&2
  exit 1
fi
grep -F 'default branch name' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bin/clone-repo' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
grep -F 'bin/new-worktree' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
grep -F '.envrc' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
grep -F '.envrc.local' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
grep -F 'dhub' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
grep -F 'dre <repo>' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
grep -F 'dwt <name>' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
if grep -F 'temporary compatibility alias to `dhub`' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null; then
  printf 'FAIL test_bare_hub_guardrails: lifecycle runbook must not describe dd compatibility alias\n' >&2
  exit 1
fi
grep -F 'state/hub/etc/install.env' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null

grep -F 'prefer `bin/clone-repo` and `bin/new-worktree`' .config/opencode/AGENTS.md >/dev/null
grep -F 'prefer `bin/clone-repo` and `bin/new-worktree`' .config/opencode/agents/maestro.md >/dev/null
grep -F 'prefer `bin/clone-repo` and `bin/new-worktree`' .config/opencode/agents/senior-implementer.md >/dev/null

printf 'PASS test_bare_hub_guardrails\n'
