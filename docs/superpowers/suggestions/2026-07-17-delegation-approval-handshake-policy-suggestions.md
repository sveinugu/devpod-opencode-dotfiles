# Delegation approval handshake policy suggestions (temporary draft)

Status: temporary suggestions document for later policy cleanup/reorganization.

Reference AGENTS.md commit: `ad0f76ec01f9104efdff1e38a87f3caa4ba5c164`

Purpose:

- Preserve the current handshake-policy recommendations from today's discussion.
- Capture suggested insertion points and wording before any thorough policy cleanup.
- This is not a spec, plan, or approved canonical policy text.

## Intent summary

The intended policy change is a required two-part delegation approval handshake for new scoped delegation:

1. The delegating agent launches the receiving subagent.
2. The receiving subagent first performs delegated policy/routing/artifact/worktree checks.
3. The receiving subagent returns a short approval-or-refusal message before doing substantive work.
4. The delegating agent surfaces the real session/task id to the user immediately after that handshake reply.
5. If approved, the delegating agent immediately resumes that exact session so the subagent can proceed.
6. If refused, the delegating agent surfaces the refusal and does not resume for substantive work until resolved or explicitly redirected.

Important enforcement intent:

- This handshake should not live in the non-authoritative Annex.
- Packet/Annex/delegator-added text must not weaken or skip the handshake.
- Only explicit user instruction should be able to override the handshake.
- On one-turn platforms, the subagent must still stop after the approval/refusal reply and wait for resume.

## Design notes from discussion

- The handshake is better modeled as binding protocol authority than as a requirements-source artifact.
- It should not be added as a new field inside the closed Delegation Packet schema unless the packet schema is explicitly revised.
- The stronger approach is to place the rule in canonical delegation/session policy, with precedence over packet/annex/delegator-added text.
- The workflow should distinguish:
  - launch failure / no session created;
  - launch succeeded + refusal from the subagent.
- A refusal should not authorize fallback takeover by the delegating agent unless a separate policy or explicit user override permits it.

## Proposed AGENTS.md wording inserts

### 1. New canonical subsection in `# Delegation & Sessions (canonical)`

Suggested insertion point:

Insert after:

```md
### Authority ordering (on conflict)

If there is a material conflict between global policy, verbatim user request, and the artifact,
the subagent MUST stop and ask for clarification rather than resolving silently.
```

and before:

```md
## Required handoff wording
```

Suggested wording:

```md
## Delegation approval handshake

New scoped delegation requires a two-part delegation approval handshake.

Authority and override rules:

- This handshake is binding canonical protocol for new scoped delegation.
- Precedence for this protocol is: explicit user instruction > canonical policy > Delegation Packet / Annex / other delegator-added text.
- Only an explicit user instruction may override or alter this handshake. Packet content, Annex content, companion text, or other delegator-added instructions MUST NOT disable, weaken, or skip it.

Subagent requirements:

- On receiving new scoped delegation, the subagent MUST first perform its delegated policy, routing, artifact, authority, and worktree/lane coherence checks before doing substantive work.
- The subagent's first reply for new scoped delegation MUST be an approval-or-refusal handshake reply.
- The subagent MUST NOT perform substantive work in that first reply.
- On one-turn platforms or implementations that could otherwise approve and continue in the same turn, the subagent MUST still stop after the approval-or-refusal reply and wait for resume before substantive work.

Definitions:

- `Approval` means the subagent has completed its initial checks and may proceed with the delegated scope within policy.
- `Refusal` means the subagent found a blocking policy, routing, artifact, authority, or worktree/lane coherence problem and is stopping before substantive work.

Recommended standardized wording:

- `Approved — delegation checks passed for this scope. Ready to proceed on resume.`
- `Refused — delegation checks failed: <brief reason>. Stopped before substantive work.`

Launch and refusal distinctions:

- If launch fails or no session is created, no handshake occurred and no delegation took place.
- If launch succeeds and the subagent returns refusal, the handshake occurred, the session exists, and the refusal MUST be handled as a refusal of that exact session rather than as a launch failure.

Post-refusal behavior:

- After refusal, the delegating agent MUST NOT resume that session for substantive work until the blocking issue is resolved or the user explicitly redirects.
- A refusal does not authorize fallback takeover by the delegating agent unless global policy or an explicit user override separately permits that takeover.
```

