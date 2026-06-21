# Overview

> What changed for implementers: top-level bootstrap is `main`-only, `dhub` is shell-level via `.config/shell/workspace-navigation.zsh` + `scripts/lib/resolve-install-target.sh`, and no `dd` alias is shipped in v1.

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

## Agent start here

Use this section to choose a reading route. `AGENTS.md` remains the canonical policy source; the template and review-record paths below are supporting context only.

- **Maestro / delegator:** start with `# Subagent delegation`, then read `# Delegation & Sessions (canonical)`, `## Managed worktree lane safety (v1)`, and `## Simple Maestro override (human-only, two-message confirmation)`.
- **Implementer:** start with `## The Superpowered Pragmatic Programmers:`, then read `### On Test-driven development`, `### Refactor phase policy`, `## Planning and implementation policy`, and `## Managed worktree lane safety (v1)`.
- **Reviewer:** start with `## The Superpowered Pragmatic Programmers:`, then read `### PR reporting template policy`, `## Named-responsibility ownership`, and `## Subagent interaction rules`.
- **Newcomer / first-time agent contributor:** read `# Overview`, `## Intent and operational setup`, and `# Subagent delegation` first.

### Quick vocabulary bridge

- `Delegation Packet` — the closed-schema Maestro → subagent dispatch block.
- `Artifact path` — the binding requirements source named in a packet when one exists.
- `Session` / `Resume` — the exact `task_id` and `$<task_id> <reply>` routing token for continuing a subagent conversation.
- `Lane-qualified work item` — scoped work tied to a specific managed worktree lane.
- `Maestro override` — the human-only two-message authorization that temporarily lets Maestro perform subagent-owned work directly.

Supporting references:

- Packet construction example: `docs/superpowers/templates/subagent-handoff-templates.md`
- Historical packet review context: `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`

# How the agent should relate to the supported skills

The configuration imports the following skills, in prioritized order:

- wondelai/pragmatic-programmer
- oc-plugin-karpathy-guidelines
- wondelai/clean-code
- obra/superpowers

Please report major disagreements between skills to the human partner (user)!

## Auto-loaded skills

Agents must always load the "pragmatic-programmer" skill!
Agents must always load the "karpathy-guidelines" skill!
Agents must load the "clean-code" skill before starting any coding task, including implementation, refactoring, code review, and post-implementation review.

## The Superpowered Pragmatic Programmers:

All agents described in this repo are members of The Superpowered Pragmatic Programmers team.
This section is the canonical implementation-policy section for how pragmatic-programmer and Superpowers interact in this repository.
Following this interaction policy is the priority of all members of The Superpowered Pragmatic Programmers.

### On Test-driven development

- Important: TDD tests are NOT unit tests! It is important that the tests are implemented at the level where they describe and provide specific behavior/functionality to the human partner.
- Tests of particular software subcomponents should be prioritized only if they are generally useful or particularly important for the architecture.
- If tests are implemented as unit tests at too low a level, then code refactor becomes more difficult and TDD breaks down (too much time refactoring tests vs coding new features).
- More than in obra/superpowers, the Pragmatic Programmer highlights the importance of tests as exploratory devices to pin down the interfaces, functionality, architecture and design of code before it is written, in discussions with the human partner. Interaction with the human partner around tests should be prioritized if new interfaces or architectures are considered, unless the human says otherwise.

### Concrete policies

- Agents must apply TDD at the test level that best drives the current goal. For a tracer bullet or cross-layer change, write a failing integration/contract test first. For isolated business logic, write a focused unit test first.
- All prototypes must live in a git worktree or a branch named 'prototype/*'. Prototypes must be deleted or converted to tests+design before merging. No prototype code may be merged to main.
- Prefer real interactions for contract/integration checks. Mock only when unavoidable and document rationale in the test file header.
- Agents SHOULD complete brainstorming before planning.
- Agents MUST complete planning before implementation.
- Design specifications and plan documents MUST be made available to the user (docs path + commit) and approved before moving on to the next phase.
- Human interaction in the brainstorming and planning processes are crucial. Make sure the intent of the user is followed before moving on to details.
- Tests are primary deliverables of plans and a focus of discussions with the owners. They define the scope of the work and the interfaces towards users and other components. Avoid adding too much implementation details into plans, even though the
  `writing-plans` skill says otherwise.
- After plan approval, agents must follow TDD (tests-first) on the agreed slice. If tests reveal gaps, open a focused design and/or plan update (depending on severity) and re-approve.
- After a task is implemented, the work should be presented to the human for manual testing, iterative improvements, and approval.
- Tasks that depend sequentially on other tasks must not be started until prior tasks have been approved, unless instructed otherwise by a human.
- Before marking a feature done, run the pragmatic-programmer quick diagnostic and a clean-code checklist/score review. Append both results to the PR, review summary, or handoff note. If the pragmatic-programmer score is < 8, append 1–3 remediation tasks. If the clean-code review finds material issues, append 1–3 cleanup/remediation tasks or explicitly justify why they are deferred.
- Any deviation from these rules requires one-line justification and explicit human approval, recorded in the PR.

