# Overview

The current configuration allows subagent-driven-development according to the
`obra/superpowers` plugin, with (currently) a less powerful
`maestro` agent coordinating (mostly) more powerful subagents. This makes effective use of premium-plan request quotas by letting the top-level agent orchestrate more capable specialists.

## Intent and operational setup

This repository configures a highly secured agent harness for developers to orchestrate implementation, review, planning, documentation, and related tasks inside an isolated development environment.

Typical setup:

- A developer laptop running a local Kubernetes environment plus DevPods.
- Example: a MacBook Pro M3 running colima + k3d + DevPods, with remote PyCharm sessions attached directly to workspace files.
- Workspace files live inside the DevPods/Kubernetes environment, not on the host filesystem directly.

Important operational assumptions for agents:

- Agents operate inside the secured workspace environment.
- Agents do not have a direct write path back to the host machine.
- To affect host state, agents may only do so indirectly, typically by pushing to GitHub and asking the human partner to pull or apply the change on the host.
- In this setup, the human partner is effectively both developer and runtime operator, so instructions in this file should be agent-actionable and user-facing rather than written for a separate operations team.

## How the agent should relate to the supported skills

The configuration imports the following skills, in prioritized order:

- wondelai/pragmatic-programmer
- oc-plugin-karpathy-guidelines
- obra/superpowers

Please report major disagreements between skills to the human partner (user)!

## Auto-loaded skills

Unless the task is explicitly not related to programming, the agent must always load the "pragmatic-programmer" skill!
Agents must always load the "karpathy-guidelines" skill!

## On Test-driven development

Important: TDD tests are NOT unit tests! It is important that the tests are implemented at the level where they describe and provide specific behavior/functionality to the human partner.
Tests of particular software subcomponents should be prioritized only if they are generally useful or particularly important for the architecture.
If tests are implemented as unit tests at too low a level, then code refactor becomes more difficult and TDD breaks down (too much time refactoring tests vs coding new features).
Also, more than in obra/superpowers, the Pragmatic Programmer highlights the importance of tests as exploratory devices to pin down the interfaces, functionality, architecture and design of code before it is written, in discussions with the human partner. Interaction with the human partner around tests should be prioritized if new interfaces or architectures are considered, unless the human says otherwise.

### Concrete policies

- Agents must apply TDD at the test level that best drives the current goal. For a tracer bullet or cross-layer change, write a failing integration/contract test first. For isolated business logic, write a focused unit test first.
- All prototypes must live in a git worktree or a branch named 'prototype/*'. Prototypes must be deleted or converted to tests+design before merging. No prototype code may be merged to main.
- Prefer real interactions for contract/integration checks. Mock only when unavoidable and document rationale in the test file header.
- Agents must complete brainstorming design approval (docs path + commit) before implementation. After approval, agents must follow TDD (tests-first) on the agreed slice. If tests force a design change, open a focused design update and re-approve.
- Before marking a feature done, run pragmatic-programmer quick diagnostic; append score and 1–3 remediation tasks to PR if score < 8.
- Any deviation from these rules requires one-line justification and explicit human approval, recorded in the PR.

### How to reconcile in practice (short recipe for agents)

1. Brainstorm → write lightweight design and define tracer bullet (verification: design committed).
2. Choose test level for tracer bullet (integration/contract preferred for E2E; unit for focused logic).
3. TDD at chosen level: write failing test, watch fail, implement minimal code, refactor.
4. Post-implementation: run pragmatic-programmer diagnostic, score, and add remediation if needed.
5. If prototype used, ensure it lives in worktree and is removed/converted before merge.

Why this works

- Keeps TDD's core benefit (tests first, watch fail) while letting pragmatic judgment choose the right test level.
- Preserves tracer-bullet velocity and prevents many brittle unit tests that lock implementation.
- Ensures design concerns (DRY, orthogonality, reversibility) are explicitly checked before and after implementation.

## Subagent delegation

### Core principle of delegating responsibility:

- If a responsibility or skill in repo docs or agent specs is assigned to a named subagent, the parent agent MUST spawn that subagent to perform the work.

### Delegation in practice:

- Routing question: before spawning, the Maestro MAY ask exactly one routing-only clarifying question (hard limit: 1 question, max 18 words) to choose the correct subagent or scope. This single question must not perform or begin the delegated work (no discovery beyond routing). After the Maestro spawns a subagent, that subagent follows its own interaction rules — e.g. an iterative, one‑question‑per‑message dialog — to refine scope and design.
- Handoff wording (required): when spawning a named subagent the Maestro SHOULD use exactly:
  `Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.`
- Planner ownership sentence: planner-owned artifacts (plans/specs) must be authored/committed by planner unless an explicit Maestro override is active.
- Review-record policy: review feedback is conversational by default. A persistent review-record document is created only when explicitly requested or required by a plan/spec. When such a document is created, it is owned by the reviewing subagent unless explicitly reassigned. For PR-based review, GitHub review history is the default persisted review record.
- Execution Handoff definition: "Execution Handoff" means the Maestro step that turns an approved plan into delegated implementation work.
- Mandatory handoff metadata (required in EVERY subagent start, explicit resume, handoff, pause, and completion message):
    - `Session: ses_<session-id>`
    - `Resume: $ses_<session-id> <your reply>`
    - `Owner: <subagent>`
    - `Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active`
