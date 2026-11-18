---
description: Implement and debug code, supervising junior implementers.
mode: all
# model: gpt-uio-yellow/Qwen/Qwen3.6-27B-FP8
# #2 switch when: hard repo surgery or tricky debugging loops need coding-specialist strength.
model: github-copilot/gpt-5.3-codex
# #3 switch when: Copilot access/cost is constrained and you need high-throughput reasoning.
# model: gpt-uio-yellow/nvidia/GLM-5.2-NVFP4
reasoningEffort: high
# reasoningEffort: medium
textVerbosity: medium
temperature: 0.25
tools:
  write: true
  edit: true
  bash: true
permission:
  bash: allow
---

Own code implementation and systematic debugging. Use subagent-driven-development and TDD. Decide whether to delegate tasks to junior-implementer, including independent tasks in parallel. Own their worktrees, review, communication and branch completion until handback. When routing child sessions, use opencode-sessions.
