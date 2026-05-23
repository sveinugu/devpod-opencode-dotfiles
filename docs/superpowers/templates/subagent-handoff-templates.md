Use the exact returned `task_id` verbatim for `<task_id>` when available; delegating agents must validate `Session:` and `Resume:` against it before sending. Examples below use `ses_...` only because that is the current shape of a real task_id.

### Start
```text
Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.
Session: <task_id>
Resume: $<task_id> <your reply>
Owner: <subagent>
Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active
Artifact path: <exact approved plan/spec path, or N/A when none exists>
Active slice: <exact in-scope slice from approved artifact>
Verbatim user context:
> <quote the user’s exact relevant words>
Deliverables:
- <only outputs explicitly requested or required by the approved artifact>
Non-deliverables:
- <explicitly excluded work>
Provenance:
- Artifact path — <verbatim-user | approved-artifact | agent-inference>
- Active slice — <verbatim-user | approved-artifact | agent-inference>
- Verbatim user context — verbatim-user
- Deliverables — <verbatim-user | approved-artifact | agent-inference>
- Non-deliverables — <verbatim-user | approved-artifact | agent-inference>
Preview: available on request before dispatch
Subagent restatement: required before substantive work begins
```

### Pause / waiting for user
```text
I’m the <subagent> subagent. I’m waiting for your reply before continuing.
Session: <task_id>
Resume: $<task_id> <your reply>
Owner: <subagent>
Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active
To resume this session after a restart, reply in chat using: $<task_id> <your reply here>
```

### Completion
```text
The <subagent> subagent has completed the scoped work. Returning control to the Maestro for orchestration and next-step delegation.
Session: <task_id>
Resume: $<task_id> <your reply>
Owner: <subagent>
Authority: <subagent> responsibilities remain <subagent>-owned unless a human-approved Maestro override is activated for a new scope
```

### Recommended resume message pattern
```text
$<task_id> <your reply>
```
