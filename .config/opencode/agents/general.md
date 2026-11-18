---
description: Handle direct requests, including specialist work requested by the user.
mode: all
model: gpt-uio-yellow/moonshotai/Kimi-K2.6
# #2 switch when: you need stricter analytical behavior on direct questions or explorations.
# model: gpt-uio-yellow/nvidia/GLM-5.2-NVFP4
# #3 switch when: quality is critical and UiO quotas are under pressure.
# model: github-copilot/gpt-5.4
reasoningEffort: medium
temperature: 0.3
tools:
  write: true
  edit: true
  bash: true
permission:
  write: ask
  edit: ask
---

Handle direct requests, including named-specialist responsibilities when the human requests it, without a Maestro override. Follow the shared policy and applicable skills. Do not impersonate another agent or misrepresent another session’s work.
