# P2 Runbook Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the three operational runbooks into a clear HOST/POD-routed documentation set with one canonical source per concept, wrapper-first host guidance, and a doc-contract test that prevents the overlap and routing drift identified in DG-4, DG-5, and DG-6.

**Architecture:** Treat the runbooks as one documentation system with three distinct owners: `devspace-workspace-lifecycle.md` owns host-side DevSpace lifecycle commands, `devspace-bare-hub-usage.md` owns in-pod install/navigation/worktree usage, and `host-bare-hub-bootstrap.md` owns first-time host bootstrap plus explicit manual fallback. Start by writing one failing doc-contract test that locks the new routing and canonical section anchors, then rewrite each runbook in turn until the test passes.

**Tech Stack:** Markdown runbooks, one Bash doc-contract test under `tests/docs/`, and `rg`-based anchor checks modeled after `tests/docs/test_p1_docs_orientation.sh`.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved slice: `P2 — Documentation consolidation: runbooks`
- Audit gaps this slice must close:
  - `DG-4` — overlap between `devspace-bare-hub-usage.md` and `devspace-workspace-lifecycle.md`
  - `DG-5` — `host-bare-hub-bootstrap.md` manual flows drift from `bin/clone-repo` / `bin/new-worktree`
  - `DG-6` — no consistent HOST/POD audience routing
- Reference plan format: `docs/superpowers/plans/2026-06-20-p1-docs-orientation.md`
- Existing docs-contract pattern: `tests/docs/test_p1_docs_orientation.sh`
- Primary surfaces:
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
  - `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`

## Scope

### In scope

- Rewrite the three runbooks so each one has a top-level HOST/POD routing block.
- Make `devspace-workspace-lifecycle.md` the canonical host-side lifecycle runbook.
- Make `devspace-bare-hub-usage.md` the canonical in-pod usage runbook.
- Make `host-bare-hub-bootstrap.md` wrapper-first for day-2 work, with manual fallback kept explicit and secondary.
- Add one doc-contract test that locks the consolidated structure and de-duplication boundaries.

### Out of scope

- No shell/script behavior changes.
- No `README.md` changes.
- No agent-policy edits.
- No new runbook files.
- No content expansion beyond the three audited gaps.
- No cleanup of developer workflow gaps `DG-7` through `DG-9`.

## Proposed file map

- Create: `tests/docs/test_p2_runbook_consolidation.sh` — locks HOST/POD routing anchors, canonical section ownership, wrapper-first guidance, and the absence of the worst duplicate sections.
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` — canonical host-side lifecycle runbook with explicit routing to bootstrap and in-pod usage docs.
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md` — canonical in-pod install, navigation, child-repo onboarding, and managed worktree runbook.
- Modify: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md` — canonical first-time host bootstrap runbook with wrapper-first day-2 flow and explicit manual fallback.
- Verify only:
  - `tests/docs/test_p2_runbook_consolidation.sh`
  - `git diff --name-only`

---

## Task 1: Lock the consolidated structure with one failing docs contract

**Files:**
- Create: `tests/docs/test_p2_runbook_consolidation.sh`

- [ ] **Step 1: Write the failing docs contract first**

```bash
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
```

- [ ] **Step 2: Verify RED**

Run:

```bash
bash tests/docs/test_p2_runbook_consolidation.sh
```

Expected: FAIL because the current runbooks do not yet have consistent `## Choose your environment` routing blocks, the lifecycle runbook still owns an in-pod worktree section, the bare-hub runbook still owns host lifecycle sections, and the bootstrap runbook still presents manual in-pod worktree creation as the primary flow.

- [ ] **Step 3: Commit the red test slice**

```bash
git add tests/docs/test_p2_runbook_consolidation.sh
git commit -m "test(docs): lock p2 runbook consolidation contract"
```

---

