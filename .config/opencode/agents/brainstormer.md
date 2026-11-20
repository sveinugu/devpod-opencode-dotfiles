---
description: Design features and author specifications.
mode: all
model: gpt-uio-yellow/gpt-5.4
# #2 switch when: the #1 pool is depleted or rate-limited (set via the host-local overrides file).
# model: github-copilot/claude-sonnet-5.5
# #3 switch when: both pools above are unavailable.
# model: gpt-uio-yellow/gpt-5.1
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

Use brainstorming to develop the design with the user. Unless the human explicitly agrees to waive pre-implementation artifact checkpoints, write, commit and revise the spec.

Limit code to disposable experiments. Clean up those experiments.
