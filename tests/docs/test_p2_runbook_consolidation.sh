#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
bare_hub="$repo_root/docs/superpowers/runbooks/devspace-bare-hub-usage.md"
lifecycle="$repo_root/docs/superpowers/runbooks/devspace-workspace-lifecycle.md"
bootstrap="$repo_root/docs/superpowers/runbooks/host-bare-hub-bootstrap.md"
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

check_absent() {
    local file="$1" pattern="$2" label="$3"
    if rg -qF -- "$pattern" "$file" 2>/dev/null; then
        printf '  FAIL  %s — still present in %s\n' "$label" "$file" >&2
        fail=1
    else
        printf '  PASS  %s\n' "$label"
    fi
}

echo "=== P2 Runbook Consolidation Contract Test ==="

check_fixed "$lifecycle" '## Choose your environment' 'lifecycle environment router heading'
check_fixed "$lifecycle" '- **HOST:** Stay in this runbook for `devspace run-pipeline provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`.' 'lifecycle host route'
check_fixed "$lifecycle" '- **HOST, first-time setup:** If the bare-hub layout does not exist yet, start with [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).' 'lifecycle bootstrap route'
check_fixed "$lifecycle" '- **POD:** Switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `dhub`, `dre`, `dwt`, `bin/new-worktree`, `bin/clone-repo`, and `bin/retire-worktree`.' 'lifecycle pod route'
check_fixed "$lifecycle" '## Host lifecycle commands (canonical)' 'lifecycle canonical section heading'
check_fixed "$lifecycle" 'This runbook is the canonical source for host-side DevSpace lifecycle commands.' 'lifecycle canonical ownership note'
check_fixed "$lifecycle" '## After the host step, continue in pod' 'lifecycle pod handoff section'
check_absent "$lifecycle" '## In-pod managed repo/worktree commands' 'lifecycle no longer duplicates in-pod worktree section'

check_fixed "$bare_hub" '## Choose your environment' 'bare-hub environment router heading'
check_fixed "$bare_hub" '- **HOST:** Use [DevSpace Workspace Lifecycle](devspace-workspace-lifecycle.md) for `devspace run-pipeline provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`, and use [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md) for first-time host setup.' 'bare-hub host route'
check_fixed "$bare_hub" '- **POD:** Stay in this runbook for `bash install.sh`, `dhub`, `dre`, `dwt`, `bin/clone-repo`, `bin/new-worktree`, and `bin/retire-worktree`.' 'bare-hub pod route'
check_fixed "$bare_hub" '## In-pod install and guardrails (canonical)' 'bare-hub canonical install heading'
check_fixed "$bare_hub" '## In-pod managed repo and worktree commands (canonical)' 'bare-hub canonical worktree heading'
check_fixed "$bare_hub" '## Navigation helpers (canonical)' 'bare-hub canonical navigation heading'
check_fixed "$bare_hub" 'For host lifecycle operations, see [DevSpace Workspace Lifecycle](devspace-workspace-lifecycle.md).' 'bare-hub lifecycle cross-link'
check_absent "$bare_hub" '## Provision and connect' 'bare-hub no longer duplicates host provision section'
check_absent "$bare_hub" '## Rebuild workspace image' 'bare-hub no longer duplicates host image rebuild section'

check_fixed "$bootstrap" '## Choose your environment' 'bootstrap environment router heading'
check_fixed "$bootstrap" '- **HOST:** Stay in this runbook for first-time bare-hub bootstrap, host-side verification, and recovery-only host actions.' 'bootstrap host route'
check_fixed "$bootstrap" '- **POD:** After the mount exists, switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `bin/new-worktree`, `bin/clone-repo`, `dhub`, `dre`, and `dwt`.' 'bootstrap pod route'
check_fixed "$bootstrap" '## Wrapper-first day-2 flow' 'bootstrap wrapper-first heading'
check_fixed "$bootstrap" '/workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example' 'bootstrap wrapper-first hub worktree command'
check_fixed "$bootstrap" '/workspaces/dotfiles/main/bin/clone-repo https://github.com/<owner>/<repo>.git' 'bootstrap wrapper-first clone command'
check_fixed "$bootstrap" '## Manual fallback (only when wrappers cannot be used)' 'bootstrap manual fallback heading'
check_fixed "$bootstrap" 'Do not treat the manual fallback commands below as the default workflow.' 'bootstrap manual fallback warning'
check_fixed "$bootstrap" 'git worktree add "/workspaces/dotfiles/work/feature-example" -b feature-example main' 'bootstrap manual worktree fallback command'
check_fixed "$bootstrap" 'REPO_DEFAULT_BRANCH="$(git --git-dir="$REPO_HUB/.bare" symbolic-ref --short refs/remotes/origin/HEAD | sed '\''s#^origin/##'\'')"' 'bootstrap manual default-branch detection command'
check_fixed "$bootstrap" 'git clone --bare "$REPO_URL" "$REPO_HUB/.bare"' 'bootstrap manual clone fallback command'
check_fixed "$bootstrap" 'git worktree add "$REPO_HUB/$REPO_DEFAULT_BRANCH" "$REPO_DEFAULT_BRANCH"' 'bootstrap manual default-branch worktree command'
check_absent "$bootstrap" '## Step 7 (IN POD): Create a feature worktree' 'bootstrap removes manual pod step as primary flow'

if [ "$fail" -eq 0 ]; then
    printf 'PASS test_p2_runbook_consolidation\n'
else
    printf 'FAIL test_p2_runbook_consolidation\n' >&2
    exit 1
fi
