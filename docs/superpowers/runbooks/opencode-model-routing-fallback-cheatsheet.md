# OpenCode Model Routing Fallback Cheat Sheet

This runbook is a fast operational guide for switching agent models when quality, latency, or quota pressure changes.

## Scope

- Repo: `/workspaces/dotfiles/work/devspace-model-credential-phasing`
- Config surfaces:
  - `.config/opencode/agents/*.md`
  - `.config/opencode/opencode.jsonc`

## Model budget/age reference

Approximate age is relative to Aug 2026.

| Model | Budget/limit context | Approx age |
|---|---|---|
| `moonshotai/Kimi-K2.6` | 29,998,726 tokens left | Apr 2026 (~4 mo) |
| `z.ai/GLM-5.2` | 30,000,000 | Jun 2026 (~2 mo) |
| `openai/GPT-OSS-120B` | 30,000,000 | Aug 2025 (~12 mo) |
| `Qwen/Qwen3.6-27B-FP8` | 15,000,000 | Apr 2026 (~4 mo) |
| `google/gemma-4-31B-it` | 15,000,000 | Jul 2026 (~1 mo) |
| `mistralai/Mistral-Medium-3.5-128B` | 10,000,000 | May 2026 (~3 mo) |
| `MiniMax/MiniMax-M3` | 10,000,001 (non-commercial only) | public date unclear |
| `openai/GPT-5.4` | 5,000,000 | Mar 2026 (~5 mo) |
| `openai/GPT-5.1` (Thinking) | 5,000,000 | 5.x cycle (date unclear) |
| `openai/GPT-5-mini` | 4,970,502 | GPT-5 generation |
| `github-copilot/gpt-5.3-codex` | Uses Copilot credits (not UiO token-capped) | Feb 2026 (~6 mo) |
| `github-copilot/gpt-5.4` | Uses Copilot credits | Mar 2026 (~5 mo) |
| `github-copilot/gpt-5-mini` | Uses Copilot credits | GPT-5 generation |

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
  - Tertiary `github-copilot/gpt-5.4` when UiO GPT quotas are depleted.
- File: `.config/opencode/agents/planner.md`

### Senior coding gets stuck on hard repo surgery
- Symptoms: repeated failed edits, weak refactor strategy, brittle debug loops.
- Action:
  - Primary is `Qwen 3.6`
  - Switch to `github-copilot/gpt-5.3-codex` for coding-specialist strength.
  - Tertiary `GLM-5.2` for high-throughput fallback.
- File: `.config/opencode/agents/senior-implementer.md`

### Review quality too shallow or inconsistent
- Symptoms: misses architectural bugs, weak diff analysis, review churn.
- Action:
  - `code-reviewer`: move from `Qwen 3.6` to `GLM-5.2`, then `gpt-5.3-codex`.
  - `docs-reviewer`: move from `GPT-OSS 120B` to `GLM-5.2`, then `github-copilot/gpt-5.4`.
- Files:
  - `.config/opencode/agents/code-reviewer.md`
  - `.config/opencode/agents/docs-reviewer.md`