## Task 2: Rewrite `devspace-workspace-lifecycle.md` as the canonical HOST lifecycle runbook

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Test: `tests/docs/test_p2_runbook_consolidation.sh`

- [ ] **Step 1: Replace `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` with this exact content**

```markdown
# DevSpace Workspace Lifecycle

> What changed for implementers: `dhub` is the install-root navigation helper; child repo default branches must be preserved exactly instead of being normalized to `main`.

## Choose your environment

- **HOST:** Stay in this runbook for `devspace run-pipeline provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`.
- **HOST, first-time setup:** If the bare-hub layout does not exist yet, start with [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).
- **POD:** Switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `dhub`, `dre`, `dwt`, `bin/new-worktree`, `bin/clone-repo`, and `bin/retire-worktree`.

## Host lifecycle commands (canonical)

This runbook is the canonical source for host-side DevSpace lifecycle commands. It intentionally routes in-pod install, navigation, and managed worktree details to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) instead of repeating them here.

## Provision

Run the full provision + connect sequence from the host:

```bash
devspace run-pipeline provision
devspace dev
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
devspace run-pipeline verify-ssh
```

To force tool refresh during provision (pyenv + opencode):

```bash
devspace run-pipeline provision --refresh-tools
HUB_PROVISION_ARGS='--refresh-tools' devspace run-pipeline provision
```

To provision using a non-`main` install checkout via environment override:

```bash
HUB_INSTALL_BRANCH=feature/env-override devspace run-pipeline provision
```

If `HUB_INSTALL_BRANCH` is not set, provision defaults to `main`.

## Rebuild workspace image

```bash
devspace build
```

Then redeploy:

```bash
devspace deploy
```

If your Kubernetes cluster cannot pull from your local image store, push to a registry and use a registry-qualified image name in `devspace.yaml`.

## Doctor

Run a read-only health checklist from the host:

```bash
devspace run-pipeline doctor
```

Behavior:

- exit `0`: all required checks pass
- exit `1`: one or more required checks failed
- exit `2`: invalid CLI usage

The v1 checklist includes Deployment/PVC presence, pod reachability, top-level bare-hub validity, managed directory existence, canonical `state/hub/main` and `tmp/hub/main` paths, `/home/vscode` symlink targets, and installed-branch reporting from `state/hub/etc/install.env` when present.

## Repair

Run non-destructive structural recovery:

```bash
devspace run-pipeline repair
```

Behavior:

- recreates missing managed directories (`work/`, `repos/`, `state/`, `tmp/`)
- recreates canonical top-level paths (`state/hub/main`, `tmp/hub/main`)
- reattaches `main` only when `.bare` is valid and recognizable
- preserves valid non-`main` `/home/vscode` symlink targets
- resolves install source in this order: explicit `HUB_INSTALL_BRANCH`, then `state/hub/etc/install.env`, then `main`
- keeps `/workspaces/dotfiles/main` attached to `main` even when install source is non-`main`
- refuses when identity is ambiguous, `.bare` is invalid, or managed paths conflict by type

Inspect installed-branch state before repair:

```bash
cat /workspaces/dotfiles/state/hub/etc/install.env
```

`repair` is best-effort and non-destructive; it does not delete existing files or worktrees.

Child repo note: preserve the exact child remote default branch name when reconstructing or validating managed child checkouts.

## Destroy

Run destructive reset:

```bash
devspace run-pipeline destroy
```

Behavior:

- deletes Deployment/pod
- deletes PVC
- does not preserve uncommitted work, runtime session data, or `/home/vscode` content on the deleted PVC

After `destroy`, run `devspace run-pipeline provision` to recreate from scratch.

## After the host step, continue in pod

Once `devspace dev` is open and `/workspaces/dotfiles` is mounted:

- run `bash /workspaces/dotfiles/main/install.sh` from an explicit checkout
- use `dhub`, `dre`, and `dwt` for navigation
- create managed worktrees with `/workspaces/dotfiles/main/bin/new-worktree`
- onboard child repos with `/workspaces/dotfiles/main/bin/clone-repo`
- retire managed worktrees with `/workspaces/dotfiles/main/bin/retire-worktree`

For those in-pod commands, use [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md). For first-time host layout creation, use [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).
```

