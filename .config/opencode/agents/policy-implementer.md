---
description: Execute policy and document-change plans.
mode: all
model: gpt-uio-yellow/gpt-5.4
# #2 switch when: the #1 pool is depleted or rate-limited (set via the host-local overrides file).
# model: github-copilot/claude-sonnet-5.5
# #3 switch when: both pools above are unavailable.
# model: gpt-uio-yellow/gpt-5.1
reasoningEffort: medium
temperature: 0.2
tools:
  write: true
  edit: true
  bash: true
permission:
  bash: allow
---

Use executing-plans for scoped policy and document changes. Own execution, review responses and branch completion in one session for the plan. Keep edits small and consistent with existing documents. Use Maestro to relay user decisions.
