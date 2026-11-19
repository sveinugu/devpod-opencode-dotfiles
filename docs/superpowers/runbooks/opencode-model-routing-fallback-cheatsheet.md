# OpenCode Model Routing Fallback Cheat Sheet

This runbook is a fast operational guide for choosing agent models and switching them when quality, latency, or quota pressure changes.

## Scope

Paths are relative to the repository root; the install branch's `.config/opencode` is linked to `~/.config/opencode`.

- Target routing (committed): `.config/opencode/agents/*.md` and `.config/opencode/opencode.jsonc`.
- UiO model list and context/output limits (committed): `.config/opencode/provider-policy.jsonc`, generated into `provider-runtime.json` by `bin/sync-provider-enablement`.
- Temporary switches and quota status (host-local, never committed): `/workspaces/dotfiles/state/hub/etc/model-overrides.json`.

## UiO / primary models and quotas

> Numbers are approximate and may change; always verify against UiO's current quotas and dashboards.

> **AA Index** = Artificial Analysis Intelligence Index v5.0.1 (artificialanalysis.ai, fetched 2026-11-19; higher is better; top model scores 65). Scores are measured at each model's maximum reasoning setting; agents here run at `high` or `medium`, which scores lower (for example `gpt-6.1-sol` scores 50 at `high`). `n/a` = no score on the current index. Agentic coding (Terminal-Bench 4.0, FrontierCode-AA) is part of the index. Use it to compare tiers, not as a role-specific ranking.

| Model ID                               | Friendly name              | AA Index | Context length (tokens) | Monthly pool (tokens, approx) | RPM / instance | Endpoints                              | Notes                                                                                                                                                                       |
|----------------------------------------|----------------------------|----------|-------------------------|-------------------------------|----------------|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| google/gemma-4-31B-it                  | Gemma 4                    | 4 | 131,072                 | 25,000,000                    | 8,000          | /models, /chat/completions             | Small, open model developed by Google DeepMind, launched in April 2026. Runs locally on educloud                                                                            |
| gpt-5                                  | GPT-5                      | n/a | 64,000                  | 5,000,000                     | 3,000          | /models, /chat/completions, /responses | A model with higher-quality reasoning and language understanding than lighter variants, suitable for complex tasks. Developed by OpenAI.                                   |
| gpt-5-mini                             | GPT-5 mini                 | n/a | 64,000                  | 5,000,000                     | 3,000          | /models, /chat/completions, /responses | Fast, lightweight model for quick notes, ideas, or email drafts with fast processing times. Developed by OpenAI.                                                            |
| gpt-5.1                                | GPT-5.1 Thinking           | n/a | 400,000                 | 5,000,000                     | 3,000          | /models, /chat/completions, /responses | Reasoning model designed for deeper insights and demanding problem types. Use this when you need advanced explanations, logical derivation, or problem solving. Developed by OpenAI. |
| gpt-5.4                                | GPT-5.4                    | n/a | 128,000                 | 15,000,000                    | 250            | /models, /chat/completions, /responses | Reasoning model designed for deeper insights and demanding problem types. Use this when you need advanced explanations, logical derivation, or problem solving. Developed by OpenAI. |
| gpt-oss-120b                           | GPT-OSS 120B               | 4 | 64,000                  | 30,000,000                    | 120            | /models, /chat/completions, /responses | Powerful, open-weight model for extensive data processing, analysis, or other tasks that require long context and computational power. Developed by OpenAI, and runs on NTNU's servers. |
| intfloat/multilingual-e5-large-instruct| Multilingual E5 Large Inst | — | 512                     | 5,000,000                     | 8,000          | /models, /embeddings                   | OpenAI compatible                                                                                                                                                            |
| norallm/normistral-11b-thinking        | NorMistral 11B             | n/a | 65,536                  | 15,000,000                    | 8,000          | /models, /chat/completions             | A large Norwegian language model developed by the Language Technology Group at the University of Oslo                                                                       |
| NorwAI/NorwAI-Magistral-24B-reasoning  | NorwAI Magistral           | n/a | 40,960                  | 5,000,000                     | 120            | /models, /chat/completions             | A Norwegian model, under development at NTNU. The model is offered for testing. It runs on NTNU's servers.                                                                  |
| moonshotai/Kimi-K2.6                   | Kimi K2.6                  | n/a | 160,000                 | 30,000,000                    | 120            | /models, /chat/completions             | Newest Kimi model as of April 2026. The model is compatible with images and works well for coding. It is developed by Moonshot AI in China and runs on NTNU's servers.      |
| mistralai/Mistral-Medium-3.5-128B      | Mistral Medium 3.5 128B    | 5 | 256,000                 | 10,000,000                    | 8,000          | /models, /chat/completions             | A compact European model that works with a wide range of languages. The model was developed in Europe and runs on NTNU's servers.                                           |
| Inferact/GLM-5.3-NVFP4                 | GLM 5.3                    | 32 | 1,000,000               | 30,000,000                    | 200            | /models, /chat/completions             | The best large open model as of September 2026. The model is recommended for coding tasks. This model was developed in China by Z.Ai and runs on NTNU's servers.            |
| Qwen/Qwen3.8-27B-FP8                   | Qwen 3.8                   | 20 | 262,144                 | 25,000,000                    | 8,000          | /models, /chat/completions             | Small, open model developed by Alibaba Cloud, launched in August 2026. Runs locally on educloud                                                                             |
| gpt-6-luna                             | GPT-6 Luna                 | 28 | 1,050,000               | 15,000,000                    | 150            | /models, /chat/completions, /responses | Fast and efficient model from OpenAI from September 2026.                                                                                                                   |
| gpt-6.1-sol                            | GPT-6.1 Sol                | 55 | 1,050,000               | 15,000,000                    | 100            | /models, /chat/completions, /responses | One of the most powerful models as of September 2026.                                                                                                                       |
| gpt-6.1-terra                          | GPT-6.1 Terra              | 51 | 1,050,000               | 15,000,000                    | 120            | /models, /chat/completions, /responses | Balanced flagship model from OpenAI. New and improved in November 2026.                                                                                                     |

