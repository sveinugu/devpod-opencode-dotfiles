# OpenCode Model Routing Fallback Cheat Sheet

This runbook is a fast operational guide for switching agent models when quality, latency, or quota pressure changes.

## Scope

- Repo: `/workspaces/dotfiles/work/devspace-model-credential-phasing`
- Config surfaces:
  - `.config/opencode/agents/*.md`
  - `.config/opencode/opencode.jsonc`

## UiO / primary models and quotas

> Numbers are approximate and may change; always verify against UiO's current quotas and dashboards.

| Model ID                               | Friendly name              | Context length (tokens) | Monthly pool (tokens, approx) | RPM / instance | Endpoints                              | Notes                                                                                                                                                                       |
|----------------------------------------|----------------------------|-------------------------|-------------------------------|----------------|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| google/gemma-4-31B-it                  | Gemma 4                    | 131,072                 | 25,000,000                    | 8,000          | /models, /chat/completions             | Small, open model developed by Google DeepMind, launched in April 2026. Runs locally on educloud                                                                            |
| gpt-5                                  | GPT-5                      | 64,000                  | 5,000,000                     | 3,000          | /models, /chat/completions, /responses | A model with higher-quality reasoning and language understanding than lighter variants, suitable for complex tasks. Developed by OpenAI.                                   |
| gpt-5-mini                             | GPT-5 mini                 | 64,000                  | 5,000,000                     | 3,000          | /models, /chat/completions, /responses | Fast, lightweight model for quick notes, ideas, or email drafts with fast processing times. Developed by OpenAI.                                                            |
| gpt-5.1                                | GPT-5.1 Thinking           | 400,000                 | 5,000,000                     | 3,000          | /models, /chat/completions, /responses | Reasoning model designed for deeper insights and demanding problem types. Use this when you need advanced explanations, logical derivation, or problem solving. Developed by OpenAI. |
| gpt-5.4                                | GPT-5.4                    | 128,000                 | 15,000,000                    | 250            | /models, /chat/completions, /responses | Reasoning model designed for deeper insights and demanding problem types. Use this when you need advanced explanations, logical derivation, or problem solving. Developed by OpenAI. |
| gpt-oss-120b                           | GPT-OSS 120B               | 64,000                  | 30,000,000                    | 120            | /models, /chat/completions, /responses | Powerful, open-weight model for extensive data processing, analysis, or other tasks that require long context and computational power. Developed by OpenAI, and runs on NTNU's servers. |
| intfloat/multilingual-e5-large-instruct| Multilingual E5 Large Inst | 512                     | 5,000,000                     | 8,000          | /models, /embeddings                   | OpenAI compatible                                                                                                                                                            |
| norallm/normistral-11b-thinking        | NorMistral 11B             | 65,536                  | 15,000,000                    | 8,000          | /models, /chat/completions             | A large Norwegian language model developed by the Language Technology Group at the University of Oslo                                                                       |
| NorwAI/NorwAI-Magistral-24B-reasoning  | NorwAI Magistral           | 40,960                  | 5,000,000                     | 120            | /models, /chat/completions             | A Norwegian model, under development at NTNU. The model is offered for testing. It runs on NTNU's servers.                                                                  |
| moonshotai/Kimi-K2.6                   | Kimi K2.6                  | 160,000                 | 30,000,000                    | 120            | /models, /chat/completions             | Newest Kimi model as of April 2026. The model is compatible with images and works well for coding. It is developed by Moonshot AI in China and runs on NTNU's servers.      |
| mistralai/Mistral-Medium-3.5-128B      | Mistral Medium 3.5 128B    | 256,000                 | 10,000,000                    | 8,000          | /models, /chat/completions             | A compact European model that works with a wide range of languages. The model was developed in Europe and runs on NTNU's servers.                                           |
| Inferact/GLM-5.3-NVFP4                 | GLM 5.3                    | 1,000,000               | 30,000,000                    | 200            | /models, /chat/completions             | The best large open model as of September 2026. The model is recommended for coding tasks. This model was developed in China by Z.Ai and runs on NTNU's servers.            |
| Qwen/Qwen3.8-27B-FP8                   | Qwen 3.8                   | 262,144                 | 25,000,000                    | 8,000          | /models, /chat/completions             | Small, open model developed by Alibaba Cloud, launched in August 2026. Runs locally on educloud                                                                             |
| gpt-6-luna                             | GPT-6 Luna                 | 1,050,000               | 15,000,000                    | 150            | /models, /chat/completions, /responses | Fast and efficient model from OpenAI from September 2026.                                                                                                                   |
| gpt-6.1-sol                            | GPT-6.1 Sol                | 1,050,000               | 15,000,000                    | 100            | /models, /chat/completions, /responses | One of the most powerful models as of September 2026.                                                                                                                       |
| gpt-6.1-terra                          | GPT-6.1 Terra              | 1,050,000               | 15,000,000                    | 120            | /models, /chat/completions, /responses | Balanced flagship model from OpenAI. New and improved in November 2026.                                                                                                     |

