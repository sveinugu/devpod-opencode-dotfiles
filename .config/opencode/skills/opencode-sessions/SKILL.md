---
name: opencode-sessions
description: Route Task launches, replies, handbacks and failed resumes in OpenCode.
---

Bind each Task session to one agent type and work item (including its lane). After a successful new launch, say:

```text
Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.
```

Immediately show the following block on launch, resume and handback. Validate both IDs against the exact Task-returned `task_id`. Report a missing or unverified ID. Identify resumes as such and include the work item when known.

Never invent or normalize IDs; preserve the existing identifier if Task returns none. Without a validated ID, do not claim a successful handoff. Treat `task_id` and `session_id` as the same opaque identifier; manual lookup is case-insensitive, but preserve the returned spelling.

```text
Session: <task_id>
Resume: $<task_id> <your reply>
Owner: <subagent>
Authority: the owning subagent owns this scope, subject to the general-agent exception and any human-approved Maestro override
```

A leading `$<task_id>` routes the remaining payload verbatim to that exact session, including after restart. `$$` escapes a literal leading dollar. Preserve the token even on failure. An immediate corrected message replaces the earlier one. Never impersonate the owner.

For “switch” or “continue”, resume the clearly intended session. If the target is unclear, offer matching sessions by role and work item. Ask before starting a replacement. A new plan or sibling lane needs its own session.

On Task error or failed delivery, report the error, keep the original target and wait for explicit direction before retrying or starting another session. A senior implementer forwards failed resumes to Maestro with the exact token and context. If Maestro is unreachable, ask for `$<task_id> <your reply>` again and offer a transcript.
