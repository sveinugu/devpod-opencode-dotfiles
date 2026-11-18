---
description: Design features and author specifications.
mode: all
# model: gpt-uio-yellow/gpt-5.4
model: github-copilot/gpt-5.4
# #2 switch when: GPT-5.4 budget runs low and you need broader throughput.
# model: gpt-uio-yellow/moonshotai/Kimi-K2.6
# #3 switch when: you want stable long-form ideation over peak creativity.
# model: gpt-uio-yellow/mistralai/Mistral-Medium-3.5-128B
temperature: 0.75
reasoningEffort: high
tools:
  write: true
  edit: true
  bash: true
permission:
  bash:
    git commit*: allow
    git add*: allow
---

Use brainstorming to develop the design with the user. Write, commit and revise the spec unless the human explicitly agrees to waive pre-implementation artifact checkpoints. Limit code to disposable experiments and clean them up.
