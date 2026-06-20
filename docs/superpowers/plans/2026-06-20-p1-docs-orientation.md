# P1 Docs Foundation: Top-Level Orientation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the repo entry points into a coherent “start here” experience by expanding `README.md`, adding orientation comments to `devspace.yaml` and `install.sh`, and locking the slice with one doc-contract test plus existing behavior guards.

**Architecture:** Treat the orientation copy as the product surface. First write one failing docs contract that asserts the final README sections and cross-links plus the new comment headers in `devspace.yaml` and `install.sh`. Then make the smallest doc-only edits needed to satisfy that contract while re-running existing DevSpace and install tests to prove behavior did not change.

**Tech Stack:** Markdown, YAML comments, Bash comments, one shell doc-contract test under `tests/docs/`, and existing shell verification tests under `tests/devspace/` and `tests/install/`.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved slice: `Docs foundation: top-level orientation`
- Primary surfaces:
  - `README.md`
  - `devspace.yaml`
  - `install.sh`
- Required downstream links:
  - `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
  - `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
  - `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- Agent-reader links required in README:
  - `.config/opencode/AGENTS.md`
  - `.config/opencode/agents/maestro.md`

## Scope

### In scope

- Replace the 2-line `README.md` with a top-level orientation page.
- Add one short orientation comment header to `devspace.yaml`.
- Add one short “what this script does” comment block to `install.sh`.
- Add one doc-contract test for the new orientation surface.
- Re-run existing behavior tests that cover `devspace.yaml` and `install.sh`.

### Out of scope

- No behavior changes.
- No runbook edits.
- No policy edits.
- No refactors of `install.sh` logic.
- No expansion into the P2/P3 audit slices.

## Proposed file map

- Create: `tests/docs/test_p1_docs_orientation.sh` — locks the required README sections, runbook links, agent-doc links, and entry-point comment anchors.
- Modify: `README.md` — becomes the first-contact orientation page for users, developers, and agents.
- Modify: `devspace.yaml` — add a short top-of-file routing comment to README + runbooks.
- Modify: `install.sh` — add a short top-of-file high-level flow comment block plus runbook links.
- Verify only:
  - `tests/devspace/test_devspace_command_surface.sh`
  - `tests/install/test_install_local_source_contract.sh`

---

## Task 1: Lock the orientation slice with one failing docs contract

**Files:**
- Create: `tests/docs/test_p1_docs_orientation.sh`

- [ ] **Step 1: Write the failing docs contract first**

```bash
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
check_fixed "$readme" 'Never work directly from `/workspaces/dotfiles`' 'README hub-root warning'
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
```

- [ ] **Step 2: Verify RED**

Run:

```bash
bash tests/docs/test_p1_docs_orientation.sh
```

Expected: FAIL because `README.md` is still 2 lines and neither entry-point comment block exists yet.

- [ ] **Step 3: Commit the red test slice**

```bash
git add tests/docs/test_p1_docs_orientation.sh
git commit -m "test(docs): lock p1 orientation contract"
```

---

## Task 2: Replace `README.md` with the orientation page

**Files:**
- Modify: `README.md`
- Test: `tests/docs/test_p1_docs_orientation.sh`

- [ ] **Step 1: Replace the README with the exact orientation content**

```markdown
# DevPod OpenCode Dotfiles

Dotfiles, bootstrap scripts, and agent policy for a DevSpace-managed bare-git workspace hub. Use this repo to provision the workspace, apply the in-pod shell/OpenCode setup, and work safely from explicit checkouts such as `/workspaces/dotfiles/main` or `/workspaces/dotfiles/work/<branch>`.

## Start here

Choose the first command based on where you are:

- **Inside the workspace pod:** run `bash install.sh` from `/workspaces/dotfiles/main` or another explicit worktree to apply the dotfiles into `$HOME`.
- **On the host or DevSpace operator side:** run `devspace run-pipeline provision` to create or rebuild the workspace before opening a shell.
- **When the workspace already exists:** use `devspace run-pipeline doctor` for read-only health checks and `devspace run-pipeline repair` for non-destructive structural recovery.

Important guardrails:

- Never work directly from `/workspaces/dotfiles`; it is the bare hub manager root, not a normal checkout.
- Use `/workspaces/dotfiles/main` for the default checkout and `/workspaces/dotfiles/work/<branch>` for feature worktrees.
- Prefer `bin/new-worktree` and `bin/clone-repo` over manual `git worktree add` or `git clone` in the managed workspace.

## Main runbooks

- [DevSpace Bare Hub Usage](docs/superpowers/runbooks/devspace-bare-hub-usage.md) — day-to-day pod usage, install flow, navigation helpers, child repo onboarding, and managed worktree commands.
- [DevSpace Workspace Lifecycle](docs/superpowers/runbooks/devspace-workspace-lifecycle.md) — host-side lifecycle commands such as `provision`, `doctor`, `repair`, `destroy`, and `verify-ssh`.
- [Host Bare-Hub Bootstrap](docs/superpowers/runbooks/host-bare-hub-bootstrap.md) — first-time host bootstrap for the bare-hub + worktree layout before the workspace is mounted into DevPod.

## Key commands

### Host / operator

```bash
devspace run-pipeline provision
devspace run-pipeline doctor
devspace run-pipeline repair
devspace run-pipeline destroy
devspace dev
```

### In-pod setup and navigation

```bash
bash install.sh
bash install.sh --dry-run
dhub
dre <repo>
dwt <branch>
bin/new-worktree --repo hub feature/example
bin/clone-repo https://github.com/<owner>/<repo>.git
```