## GitHub Copilot / fallback models

> Uses Copilot credits, not UiO token pools. Quotas are consumption-based and depend on your GitHub subscription tier.
> GitHub Copilot is configured with `mode: all`; the table below reflects the current observed catalog, not a repo-enforced allowlist. Your org may enable a subset of these.

| Model ID | Friendly name | Context length (tokens) | Max output (tokens) | Vision | Notes |
|----------|---------------|------------------------|---------------------|--------|-------|
| github-copilot/claude-haiku-5.5 | Claude Haiku 5.5 | 200,000 | 100,000 | Yes | Anthropic; lightweight; adaptive thinking |
| github-copilot/claude-opus-5.5 | Claude Opus 5.5 | 328,000 | 128,000 | Yes | Anthropic; powerful; adaptive thinking |
| github-copilot/claude-sonnet-5.5 | Claude Sonnet 5.5 | 328,000 | 128,000 | Yes | Anthropic; versatile; adaptive thinking |
| github-copilot/claude-sonnet-5 | Claude Sonnet 5 | 264,000 | 64,000 | Yes | Anthropic; versatile; max thinking budget 32,000 |
| github-copilot/gemini-3.8-flash | Gemini 3.8 Flash | 265,536 | 65,536 | Yes | Google; versatile |
| github-copilot/gemini-4-argon | Gemini 4 Argon | 265,536 | 65,536 | Yes | Google; powerful |
| github-copilot/gemini-4-carbon | Gemini 4 Carbon | 264,000 | 64,000 | Yes | Google; powerful |
| github-copilot/gemini-4-hydrogen | Gemini 4 Hydrogen | 1,048,576 | 65,536 | Yes | Google; versatile; very large context |
| github-copilot/gpt-5.3-codex | GPT-5.3 Codex | 400,000 | 128,000 | Yes | OpenAI; powerful; coding specialist |
| github-copilot/gpt-5.6-luna | GPT-5.6 Luna | 328,000 | 128,000 | Yes | OpenAI; lightweight |
| github-copilot/gpt-5.6-sol | GPT-5.6 Sol | 400,000 | 128,000 | Yes | OpenAI; powerful |
| github-copilot/gpt-6-astra | GPT-6 Astra | 400,000 | 128,000 | Yes | OpenAI; powerful |
| github-copilot/gpt-6-luna | GPT-6 Luna | 400,000 | 128,000 | Yes | OpenAI; lightweight |
| github-copilot/gpt-6-sol | GPT-6 Sol | 400,000 | 128,000 | Yes | OpenAI; powerful |
| github-copilot/gpt-6.1-sol | GPT-6.1 Sol | 400,000 | 128,000 | Yes | OpenAI; powerful |
| github-copilot/gpt-6.1-terra | GPT-6.1 Terra | 400,000 | 128,000 | Yes | OpenAI; versatile |
| github-copilot/gpt-6.2-astra | GPT-6.2 Astra | 400,000 | 128,000 | Yes | OpenAI; powerful |
| github-copilot/gpt-6.2-sol | GPT-6.2 Sol | 400,000 | 128,000 | Yes | OpenAI; powerful |
| github-copilot/grok-4.6 | Grok 4.6 | 328,000 | 128,000 | Yes | xAI; versatile |
| github-copilot/grok-4.7 | Grok 4.7 | 328,000 | 128,000 | Yes | xAI; versatile |
| github-copilot/mai-code-2 | MAI Code 2 | 1,050,000 | 128,000 | Yes | Microsoft; powerful; very large context |
| github-copilot/mai-code-2-flash | MAI Code 2 Flash | 1,050,000 | 128,000 | Yes | Microsoft; lightweight; very large context |
| github-copilot/mai-code-1.1-flash | MAI-Code-1.1-Flash | 256,000 | 128,000 | Yes | Microsoft; lightweight |

## Important runtime note

OpenCode config is loaded at startup.

After any model switch:
1. Save config changes.
2. Restart OpenCode.

---

## Fast switch procedure

