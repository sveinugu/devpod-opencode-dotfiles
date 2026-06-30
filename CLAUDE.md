# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Dotfiles for a personal DevPod/OpenCode setup. The repo manages a bare-git workspace hub deployed on Kubernetes via DevSpace, providing zsh config, OpenCode agent configuration, and workspace lifecycle scripts.

## Repository layout (bare hub)

`/workspaces/dotfiles` is the **bare hub root**, not a normal checkout. Never work directly in it.

- `/workspaces/dotfiles/main` — editable main checkout
- `/workspaces/dotfiles/work/<branch>` — worktrees for branches
- `/workspaces/dotfiles/repos/<name>/` — managed child repos (same pattern)
- `/workspaces/dotfiles/state/hub/etc/install.env` — active install-branch env vars

Always use an explicit worktree path. The hub root is guarded: `install.sh` and provision scripts refuse execution from it.

## Key commands

**Install dotfiles (inside workspace):**
```bash
bash install.sh          # standard install
bash install.sh --dry-run
```

**Workspace lifecycle (from host, via DevSpace):**
```bash
devspace run-pipeline provision   # first-time workspace setup
devspace run-pipeline doctor      # health check
devspace run-pipeline repair      # re-apply install without full reprovision
devspace run-pipeline destroy     # tear down
devspace dev                      # open terminal session
```

**Navigation shell helpers (inside workspace):**
```bash
dhub              # cd to active install branch dir
dre <repo>        # cd to a managed child repo's default branch
dwt <branch>      # cd to a worktree inside the current repo context
```

**Worktree / repo management:**
```bash
bin/new-worktree [--repo <hub|repo-name>] <branch>
bin/clone-repo <github-repo>
```

**Run a single test:**
```bash
bash tests/devspace/test_workspace_provision.sh
bash tests/docs/test_delegation_packet_policy_contract.sh
```

There is no global test runner — run individual files directly with `bash`.

## Tests

Tests live in `tests/` organized by domain:

- `tests/devspace/` — workspace lifecycle (provision, repair, navigation, SSH, worktrees)
- `tests/install/` — install script behavior
- `tests/bootstrap/` — host bare-hub bootstrap
- `tests/docs/` — **doc-contract tests**: check that policy anchors exist in AGENTS.md, maestro.md, and spec files; these fail on policy drift

Doc-contract tests use `rg` (ripgrep) to assert that required text patterns exist in canonical files. When updating policy, run these tests to confirm the anchors are still present.

## OpenCode agent system

Config lives in `.config/opencode/`. This directory is symlinked to `~/.config/opencode` after install.

- `opencode.jsonc` — model config, permission rules, plugins
- `AGENTS.md` — **canonical policy document** for the entire agent system (TDD policy, delegation packet schema, session management, Maestro override rules)
- `agents/maestro.md` — primary orchestrator (low-power model, delegates everything)
- `agents/*.md` — specialist subagents (planner, senior/junior implementer, code-reviewer, docs-writer, etc.)
- `commands/*.md` — slash command definitions (loop-* family)
- `plugins/opencode-loop.js` — plugin implementation

`AGENTS.md` is the single source of truth for delegation packet schema and session policy. Agent files are downstream pointers, not co-equal policy sources.

## Architecture constraints worth knowing

**Delegation**: Maestro may only write code or perform subagent work when the human activates the two-message Maestro override (`maestro-override: <scope>` then `maestro-override-confirm`). Without that, all implementation, planning, and doc-writing must go through Task-tool delegation to the appropriate subagent.

**Delegation Packet**: Maestro → subagent handoffs use a closed-schema block. The canonical schema is in `AGENTS.md → "Delegation & Sessions (canonical)"`. The `maestro.md` file is a downstream pointer. Forbidden fields include `Instructions:`, `Notes:`, `Deliverables:`, and any interpretive text outside the packet/Annex structure.

**TDD level**: Tests are written at the integration/contract level for cross-layer changes. Unit tests are used only for isolated logic. Tests in `tests/docs/` are contract tests that verify policy documents — they are not unit tests.

**Prototypes**: Must live in `git worktree` or a branch named `prototype/*`. Must be deleted or converted to tests+design before merging to main.

**Install branch tracking**: `state/hub/etc/install.env` exports `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR`. Scripts and navigation helpers read this to locate the active checkout.

## docs/ structure

- `docs/superpowers/plans/` — approved implementation plans
- `docs/superpowers/specs/` — design specs (binding requirements sources when referenced in a Delegation Packet)
- `docs/superpowers/runbooks/` — operational how-tos
- `docs/superpowers/review-records/` — persistent review artifacts (only when explicitly requested)
- `docs/superpowers/templates/` — handoff templates
