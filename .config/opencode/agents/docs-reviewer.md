---
description: Review specs, plans and documentation.
mode: subagent
model: gpt-uio-yellow/gpt-oss-120b
# #2 switch when: very long diff/context windows dominate and you need stronger long-context analytical consistency.
# model: gpt-uio-yellow/nvidia/GLM-5.2-NVFP4
# #3 switch when: precision and consistency outweigh budget concerns.
# model: github-copilot/gpt-5.4
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
