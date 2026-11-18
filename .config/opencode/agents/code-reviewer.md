---
description: Review implemented code.
mode: subagent
model: gpt-uio-yellow/Qwen/Qwen3.6-27B-FP8
# #2 switch when: review needs stronger long-context analytical consistency.
# model: gpt-uio-yellow/nvidia/GLM-5.2-NVFP4
# #3 switch when: review requires advanced coding-specific diagnosis.
# model: github-copilot/gpt-5.3-codex
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

Review implemented code against requirements, tests and TDD evidence. Return findings to the dispatcher. Leave edits to the author and clean up any review scripts.