### Refactor phase policy

- After reaching green, agents MUST enter a standalone refactor phase for every TDD slice.
- This refactor phase is a mandatory checkpoint even when the agent expects no code changes. The agent may conclude that no refactoring is needed, but the checkpoint itself MUST still happen explicitly.
- The refactor phase should review the changed slice and nearby connected code for maintainability improvements that preserve behavior, including naming, duplication, boundaries, readability, and small local cleanups that reduce future change cost.
- Agents must load the "clean-code" skill before starting any coding task, including implementation, refactoring, code review, and post-implementation review.
- Authority ordering for TDD and refactoring: user instructions and repository policy always win. Repository policy plus `pragmatic-programmer` govern test-level selection, tracer-bullet scope, overall design trade-offs, and conflict resolution for refactoring choices. `karpathy-guidelines` remains a cross-cutting aid for simplicity, ambiguity handling, and surgical changes, but does not override higher-priority policy or `pragmatic-programmer`. `obra/superpowers` governs tests-first execution discipline (`red → verify red → green → verify green → refactor → verify green`). `clean-code` is loaded for all coding tasks and governs refactor-quality guidance most directly during the standalone refactor phase. It may override conflicting `superpowers` guidance about cleanup technique or code-quality heuristics. If `clean-code` conflicts with `pragmatic-programmer`, `pragmatic-programmer` wins.
- `clean-code` MUST NOT override user instructions, repository policy, approved artifacts, the chosen test level, or the requirement to keep behavior protected by tests.
- The refactor phase should end with an explicit clean-code review outcome: either the applied refactors, or an explicit conclusion that no refactor was needed, plus any follow-up cleanup items discovered during the checkpoint.
- After refactoring, agents MUST rerun the relevant tests and keep behavior green. If the refactor would require behavior changes or a hard-to-reverse architectural shift outside the approved slice, pause and ask the human partner before proceeding.

### How to reconcile in practice (short recipe for agents)

1. Brainstorm → write lightweight design and define tracer bullet (verification: design committed).
2. Plan → select tech stack, break down into verifiable tasks, define acceptance tests, describe the task with enough detail to be implemented by a specialist subagent.
3. Choose test level for the tracer bullet (integration/contract preferred for E2E; unit for focused logic).
4. TDD at the chosen level → write a failing test, watch it fail, implement minimal code, and verify green.
5. Coding work → keep `clean-code` loaded while implementing and reviewing code quality.
6. Refactor phase → perform the mandatory refactor checkpoint on the changed slice and connected code, refactor if warranted or explicitly conclude that no refactor is needed, then verify green again.
7. Post-implementation → run the pragmatic-programmer diagnostic and the clean-code checklist/score review; record results and remediation tasks in the PR, review summary, or handoff note if needed.
8. If a prototype was used, ensure it lives in a worktree and is removed or converted before merge.

Why this works

- Keeps TDD's core benefit (tests first, watch fail) while letting pragmatic judgment choose the right test level.
- Preserves tracer-bullet velocity and prevents many brittle unit tests that lock implementation.
- Ensures design concerns (DRY, orthogonality, reversibility) are explicitly checked before and after implementation.

### PR reporting template policy

- The policy reporting template lives at `.config/opencode/PULL_REQUEST_TEMPLATE.md`.
- This template is a reporting aid, not a second source of truth. `AGENTS.md` remains canonical.
- Agents may copy or adapt the template structure when preparing PR descriptions, review summaries, or handoff notes that need to show compliance with the policy above.
- Agents should fill in only the sections relevant to the scoped work and may explicitly mark non-applicable items as
  `N/A`.
- When relevant, PR descriptions, review summaries, or handoff notes should include the pragmatic-programmer score, the clean-code checklist/score outcome, and any resulting remediation or cleanup follow-up items.
- If the human partner wants a different PR or handoff format, follow the human's requested format while preserving the same underlying policy evidence.

# Subagent delegation

- `/workspaces/dotfiles` is a manager hub, not a normal checkout.
- Agents MUST treat `/workspaces/dotfiles/main` or another explicit worktree path as the editable repository root.
- Child repos under `repos/` follow the same pattern; use each repo's detected default-branch checkout at `repos/<repo>/<default-branch>` and worktrees under `repos/<repo>/work/<branch>`.
- Refused — hub-root CWD detected. Provide explicit worktree path.
- Agents should prefer `bin/clone-repo` and `bin/new-worktree` over manual `git clone` / `git worktree add`, and read `state/hub/etc/install.env` when install-branch context is relevant.

## Core principle of delegating responsibility:

- If a responsibility or skill in repo docs or agent specs is assigned to a named subagent, the parent agent MUST spawn that subagent to perform the work.

## Delegation in practice

- (OpenCode-specific) For delegation to actually occur, the Task tool must be actively used, it is not enough to declare intent.
- Delegation does not count unless the Task tool (or native subagent launch mechanism) was actually invoked successfully. Merely announcing, describing, previewing, or roleplaying a handoff is not delegation.
- Routing question: before spawning, the Maestro MAY ask exactly one routing-only clarifying question (hard limit: 1 question, max 18 words) to choose the correct subagent or scope. This single question must not perform or begin the delegated work (no discovery beyond routing). After the Maestro spawns a subagent, that subagent follows its own interaction rules — e.g. iterative clarification or discovery exchanges — to refine scope and design.
- Handoff wording (required): when spawning a named subagent the Maestro MUST use exactly, and only after successful launch:
  `Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.`
- Planner ownership sentence: planner-owned artifacts (plans/specs) must be authored/committed by planner unless an explicit Maestro override is active.
- Design specifications and plan documents must be written to file and committed by the sub-agents before handed back to the Maestro.
- Review-record policy: review feedback is conversational by default. A persistent review-record document is created only when explicitly requested or required by a plan/spec. When such a document is created, it is owned by the reviewing subagent unless explicitly reassigned. For PR-based review, GitHub review history is the default persisted review record.
- Delegation Packet definition: `Delegation Packet` is the canonical Maestro-to-subagent routing wrapper for new scoped delegation. It preserves exact references and verbatim user intent; it is not an interpretation step.
- Router-owned session metadata (required whenever a delegating/router agent dispatches, resumes, or reports handback for a subagent session, replace
  `<task_id>` with the exact returned task_id when available):
    ```text
    Session: <task_id>
    Resume: $<task_id> <your reply>
    Owner: <subagent>
    Authority: only the owning subagent may perform <subagent> responsibilities unless a human-approved Maestro override is active
    ```
- When a Task or native subagent launch returns `task_id`, agents MUST use that exact returned `task_id` verbatim as the canonical session identifier.
- Delegating agents MUST validate surfaced `Session:` and `Resume:` values against that exact returned `task_id` before sending or repeating them.
- If no `task_id` is available, agents MUST preserve the exact existing session identifier when known and MUST NOT invent, rewrite, or normalize one.
- Session visibility rule: when a delegating agent spawns or resumes a subagent session, it MUST print that session's metadata in the chat. Too many visible session ids are preferred over too few.
- Metadata timing rule: after successful launch or resume, the delegating agent MUST surface the validated `Session:` / `Resume:` / `Owner:` / `Authority:` block immediately, before any other orchestration text beyond the required handoff wording.
- Launch-failure rule: if Task/native launch fails, or no validated `task_id` is available, the agent MUST say so briefly and MUST NOT claim delegation occurred, MUST NOT print a fake handoff, and MUST NOT impersonate the subagent.
- Maestro handoff checklist (required before sending any subagent handoff):
    1. Name the target subagent explicitly.
    2. Include the exact returned `task_id` when available.
    3. Include the exact resume command in `$<task_id> <reply>` form.
    4. State that replies with `$<task_id>` route to the owning subagent, not Maestro triage.
    5. State that only the owning subagent may perform its named responsibilities unless the human activates the two-step Maestro override.
    6. When resuming an existing subagent session, explicitly say it is a resume of the existing session, not a new session.
- Per-subagent override: a subagent file may define a more specific first-message/handoff wording; that override applies only to that subagent and must be explicit in the subagent file.

## Delegation Packet

> **Deprecated:** superseded by “Delegation & Sessions (canonical)”. Do not use for new delegations.

- Canonical source: `# Delegation & Sessions (canonical)` below.
- For packet schema, allowed fields, forbidden fields, Annex rules, and stop-rules, use only the canonical chapter.



# Delegation & Sessions (canonical)

> This chapter is the single source of truth for delegation packet and session policy.
> All other surfaces (agent prompts, templates) are pointers to this chapter.
> Binding design spec: `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`
> Preview/dispatch identity follow-on spec: `docs/superpowers/specs/2026-06-13-maestro-preview-dispatch-identity-design.md`

## Delegation Packet (closed schema; Maestro → subagent only)

The Delegation Packet is a closed-schema block used only for **Maestro → subagent scoped delegation**.
It is not for resume messages, subagent questions, or subagent completion messages.

### Allowed packet fields (only these)

- `Artifact path:` or `Artifact paths:` with exact path strings when applicable
- `Worktree path:` (explicit absolute path to editable checkout)
- `Verbatim user request:` as a `>`-quoted block (see verbatim quoting contract below)
- `Warnings:` only when non-empty; brief factual flags only; non-authoritative
- router-owned metadata: `Session:`, `Resume:`, `Owner:`, `Authority:`