### UiO availability and locality

- **Local** (educloud or NTNU servers; preferred for high-volume and utility traffic): `Gemma 4`, `Qwen 3.8` (educloud); `GPT-OSS 120B`, `Kimi K2.6`, `Mistral Medium 3.5`, `GLM 5.3`, `NorwAI Magistral` (NTNU). `NorMistral 11B` and the E5 embedding model are UiO models with no stated location.
- **Hosted OpenAI** (`gpt-5`, `gpt-5-mini`, `gpt-5.1`, `gpt-5.4`, `gpt-6-luna`, `gpt-6.1-sol`, `gpt-6.1-terra`): not local. Whenever a GPT model is the right choice, prefer the UiO GPT model over the Copilot GPT equivalent. Which family to use (Claude, GPT or other) is a separate per-role choice.
- Each UiO model has its own monthly pool. Current depletion is recorded only in the host-local overrides file (see "Temporary switches").
- `MiniMax M3` is no longer available; do not reference it.
- `github-copilot/gpt-5.4` and `github-copilot/gpt-5-mini` do not exist. Those IDs are UiO-only.

## GitHub Copilot / fallback models

> Uses GitHub AI credits (1 credit = $0.01), billed per token, not UiO token pools. There are no per-request multipliers on the usage-based plans.
> Prices are USD per 1M tokens, from GitHub's "Models and pricing for GitHub Copilot" page (fetched 2026-11-19); re-check it before relying on them, especially after promo end dates.
> Anthropic models also have a cache-write cost: Haiku 5.5 0.125, Sonnet 5.5 2.50, Opus 5.5 5.00.
> Context and max output are the Copilot defaults as observed; several models offer an extended context of up to about 1M tokens at long-context prices. The 265,536 context for Gemini 3.8 Flash and Gemini 4 Argon is unverified.
> The provider policy allows all Copilot models (`mode: all` in `provider-policy.jsonc`); the table below reflects the observed catalog, not a repo-enforced allowlist. Your org may enable a subset.

