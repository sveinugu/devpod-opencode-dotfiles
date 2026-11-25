# Host-local OpenCode model overrides

Status: draft for approval (2026-11-19, revision 3)

## Problem

Agent model routing is committed in `.config/opencode/agents/*.md` and `.config/opencode/opencode.jsonc`. Each role has a `#1` model and commented `#2`/`#3` fallbacks (see `docs/superpowers/runbooks/opencode-model-routing-fallback-cheatsheet.md`). The top-level `model` and `small_model` defaults have fallback chains too.

Quota state changes often: UiO pools deplete per model and reset monthly, and the GitHub Copilot credit pool is shared. Today the only way to switch to a fallback is to edit the committed files. That either leaves uncommitted changes in tracked files or commits temporary state (for example "UiO GPT depleted until December") into the repository.

## Goals

1. The repository holds only the target routing: every role and default runs its `#1` model.
2. Temporary switches, and the reason for them, live in one host-local file outside every checkout.
3. Overrides apply at OpenCode launch with no edits to tracked files, and apply to every worktree.
4. A broken or mistyped overrides file never silently changes routing.

## Non-goals

- Automatic fallback when a request fails (OpenCode has no native fallback chain).
- Detecting quota depletion automatically.
- A CLI to edit overrides (hand-edited JSON is enough; revisit if it becomes tedious).
- Overriding anything other than models (agent `model`, top-level `model`, top-level `small_model`).
- Applying overrides to already-running sessions; overrides take effect at the next launch.

## Design

### Overrides file

Path: `/workspaces/dotfiles/state/hub/etc/model-overrides.json` (host-local, like `provider-enablement.json`; not in any checkout, so no gitignore entry is needed). The wrapper reads the path from `HUB_OPENCODE_MODEL_OVERRIDES_PATH`, defaulting to that location, so tests can point it at fixtures. The file is optional; a missing file means no overrides.

```json
{
  "agents": {
    "maestro": {
      "model": "github-copilot/gpt-6.1-terra",
      "reason": "UiO gpt-6.1-terra quota depleted",
      "until": "2026-12-01"
    }
  },
  "defaults": {
    "small_model": {
      "model": "gpt-uio-yellow/Qwen/Qwen3.8-27B-FP8",
      "reason": "Gemma 4 quota depleted"
    }
  }
}
```

- Top-level keys: `agents` and `defaults`, both optional objects. Any other top-level key is refused.
- `agents` keys are agent names: files in `.config/opencode/agents/*.md` (without `.md`) in the install-branch checkout the wrapper runs from (`$source_root`) and the built-ins `build`, `plan`, `general`, `explore`, `title`, `summary`, `compaction`. An entry for any other name is skipped with a warning (see below), because OpenCode turns an unknown agent name into a new selectable agent instead of failing.
- `defaults` keys are `model` and `small_model` only.
- Each entry has exactly these keys:
  - `model` (required): `provider/model`.
  - `reason` (required): free text that records the quota status. It is the only place depletion status is written down.
  - `until` (optional): a date in `YYYY-MM-DD` form, compared with the pod's current UTC date. The override applies before that date and is ignored, with a warning, on or after it, so overrides cannot outlive a reset unnoticed.

### Launch-time merge

The secure wrapper `.config/opencode/bin/opencode` builds the JSON it passes to OpenCode as `OPENCODE_CONFIG_CONTENT` (through the image-installed launch helper, which already accepts `--opencode-config-content`). That JSON currently holds the generated provider config from `provider-runtime.json`.

A new Python helper under `scripts/lib/` reads the provider runtime and the overrides file and prints the config content. Its output may contain only:
- the provider block (`enabled_providers`, `provider`), unchanged;
- `agent.<name>.model` for each active agent override;
- top-level `model` and `small_model` for each active default override.

The wrapper calls the helper in place of its current inline Python. The launch helper, the image and the sudoers rules do not change, so no image rebuild is needed. The wrapper runs live from the install-branch checkout (`$HUB_INSTALL_BRANCH_DIR`, currently `/workspaces/dotfiles/main`), so a change takes effect at the next launch once it is in that checkout.

Validation (refuse to launch, before `sudo`, with a message on stderr naming the file and entry). These mean the file itself is broken:
- The file is not valid JSON, has a duplicate key or an unknown top-level key, or `agents`/`defaults` is not an object.
- A default key is not `model` or `small_model`.
- An entry lacks `model` or `reason`, has an unknown key, has an `until` that is not `YYYY-MM-DD`, or has a `model` that is not a literal `provider/model` id.

Skipped with a warning (launch continues with the other entries). The file is shared by all checkouts, so an entry can be valid on one branch and not apply on another:
- The agent name is not an agent of the installed checkout (`.config/opencode/agents/*.md`) or a built-in.
- `model` uses a provider that is not in `enabled_providers` of `provider-runtime.json`.
- `model` uses a provider that lists models in `provider-runtime.json` (the UiO providers) and the model is not listed there.