### Token pressure on UiO GPT-5 family (5M pools)
- Symptoms: nearing monthly cap on GPT-5.1 / GPT-5.4 / GPT-5-mini.
- Action:
  - Move high-volume traffic to `Kimi K2.6`, `GLM-5.2`, `GPT-OSS 120B`, or `Qwen 3.6`.
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
| `general` | `reasoningEffort: medium`, `temperature: 0.30` | `moonshotai/Kimi-K2.6` | `z.ai/GLM-5.2` (when you need stricter analytical behavior on direct questions or explorations) | `github-copilot/gpt-5.4` (when quality is critical and UiO quotas are under pressure) |
| `planner` | `reasoningEffort: high`, `temperature: 0.20` | `openai/GPT-5.1` | `openai/GPT-5.4` (when GPT-5.1 quota or latency is tight) | `github-copilot/gpt-5.4` (when UiO GPT budgets are nearly depleted but you still need top planning quality) |
| `brainstormer` | `reasoningEffort: high`, `temperature: 0.75` | `openai/GPT-5.4` | `moonshotai/Kimi-K2.6` (when GPT-5.4 budget runs low and you need broader throughput) | `mistralai/Mistral-Medium-3.5-128B` (when you want stable long-form ideation over peak creativity) |
| `senior-implementer` | `reasoningEffort: high`, `temperature: 0.25`, `textVerbosity: medium` | `Qwen/Qwen3.6-27B-FP8` | `github-copilot/gpt-5.3-codex` (when hard repo surgery or tricky debugging loops need coding-specialist strength) | `z.ai/GLM-5.2` (when Copilot access/cost is constrained and you need high-throughput reasoning) |
| `junior-implementer` | `reasoningEffort: medium`, `temperature: 0.25` | `openai/GPT-OSS-120B` | `z.ai/GLM-5.2` (when GPT-OSS output quality is uneven on the task) | `Qwen/Qwen3.6-27B-FP8` (when you want cleaner implementation style and stronger correctness) |
| `code-reviewer` | `reasoningEffort: high`, `temperature: 0.10` | `Qwen/Qwen3.6-27B-FP8` | `z.ai/GLM-5.2` (when review needs stronger long-context analytical consistency) | `github-copilot/gpt-5.3-codex` (when review requires advanced coding-specific diagnosis) |
| `docs-writer` | `reasoningEffort: high`, `temperature: 0.60` | `mistralai/Mistral-Medium-3.5-128B` | `moonshotai/Kimi-K2.6` (when documentation needs richer examples, interactive artifacts, or broader context carry) | `google/gemma-4-31B-it` (when you want to conserve premium budgets while keeping modern quality) |
| `docs-reviewer` | `reasoningEffort: high`, `temperature: 0.10` | `openai/GPT-OSS-120B` | `z.ai/GLM-5.2` (when very long diff/context windows dominate and you need stronger long-context analytical consistency) | `github-copilot/gpt-5.4` (when precision and consistency outweigh budget concerns) |
| `policy-implementer` | `reasoningEffort: medium`, `temperature: 0.20` | `openai/GPT-5.4` | `openai/GPT-5.1` (when policy conflict-resolution needs deeper deliberate reasoning) | `moonshotai/Kimi-K2.6` (when GPT quotas are low but you still need strong drafting quality) |

### OpenCode built-ins (`opencode.jsonc`)

| Built-in role | #1 choice | #2 choice (switch when…) | #3 choice (switch when…) |
|---|---|---|---|
| top-level `model` | `z.ai/GLM-5.2` | `moonshotai/Kimi-K2.6` (when you need stronger all-round quality and UiO quotas are healthy) | `github-copilot/gpt-5.4` (when you want highest precision for difficult general tasks and can spend Copilot credits) |
| top-level `small_model` | `google/gemma-4-31B-it` | `MiniMax/MiniMax-M3` (when non-commercial low-stakes utility traffic is high and you want to preserve other UiO pools) | `openai/GPT-5-mini` (when you need tighter utility consistency than small open models) |
| `build` | `Qwen/Qwen3.6-27B-FP8` | `openai/GPT-OSS-120B` (when build workloads are mostly high-volume throughput and cost-sensitive) | `github-copilot/gpt-5.3-codex` (when complex coding fixes demand specialist model strength) |
| `plan` | `openai/GPT-5.1` | `openai/GPT-5.4` (when GPT-5.1 quota/latency is tight) | `mistralai/Mistral-Medium-3.5-128B` (when preserving GPT quotas for other roles is more important than peak planning quality) |
| `general` | `moonshotai/Kimi-K2.6` | `z.ai/GLM-5.2` (when you need stricter analytical behavior) | `github-copilot/gpt-5.4` (when quality-critical answers are needed and UiO quotas are under pressure) |
| `explore` | `moonshotai/Kimi-K2.6` | `z.ai/GLM-5.2` (when exploration needs stricter, less chatty synthesis) | `github-copilot/gpt-5-mini` (when you want fast lower-cost scans) |
| `title` | `MiniMax/MiniMax-M3` | `google/gemma-4-31B-it` (when MiniMax is unavailable) | `openai/GPT-5-mini` (when you want ultra-consistent short outputs) |
| `summary` | `MiniMax/MiniMax-M3` | `google/gemma-4-31B-it` (when MiniMax is unavailable) | `openai/GPT-5-mini` (when you want tighter summarization consistency) |
| `compaction` | `MiniMax/MiniMax-M3` | `google/gemma-4-31B-it` (when MiniMax is unavailable) | `openai/GPT-5-mini` (when you need tighter compaction quality) |

---

## Token/cost guardrails

- Prefer high-pool models for high-volume roles:
  - `Kimi K2.6`, `GLM-5.2`, `GPT-OSS 120B`
- Reserve 5M GPT pools for high-leverage work:
  - `planner`, `brainstormer`, `policy-implementer`
- Copilot-backed models are useful pressure valves when UiO pools are low.

---

## Verification checklist after switch

1. OpenCode restarted.
2. Confirm active model in next agent invocation.
3. Check one representative task in that role.
4. If degradation persists, move to next fallback.