| Model ID | Friendly name | AA Index | Context (tokens) | Max output (tokens) | Input $ | Cached in $ | Output $ | Notes |
|----------|---------------|----------|------------------|---------------------|---------|-------------|----------|-------|
| github-copilot/claude-haiku-5.5 | Claude Haiku 5.5 | 36 | 200,000 | 100,000 | 0.10 | 0.01 | 0.50 | Anthropic; lightweight; >100K input tier is 0.50 / 0.05 / 2.50, cache write 0.625 |
| github-copilot/claude-sonnet-5.5 | Claude Sonnet 5.5 | 55 | 328,000 | 128,000 | 2.00 | 0.10 | 10.00 | Anthropic; versatile; adaptive thinking |
| github-copilot/claude-sonnet-5 | Claude Sonnet 5 | n/a | 264,000 | 64,000 | 2.00 | 0.20 | 10.00 | Anthropic; versatile; max thinking budget 32,000 |
| github-copilot/claude-opus-5.5 | Claude Opus 5.5 | 59 | 328,000 | 128,000 | 4.00 | 0.20 | 20.00 | Anthropic; powerful; adaptive thinking |
| github-copilot/gemini-3.8-flash | Gemini 3.8 Flash | n/a | 265,536 | 65,536 | 0.75 | 0.075 | 3.75 | Google; versatile; promo price through 2026-12-31 |
| github-copilot/gemini-4-hydrogen | Gemini 4 Hydrogen | 54 | 1,048,576 | 65,536 | 1.50 | 0.075 | 7.50 | Google; versatile; very large context |
| github-copilot/gemini-4-argon | Gemini 4 Argon | 50 | 265,536 | 65,536 | 2.00 | 0.10 | 10.00 | Google; powerful; promo price until 2026-12-01 |
| github-copilot/gemini-4-carbon | Gemini 4 Carbon | 60 | 264,000 | 64,000 | 2.00 | 0.10 | 10.00 | Google; powerful; promo until 2026-12-01, then 4.00 / 0.20 / 20.00 |
| github-copilot/gpt-5.3-codex | GPT-5.3 Codex | n/a | 400,000 | 128,000 | 1.75 | 0.175 | 14.00 | OpenAI; coding specialist; Copilot's LTS fallback model |
| github-copilot/gpt-5.6-luna | GPT-5.6 Luna | n/a | 328,000 | 128,000 | 0.20 | 0.02 | 1.20 | OpenAI; lightweight; cache write 0.25 |
| github-copilot/gpt-5.6-sol | GPT-5.6 Sol | n/a | 400,000 | 128,000 | 4.00 | 0.40 | 20.00 | OpenAI; powerful; cache write 5.00 |
| github-copilot/gpt-6-luna | GPT-6 Luna | 28 | 400,000 | 128,000 | 0.10 | 0.01 | 0.50 | OpenAI; lightweight; cache write 0.125 |
| github-copilot/gpt-6-sol | GPT-6 Sol | n/a | 400,000 | 128,000 | 2.00 | 0.20 | 10.00 | OpenAI; powerful; cache write 2.50 |
| github-copilot/gpt-6-astra | GPT-6 Astra | n/a | 400,000 | 128,000 | 10.00 | 1.00 | 50.00 | OpenAI; powerful; most expensive; avoid by default |
| github-copilot/gpt-6.1-terra | GPT-6.1 Terra | 51 | 400,000 | 128,000 | 1.00 | 0.05 | 5.00 | OpenAI; versatile; cache write 1.25 |
| github-copilot/gpt-6.1-sol | GPT-6.1 Sol | 55 | 400,000 | 128,000 | 2.00 | 0.10 | 10.00 | OpenAI; powerful; cache write 2.50 |
| github-copilot/gpt-6.2-sol | GPT-6.2 Sol | 57 | 400,000 | 128,000 | 2.00 | 0.10 | 10.00 | OpenAI; powerful; cache write 2.50 |
| github-copilot/gpt-6.2-astra | GPT-6.2 Astra | 62 | 400,000 | 128,000 | 8.00 | 0.40 | 40.00 | OpenAI; powerful; expensive |
| github-copilot/grok-4.6 | Grok 4.6 | n/a | 328,000 | 128,000 | 2.00 | 0.50 | 6.00 | xAI; versatile; >200K input tier doubles price |
| github-copilot/grok-4.7 | Grok 4.7 | 35 | 328,000 | 128,000 | 2.00 | 0.50 | 6.00 | xAI; versatile; >200K input tier doubles price |
| github-copilot/mai-code-2 | MAI Code 2 | n/a | 1,050,000 | 128,000 | 0.50 | 0.025 | 2.50 | Microsoft; powerful; promo until 2027-05-17, then 1.00 / 0.05 / 5.00 |
| github-copilot/mai-code-2-flash | MAI Code 2 Flash | n/a | 1,050,000 | 128,000 | 0.05 | 0.005 | 0.25 | Microsoft; lightweight; promo until 2027-05-17, then 0.10 / 0.01 / 0.50 |
| github-copilot/mai-code-1.1-flash | MAI-Code-1.1-Flash | n/a | 256,000 | 128,000 | 0.20 | 0.02 | 1.20 | Microsoft; lightweight |

