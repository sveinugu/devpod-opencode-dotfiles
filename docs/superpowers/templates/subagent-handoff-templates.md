### Task payload

Use the packet rules in `.config/opencode/skills/opencode-dispatch/SKILL.md`.

`````text
Delegation Packet
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
`````

`Preview:` is meta-commentary outside the packet, not a packet field.

For non-trivial packets, use a separate preview wrapper. Show the exact outgoing dispatch content and explicitly ask for `ok / edit / cancel`.

### After successful launch

Use the exact returned `task_id` with `.config/opencode/skills/opencode-sessions/SKILL.md`.

```text
Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.
Session: <task_id>
Resume: $<task_id> <your reply>
Owner: <subagent>
Authority: the owning subagent owns this scope, subject to the general-agent exception and any human-approved Maestro override
```

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