### Forbidden packet content (includes, but not limited to)

- `Instructions:` / `Notes:` / `Reminders:` / `Summary:` / `Deliverables:` / `Non-deliverables:` / `Provenance:` / `Active slice:` / any other extra field
- interpretative summaries
- inferred deliverables or scope
- implementation steering beyond the approved artifact
- "helpful corrections" to user wording
- `Preview:` is meta-commentary outside the packet, not a packet field

### Packet/Annex boundary

The packet block ends after the last allowed field. After a blank line, the optional Annex may begin.
No text is permitted between the end of the packet and the Annex header (besides a blank line).
Outside the packet block and optional Annex, the ONLY permitted text in the dispatch message is the required handoff wording line.
No other free-form context is permitted outside the packet/Annex.

## Verbatim quoting contract

Under `Verbatim user request:`, every non-empty line MUST be a Markdown blockquote line starting with `>`.

### Multi-message quoting

- If 2+ user messages are included, `> ---` MUST appear between messages.
- If exactly 1 message is included, `> ---` MUST NOT appear.
- Messages appear in chronological order (oldest first, newest last).
- No other non-user-authored boundary markers are permitted inside `Verbatim user request:`.

### Content rules

- Quoted text MUST be **verbatim user-authored text**.
- Raw fragments and shorthand are allowed and encouraged.
- Do not paraphrase. Do not rewrite into full sentences.
- Prefer quoting the **entire** relevant user message.

## Maestro-side prevention for new scoped delegation

Maestro MUST NOT call Task / launch a subagent for new scoped delegation until the `Delegation Packet` has passed the Maestro pre-dispatch checks defined below.

If the packet fails any pre-dispatch check, Maestro MUST refuse dispatch, MUST NOT emit the required handoff wording, MUST NOT fabricate session metadata, and MUST instead surface the failure and seek correction.

Recommended refusal style:

`Delegation Packet refused — <brief reason>. Dispatch stopped before launch.`

If Maestro had to choose, compress, or explain, preview is mandatory.
Router-owned metadata (`Session:`, `Resume:`, `Owner:`, `Authority:`) is exempt from the preview requirement because those fields are launch-generated and populated only after Task returns.

### Maestro pre-dispatch checks

1. **Allowed fields only**
   - Packet contains only allowed packet fields.
   - No `Instructions:`, `Notes:`, `Summary:`, `Deliverables:`, `Preview:`, or other extra fields.
2. **Verbatim quoting contract satisfied**
   - `Verbatim user request:` contains one or more `>`-quoted user lines.
   - Multi-message quoting uses `> ---` only when required.
   - Quotes are verbatim user-authored text, not paraphrase.
3. **Warnings discipline**
   - `Warnings:` is omitted when empty.
   - If present, entries are brief factual flags only.
   - `Warnings:` must not contain imperatives, inferred deliverables, or implementation steering.
4. **Artifact-path discipline**
   - Any artifact path is exact.
   - If the selected artifact is newly introduced or not clearly established, the packet is non-trivial and must go through preview.
5. **Packet/Annex boundary discipline**
   - No free-form text outside the required handoff wording line, packet block, and optional Annex block.
   - Annex, if present, uses only approved headings.

### Trivial vs non-trivial packet gate

- A packet is trivial only if one full user message is quoted verbatim, `Warnings:` is omitted, no Annex is present, the artifact path is already clear, and Maestro did not need to choose, compress, or explain.
- Trivial packets may dispatch without user preview after passing the pre-dispatch checks.
- A packet is non-trivial if `Warnings:` is non-empty, any Annex is present, `Verbatim user request:` includes multiple user messages, Maestro quotes only part of a user message instead of the full message, Maestro selects or introduces an `Artifact path:` that was not already clearly established, or Maestro resolves ambiguity from context rather than routing from one obvious user message.
- For non-trivial packets, Maestro must show the exact outgoing dispatch content that exists before launch and require explicit user approval before dispatch.
- This preview excludes router-owned metadata (`Session:`, `Resume:`, `Owner:`, `Authority:`) because those fields do not exist until after launch.
- If a single full user message is sufficient, Maestro should quote that whole message.
- Partial-message quoting automatically makes the packet non-trivial and therefore preview-gated.

### Preview wrapper vs dispatch structure

- For non-trivial packets, the preview message is not itself a dispatch message.
- The preview wrapper may contain only: a brief notice that preview is required, the exact previewed dispatch content, and an explicit response prompt offering `ok / edit / cancel`.
- No other explanatory or operational prose is allowed in the preview wrapper.

### Preview response tokens