Documented by GitHub but not seen in the observed catalog (verify availability before use; input / cached / output):

- `claude-opus-4.8` 5.00 / 0.50 / 25.00; `claude-opus-4.8` fast mode 10.00 / 1.00 / 50.00
- `claude-sonnet-4.6` and `claude-sonnet-4` 3.00 / 0.30 / 15.00; `claude-haiku-4.5` 1.00 / 0.10 / 5.00
- `claude-fable-5`, `claude-fable-5.1`, `claude-fable-5.2` 8.00-10.00 / 0.20-1.00 / 40.00-50.00 (Anthropic retains data by default; do not use for sensitive work)
- `gemini-4-neon` 3.00 / 0.15 / 15.00; `grok-4.5` 2.00 / 0.50 / 6.00; `kimi-k3` 3.00 / 0.30 / 15.00; `gpt-5.4-nano` 0.20 / 0.02 / 1.25

Cost tiers, examples only (input / output per 1M): **cheap** `gpt-6-luna`, `claude-haiku-5.5`, `mai-code-2-flash` (<= 0.10 / 0.50); **mid** `gpt-6.1-terra`, `claude-sonnet-5.5`, `gpt-6.1-sol`, `gpt-6.2-sol`, `gemini-4-hydrogen` (1-2 / 5-10); **premium** `claude-opus-5.5`, `gpt-5.6-sol` (4 / 20); **avoid** the Astra models (8-10 / 40-50).

## Important runtime note

OpenCode loads config, agent files and model overrides once, at launch. Restart OpenCode after any change; running sessions keep the models they started with.

There is no automatic model fallback. Each agent has one active `model:`; the `#2` / `#3` comments document the fallback chain.

Check effective models:

- **Your shell (as `vscode`):** `opencode debug agent <name>` goes through the wrapper, reads the current overrides file and prints the `model override:` lines.
- **Inside an agent session (nono):** `opencode` is not on PATH. `opencode-raw debug agent <name> --pure` shows only the config that session started with, not the current overrides file. To preview what the next launch will apply, run:
  `python3 scripts/lib/opencode-config-content.py --runtime .config/opencode/provider-runtime.json --overrides /workspaces/dotfiles/state/hub/etc/model-overrides.json --agents-dir .config/opencode/agents`
  from the install-branch checkout.

