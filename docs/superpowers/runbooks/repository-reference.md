# Repository commands and layout

Reference material for this dotfiles repository. Before running commands, follow the shared execution boundaries and the required test context.

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
bash tests/static/test_harness_structure.sh
```

**Run by execution context (preferred):**
```bash
bash tests/run.sh host
bash tests/run.sh static
bash tests/run.sh pod-outside-nono
bash tests/run.sh pod-inside-nono
```

The runner selects tests by execution context. You can also run individual files directly with `bash` in their required context.

## OpenCode agent system

Config lives in `.config/opencode/`. This directory is symlinked to `~/.config/opencode` after install.

- `opencode.jsonc` — model config, permission rules, plugins
- `AGENTS.md` — shared working agreements and triggers for harness skills
- `agents/maestro.md` — primary orchestrator (low-power model, delegates everything)
- `agents/*.md` — specialist subagents (planner, senior/junior implementer, code-reviewer, docs-writer, etc.)
- `commands/*.md` — slash command definitions (loop-* family)
- `plugins/opencode-loop.ts` — installer-generated OpenCode Loop plugin (gitignored)

Harness-wide procedures live in `.config/opencode/skills/`. Project-local skills and their external install lock live at the repo root.

## Install branch tracking

`state/hub/etc/install.env` exports `HUB_INSTALL_BRANCH` and `HUB_INSTALL_BRANCH_DIR`. Scripts and navigation helpers read this file to locate the active checkout.

## Tests and documentation

Tests live in `tests/`, primarily organized by execution context. Read [test guidance](../../../tests/README.md) before selecting or running checks. `tests/run.sh` defines active suite membership. The additional `tests/devspace/` scripts are not included automatically.

Read the [authoring guide](../AGENTS.md) before creating or editing documentation in `docs/superpowers/`. It defines artifact placement and manual-additions maintenance.