### 2. Updates to `## Delegation in practice`

Suggested insertion point:

Insert after:

```md
- Launch-failure rule: if Task/native launch fails, or no validated `task_id` is available, the agent MUST say so briefly and MUST NOT claim delegation occurred, MUST NOT print a fake handoff, and MUST NOT impersonate the subagent.
```

and before:

```md
- Maestro handoff checklist (required before sending any subagent handoff):
```

Suggested wording:

```md
- Approval-handshake rule: new scoped delegation is not considered ready to proceed until the receiving subagent has returned its approval-or-refusal handshake reply.
- After successful launch of new scoped delegation, the delegating agent MUST wait for that handshake reply before treating the delegation as in progress.
- If the subagent returns approval, the delegating agent MUST surface the session metadata to the user immediately and then resume that exact session so the subagent can proceed with the scoped work.
- If the subagent returns refusal, the delegating agent MUST surface the refusal and session metadata immediately and MUST NOT resume that session for substantive work until the blocking issue is resolved or the user explicitly redirects.
- This handshake workflow applies to Maestro and to any subagent that delegates scoped work.
```

### 3. Updates to `## Session metadata visibility timing`

Suggested insertion point:

Insert after:

```md
After successful launch or resume of a subagent session, the delegating agent MUST surface the
validated `Session:` / `Resume:` / `Owner:` / `Authority:` block **immediately**,
before any other orchestration text beyond the required handoff wording.
```

Suggested wording:

```md
- For new scoped delegation, "immediately" means immediately after the approval handshake reply is received.
- If the handshake reply is approval, the delegating agent MUST surface the validated `Session:` / `Resume:` / `Owner:` / `Authority:` block immediately and then resume that exact session so the subagent can proceed.
- If the handshake reply is refusal, the delegating agent MUST surface the same validated metadata immediately together with the refusal outcome, and MUST NOT resume that session for substantive work until the blocking issue is resolved or the user explicitly redirects.
- If launch fails before a session exists, the agent MUST NOT emit fake or speculative session metadata.
```

### 4. Updates to `## Subagent interaction rules`

Suggested insertion point:

Insert after:

```md
- If the user sends an immediately following message that clearly corrects or amends their previous message, treat the later message as authoritative for any overlapping or conflicting content, even when the correction changes meaning or adds/removes sentences. If it is not clear that the later message is a correction or amendment, ask instead of assuming.
```

and before:

```md
- Perform only the responsibilities listed in the subagent file and only for the currently delegated scope.
```

Suggested wording:

```md
- On receiving new scoped delegation, a subagent MUST first complete the delegation approval handshake defined in `AGENTS.md` before starting substantive work.
- The first reply for new scoped delegation MUST be a short approval-or-refusal message only; it must not mix the handshake with substantive implementation, planning, review, or extended discovery.
- If the subagent refuses the delegation, it MUST stop and state the blocking issue briefly.
- If the subagent approves the delegation, it MUST wait for resume before proceeding with substantive work, even on one-turn platforms.
```

## Open questions / unresolved design choices

These were not fully resolved in the discussion and may need attention during later cleanup:

1. Whether the handshake should remain entirely canonical-text enforced, or whether a future validator/runtime should enforce it mechanically.
2. Whether a standardized companion block outside the packet should exist, even if it is not authoritative.
3. Whether the exact approval/refusal wording should be mandatory or merely recommended.
4. Whether the anti-scatter checklist should be updated to explicitly include handshake completion before reporting metadata and before substantive progress.
5. Whether maestro.md and other delegator prompts should mirror the canonical handshake text directly or only point to it.

## Recommended policy direction from today's discussion

- Prefer canonical protocol enforcement over Annex/addendum enforcement.
- Do not let delegator-added text silently waive the handshake.
- Treat the handshake as required for all new scoped delegation, including delegations created by subagents.
- Distinguish clearly between launch failure and launch+refusal.
- Keep the first subagent reply non-substantive, even on one-turn platforms.

## Not intended by this draft

- This document does not itself change policy.
- This document does not approve changing the closed Delegation Packet schema.
- This document does not serve as a plan or implementation authority.