1. Open the relevant agent file (or `opencode.jsonc` for built-ins).
2. Find active `model:` and the commented `#2` / `#3` alternatives.
3. Promote the desired fallback by uncommenting it and commenting the current primary.
4. Keep the existing `reasoningEffort` / `temperature` unless a specific incident calls for tuning.
5. Restart OpenCode.

---

## Symptoms → switch action

### Maestro/orchestration quality drops
- Symptoms: weak delegation packet quality, routing confusion, higher retries.
- Action:
  - Primary is `Kimi K2.6`
  - Switch to `GPT-5 mini` for tighter routing behavior.
  - If still unstable or constrained, switch to `Mistral Medium 3.5`.
- File: `.config/opencode/agents/maestro.md`

### Planner/architecture quality drops
- Symptoms: shallow plans, weak risk framing, poor acceptance-test framing.
- Action:
  - Primary is `GPT-5.1`
  - Switch to `GPT-5.4` when 5.1 is weak/limited.
  - Tertiary `github-copilot/gpt-6.1-terra` when UiO GPT quotas are depleted.
- File: `.config/opencode/agents/planner.md`

### Senior coding gets stuck on hard repo surgery
- Symptoms: repeated failed edits, weak refactor strategy, brittle debug loops.
- Action:
  - Primary is `Qwen 3.8`
  - Switch to `github-copilot/gpt-5.3-codex` for coding-specialist strength.
  - Tertiary `GLM 5.3` for high-throughput fallback.
- File: `.config/opencode/agents/senior-implementer.md`

### Review quality too shallow or inconsistent
- Symptoms: misses architectural bugs, weak diff analysis, review churn.
- Action:
  - `code-reviewer`: move from `Qwen 3.8` to `GLM 5.3`, then `gpt-5.3-codex`.
  - `docs-reviewer`: move from `GPT-OSS 120B` to `GLM 5.3`, then `github-copilot/gpt-6.1-terra`.
- Files:
  - `.config/opencode/agents/code-reviewer.md`
  - `.config/opencode/agents/docs-reviewer.md`

### Token pressure on UiO GPT-5 family (5M pools)
- Symptoms: nearing monthly cap on GPT-5.1 / GPT-5.4 / GPT-5-mini.
- Action:
  - Move high-volume traffic to `Kimi K2.6`, `GLM 5.3`, `GPT-OSS 120B`, or `Qwen 3.8`.
  - Keep GPT-5.1 / GPT-5.4 for planner/brainstormer/policy-critical turns.

### Utility traffic (title/summary/compaction) burns premium models
- Symptoms: avoidable spend/consumption on non-critical helper tasks.
- Action:
  - Keep `MiniMax M3` as primary (non-commercial allowed in this workspace).
  - Fallback to `Gemma 4`, then `GPT-5 mini`.
- File: `.config/opencode/opencode.jsonc` under `agent.title`, `agent.summary`, `agent.compaction`.

---

## Current role mapping (table view)

### Team/specialist agents