- [ ] **Step 2: Run the docs contract after rewriting the lifecycle runbook**

Run:

```bash
bash tests/docs/test_p2_runbook_consolidation.sh
```

Expected: FAIL only on the still-missing bare-hub and bootstrap anchors.

- [ ] **Step 3: Commit the lifecycle slice**

```bash
git add docs/superpowers/runbooks/devspace-workspace-lifecycle.md
git commit -m "docs: make lifecycle runbook host-canonical"
```

---

## Task 3: Rewrite `devspace-bare-hub-usage.md` as the canonical POD usage runbook

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Test: `tests/docs/test_p2_runbook_consolidation.sh`

- [ ] **Step 1: Replace `docs/superpowers/runbooks/devspace-bare-hub-usage.md` with this exact content**

```markdown
# DevSpace Bare Hub Usage

> What changed for implementers: `dhub` is the install-checkout helper; child repos keep their exact remote default branch names instead of being normalized to `main`.

## Choose your environment

- **HOST:** Use [DevSpace Workspace Lifecycle](devspace-workspace-lifecycle.md) for `devspace run-pipeline provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`, and use [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md) for first-time host setup.
- **POD:** Stay in this runbook for `bash install.sh`, `dhub`, `dre`, `dwt`, `bin/clone-repo`, `bin/new-worktree`, and `bin/retire-worktree`.

## In-pod install and guardrails (canonical)

This runbook is the canonical source for in-pod install, navigation, and managed worktree usage. For host lifecycle operations, see [DevSpace Workspace Lifecycle](devspace-workspace-lifecycle.md).

Use `/workspaces/dotfiles/main` as the editable workspace checkout.

```bash
bash /workspaces/dotfiles/main/install.sh --dry-run -y
bash /workspaces/dotfiles/work/feature-example/install.sh --dry-run -y
```

Never run the hub-root copy at `/workspaces/dotfiles/install.sh`; it must refuse with:

```text
Refused — hub-root CWD detected. Provide explicit worktree path.
```

Workflow policy for dev/testing/production behavior changes:

- develop policy in a non-`main` worktree
- test with `HUB_INSTALL_BRANCH=<branch> devspace run-pipeline provision` or `repair`
- merge to `main` for staging/testing
- push `main` to origin for production/default behavior

## In-pod managed repo and worktree commands (canonical)

From inside the workspace pod, add a child repo as a managed bare hub under `repos/<name>`:

```bash
/workspaces/dotfiles/main/bin/clone-repo https://github.com/<owner>/<repo>.git
```

Create managed worktrees (top-level hub and child repos):

```bash
/workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
/workspaces/dotfiles/main/bin/new-worktree --repo <child-repo-name> feature/example
```

When creating a lane-safe worktree, keep lane identity distinct from branch naming whenever needed:

```bash
MANAGED_LANE_ID=lane/example /workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
```

For scoped authoring, scoped authoring should not proceed from hub root or unrelated worktrees.

Managed checkout environment behavior:

- each managed checkout gets `.envrc` and `.envrc.local`
- managed `.envrc` exports `HUB_*`, `DYN_REPO_*`, and `DYN_WORKTREE_*` variables
- managed `.envrc` sources `state/hub/etc/install.env` when present
- managed `.envrc` sources `.envrc.local` after managed exports

`install.sh` writes installed-branch state to:

```text
/workspaces/dotfiles/state/hub/etc/install.env
```

## Navigation helpers (canonical)

The repo-managed shell package is the intended home for the interactive wrappers:

- `dhub` → jump to `$HUB_INSTALL_BRANCH_DIR`
- `dre <repo>` → jump to child default checkout at `/workspaces/dotfiles/repos/<repo>/<default-branch>`
- `dwt` with no argument → jump to the current managed repo default checkout
- `dwt <default-branch-name>` → jump to that same default checkout
- `dwt <name>` → jump to `work/<name>` inside the current managed repo context

Behavior notes:

- `dhub` prints the resolved install checkout before changing directories
- `dre` excludes the top-level hub; use it only for child repos under `repos/`
- `dwt` only works from an existing managed repo context and uses the canonical `work/` directory
- for top-level hub, default alias is `main`; for child repos, it is the detected remote default branch name
- invalid names may print a simple text `did you mean ...` hint
- no `dd()` compatibility alias
- no `fzf` integration in v1

## Managed local retirement

Retire lane worktrees with the managed command instead of manual `git worktree remove` + `git branch -D`:

```bash
/workspaces/dotfiles/main/bin/retire-worktree --repo hub lane/example
/workspaces/dotfiles/main/bin/retire-worktree --repo <child-repo-name> lane/example
```

Use `--dry-run` first to inspect potential loss evidence and the force-token retry command when applicable.

## Child repo branch behavior

Child onboarding preserves the child repo's exact remote default branch name. Example: if a child repo defaults to `master`, the managed checkout is `repos/<name>/master`, not `repos/<name>/main`.

V1 constraints:

- public source only
- child repo default branch is detected from the remote and kept exactly as-is
- `repos/<name>` is derived from the repo URL/path
- `--name` override is not supported
- collisions refuse (no auto-rename)

Successful onboarding creates:

- `repos/<name>/.bare`
- `repos/<name>/<default-branch>`
- `repos/<name>/work/`
- `state/repos/<name>/<default-branch>/`
- `tmp/repos/<name>/<default-branch>/`

Child onboarding does not change `/home/vscode` symlink authority; top-level dotfiles remains the only authority.
```