GitHub Copilot model names are not checked: `provider-runtime.json` has no model list for `github-copilot`, and OpenCode loads an unknown Copilot model without error. A mistyped Copilot model fails only on first use.

Warnings on stderr (launch continues): expired `until`.

The wrapper prints one stderr line per active override before launch, for example `model override: maestro -> github-copilot/gpt-6.1-terra (UiO gpt-6.1-terra quota depleted; until 2026-12-01)`. The TUI's alternate screen may hide it, so the runbook documents how to check effective models (`opencode debug agent <name>`).

### Committed config and runbook

- Every committed role and default uses its `#1` model. Remove "#2 active" and "restore after reset" comments.
- The runbook drops quota-status statements, documents the overrides file with an example, and states that overrides apply only at launch.

### Generated nono profile

The nono profile generator also reads `provider-runtime.json`. The helper only reads that file and never writes it, and an override can only name a provider that is already enabled, so overrides cannot add providers or network hosts to the profile.

## Precedence

Verified on OpenCode 1.18.5 by the docs reviewer: `Config.loadInstanceState` loads agent directories, including markdown agents, before it merges `OPENCODE_CONFIG_CONTENT` at local scope; only account/organisation config merges after it. Running `opencode-raw debug agent <name> --pure` with `OPENCODE_CONFIG_CONTENT` setting `agent.maestro.model` and `agent.compaction.model` showed both overrides winning over markdown frontmatter and `opencode.jsonc`.

Not verified: plugin `config` hooks (excluded by `--pure`), and whether `title` and `summary` use their agent model at runtime rather than `small_model`.

The planned OpenCode upgrade may change this. Acceptance test 3 guards it.

## Acceptance tests

1. **Merge helper (pod-inside-nono contract test):** given a provider runtime and an overrides file, the output contains the provider block unchanged plus the agent and default overrides that are active, and nothing else. A missing file produces the provider block unchanged. Expired overrides are omitted with a stderr warning. Each refusal case above is refused with its message, and each skip case is skipped with its warning while the other entries apply.
2. **Wrapper behavior (pod-inside-nono contract test, extending `tests/pod-inside-nono/test_opencode_secure_wrapper_contract.sh`):** with `HUB_OPENCODE_MODEL_OVERRIDES_PATH` pointing at a fixture, the `--opencode-config-content` captured in the sudo mock log contains the overrides, and an invalid fixture makes the wrapper exit non-zero before calling `sudo`. Lines in that test that pin the old inline variable are updated deliberately, not weakened.
3. **Precedence regression (pod-inside-nono, agent-run):** `opencode-raw debug agent <name> --pure` with a synthetic `OPENCODE_CONFIG_CONTENT` reports the overridden model for one custom agent and one built-in, and the committed model without it. Run again after every OpenCode upgrade.
4. **Real launch path (pod-outside-nono, run by the human):** with an overrides file for one custom agent and one built-in, launching through the wrapper as `vscode` prints the override lines, and `opencode debug agent <name>` shows the overridden models. With the file removed, it shows the committed `#1` models.

## Tasks

The wrapper runs live from the install-branch checkout (`$HUB_INSTALL_BRANCH_DIR`, currently `/workspaces/dotfiles/main`), so edits there affect the next launch even before they are committed. Tasks 1, 2 and 4 are done in a managed worktree created with `bin/new-worktree`, and reach `main` only by merge.

1. Write failing tests 1, 2 and 3.
2. Implement the merge helper and wrapper change; make tests 1, 2 and 3 pass.
3. **User Check-in:** the human creates `/workspaces/dotfiles/state/hub/etc/model-overrides.json` for the current depletion. The current wrapper ignores the file, so creating it early is harmless. This must happen before task 4 is merged into the install branch, or depleted `#1` models go live.
4. Set every committed role and default to `#1`, remove depletion comments, update the runbook.
5. **User Check-in:** the human runs acceptance test 4.

## Risks

- **OpenCode upgrade changes precedence or schema.** The human plans an upgrade after this work. Mitigation: acceptance test 3 runs before and after the upgrade. If precedence breaks, write overrides as generated agent files in a host-local config directory instead.
- **Agents can edit the overrides file.** nono grants agents read and write on `/workspaces/dotfiles`, which includes `state/hub/etc/`. Today a routing change shows in `git status`; with this design it shows only in the launch lines and `opencode debug agent`. Mitigation: launch lines and the `reason` field. Follow-up, out of scope here: deny agent writes to the file if nono can express a per-file deny inside the `/workspaces/dotfiles` grant (Landlock only grants access, so the file may instead need to move outside the granted tree). Not checked.
- **Mistyped Copilot model names are not caught at launch** (see Validation).
- **Helper trust.** The helper runs as `vscode` from the agent-writable install-branch checkout, the same trust as the existing `nono-secret-env.sh` helper, and its output merges at near-highest precedence. Mitigation: the helper's output is restricted to the keys listed under Launch-time merge, and tests 1 and 2 check that.
