Use the exact returned `task_id` verbatim for `<task_id>` when available; delegating agents must validate `Session:` and `Resume:` against it before sending. Examples below use `ses_...` only because that is the current shape of a real task_id.

### Start
```text
Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.
Delegation Packet
Session: <task_id>
Resume: $<task_id> <your reply>
Owner: <subagent>
Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active
Artifact path: <exact approved plan/spec path; omit when not applicable>
Worktree path: <explicit absolute path to editable checkout; omit when not applicable>
Verbatim user request:
> <quote the user's exact relevant words>
Warnings:
- <optional, non-authoritative note; omit section when empty>

Annex (non-authoritative; not part of Delegation Packet)
Pointers:
- <file path or URL references>
Highlight (derived from verbatim; must match after stripping markup):
> <exact copy of verbatim line with **bold** only>
Open questions:
- <questions before committing to a choice>
Hypotheses:
- <hypothesis; confirm before relying>
Evidence (verbatim, source: <label>):
````text
<raw output>
````
```
> **Note:** `Preview:` is meta-commentary outside the packet, not a packet field.
> Preview non-trivial packets before dispatch by showing the exact outgoing packet and obtaining explicit user approval.

### Pause / waiting for user
```text
I’m the <subagent> subagent. I’m waiting for your reply before continuing.
```

### Completion
```text
The <subagent> subagent has completed the scoped work. Returning control to the Maestro for orchestration and next-step delegation.
```

### Recommended resume message pattern
```text
$<task_id> <your reply>
```