- The valid control responses are `ok`, `edit`, and `cancel`.
- Match them mechanically: trim leading and trailing whitespace.
- Then compare case-insensitively to exactly one token: `ok`, `edit`, or `cancel`.
- `ok.` and `ok thanks` do not count as approval.
- Messages that do not match one of those exact control responses must not be treated as approval or cancellation tokens.
- `ok` is valid only as the direct response to the preview prompt that explicitly offered `ok / edit / cancel`.
- `ok` means only “dispatch this exact previewed content,” plus allowed launch-generated router metadata when needed at launch time.
- When the user replies `edit`, do not launch; invalidate the pending approval; rebuild, revalidate, and re-preview the candidate payload; and require a fresh `ok` before launch.
- When the user replies `cancel`, do not launch; terminate the current preview/dispatch attempt; discard the pending payload and approval state for that attempt; and require a completely new preview cycle before any later dispatch of that work.

### No post-approval payload drift

- After preview approval, Maestro must not regenerate the outgoing dispatch from memory, from a summary, or from an internal restatement.
- For non-trivial delegation, the outgoing dispatch must be textually identical to the approved previewed content, except for allowed launch-generated router metadata when those values were not yet available during preview.
- If any content changes after preview — including packet lines, Annex lines, or any surrounding text — Maestro must revalidate the updated payload, re-preview the exact updated dispatch content, and obtain a fresh `ok` before launch.
- If the outgoing dispatch differs from the approved preview, Maestro must refuse launch before Task/subagent launch.
- Recommended refusal style for this mismatch:
  `Delegation Packet refused — outgoing dispatch differs from approved preview. Dispatch stopped before launch.`
- If continuing, Maestro must show the corrected exact payload and require a fresh `ok` before launch, without silently correcting the difference.

### No free-form prose outside the allowed structure

- No free-form prose outside the allowed structure.
- For dispatch messages, outside the required handoff wording, packet block, and optional Annex block, no extra prose is allowed.
- This explicitly forbids post-packet additions such as `Please implement...`, `Tasks:`, and `Deliverables:`.
- Preview messages follow the distinct preview-wrapper rule above; dispatch messages must follow the stricter handoff + packet + optional Annex structure.

### Warnings discipline (tightened)

- `Warnings:` remains limited to short factual flags only.
- `Warnings:` must not contain implied action, task extraction, implementation steering, disguised instructions, or expanded interpretations of a user `ok`.

### Deferred runtime enforcement

This policy should be written so a later runtime validator can implement it directly, but no runtime/plugin work is part of this slice.

### Subagent stop-rule (all subagents)

If a subagent receives a Delegation Packet where `Verbatim user request:` contains **zero** `>`-quoted lines
(or is `N/A`), the subagent MUST:

1. Stop before doing substantive work.
2. Ask the delegator (chain of command) to provide the exact user text as `>` quotes.
3. If the delegator cannot/will not provide it, ask the user directly.

## Annex (non-authoritative; not part of Delegation Packet)

The Annex is a safe outlet for helpful context that does NOT modify the Delegation Packet schema
and does NOT turn helpful prose into requirements.

### Allowed Annex headings (fixed)

```text
Annex (non-authoritative; not part of Delegation Packet)

Pointers:

Highlight (derived from verbatim; must match after stripping markup):

Open questions:

Hypotheses:

Evidence (verbatim, source: <label>):
```

### Highlight rules

- Each highlighted `>` line MUST be a **full-line copy** of a line from `Verbatim user request:`.
- Highlight may add ONLY:
  - emphasis markers: `**bold**` only (`_italic_` is forbidden due to variable naming collisions)
  - inline code markers: `` `like this` ``
- Highlight MUST NOT:
  - delete words, add words, use ellipses (`...`), or re-order text
- Mechanically: the highlighted line MUST match an original verbatim line after stripping allowed markup.

If Highlight is present but does not match verbatim lines after stripping markup, the subagent MUST stop and request correction.

### Forbidden Annex content

- Imperatives and instruction lists
- Deliverables / non-deliverables / acceptance criteria
- New requirements language
- Interpretative summaries of the user's intent
- Anything that substitutes for the approved artifact as the requirements source

### Annex subrules

- `Open questions:` entries must be questions.
- Each `Hypotheses:` bullet MUST include the literal phrase `confirm before relying`.
- Evidence blocks MUST contain raw output only inside a fenced block and MUST include a `source:` label.

## Artifact semantics + handshake

### Default semantics

When `Artifact path:` is present, the referenced artifact is treated as a **binding requirements source by default**.
When `Artifact paths:` is present, all listed paths are binding requirements sources, and the handshake applies across the full listed set rather than only the first path.

### Handshake (all subagents — required)

If `Artifact path:` is present, the subagent MUST:

1. Open/read the artifact.
2. Form a short statement of what the artifact appears to specify (1–2 sentences).
3. Compare it to the verbatim user request.
4. If the artifact seems unrelated or materially conflicting with verbatim intent/global policy:
   - stop before substantive work
   - ask the delegator to confirm/correct the artifact selection (chain of command)
   - if unresolved, ask the user

The subagent MUST include its 1–2 sentence artifact-summary statement in its **first response after receiving the delegation**.

