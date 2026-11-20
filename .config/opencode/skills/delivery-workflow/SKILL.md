---
name: delivery-workflow
description: Apply local phase approvals, behavioral TDD and review rules to a delivery task.
---

## What tests mean

TDD does not mean unit testing: tests must describe specific behavior and functionality meaningful to the human partner, at the level that best drives the current goal. Prioritize tests of individual software subcomponents only when they are generally useful or particularly important to the architecture. Avoid tests coupled to low-level implementation details that make behavior-preserving refactoring require extensive test rewrites.

Use tests as exploratory devices to pin down interfaces, functionality, architecture and design with the human partner before writing the implementation. When considering new interfaces or architectures, prioritize discussion with the human partner around those tests unless the human says otherwise.

## Testing scope

Changes to executable behavior, including scripts, plugins, permissions and runtime configuration, need verification of their meaningful outcomes and applicable TDD. Prefer behavioral tests and parsed configuration checks over assertions about source spelling.

Documentation and policy prose normally need semantic review and relevant structural validation, not new tests or a manufactured red/green cycle. Check meaning, consistency, references and retained/changed/removed obligations. Keep lightweight checks for machine-consumed metadata, configuration and required files; validate links and executable examples when relevant. These checks do not establish that an agent follows a policy.

Do not freeze policy sentences, prose headings, Markdown table rows or formatting with exact-text assertions, snapshots or keyword checks. Do not retain recurring acceptance tests for historical plans, review records or completed documentation migrations. Use the preservation inventory as a review aid, not another executable specification. Use targeted behavioral evaluations only when evidence about actual agent behavior is needed.

Read-only repository checks belong in the `static` suite and can run on host or in the pod. Tests that exercise a runtime keep their required environment and guards. This distinction does not authorize bypassing guards or moving runtime operations into the static suite.

## Design and planning

Brainstorm before planning where useful; plan before implementation. Authors write and commit specs and plans and present the path and commit for user approval unless explicitly waived below. An approved spec, plan or acceptance document that defines the work is sufficient implementation authority. Describe goals, constraints, risks and behavioral acceptance tests. Include mandatory pause points as `User Check-in` in plans and specs only.

For changes to executable behavior, tests are primary deliverables of plans and define behavior, interfaces and scope for discussion with the user. For documentation and policy prose, define review criteria and relevant structural validation instead. Plans and specs must stay high-level and must not prescribe detailed implementation steps unless the user explicitly requests them, even when `writing-plans` says otherwise.

The human and agent may explicitly agree to waive pre-implementation approval checkpoints, including written or committed planning artifacts. This agreement does not waive planning, workspace safety, applicable TDD and refactoring, or verification. The testing scope above determines applicability; prose-only work does not require inventing tests. The agreement may cover pre-implementation `User Check-in` markers; other check-ins remain mandatory.

## Role and skill assignments

Load the listed skills when performing their assigned responsibilities, alongside the shared skill triggers. These assignments preserve the general-agent exception and scoped human Maestro overrides. A skill does not authorize taking over another role.

| Role | Superpowers skills | Responsibility |
| --- | --- | --- |
| Maestro | `subagent-driven-development`, `dispatching-parallel-agents`, `using-git-worktrees`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review` | Top-level orchestration, worktrees, review routing and branch completion; relay feedback to the author. |
| senior-implementer | `subagent-driven-development`, `dispatching-parallel-agents`, `using-git-worktrees`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review`, `systematic-debugging`, `test-driven-development` | Code execution and model selection; own junior workflows, worktrees, reviews and branch completion until handback. |
| junior-implementer | `test-driven-development`, `receiving-code-review`, `systematic-debugging` (only for assigned debugging) | Implement the assigned slice under the senior; do not delegate further. |
| policy-implementer | `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`, `receiving-code-review`, `test-driven-development` | Own policy/document plan execution, applicable TDD, reviews and scoped branch completion in one session. |
| brainstormer | `brainstorming`, `receiving-code-review` | Design with the user, author specifications and respond to their reviews. |
| planner | `writing-plans`, `writing-skills`, `test-driven-development`, `receiving-code-review` | Author plans and skills; ensure plans support TDD and verification against the spec. |
| docs-writer | `receiving-code-review` | Author documentation and respond to reviews. |
| code-reviewer, docs-reviewer-gpt, docs-reviewer-claude | `requesting-code-review`, `test-driven-development` | Carry out the dispatched review; understand TDD and report noncompliance, without implementing the reviewed work. |