- [ ] **Step 2: Run the docs contract after rewriting the bare-hub runbook**

Run:

```bash
bash tests/docs/test_p2_runbook_consolidation.sh
```

Expected: FAIL only on the still-missing bootstrap anchors.

- [ ] **Step 3: Commit the bare-hub slice**

```bash
git add docs/superpowers/runbooks/devspace-bare-hub-usage.md
git commit -m "docs: make bare-hub runbook pod-canonical"
```

---

## Task 4: Rewrite `host-bare-hub-bootstrap.md` around wrapper-first flow with explicit manual fallback

**Files:**
- Modify: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- Test: `tests/docs/test_p2_runbook_consolidation.sh`

- [ ] **Step 1: Replace `docs/superpowers/runbooks/host-bare-hub-bootstrap.md` with this exact content**

```markdown
# Host Bare-Hub Bootstrap

## Choose your environment

- **HOST:** Stay in this runbook for first-time bare-hub bootstrap, host-side verification, and recovery-only host actions.
- **POD:** After the mount exists, switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `bin/new-worktree`, `bin/clone-repo`, `dhub`, `dre`, and `dwt`.

This runbook sets up a **bare-repo + worktree** layout where:

- the host owns the hub and durable state
- you do daily coding inside `/workspaces/dotfiles/main` in the pod

The pattern is inspired by (and thanks to) this article:
https://dev.to/metal3d/git-worktree-like-a-boss-2j1b

In practical terms, after bootstrap you get:

- one managed hub root (admin structure)
- one primary editable worktree (`main`, required)
- a predictable place for feature worktrees (`work/`)
- repo-local durable state paths (`state/`)

Run host steps first, then continue in pod for normal development work.

Set `HUB_PATH` to your host-managed hub directory:

```bash
export HUB_PATH="/srv/devpod-workspaces/dotfiles"
```

## Step 1 (HOST): Create the managed hub

Mode guidance:

- Use `--mode host` for host bootstrap and permission enforcement.
- `--mode auto` exists, but `--mode host` is clearer for this step.
- Help: `bash "./scripts/setup-host-bare-hub.sh" --help`

```bash
bash "./scripts/setup-host-bare-hub.sh" --hub-root "$HUB_PATH" --mode host
```

Username/email behavior:

- Prompt: `Use existing git username/email? Y/N`
- `Y`: keep current values
- `N`: enter GitHub username/email and save to hub-local git config
- If needed, pass `--github-user-name` and `--github-user-email`

Expected output:

```text
ok: ensured host bare-hub layout at /srv/devpod-workspaces/dotfiles
```

After Step 1:

- `$HUB_PATH/.git` points to `./.bare` (so normal `git` works from the hub path)
- fetch refspec is configured in `$HUB_PATH/.bare/config`
- username/email configuration is written in hub-local git config for pod reuse via mounted path
- bootstrap enforces a **main-only** convention: source checkout must have `main`, and hub main worktree is always created from `main`
- bootstrap enforces/repairs `main/install.sh` to mode `700` during host runs
- bootstrap resets top-level bare-repo excludes from `scripts/lib/bare-excludes.list` (managed default pattern set)

## Step 2 (HOST): Verify bootstrap result

```bash
bash "./scripts/verify-host-bare-hub.sh" --hub-root "$HUB_PATH"
```

Expected verifier result includes:

```text
result: PASS
```

## Step 3 (HOST/DevPod config): Mount in DevPod

Mount `$HUB_PATH` into the container as `/workspaces/dotfiles`.
Open `/workspaces/dotfiles/main` as the workspace folder.

## Wrapper-first day-2 flow

Once the mount exists and you are working inside the pod, prefer the managed wrappers instead of manual `git worktree` / `git clone` commands.

Create a top-level feature worktree:

```bash
/workspaces/dotfiles/main/bin/new-worktree --repo hub feature/example
```

Onboard an additional repo under `repos/`:

```bash
/workspaces/dotfiles/main/bin/clone-repo https://github.com/<owner>/<repo>.git
```

Create a managed worktree inside that child repo:

```bash
/workspaces/dotfiles/main/bin/new-worktree --repo <child-repo-name> feature/example
```

For daily in-pod install, navigation, and managed worktree usage, continue with [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md). For host lifecycle commands after bootstrap, continue with [DevSpace Workspace Lifecycle](devspace-workspace-lifecycle.md).

## Host recovery only

Use these host-side commands only when you need to inspect or rebuild the primary host layout.

Recreate `main` from the host:

```bash
rm -rf "$HUB_PATH/main"
cd "$HUB_PATH"
git worktree add "$HUB_PATH/main" main
```

Verify the host layout quickly:

```bash
cd "$HUB_PATH"
git worktree list
ls -ld "$HUB_PATH/state" "$HUB_PATH/state/opencode" "$HUB_PATH/state/opencode/exported_sessions"
```

## Manual fallback (only when wrappers cannot be used)

Do not treat the manual fallback commands below as the default workflow. Keep them as explicit recovery/reference steps for environments where the managed wrappers are unavailable.

Manual in-pod feature worktree creation:

```bash
git worktree add "/workspaces/dotfiles/work/feature-example" -b feature-example main
```

Manual child repo onboarding fallback:

```bash
REPO_NAME="myrepo"
REPO_URL="git@github.com:your-org/myrepo.git"
REPO_HUB="/workspaces/dotfiles/repos/$REPO_NAME"

