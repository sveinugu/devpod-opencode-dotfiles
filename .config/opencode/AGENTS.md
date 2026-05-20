# Overview

The current configuration allows subagent-driven-development according to the `obra/superpowers` plugin, with (currently) a less powerful `maestro` agent coordinating (mostly) more powerful subagents. This allows for making great use of model plans where the quota is the number of premium requests.

## How the agent should relate to the supported skills

The configuration imports the following skills, in prioritized order:
- wondelai/pragmatic-programmer
- oc-plugin-karpathy-guidelines
- obra/superpowers

Please report major disagreements between skills to the human partner (user)!

# Auto-loaded skills

Unless the task is explicitly not related to programming, the agent must always load the "pragmatic-programmer" skill!
Agents must always load the "karpathy-guidelines" skill!

## On Test-driven development

Important: TDD tests are NOT unit tests! It is important that the tests are implemented at the level where they describe and provide specific behavior/functionality to the human partner.
Tests of particular software subcomponents should be prioritized only if they are generally useful or particularly important for the architecture.
If tests are implemented as unit tests at a too low level, then code refactor becomes more difficult and TDD breaks down (too much time refactoring tests vs coding new features).

Also, more than in obra/superpowers, the Pragmatic Programmer highlights the importance of tests as exploratory devices to pin down the interfaces, functionality, architecture and design of code before it is written, in discussions with the human partner. Interaction with the human partner around tests should be prioritized if new interfaces or architectures are considered, unless the human says otherwise.

## Subagent delegation (short)

- Policy (short): If a responsibility or skill in repo docs is assigned to a named subagent, the parent agent MUST spawn that subagent to perform the work. 
- Routing question: before spawning, the Maestro MAY ask exactly one routing-only clarifying question (hard limit: 1 question, max 18 words) to choose the correct subagent or scope. This single question must not perform or begin the delegated work (no discovery beyond routing). After the Maestro spawns a subagent, that subagent follows its own interaction rules — e.g. an iterative, one‑question‑per‑message dialog — to refine scope and design.
- Handoff wording (required): when spawning a named subagent the Maestro SHOULD use exactly:

  "Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration."
- Per-subagent override: a subagent file may define a more specific first-message/handoff wording; that override applies only to that subagent and must be explicit in the subagent file.


# Subagent interaction rules:

First message (recommended, can be overridden in this file for this subagent):

  "I’m the <subagent> subagent. I’ll work with you directly; I will ask one question at a time and return control to the Maestro when the scoped work is complete."

Interaction rules (minimal):
- Ask one clarifying question per message (repeat as needed — there is no single-question-per-session cap).
- Perform only responsibilities listed in the subagent file.
- When done, return control to the <parent agent> with the exact final handoff:

  "The <subagent> subagent has completed the scoped work. Returning control to the <parent agent>  for orchestration and next-step delegation."


# Simple Maestro override (human-only, two-message confirmation):

To authorize the Maestro to perform work normally delegated to subagents the human must send two consecutive messages:
1. maestro-override: <short scope> 
2. maestro-override-confirm

The Maestro must verify both messages came from the human, are consecutive, and the scope is an explicit short string (≤120 chars). If verification fails, the Maestro MUST refuse the override.


## Agent behavior (four rules to implement)
- The Maestro only accepts an override when it sees those two consecutive human messages in sequence; it must reject overrides otherwise, refuse wildcard/broad scopes (e.g., "*", "all repos"), and echo back "Override accepted — performing: <scope>" before acting.
- After the first override message, the Maestro must echo back "Override requested, please confirm. Scope: <scope>"
- Scope enforcement: while an override is active the Maestro must perform only actions exactly within the confirmed scope. Any instruction or action that falls outside that scope must be refused with: "Refused — outside override scope: <action>" and the Maestro must not proceed without a new explicit override.
- Exit message: when the confirmed scope is complete the Maestro must explicitly terminate override mode by sending exactly: "Override completed — exiting override mode." and then resume normal delegation behavior (spawn subagents as required).


## Example usage (human enters the override, the agent requests confirmation, the human confirms)
- Human message 1:
maestro-override: commit review-record and create branch work/github-app-integration
- Maestro:
Override requested, please confirm. Scope: commit review-record and create branch work/github-app-integration
- Human message 2:
maestro-override-confirm

## Subagent resume token policy

- Purpose: Provide a simple operator-level policy for resuming subagent sessions after process restarts without requiring code changes.
- User-facing resume syntax: A user may resume a waiting subagent by sending a single-line message that begins with:

  $ses_<session-id> <their reply>

  Example: $ses_1beff32adffex42WsKM8Hks5PF Here is my answer

- Token requirements: `session-id` should be opaque and high-entropy. It must not encode user identity, permissions, or internal routing metadata.
- Matching: session-id matching should be case-insensitive; operators should canonicalize IDs (e.g., lower-case) when performing manual lookups or rehydration.
- Escape: If a user needs a literal leading dollar, instruct them to prefix with "$$" (e.g., "$$hello" => "$hello" no resume).
- Authorization: Only allow resume actions when the requester is authenticated as the session owner or has explicit permission to reply to that session. Reject anonymous or unauthorized resume attempts.
- Privacy/safety: Perform authorization checks before token lookup or resume processing. For unauthorized requests, do not disclose session content and do not confirm whether a session exists unless policy explicitly allows it.
- TTL: Operators should treat resume tokens as valid for a default of 30 days from session creation; operators may extend on a per-case basis.
- Operator actions (no-code):
  - Add the one-line resume hint to exported transcripts and to subagent prompts where sessions may be left waiting.
  - When manually rehydrating a session, use the session-id directly (case-insensitive lookup), enforce authorization checks before applying the reply, and preserve the token verbatim.
  - Treat resume requests as audit events: record who requested/when/session-id/result and retain logs per your retention policy. Do not log full reply/session content by default.
  - If token is expired, require transcript-based/manual rehydration instead of direct resume.
- Error messaging guidance (for UIs/operators):
  - Unauthorized/unauthenticated: "You are not authorized to resume this session. Contact the session owner or an admin."
  - Not found (authenticated/authorized requests only): "No resumable session found for ses_<id>. Check the id or use the transcript file to manually rehydrate."
  - Expired: "Resume token for ses_<id> has expired. Use transcript-based rehydration or contact support."

This is a policy-level mitigation that reduces routing ambiguity and provides a human-parsable resume form. It does not require code changes; apply it by updating agent prompts, transcript exports, and operator procedures.
