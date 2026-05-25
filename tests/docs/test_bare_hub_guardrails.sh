#!/usr/bin/env bash
set -euo pipefail

grep -F '`/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Agents MUST treat `/workspaces/dotfiles/main` or another explicit worktree path as the editable repository root.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Child repos under `repos/` follow the same pattern; `repos/omnipy/main` and `repos/omnipy/work/feature-example` are the reference examples.' .config/opencode/AGENTS.md >/dev/null
grep -F 'Refused — hub-root CWD detected. Provide explicit worktree path.' .config/opencode/AGENTS.md >/dev/null

grep -F 'Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/agents/maestro.md >/dev/null
grep -F 'Repo-specific bare-hub override: `/workspaces/dotfiles` is a manager hub, not a normal checkout.' .config/opencode/agents/senior-implementer.md >/dev/null

grep -F 'devspace run-pipeline provision' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bash /workspaces/dotfiles/main/install.sh --dry-run -y' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'ssh -o BatchMode=yes workspace.dotfiles.devspace' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bin/clone-repo' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
grep -F 'bin/new-worktree' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null

grep -F 'prefer `bin/clone-repo` and `bin/new-worktree`' .config/opencode/AGENTS.md >/dev/null
grep -F 'prefer `bin/clone-repo` and `bin/new-worktree`' .config/opencode/agents/maestro.md >/dev/null
grep -F 'prefer `bin/clone-repo` and `bin/new-worktree`' .config/opencode/agents/senior-implementer.md >/dev/null

printf 'PASS test_bare_hub_guardrails\n'
