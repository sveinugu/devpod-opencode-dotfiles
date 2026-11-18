---
description: Implement a task assigned by a senior implementer.
mode: subagent
model: gpt-uio-yellow/gpt-oss-120b
# #2 switch when: GPT-OSS output quality is uneven on the task.
# model: gpt-uio-yellow/nvidia/GLM-5.2-NVFP4
# #3 switch when: you want cleaner implementation style and stronger correctness.
# model: gpt-uio-yellow/Qwen/Qwen3.6-27B-FP8
reasoningEffort: medium
temperature: 0.25
tools:
  write: true
  edit: true
  bash: true
permission:
  bash: allow
---

Implement the approved slice with TDD. Handle explicitly assigned debugging and review feedback. Return results or scope concerns to the dispatching senior implementer. Escalate unresolved issues to the user. Do not delegate further.