### Authority ordering (on conflict)

If there is a material conflict between global policy, verbatim user request, and the artifact,
the subagent MUST stop and ask for clarification rather than resolving silently.

## Required handoff wording

When spawning a named subagent, the Maestro MUST use exactly, and only after successful launch:

```text
Switching you to the <subagent> subagent now — please interact directly with it; I will remain available for orchestration.
```

## Session metadata visibility timing

After successful launch or resume of a subagent session, the delegating agent MUST surface the
validated `Session:` / `Resume:` / `Owner:` / `Authority:` block **immediately**,
before any other orchestration text beyond the required handoff wording.

## Resume token routing semantics

- Purpose: provide the canonical routing policy for resuming subagent sessions after process restarts.
- User-facing resume syntax: a user may resume a waiting subagent by sending a single-line message that begins with:

  `$<task_id> <their reply>`

  Example: `$ses_1beff32adffex42WsKM8Hks5PF Here is my answer`

- Token requirements: `task_id` is opaque. It must not encode user identity, permissions, or internal routing metadata.
- Matching: task_id matching should be treated as case-insensitive when manual lookup is required.
- Escape: if a user needs a literal leading dollar, instruct them to prefix with `$$` (for example, `"$$hello" => "$hello"` no resume).
- Routing guarantee: when a valid `$<task_id>` token is present, the reply MUST be routed directly and verbatim to that session's owning subagent rather than being re-triaged as a fresh task for the dispatching agent. The subagent-facing payload begins immediately after the token and extends unchanged to the end of the user message.
- Never override or reroute a user-provided `$<task_id>` token. Always route to that exact session regardless of other active sessions.
- Preserve resume tokens verbatim. Do not rewrite, normalize, shorten, or absorb them.

### Session-resume and "switch" semantics

1. Definitions:
    - "session" (aka process instance): a single subagent session identified by the exact Task-returned `task_id` when available. Current task_ids may look like `ses_...`. A subagent process may host multiple sessions, but UI/resume tokens map to sessions.
    - "work item": the scope a subagent session is bound to: use the approved artifact path when one exists; otherwise use a short ad-hoc descriptor (for example `explore-shell-startup-lag`).
    - Intended session model: use one session per `(subagent type, lane-qualified work item)` for scoped work, and one session per `(subagent type, work item)` otherwise. Do not reuse a session across subagent types or across different lane-qualified work items. An implementer session stays with its current plan/lane-qualified work item until that work item is complete; a new plan requires a new implementer session.
    - Session metadata: subagent start/resume messages SHOULD also include `Work item: <artifact path|short descriptor>` when available.
    - "switch" (user intent): by default, interpret as "resume an existing session" when a matching recent session exists; otherwise offer to start a new session.
2. Default resume behavior:
    - Resume an existing session only when both the subagent type and work item match the user's intended scope.
    - If the subagent type matches but the work item changes, spawn a new session instead of reusing the old one.
    - When the user's message does not include a resume token but appears to target a subagent type and there exists one or more resumable sessions of that subagent type owned by the user:
        - The orchestrator (for example Maestro) SHOULD attempt to detect the best candidate recent session with the same work item and prompt the user with a short choice:
          `I found an active <subagent> session for <work item> from <time>. Resume it? (yes / start new)`
        - Do not silently spawn a new session. Do not spawn a new session automatically without either: (a) an explicit "start new" command from the user, or (b) explicit confirmation to spawn.
    - Follow-up messages like "continue", "switch", or similar should default to the most recent relevant session if the user's immediately preceding interaction clearly targeted that session or subagent.
    - Before spawning a new subagent, check whether the last relevant session is still active, waiting for input, or the most likely intended target.
    - If more than one session is a plausible match, ask rather than guessing.
3. Explicit resume precedence:
    - If the user supplies a resume token in the message (line begins with `$<task_id>`), route the message to that session immediately and verbatim (no spawn).
    - If the user uses "switch to <subagent>" and provides a resume token, route to that token.
    - If the user uses "switch" without a token and the orchestrator cannot find any reasonable candidate session, ask: `No recent <subagent> session found. Start a new one?` and wait for confirmation.
4. Error / tool-failure behavior:
    - On Task/tool schema errors (for example, missing required params) or other tool-level failures, do not auto-retry or spawn a new subagent.
    - Instead, surface the error to the user with a concise explanation and suggest corrective actions. Example: `Task invocation failed: missing parameter 'subagent_type'. Please confirm and retry. (no auto-retry)`
    - The orchestrating agent must only retry or spawn after explicit user confirmation.

## Recovery alignment

- Session and resume metadata are routing concerns and are owned by Maestro or another delegating/router agent.
- Maestro should surface session metadata when dispatching a subagent, resuming an existing subagent session, and immediately after control is handed back from a subagent.
- Failed session-resume and recovery policy must preserve the same authority model as normal delegation.
- Recovery may restore routing context, but must not reinterpret intent.
- If recovery would require substantive interpretation, Maestro should ask the user rather than reconstructing intent from a paraphrase.

