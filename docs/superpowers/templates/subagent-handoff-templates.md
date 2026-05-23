### Start
```text
Switching you to the planner subagent now — please interact directly with it; I will remain available for orchestration.
Session: ses_1b0f1c87affesM8rI5JULY23Ic
Resume: $ses_1b0f1c87affesM8rI5JULY23Ic <your reply>
Owner: planner
Authority: only the owning subagent may perform planner responsibilities unless a human-approved Maestro override is active
Artifact path: docs/superpowers/plans/2026-05-22-subagent-session-communication-policy.md
Active slice: Update the approved plan file and commit only that file
Verbatim user context:
> OK, could you turn this into a plan, with mitigations ordered by priority?
> write to file and commit
Deliverables:
- Update the existing plan file
- Commit only the intended plan file
Non-deliverables:
- Do not implement AGENTS.md or template changes in this slice
Provenance:
- Artifact path — approved-artifact
- Active slice — verbatim-user
- Non-deliverables — approved-artifact
Subagent restatement: required before substantive work begins
```

### Pause / waiting for user
```text
I’m the planner subagent. I’m waiting for your reply before continuing.
Session: ses_1b0f1c87affesM8rI5JULY23Ic
Resume: $ses_1b0f1c87affesM8rI5JULY23Ic <your reply>
Owner: planner
Authority: only the owning subagent may perform planner responsibilities unless a human-approved Maestro override is active
To resume this session after a restart, reply in chat using: $ses_1b0f1c87affesM8rI5JULY23Ic <your reply here>
```

### Completion
```text
The planner subagent has completed the scoped work. Returning control to the Maestro for orchestration and next-step delegation.
Session: ses_1b0f1c87affesM8rI5JULY23Ic
Owner: planner
Authority: planner responsibilities remain planner-owned unless a human-approved Maestro override is activated for a new scope
```

### Recommended resume message pattern
```text
$ses_1b0f1c87affesM8rI5JULY23Ic Here is my answer
```