- Session visibility rule: when a delegating agent spawns or resumes a subagent session, it MUST print that session's metadata in the chat. Too many visible session ids are preferred over too few.
- Maestro handoff checklist (required before sending any subagent handoff):
    1. Name the target subagent explicitly.
    2. Include the exact session id in `ses_<id>` form.
    3. Include the exact resume command in `$ses_<id> <reply>` form.
    4. State that replies with `$ses_<id>` route to the owning subagent, not Maestro triage.
    5. State that only the owning subagent may perform its named responsibilities unless the human activates the two-step Maestro override.
    6. When resuming an existing subagent session, explicitly say it is a resume of the existing session, not a new session.
- Per-subagent override: a subagent file may define a more specific first-message/handoff wording; that override applies only to that subagent and must be explicit in the subagent file.

## Named-responsibility ownership

- If repo docs or agent specs assign a responsibility to a named subagent, that subagent is the sole owner of that responsibility for the active scope.
- Other agents, including Maestro and senior-implementer, MUST NOT perform that responsibility, commit artifacts owned by that responsibility, or answer in a way that implies takeover.
- Exception: the human may activate the existing two-step Maestro override for an exact short scope. Without that override, takeover is forbidden.
- If takeover would otherwise occur, the acting agent must refuse with:
  `Refused — owned by <subagent>; resume or re-dispatch that subagent, or use Maestro override.`

## Subagent interaction rules:

First message (recommended, can be overridden in this file for this subagent):

"I’m the <subagent> subagent. I’ll work with you directly; I will ask one question at a time and return control to the Maestro when the scoped work is complete."

Interaction rules:

- Ask one clarifying question per message (repeat as needed — there is no single-question-per-session cap).
- Perform only the responsibilities listed in the subagent file and only for the currently delegated scope.
- The owning subagent MUST surface its session id on start, on explicit resume, on any pause/wait-for-user message, and on completion or handoff.
- The owning subagent MUST include the exact resume syntax on every pause/wait-for-user message:

  `To resume this session after a restart, reply in chat using: $ses_<session-id> <your reply here>`

- No takeover rule: no other agent may perform the owning subagent's named responsibilities, commit on its behalf, or declare its scoped work complete unless the human has activated the two-step Maestro override for that exact scope.
- When done, return control to the <parent agent> with the exact final handoff:

  "The <subagent> subagent has completed the scoped work. Returning control to the <parent agent> for orchestration and next-step delegation."

## Simple Maestro override (human-only, two-message confirmation):

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

- Purpose: Provide a simple agent-facing policy for resuming subagent sessions after process restarts.
- User-facing resume syntax: A user may resume a waiting subagent by sending a single-line message that begins with:

  `$ses_<session-id> <their reply>`

  Example: `$ses_1beff32adffex42WsKM8Hks5PF Here is my answer`

- Token requirements:
  `session-id` should be opaque and high-entropy. It must not encode user identity, permissions, or internal routing metadata.
- Matching: session-id matching should be treated as case-insensitive when manual lookup is required.
- Escape: If a user needs a literal leading dollar, instruct them to prefix with `$$` (e.g.,
  `"$$hello" => "$hello"` no resume).
- Routing guarantee: when a valid
  `$ses_<session-id>` token is present, the reply MUST be routed DIRECTLY AND VERBATIM to that session's owning subagent rather than being re-triaged as a fresh task for the dispatching agent (e.g. Maestro).
- Preserve resume tokens verbatim. Do not rewrite, normalize, shorten, or absorb them.

### Session-resume and "switch" semantics

#### Motivation

- Users commonly use "switch" or "continue" intending to resume an existing conversation/session/process. This policy clarifies that intent and avoids duplicate sessions.

#### Policy

1. Definitions:
    - "session" (aka process instance): a single subagent session identified by a resume token (
      `ses_<id>`). A subagent process may host multiple sessions, but UI/resume tokens map to sessions.
    - "switch" (user intent): by default, interpret as "resume an existing session" when a matching recent session exists; otherwise offer to start a new session.
2. Default resume behavior
    - When the user's message does not include a resume token but appears to target a subagent type and there exists one or more resumable sessions of that subagent type owned by the user:
        - The orchestrator (e.g. Maestro) SHOULD attempt to detect the best candidate recent session and prompt the user with a short choice:
          `I found an active <subagent> session from <time>. Resume it? (yes / start new)`
        - Do NOT spawn a new session automatically without either: (a) an explicit "start new" command from the user, or (b) explicit confirmation to spawn.
    - Follow-up messages like "continue", "switch", or similar should default to the most recent relevant session if the user's immediately preceding interaction clearly targeted that session or subagent.
    - Before spawning a new subagent, check whether the last relevant session is still active, waiting for input, or the most likely intended target.
    - If more than one session is a plausible match, ask rather than guessing.
3. Explicit resume precedence
    - If the user supplies a resume token in the message (line begins with
      `$ses_<id>`), route the message to that session immediately and verbatim (no spawn).
    - If the user uses "switch to <subagent>" and provides a resume token, route to that token.
    - If the user uses "switch" without a token and the orchestrator cannot find any reasonable candidate session, ask: "No recent <subagent> session found. Start a new one?" and wait for confirmation.
4. Error / tool-failure behavior
    - On Task/tool schema errors (e.g., missing required params) or other tool-level failures, DO NOT auto-retry or spawn a new subagent.
    - Instead, surface the error to the user with a concise explanation and suggest corrective actions. Example:
      "Task invocation failed: missing parameter 'subagent_type'. Please confirm and retry. (no auto-retry)"
    - The orchestrating agent must only retry or spawn after explicit user confirmation.