## Managed worktree lane safety (v1)

For scoped work, actions are lane-scoped by default.

For scoped authoring work, Maestro must resolve or create the dedicated managed worktree before dispatch.

Hard-stop lane/worktree refusal conditions:

- dispatching scoped authoring work from hub root
- dispatching scoped authoring work from `main` when that lane requires its dedicated worktree
- dispatching two unrelated active lanes into one worktree
- continuing a lane from a worktree bound to a different active lane
- attempting lane-sensitive repo operations without having resolved the target lane first

Available intent signals (ordered; use in this sequence):

1. validated resume/routing context for a lane-qualified work item;
2. delegated artifact anchor(s);
3. verbatim user request when it materially distinguishes sibling lanes;
4. explicit user/delegator lane, branch, or worktree naming in the current turn.

Subagents must independently verify delegated lane/worktree/branch coherence against local repo + registry evidence and all available intent signals before substantive work.

wrong-yet-self-consistent sibling-lane dispatch is not always independently detectable when remaining intent signals are absent or ambiguous.

Intended session model for scoped work: use one session per `(subagent type, lane-qualified work item)`.
Sibling lanes under one parent artifact are different resume targets.
When only the parent artifact matches multiple active lanes, Maestro must ask rather than guess.

## Anti-scatter checklist (sequential; Maestro must follow)

1. **Identify target subagent and confirm this is new scoped delegation.**
2. **Collect exact `Artifact path:` / `Artifact paths:` / `Worktree path:` values if any.**
3. **Collect exact user message text for `Verbatim user request:`.**
4. **Assemble packet using allowed fields only.**
5. **Run Maestro pre-dispatch checks.**
6. **If the packet is non-trivial, preview the exact outgoing dispatch content and obtain explicit user approval.**
7. **Only then call Task / launch the subagent.**
8. **After successful launch, emit required handoff wording and validated session metadata.**

## Planning and implementation policy

- An approved plan, spec, acceptance-test document, or similar approved artifact is enough to start when it already defines the task at the right level. Maestro must not require a separate implementation plan by default.
- For policy, documentation, and similarly bounded process changes, an approved spec may serve directly as the implementation authority when it already defines the work at the correct level.
- Plans and specs should stay high-level. They should define goals, tests / acceptance criteria, constraints, known risks, and `User Check-in` markers.
- Plans and specs should not prescribe detailed implementation steps unless the user explicitly asks for that level of detail.
- Acceptance-test documents should remain behavioral and should not carry `User Check-in` markers.
- Implementers should use pragmatic TDD with direct user feedback. Tests are the primary basis for refining interface shape, feature boundaries, and behavior.
- Implementers may propose solutions that diverge from plan details, but must surface the divergence explicitly before it hardens into costly downstream work.
- Implementers must pause before hard-to-reverse choices, especially around interfaces, test semantics, and architecture boundaries, if ownership is unclear.
- `User Check-in` markers are mandatory pause points.

## Named-responsibility ownership

- If repo docs or agent specs assign a responsibility to a named subagent, that subagent is the sole owner of that responsibility for the active scope.
- Other agents, including Maestro and senior-implementer, MUST NOT perform that responsibility, commit artifacts owned by that responsibility, or answer in a way that implies takeover.
- Exception: the human may activate the existing two-step Maestro override for an exact short scope. Without that override, takeover is forbidden.
- If takeover would otherwise occur, the acting agent must refuse with:
  `Refused — owned by <subagent>; resume or re-dispatch that subagent, or use Maestro override.`

## Subagent interaction rules

First message (recommended, can be overridden in this file for this subagent):

"I’m the <subagent> subagent. I’ll work with you directly; I may ask one or more related questions and return control to the Maestro when the scoped work is complete."

Interaction rules:

- For ordinary clarifying or discovery exchanges, subagents SHOULD ask multiple related questions in the same message when that helps the user answer efficiently.
- Ask at most five questions in one message.
- If only one meaningful question is needed, ask only one; do not invent filler questions just to force a batch.
- If more questions are still pending after the current batch, say so and give a rough estimate of the remaining question count or follow-up rounds.
- Exact-token or other protocol-sensitive prompts may remain isolated when batching would reduce reliability or make the required reply ambiguous.
- Repository policy override: when a loaded skill or subagent prompt prefers one-question-at-a-time discovery, subagents in this repository should follow the batching policy above unless a stricter protocol or routing rule in `AGENTS.md` applies.
- Perform only the responsibilities listed in the subagent file and only for the currently delegated scope.
- Session metadata is router-owned. Ordinary subagents should not be required to emit `Session:` / `Resume:` metadata in start, pause, resume, or completion messages.
- Exception: subagents that themselves delegate work inherit router obligations for the child session they create.
- Ordinary subagent pause / question messages should be direct and minimal.
- When asking the user to choose between options, provide enough background for an informed choice, summarize the main trade-offs, state your recommendation when you have one, and briefly explain why.
- Do not hide your recommendation inside a rhetorical or loaded question.
- Prefer the order: context, options/trade-offs, recommendation, then the actual question or question batch.
- Anti-impersonation rule: delegating/router agents, including Maestro, MUST NOT speak in a subagent's voice, MUST NOT author first-person subagent messages, and MUST NOT fabricate subagent pause/completion/status text. The only exception is exact verbatim routing of a user-provided `$<task_id>` payload, which remains routing rather than subagent authorship.

