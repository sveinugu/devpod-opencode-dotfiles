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
bash tests/pod-inside-nono/test_nono_profile_layout.sh
bash tests/pod-inside-nono/test_delegation_packet_policy_contract.sh
```

**Run by execution context (preferred):**
```bash
bash tests/run.sh host
bash tests/run.sh pod-outside-nono
bash tests/run.sh pod-inside-nono
```

The runner selects tests by execution context; individual files can also run directly with `bash` in their required context.

## Tests

Tests live in `tests/` and are primarily organized by execution context under `tests/`:

- `tests/host/` — host-shell tests outside workspace/nono
- `tests/pod-outside-nono/` — workspace pod tests outside nono sandbox
- `tests/pod-inside-nono/` — workspace pod tests inside nono sandbox

Legacy domain folders still exist (`tests/devspace/`, `tests/install/`, `tests/bootstrap/`, `tests/docs/`) but active contract suites are context-routed via `tests/run.sh`.

Doc-contract tests use `rg` (ripgrep) to assert that required text patterns exist in canonical files. When updating policy, run these tests to confirm the anchors are still present.

## OpenCode agent system

Config lives in `.config/opencode/`. This directory is symlinked to `~/.config/opencode` after install.

- `opencode.jsonc` — model config, permission rules, plugins
- `AGENTS.md` — shared working agreements and triggers for harness skills
- `agents/maestro.md` — primary orchestrator (low-power model, delegates everything)
- `agents/*.md` — specialist subagents (planner, senior/junior implementer, code-reviewer, docs-writer, etc.)
- `commands/*.md` — slash command definitions (loop-* family)
- `plugins/opencode-loop.ts` — installer-generated OpenCode Loop plugin (gitignored)

Harness-wide procedures live in `.config/opencode/skills/`. Project-local skills and their external install lock live at the repo root.

## Architecture constraints worth knowing

**Delegation**: Maestro may only write code or perform subagent work when the human activates the Maestro override with one message (`maestro-override: <scope>`), which authorizes that scope immediately. Without that, Maestro delegates implementation, planning, and doc-writing through Task. The general agent may perform specialist work when the human requests it, without an override. Explicitly agreed pre-implementation checkpoint waivers are defined in `.config/opencode/skills/delivery-workflow/SKILL.md`.

**Delegation Packet**: Maestro → subagent handoffs use a closed-schema block. The canonical schema is in `.config/opencode/skills/opencode-dispatch/SKILL.md`. Forbidden fields include `Instructions:`, `Notes:`, `Deliverables:`, and any interpretive text outside the packet/Annex structure.

**TDD level**: Tests are written at the integration/contract level for cross-layer changes. Unit tests are used only for isolated logic. Tests in `tests/docs/` are contract tests that verify policy documents — they are not unit tests.

**Prototypes**: Must live in `git worktree` or a branch named `prototype/*`. Must be deleted or converted to tests+design before merging to main.

**Install branch tracking**: `state/hub/etc/install.env` exports `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR`. Scripts and navigation helpers read this to locate the active checkout.

## docs/ structure

- `docs/superpowers/plans/` — approved implementation plans
- `docs/superpowers/specs/` — design specs (binding requirements sources when referenced in a Delegation Packet)
- `docs/superpowers/runbooks/` — operational how-tos
- `docs/superpowers/review-records/` — persistent review artifacts (only when explicitly requested)
- `docs/superpowers/templates/` — handoff templates
