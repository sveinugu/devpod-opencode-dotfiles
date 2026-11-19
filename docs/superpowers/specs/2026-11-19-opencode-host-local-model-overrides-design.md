# Host-local OpenCode model overrides

Status: draft for approval (2026-11-19)

## Problem

Agent model routing is committed in `.config/opencode/agents/*.md` and `.config/opencode/opencode.jsonc`. Each role has a `#1` model and commented `#2`/`#3` fallbacks (see `docs/superpowers/runbooks/opencode-model-routing-fallback-cheatsheet.md`).

Quota state changes often: UiO pools deplete per model and reset monthly, and the GitHub Copilot credit pool is shared. Today the only way to switch to a fallback is to edit the committed files. That either leaves uncommitted changes in tracked files or commits temporary state (for example "UiO GPT depleted until December") into the repository.

## Goals

1. The repository holds only the target routing: every role runs its `#1` model.
2. Temporary switches, and the reason for them, live in one host-local file outside every checkout.
3. Overrides apply at OpenCode launch with no edits to tracked files, and apply to every worktree.
4. A broken overrides file never silently changes routing.

## Non-goals

- Automatic fallback when a request fails (OpenCode has no native fallback chain).
- Detecting quota depletion automatically.
- A CLI to edit overrides (hand-edited JSON is enough; revisit if it becomes tedious).
- Overriding anything other than an agent's `model`.

## Design

### Overrides file

Path: `/workspaces/dotfiles/state/hub/etc/model-overrides.json` (host-local, like `provider-enablement.json`; not in any checkout, so no gitignore entry is needed). Optional; a missing file means no overrides.

```json
{
  "overrides": {
    "maestro": {
      "model": "github-copilot/gpt-6.1-terra",
      "reason": "UiO gpt-6.1-terra quota depleted",
      "until": "2026-12-01"
    }
  }
}
```

- Keys under `overrides` are agent names: custom agents (`agents/*.md`) and built-ins (`build`, `plan`, `general`, `explore`, `title`, `summary`, `compaction`).
- `model` is required: `provider/model`.
- `reason` is required: free text that records the quota status. It is the only place depletion status is written down.
- `until` is optional: an ISO date. On or after that date the override is ignored and a warning names it, so overrides cannot outlive the reset unnoticed.

### Launch-time merge

The secure wrapper `.config/opencode/bin/opencode` already builds the JSON it passes to OpenCode as `OPENCODE_CONFIG_CONTENT` (via the launch helper `scripts/lib/launch-opencode-nono.sh`). That JSON currently holds the generated provider config from `provider-runtime.json`.

The wrapper will also read the overrides file and add `agent.<name>.model` for each active override. Logic lives in a small Python helper under `scripts/lib/` so it can be tested inside nono without launching OpenCode.

Validation (refuse to launch with a message naming the file and entry):
- File is not valid JSON, or `overrides` is not an object.
- An entry lacks `model` or `reason`, or has an unknown key.
- `model` uses a provider that is not enabled in `provider-runtime.json`, or names a UiO model that is not in the generated provider list.
- `until` is not an ISO date.

Warnings (launch continues): expired `until`; agent name not found among agent files or built-ins.

On launch the wrapper prints one line per active override, for example `model override: maestro -> github-copilot/gpt-6.1-terra (UiO gpt-6.1-terra quota depleted; until 2026-12-01)`.

### Committed config and runbook

- Every role's committed `model:` is its `#1`. Remove "#2 active" and "restore after reset" comments.
- The runbook drops quota-status statements and documents the overrides file, with an example.

## Precedence assumption

`OPENCODE_CONFIG_CONTENT` is documented as the final local-scope merge, so `agent.<name>.model` from it is expected to win over agent-file frontmatter and `opencode.jsonc`. This has not been verified for markdown agents. Task 1 verifies it before any other work.

## Acceptance tests

1. **Merge helper (pod-inside-nono contract test):** given a provider runtime and an overrides file, the helper output contains the provider config unchanged plus `agent.<name>.model` for each active override; expired overrides are omitted with a warning; each invalid case above is refused with its message; a missing file produces the provider config unchanged.
2. **Wrapper wiring (pod-inside-nono contract test):** the wrapper calls the helper with the canonical overrides path and passes its output as the config content.
3. **Runtime precedence (pod-outside-nono, run by the human):** with an override for one custom agent and one built-in, OpenCode reports the overridden models for both; with the file removed, it reports the committed `#1` models.

## Tasks

1. Verify precedence: the human launches OpenCode with an `OPENCODE_CONFIG_CONTENT` that sets `agent.maestro.model` and `agent.compaction.model`, then reports the effective models (exact command supplied in the plan). **User Check-in:** if precedence does not hold, stop and redesign.
2. Write failing tests 1 and 2.
3. Implement the merge helper and wrapper wiring; make tests 1 and 2 pass.
4. Set every committed role to `#1`, remove depletion comments, update the runbook.
5. **User Check-in:** the human creates the overrides file for current depletion, runs acceptance test 3, and reinstalls the wrapper if the installed copy differs from the repository (outside nono).

## Risks

- **Precedence fails for markdown agents.** Mitigation: Task 1 runs first; the fallback design writes overrides as generated agent files in a host-local config directory.
- **Typo in an override breaks launch.** Intended: refusing is safer than silently running the wrong model. The message names the entry.
- **Installed wrapper drift.** The wrapper and launch helper run from installed copies; the human must reinstall after changes.