- No takeover rule: no other agent may perform the owning subagent's named responsibilities, commit on its behalf, or declare its scoped work complete unless the human has activated the two-step Maestro override for that exact scope.
- When done, return control to the <parent agent> with the exact final handoff:

  "The <subagent> subagent has completed the scoped work. Returning control to the <parent agent> for orchestration and next-step delegation."

  Example — Completion:

  ```text
  The planner subagent has completed the scoped work. Returning control to the Maestro for orchestration and next-step delegation.
  ```

## Simple Maestro override (human-only, two-message confirmation):

To authorize the Maestro to perform work normally delegated to subagents the human must send two consecutive messages:

1. maestro-override: <short scope>
2. maestro-override-confirm

The Maestro must verify both messages came from the human, are consecutive, and the scope is an explicit short string (≤120 chars). If verification fails, the Maestro MUST refuse the override.

### Agent behavior (four rules to implement)

- The Maestro only accepts an override when it sees those two consecutive human messages in sequence; it must reject overrides otherwise, refuse wildcard/broad scopes (e.g., "*", "all repos"), and echo back "Override accepted — performing: <scope>" before acting.
- After the first override message, the Maestro must echo back "Override requested, please confirm. Scope: <scope>"
- Scope enforcement: while an override is active the Maestro must perform only actions exactly within the confirmed scope. Any instruction or action that falls outside that scope must be refused with: "Refused — outside override scope: <action>" and the Maestro must not proceed without a new explicit override.
- Exit message: when the confirmed scope is complete the Maestro must explicitly terminate override mode by sending exactly: "Override completed — exiting override mode." and then resume normal delegation behavior (spawn subagents as required).

### Example usage (human enters the override, the agent requests confirmation, the human confirms)

- Human message 1:
  maestro-override: create branch work/github-app-integration and commit the approved plan update
- Maestro:
  Override requested, please confirm. Scope: create branch work/github-app-integration and commit the approved plan update
- Human message 2:
  maestro-override-confirm

## Policy readability and documentation expectations

This section is a readability nudge for policy and documentation maintenance.
Keep policy and documentation cross-references current whenever you edit a referenced file.
Update runbook and spec file paths when refactoring documented surfaces so pointers remain valid.
When policy wording changes, run the relevant doc-contract tests in `tests/docs/` to verify required anchors still hold.
Keep this guidance additive and concise, and rely on canonical sections above for full policy detail.

## Subagent resume token policy

> **Deprecated:** superseded by “Delegation & Sessions (canonical)” → Resume token routing semantics.

- Canonical source: `# Delegation & Sessions (canonical)` → `## Resume token routing semantics`.

## Session metadata ownership

> **Deprecated:** superseded by “Delegation & Sessions (canonical)” → Session metadata visibility timing.

- Canonical source: `# Delegation & Sessions (canonical)` → `## Session metadata visibility timing` and `## Recovery alignment`.

## Failed session-resume recovery alignment

> **Deprecated:** superseded by “Delegation & Sessions (canonical)” → Recovery alignment.

- Canonical source: `# Delegation & Sessions (canonical)` → `## Recovery alignment`.

# Troubleshooting

## Debugging Subagent Delegation Issues (for Maestro and other Subagent-Orchestrating Agents):

If delegation appears to stall (e.g., you see session handoff text but no subagent reply, artifact, or progress):

1. Check: Was the Task tool (or native subagent launch mechanism) actually invoked?
    - Merely surfacing session metadata, stating "delegating", or describing "handoff" is NOT sufficient—you must launch the actual subagent process with the correct Task tool invocation and details.
2. Symptom: If you see only orchestration/announcement text, but nothing from a subagent:
    - The subagent launch call (e.g., via functions.task) was likely omitted or failed.
3. Corrective action:
    - Directly call the Task tool with the relevant subagent_type, a short task description, and all context needed for the subagent to perform its task autonomously.
    - Ensure you surface the new session's validated `Session:`/`Resume:`/`Owner:`/`Authority:` metadata immediately.
4. Never assume that "delegation language" triggers a subagent. Always verify real delegation via active tool invocation / session ID.