---

## Temporary switches (host-local overrides)

Use the overrides file for every temporary switch, such as a depleted pool. Do not edit committed model lines for that.

File: `/workspaces/dotfiles/state/hub/etc/model-overrides.json` (outside every checkout; applies to all worktrees).

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
    "small_model": { "model": "gpt-uio-yellow/Qwen/Qwen3.8-27B-FP8", "reason": "Gemma 4 quota depleted" }
  }
}
```

A depleted pool needs an override for **every** role whose `#1` is that model; see "UiO pool distribution" below. For example, Gemma 4 needs `title`, `summary` and `defaults.small_model`; GLM 5.3 needs `general`, `compaction` and `defaults.model`. The example above covers only part of the Gemma case.

- `agents` keys: an agent file in the install-branch checkout's `.config/opencode/agents/` (name without `.md`; a new agent must be merged into the install branch before it can be overridden) or a built-in (`build`, `plan`, `general`, `explore`, `title`, `summary`, `compaction`).
- `defaults` keys: `model` and `small_model` (the top-level defaults in `opencode.jsonc`).
- Each entry needs `model` and `reason`; `until` (`YYYY-MM-DD`, UTC) is optional. On or after `until`, the entry is ignored with a warning.
- Pick the replacement from the role's `#2` / `#3` comments.
- At launch the wrapper prints one `model override:` line per active entry on stderr. The TUI may hide it; use `opencode debug agent <name>`.
- The wrapper refuses to launch on invalid JSON, duplicate or unknown keys, unknown agent names, a malformed entry (missing `model` or `reason`, bad `until`, non-literal `provider/model`), a provider that is not enabled, or a UiO model that is not in the provider list. Copilot model names are not checked; a typo fails on first use.
- Agents can write this file. Review it if routing looks unexpected.

---

## Design rules