mkdir -p "$REPO_HUB"
git clone --bare "$REPO_URL" "$REPO_HUB/.bare"
printf 'gitdir: ./.bare\n' > "$REPO_HUB/.git"
REPO_DEFAULT_BRANCH="$(git --git-dir="$REPO_HUB/.bare" symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##')"

cd "$REPO_HUB"
git worktree add "$REPO_HUB/$REPO_DEFAULT_BRANCH" "$REPO_DEFAULT_BRANCH"
git worktree add "$REPO_HUB/work/feature-example" -b feature-example "$REPO_DEFAULT_BRANCH"
```

After using the manual fallback, return to the wrapper-based flow documented in [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md).
```

- [ ] **Step 2: Verify GREEN on the docs contract**

Run:

```bash
bash tests/docs/test_p2_runbook_consolidation.sh
```

Expected: PASS.

- [ ] **Step 3: Commit the bootstrap slice**

```bash
git add docs/superpowers/runbooks/host-bare-hub-bootstrap.md
git commit -m "docs: align bootstrap runbook with wrapper flow"
```

---

## Task 5: Final verification, refactor checkpoint, and handoff

**Files:**
- Review only: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- Review only: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Review only: `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- Review only: `tests/docs/test_p2_runbook_consolidation.sh`

- [ ] **Step 1: Re-run the docs contract from a clean working state**

Run:

```bash
bash tests/docs/test_p2_runbook_consolidation.sh
```

Expected: PASS.

- [ ] **Step 2: Confirm the slice stayed doc-only**

Run:

```bash
git diff --name-only
```

Expected: only these paths appear in the diff for this slice:

- `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- `tests/docs/test_p2_runbook_consolidation.sh`