| Agent | Tuning | #1 choice | #2 choice (switch when…) | #3 choice (switch when…) |
|---|---|---|---|---|
| `maestro` | `reasoningEffort: medium`, `temperature: 0.15` | `moonshotai/Kimi-K2.6` | `openai/GPT-5-mini` (when Kimi orchestration drifts or you want tighter concise routing) | `mistralai/Mistral-Medium-3.5-128B` (when both above are constrained, or you want steadier long-turn planning) |
| `general` | `reasoningEffort: medium`, `temperature: 0.30` | `moonshotai/Kimi-K2.6` | `Inferact/GLM-5.3-NVFP4` (when you need stricter analytical behavior on direct questions or explorations) | `github-copilot/gpt-6.1-terra` (when quality is critical and UiO quotas are under pressure) |
| `planner` | `reasoningEffort: high`, `temperature: 0.20` | `openai/GPT-5.1` | `openai/GPT-5.4` (when GPT-5.1 quota or latency is tight) | `github-copilot/gpt-6.1-terra` (when UiO GPT budgets are nearly depleted but you still need top planning quality) |
| `brainstormer` | `reasoningEffort: high`, `temperature: 0.75` | `openai/GPT-5.4` | `moonshotai/Kimi-K2.6` (when GPT-5.4 budget runs low and you need broader throughput) | `mistralai/Mistral-Medium-3.5-128B` (when you want stable long-form ideation over peak creativity) |
| `senior-implementer` | `reasoningEffort: high`, `temperature: 0.25`, `textVerbosity: medium` | `Qwen/Qwen3.8-27B-FP8` | `github-copilot/gpt-5.3-codex` (when hard repo surgery or tricky debugging loops need coding-specialist strength) | `Inferact/GLM-5.3-NVFP4` (when Copilot access/cost is constrained and you need high-throughput reasoning) |
| `junior-implementer` | `reasoningEffort: medium`, `temperature: 0.25` | `openai/GPT-OSS-120B` | `Inferact/GLM-5.3-NVFP4` (when GPT-OSS output quality is uneven on the task) | `Qwen/Qwen3.8-27B-FP8` (when you want cleaner implementation style and stronger correctness) |
| `code-reviewer` | `reasoningEffort: high`, `temperature: 0.10` | `Qwen/Qwen3.8-27B-FP8` | `Inferact/GLM-5.3-NVFP4` (when review needs stronger long-context analytical consistency) | `github-copilot/gpt-5.3-codex` (when review requires advanced coding-specific diagnosis) |
| `docs-writer` | `reasoningEffort: high`, `temperature: 0.60` | `mistralai/Mistral-Medium-3.5-128B` | `moonshotai/Kimi-K2.6` (when documentation needs richer examples, interactive artifacts, or broader context carry) | `google/gemma-4-31B-it` (when you want to conserve premium budgets while keeping modern quality) |
| `docs-reviewer` | `reasoningEffort: high`, `temperature: 0.10` | `openai/GPT-OSS-120B` | `Inferact/GLM-5.3-NVFP4` (when very long diff/context windows dominate and you need stronger long-context analytical consistency) | `github-copilot/gpt-6.1-terra` (when precision and consistency outweigh budget concerns) |
| `policy-implementer` | `reasoningEffort: medium`, `temperature: 0.20` | `openai/GPT-5.4` | `openai/GPT-5.1` (when policy conflict-resolution needs deeper deliberate reasoning) | `moonshotai/Kimi-K2.6` (when GPT quotas are low but you still need strong drafting quality) |

### OpenCode built-ins (`opencode.jsonc`)

| Built-in role | #1 choice | #2 choice (switch when…) | #3 choice (switch when…) |
|---|---|---|---|
| top-level `model` | `Inferact/GLM-5.3-NVFP4` | `moonshotai/Kimi-K2.6` (when you need stronger all-round quality and UiO quotas are healthy) | `github-copilot/gpt-6.1-terra` (when you want highest precision for difficult general tasks and can spend Copilot credits) |
| top-level `small_model` | `google/gemma-4-31B-it` | `gpt-6-luna` (when you want a fast, efficient utility model with a large pool) | `openai/GPT-5-mini` (when you need tighter utility consistency than small open models) |
| `build` | `Qwen/Qwen3.8-27B-FP8` | `openai/GPT-OSS-120B` (when build workloads are mostly high-volume throughput and cost-sensitive) | `github-copilot/gpt-5.3-codex` (when complex coding fixes demand specialist model strength) |
| `plan` | `openai/GPT-5.1` | `openai/GPT-5.4` (when GPT-5.1 quota/latency is tight) | `mistralai/Mistral-Medium-3.5-128B` (when preserving GPT quotas for other roles is more important than peak planning quality) |
| `general` | `moonshotai/Kimi-K2.6` | `Inferact/GLM-5.3-NVFP4` (when you need stricter analytical behavior) | `github-copilot/gpt-6.1-terra` (when quality-critical answers are needed and UiO quotas are under pressure) |
| `explore` | `moonshotai/Kimi-K2.6` | `Inferact/GLM-5.3-NVFP4` (when exploration needs stricter, less chatty synthesis) | `github-copilot/gpt-6-luna` (when you want fast lower-cost scans) |
| `title` | `gpt-6-luna` | `google/gemma-4-31B-it` (when you need a smaller open model) | `openai/GPT-5-mini` (when you want ultra-consistent short outputs) |
| `summary` | `gpt-6-luna` | `google/gemma-4-31B-it` (when you need a smaller open model) | `openai/GPT-5-mini` (when you want tighter summarization consistency) |
| `compaction` | `gpt-6-luna` | `google/gemma-4-31B-it` (when you need a smaller open model) | `openai/GPT-5-mini` (when you need tighter compaction quality) |

---

## Token/cost guardrails

- Prefer high-pool models for high-volume roles:
  - `Kimi K2.6`, `GLM 5.3`, `GPT-OSS 120B`
- Reserve 5M GPT pools for high-leverage work:
  - `planner`, `brainstormer`, `policy-implementer`
- Copilot-backed models are useful pressure valves when UiO pools are low.

---

## Verification checklist after switch

1. OpenCode restarted.
2. Confirm active model in next agent invocation.
3. Check one representative task in that role.
4. If degradation persists, move to next fallback.