1. **Fallbacks keep the quality tier and switch quota pool.** Quality-critical roles (`planner`, `senior-implementer`, `code-reviewer`, `docs-writer`, both docs reviewers) fall back within the strong group (AA Index 51-59 at maximum reasoning) and alternate between a UiO pool and the shared Copilot pool. Local UiO models (AA Index 32 or lower, or unscored) serve high-volume and utility roles. `brainstormer`, `policy-implementer` and `maestro` start on unscored or mid-tier UiO GPT to spread quota. At the configured `high`/`medium` settings scores are lower and the order can change: Sonnet 5.5 at `high` scores 41.5, below `gpt-6.2-sol` at `high` (54.9).
2. **Distribute UiO pools.** Each UiO pool is #1 for different roles, so no single pool drains first. `plan` and `build` are rarely used and are not counted when spreading UiO quota; they mirror `planner` and `senior-implementer`.
3. **Claude for coding.** `senior-implementer` defaults to Sonnet 5.5. Opus 5.5 is a manual escalation for hard tasks (2x Sonnet's price). `junior-implementer` uses Haiku 5.5 (AA Index 36, cheap).
4. **Review always uses the opposite model family from the author.** Claude-written code is reviewed by `code-reviewer` (GPT). Specs, plans and docs go to `docs-reviewer-gpt` when the author ran on Claude and to `docs-reviewer-claude` when the author ran on GPT or another family. If `senior-implementer` ran on a GPT fallback, switch `code-reviewer` to Copilot `claude-sonnet-5.5` (or `claude-opus-5.5`) for that review with an override and a restart.
5. **UiO GPT is preferred over the same GPT model on Copilot.** Copilot GPT is a cross-pool fallback. At the top of the range, `gpt-6.2-sol` (57) costs half of Opus (59); `gpt-6.1-sol` and Sonnet 5.5 cost the same.
6. **Copilot is #1 only where quality matters more than volume:** `planner`, `senior-implementer`, `junior-implementer` (Haiku), `docs-writer`, `docs-reviewer-claude`.

---

## Symptoms → switch action

### Hard coding task (senior)
- Symptoms: repeated failed edits, weak refactor strategy, brittle debug loops.
- Action: override `senior-implementer` with `github-copilot/claude-opus-5.5`, then remove the override when the task is done. Overrides apply only at launch, so this restarts OpenCode and ends the coordinating session; plan the switch between tasks.

### A quota pool is depleted or rate-limited
- Action: add an override for each affected role, using its `#2` (a different pool from `#1`, except `docs-reviewer-claude`, where both are Copilot). If `#2` is also depleted, use `#3`.
- Lowest RPM limits: `gpt-6.1-sol` (100), Kimi K2.6, `gpt-6.1-terra`, GPT-OSS 120B and NorwAI Magistral (120), `gpt-6-luna` (150), GLM 5.3 (200), `gpt-5.4` (250). Parallel agents saturate these first.

### Copilot credit pressure
- Action: override Copilot-first roles with their UiO `#2` where that pool has quota; otherwise use a local model (GLM 5.3, Kimi K2.6).
- Avoid Astra models (8-10 / 40-50).

### Utility traffic (title/summary/compaction)
- Local models only.
- `compaction` uses GLM 5.3 (1M context), then Mistral 3.5 (256K), then Qwen 3.8 (262K). Gemma 4 (131K) and GPT-OSS (64K) are too small to compact large sessions.

---

## Current role mapping (table view)

Target routing as committed. Temporary switches live in the overrides file, not here.

### Team/specialist agents

| Agent | #1 | #2 | #3 | Notes |
|---|---|---|---|---|
| `planner` | Copilot `claude-opus-5.5` (59) | UiO `gpt-6.1-sol` (55) | Copilot `gpt-6.2-sol` (57) | |
| `senior-implementer` | Copilot `claude-sonnet-5.5` (55) | UiO `gpt-6.1-sol` (55) | Copilot `gpt-6.2-sol` (57) | Escalation for hard tasks: Copilot `claude-opus-5.5` (59) |
| `junior-implementer` | Copilot `claude-haiku-5.5` (36) | UiO `Kimi-K2.6` (n/a) | UiO `GLM-5.3-NVFP4` (32) | |
| `code-reviewer` | UiO `gpt-6.1-sol` (55) | Copilot `gpt-6.2-sol` (57) | UiO `gpt-6.1-terra` (51) | GPT reviews Claude-written code |
| `docs-writer` | Copilot `claude-sonnet-5.5` (55) | UiO `gpt-6.1-terra` (51) | Copilot `gpt-6.2-sol` (57) | |
| `docs-reviewer-gpt` | UiO `gpt-6.1-sol` (55) | Copilot `gpt-6.2-sol` (57) | UiO `gpt-6.1-terra` (51) | Reviews Claude-authored specs, plans and docs |
| `docs-reviewer-claude` | Copilot `claude-opus-5.5` (59) | Copilot `claude-sonnet-5.5` (55) | UiO `GLM-5.3-NVFP4` (32) | Reviews GPT- or other-authored docs; no UiO Claude exists, so `#2` shares the Copilot pool |
| `maestro` | UiO `gpt-6.1-terra` (51) | Copilot `gpt-6.1-terra` (51) | UiO `gpt-5.4` (n/a) | |
| `brainstormer` | UiO `gpt-5.4` (n/a) | Copilot `claude-sonnet-5.5` (55) | UiO `gpt-5.1` (n/a) | |
| `policy-implementer` | UiO `gpt-5.4` (n/a) | Copilot `claude-sonnet-5.5` (55) | UiO `gpt-5.1` (n/a) | |
| `general` | UiO `GLM-5.3-NVFP4` (32) | UiO `gpt-6.1-terra` (51) | Copilot `claude-sonnet-5.5` (55) | Also defined under `agent.general` in `opencode.jsonc`; edit both together |

### OpenCode built-ins and defaults (`opencode.jsonc`)

| Role | #1 | #2 | #3 | Notes |
|---|---|---|---|---|
| top-level `model` | UiO `GLM-5.3-NVFP4` (32) | UiO `gpt-6.1-terra` (51) | Copilot `claude-sonnet-5.5` (55) | Default for any agent without its own `model` |
| top-level `small_model` | UiO `gemma-4-31B-it` (4) | UiO `Qwen3.8-27B-FP8` (20) | UiO `gpt-oss-120b` (4) | Default for light tasks when a role sets no model |
| `build` | same chain as `senior-implementer` | | | Not counted for UiO quota spread |
| `plan` | same chain as `planner` | | | Not counted for UiO quota spread |
| `general` | same chain as the `general` agent | | | |
| `explore` | UiO `gpt-6-luna` (28) | Copilot `claude-haiku-5.5` (36) | UiO `gpt-5-mini` (n/a) | |
| `title` | UiO `gemma-4-31B-it` (4) | UiO `Qwen3.8-27B-FP8` (20) | UiO `gpt-oss-120b` (4) | |
| `summary` | UiO `gemma-4-31B-it` (4) | UiO `Qwen3.8-27B-FP8` (20) | UiO `gpt-oss-120b` (4) | |
| `compaction` | UiO `GLM-5.3-NVFP4` (32) | UiO `Mistral-Medium-3.5-128B` (5) | UiO `Qwen3.8-27B-FP8` (20) | |

Claude-backed roles keep their `temperature` and `reasoningEffort` settings. If a Claude role errors on a request setting, remove that setting for the agent first.

### UiO pool distribution (#1 roles, excluding `plan`/`build`)

| UiO pool | Roles using it as #1 |
|---|---|
| `gpt-6.1-sol` | `code-reviewer`, `docs-reviewer-gpt` |
| `gpt-6.1-terra` | `maestro` |
| `gpt-5.4` | `brainstormer`, `policy-implementer` |
| `gpt-6-luna` | `explore` |
| `GLM-5.3-NVFP4` | `general`, `compaction`, top-level `model` |
| `gemma-4-31B-it` | `title`, `summary`, `small_model` |
| Fallback only | `Kimi-K2.6`, `Qwen3.8-27B-FP8`, `Mistral-Medium-3.5-128B`, `gpt-5.1`, `gpt-5-mini`, `gpt-oss-120b` |
| Unused | `gpt-5`, `NorMistral`, `NorwAI Magistral` |

---

## Token/cost guardrails

- Copilot prices (input / output per 1M): Haiku 5.5 and `gpt-6-luna` 0.10 / 0.50; `gpt-6.1-terra` 1 / 5; Sonnet 5.5, `gpt-6.1-sol`, `gpt-6.2-sol` 2 / 10; Opus 5.5 4 / 20.
- Opus is used by `planner`, `plan`, `docs-reviewer-claude`, manual senior escalation, and Claude code review after a GPT-authored change.
- Long-context tiers: GPT-6 and GPT-5.6 Sol models raise input, cached-input and cache-write prices 2x and output 1.5x above 272K input tokens (GPT-5.6 Luna above 200K); Haiku 5.5 rises above 100K; Grok above 200K. GPT-5.3 Codex has no long-context tier.
- UiO context and output limits are declared in `provider-policy.jsonc` (output = smallest of the vendor maximum, 32,768, and a quarter of UiO's context) so OpenCode can trigger compaction.

---

## Verification checklist after switch

1. OpenCode restarted.
2. `opencode debug agent <name>` shows the intended model.
3. Check one representative task in that role.
4. If degradation persists, move to the next fallback.
