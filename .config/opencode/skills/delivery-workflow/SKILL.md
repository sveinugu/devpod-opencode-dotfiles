---
name: delivery-workflow
description: Apply local phase approvals, behavioral TDD and review rules to a delivery task.
---

## Design and planning

Brainstorm before planning where useful; plan before implementation. Authors write and commit specs and plans and present the path and commit for user approval unless explicitly waived below. An approved spec, plan or acceptance document that defines the work is sufficient implementation authority. Describe goals, constraints, risks and behavioral acceptance tests. Include mandatory pause points as `User Check-in` in plans and specs only. Keep implementation detail proportional to the user's request.

The human and agent may explicitly agree to waive pre-implementation approval checkpoints, including written or committed planning artifacts. This agreement does not waive planning, workspace safety, TDD, refactoring, or verification. It may cover pre-implementation `User Check-in` markers; other check-ins remain mandatory.

## Implementation

Offer the user review of interface-defining tests before implementation. Use a failing integration/contract test for cross-layer slices and a focused unit test for isolated logic. Prefer real interactions and justify unavoidable mocks in the test header. Keep prototypes isolated in a worktree or `prototype/*` branch and remove or convert them to tests and design before merge.

Follow red → verify red → green → verify green → refactor → verify green. At the refactor checkpoint record the cleanup or why none was needed. Pause for material plan divergence, gaps exposed by tests, unclear irreversible choices and every unwaived `User Check-in`. Update the design or plan for changed scope and obtain any applicable approval before dependent work.

## Review and completion

Offer the user first review and manual testing. Route committed work to the appropriate reviewer and feedback to the original author. The author commits revisions. Continue until approved or the review exceeds ten iterations. Keep feedback conversational; create a review record only when requested or required by the plan/spec. The reviewer owns it. GitHub review history suffices for PR review.

For completed features, report the pragmatic-programmer diagnostic and clean-code review in the PR, review summary or handoff. For a pragmatic-programmer score below 8, list 1–3 remediation tasks. Record material clean-code issues with fixes or reasons for deferral. The OpenCode PR template is optional. Record policy deviations with one-line justification and human approval.

Wait for user approval before dependent work or the next phase unless the user already authorized it or explicitly agreed to waive that pre-implementation checkpoint. Maestro owns GitHub and top-level branch completion. Rebase onto main/master before local merge unless directed otherwise.
