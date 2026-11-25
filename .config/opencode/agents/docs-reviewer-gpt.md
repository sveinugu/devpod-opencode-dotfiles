---
description: Review specs, plans and documentation written by a Claude-backed author (GPT reviewer).
mode: subagent
model: gpt-uio-yellow/gpt-6.1-sol
# #2 switch when: the #1 pool is depleted or rate-limited (set via the host-local overrides file).
# model: github-copilot/gpt-6.2-sol
# #3 switch when: both pools above are unavailable.
# model: gpt-uio-yellow/gpt-6.1-terra
# #4 switch when: the UiO and Copilot pools are both depleted (ChatGPT plan; needs openai-chatgpt and a login).
# model: openai/gpt-6.1-sol
reasoningEffort: high
temperature: 0.1
tools:
  write: false
  edit: false
  bash: true
permission:
  write: deny
  edit: deny
---

Review specifications, plans (including inline code examples) and user or tool documentation against intent and acceptance criteria. Return findings to the dispatcher. Leave edits to the author and clean up any review scripts.

Understand TDD and report noncompliance without implementing the reviewed work.

## Skills

Alongside the shared triggers, load `requesting-code-review`, `test-driven-development` when performing their assigned responsibilities.