- [ ] **Step 3: Mandatory refactor checkpoint for the documentation slice**

Review the changed files for readability only:

- each runbook should answer “am I on HOST or POD?” before any command block
- `devspace-workspace-lifecycle.md` should own only host lifecycle semantics plus a short pod handoff section
- `devspace-bare-hub-usage.md` should own only in-pod install/navigation/worktree semantics plus host cross-links
- `host-bare-hub-bootstrap.md` should present wrappers before manual git commands

If wording is adjusted during this checkpoint, rerun:

```bash
bash tests/docs/test_p2_runbook_consolidation.sh
git diff --name-only
```

- [ ] **Step 4: User Check-in**

Show the top `## Choose your environment` section from all three runbooks plus the `## Wrapper-first day-2 flow` and `## Manual fallback (only when wrappers cannot be used)` headings from `host-bare-hub-bootstrap.md`, and ask the user whether the HOST/POD routing is now clear enough before moving on to later audit slices.

- [ ] **Step 5: Final handoff note**

Report:

- changed files: the three runbooks plus `tests/docs/test_p2_runbook_consolidation.sh`
- fresh verification commands run
- confirmation that the slice remained doc-only
- which runbook now canonically owns host lifecycle, in-pod usage, and host bootstrap/manual fallback guidance

---

## Final verification checklist

- [ ] `bash tests/docs/test_p2_runbook_consolidation.sh`
- [ ] `git diff --name-only`
- [ ] Re-read DG-4, DG-5, and DG-6 in `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` and confirm each gap maps to an explicit section in the updated runbooks.
- [ ] Confirm all three runbooks start with `## Choose your environment` and route readers to the correct HOST/POD surface.
- [ ] Confirm `devspace-workspace-lifecycle.md` no longer duplicates in-pod managed repo/worktree details.
- [ ] Confirm `devspace-bare-hub-usage.md` no longer duplicates host provision/image rebuild guidance.
- [ ] Confirm `host-bare-hub-bootstrap.md` presents wrapper-first commands before any manual `git worktree` / `git clone` fallback.
- [ ] Confirm no scripts, tests outside `tests/docs/`, or policy files changed.

## Notes for the implementing agent

- Keep the edits surgical even though the files are being rewritten; every changed section should trace back to DG-4, DG-5, or DG-6.
- Preserve existing command syntax and warnings unless the plan explicitly repositions them.
- Prefer the exact headings and link text in this plan so the docs-contract test stays simple and durable.
- If you discover a wording improvement that would require changing both the docs and the test, only take it if it materially improves HOST/POD routing clarity.