### Agent / verification

```bash
bash tests/docs/test_p1_docs_orientation.sh
bash tests/devspace/test_devspace_command_surface.sh
bash tests/install/test_install_local_source_contract.sh
```

## Repo layout

- `/workspaces/dotfiles` — bare hub manager root; not an editable checkout
- `/workspaces/dotfiles/main` — default editable checkout
- `/workspaces/dotfiles/work/<branch>` — top-level hub feature worktrees
- `/workspaces/dotfiles/repos/<name>/<default-branch>` — child repo default checkout
- `/workspaces/dotfiles/repos/<name>/work/<branch>` — child repo feature worktrees
- `/workspaces/dotfiles/state/hub/etc/install.env` — persisted install-branch metadata used by shell/workspace helpers

## Agent docs

- [Canonical policy: `.config/opencode/AGENTS.md`](.config/opencode/AGENTS.md)
- [Maestro orchestrator: `.config/opencode/agents/maestro.md`](.config/opencode/agents/maestro.md)
- [Agent configuration directory: `.config/opencode/`](.config/opencode/)
```

- [ ] **Step 2: Run the docs contract after the README rewrite**

Run:

```bash
bash tests/docs/test_p1_docs_orientation.sh
```

Expected: FAIL only on the still-missing `devspace.yaml` and `install.sh` comment anchors.

- [ ] **Step 3: Commit the README slice**

```bash
git add README.md
git commit -m "docs: add top-level repo orientation"
```

---

## Task 3: Add comment-level routing to `devspace.yaml` and `install.sh`

**Files:**
- Modify: `devspace.yaml`
- Modify: `install.sh`
- Test: `tests/docs/test_p1_docs_orientation.sh`

- [ ] **Step 1: Add the exact header comment to `devspace.yaml`**

```yaml
# Start here: README.md explains the repo, audiences, and first commands.
# For lifecycle behavior, see docs/superpowers/runbooks/devspace-workspace-lifecycle.md.
# For host bootstrap context, see docs/superpowers/runbooks/host-bare-hub-bootstrap.md.
version: v2beta1
name: dotfiles
```

- [ ] **Step 2: Add the exact top comment block to `install.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Installs the dotfiles from the checkout that contains this script.
# High-level flow:
# 1. Resolve the install source/worktree and refuse hub-root execution.
# 2. Validate the source tree and persist install-branch state.
# 3. Link shell/OpenCode config into $HOME and install required tooling.
# Start with README.md for orientation, then see:
# - docs/superpowers/runbooks/devspace-bare-hub-usage.md
# - docs/superpowers/runbooks/devspace-workspace-lifecycle.md

dry_run=false
assume_yes=false
```

- [ ] **Step 3: Verify GREEN on the docs contract**

Run:

```bash
bash tests/docs/test_p1_docs_orientation.sh
```

Expected: PASS.

- [ ] **Step 4: Commit the entry-point cross-link slice**

```bash
git add devspace.yaml install.sh
git commit -m "docs: add entry-point cross-links"
```

---

## Task 4: Re-run behavior guards, perform the refactor checkpoint, and hand off

**Files:**
- Review only: `README.md`
- Review only: `devspace.yaml`
- Review only: `install.sh`
- Review only: `tests/docs/test_p1_docs_orientation.sh`

- [ ] **Step 1: Re-run the focused DevSpace behavior guard**

Run:

```bash
bash tests/devspace/test_devspace_command_surface.sh
```

Expected: PASS.

- [ ] **Step 2: Re-run the focused install behavior guard**

Run:

```bash
bash tests/install/test_install_local_source_contract.sh
```

Expected: PASS.

- [ ] **Step 3: Mandatory refactor checkpoint for the changed docs**

Review the changed slice for readability only:

- `README.md` should scan in this order: what the repo is → first command → deeper runbooks → key commands → agent docs.
- `devspace.yaml` comment header should stay short and non-normative.
- `install.sh` comment block should stay high-level and must not restate low-level code line by line.

If the wording is adjusted during this checkpoint, rerun:

```bash
bash tests/docs/test_p1_docs_orientation.sh
bash tests/devspace/test_devspace_command_surface.sh
bash tests/install/test_install_local_source_contract.sh
```

- [ ] **Step 4: User Check-in**

Present the rendered `README.md` plus the two new entry-point comment blocks and ask the user whether the “start here” story is clear enough before moving on to later documentation or refactor slices.

- [ ] **Step 5: Final handoff note**

Report:

- changed files: `README.md`, `devspace.yaml`, `install.sh`, `tests/docs/test_p1_docs_orientation.sh`
- fresh verification commands run
- confirmation that no runbooks, policy files, or runtime behavior changed

---

## Final verification checklist

- [ ] `bash tests/docs/test_p1_docs_orientation.sh`
- [ ] `bash tests/devspace/test_devspace_command_surface.sh`
- [ ] `bash tests/install/test_install_local_source_contract.sh`
- [ ] Re-read `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` and confirm the implementation still matches the approved P1 slice.
- [ ] Confirm `README.md` explains what the repo is, what to do first, where the three runbooks live, which commands each audience needs, and where subagent readers should go next.
- [ ] Confirm `devspace.yaml` and `install.sh` gained comments only, with no logic changes.

## Notes for the implementing agent

- Keep the work doc-only and surgical.
- Do not modify the three runbooks in this slice; route to them only.
- Prefer exact link text from this plan so the docs contract stays simple and stable.
- If a wording tweak would force a test rewrite without improving reader routing, keep the simpler wording.