Maestro, senior-implementer and junior-implementer must not use `executing-plans`; policy-implementer uses it for policy and document plans. All roles use `using-superpowers` and `verification-before-completion` as required by the shared triggers. General follows the skills for the work the human requests. Maestro communicates relevant skill usage to the user and subagents.

### Technical writing and review outputs

Apply `asd-ste100` according to the shared triggers and the responsibility being performed:

- Docs-writer and policy-implementer use it for documentation, instructions and policy.
- Brainstormer and planner use it when drafting specifications, plans and acceptance criteria. Preserve open questions, alternatives and unresolved decisions.
- Code-reviewer, docs-reviewer-gpt and docs-reviewer-claude use it for their findings, summaries and verdicts. Authors use it for responses to review.
- Maestro, code implementers and general use it for those same writing and review responsibilities when applicable. Routine coding, routing and brief conversation do not require loading it solely for style.

The skill provides flexible writing guidance and a small vocabulary reference. It does not replace role ownership or the existing skill precedence. Review outputs must retain evidence, locations, severity, confidence, verification limits and approval status. Clearer wording must not strengthen an uncertain finding, weaken a requirement, or turn a suggestion into a blocker. Report style preferences separately from defects; style alone does not block approval unless an applicable requirement makes it an acceptance criterion.

## Implementation

Apply the TDD and refactor cycle below to executable behavior. For prose-only changes, use the semantic review and structural validation described under Testing scope.

Repository policy and `pragmatic-programmer` govern test-level selection, tracer-bullet scope and design trade-offs. `karpathy-guidelines` supports simplicity, ambiguity handling and surgical changes within that policy. `obra/superpowers` governs tests-first execution discipline. `clean-code` governs refactor quality and may override conflicting Superpowers cleanup techniques or code-quality heuristics; `pragmatic-programmer` wins over `clean-code`. `clean-code` must not override user instructions, repository policy, approved artifacts, the chosen test level or test protection of behavior.

Offer the user review of interface-defining tests before implementation. Use a failing integration/contract test for cross-layer slices and a focused unit test for isolated logic. Prefer real interactions and justify unavoidable mocks in the test header. Keep prototypes isolated in a worktree or `prototype/*` branch and remove or convert them to tests and design before merge.

Follow red → verify red → green → verify green → refactor → verify green. At the refactor checkpoint record the cleanup or why none was needed. Pause for material plan divergence, gaps exposed by tests, unclear irreversible choices and every unwaived `User Check-in`. Update the design or plan for changed scope and obtain any applicable approval before dependent work.

For every TDD slice, perform a standalone refactor checkpoint after reaching green, even when no changes seem necessary. Review the changed slice and nearby connected code for naming, duplication, boundaries, readability and small behavior-preserving cleanups. Record follow-up cleanup items and rerun the relevant tests after refactoring. Pause for human approval before a refactor changes behavior or makes a hard-to-reverse architectural change outside the approved slice.

## Review and completion

Offer the user first review and manual testing. Wait until the user is content before dispatching automated review, unless the user has instructed otherwise. Facilitate direct user-author discussion when needed or requested. Route committed work to the appropriate reviewer and feedback to the original author. The author commits revisions and may explain disagreements to the reviewer. Continue until the reviewer approves or the review exceeds ten iterations; the iteration limit is not approval. Keep feedback conversational; create a review record only when requested or required by the plan/spec. The reviewer owns it unless explicitly reassigned. GitHub review history suffices for PR review.

Before marking a feature done, run the pragmatic-programmer diagnostic and clean-code review and report their results in the PR, review summary or handoff. For a pragmatic-programmer score below 8, list 1–3 remediation tasks. For material clean-code issues, list 1–3 cleanup/remediation tasks or explicit reasons for deferral. The OpenCode PR template is optional; use relevant sections or N/A and honor the user's preferred format while retaining the evidence. Record policy deviations with one-line justification and explicit human approval in the PR.

Wait for user approval before dependent work or the next phase unless the user already authorized it or explicitly agreed to waive that pre-implementation checkpoint. Maestro owns GitHub and top-level branch completion. Rebase onto main/master before local merge unless directed otherwise.
