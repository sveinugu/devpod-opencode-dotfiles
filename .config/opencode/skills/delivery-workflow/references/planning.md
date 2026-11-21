# Design and planning

Brainstorm before planning where useful. Plan before implementation.

Unless explicitly waived below, authors must write and commit specs and plans, then present the path and commit for user approval. An approved spec, plan or acceptance document that defines the work is sufficient implementation authority.

Describe goals, constraints, risks and behavioral acceptance tests. Include mandatory pause points as `User Check-in` in plans and specs only.

For changes to executable behavior, tests are primary plan deliverables. They define behavior, interfaces and scope for discussion with the user. For documentation and policy prose, define review criteria and relevant structural validation instead.

Keep plans and specs high-level. Do not prescribe detailed implementation steps unless the user explicitly requests them, even when `writing-plans` says otherwise.

## Checkpoint waivers

The human and agent may explicitly agree to waive pre-implementation approval checkpoints, including written or committed planning artifacts. This agreement does not waive planning, workspace safety, applicable TDD and refactoring, or verification.

The testing scope in [delivery-workflow](../SKILL.md#testing-scope) determines applicability. Prose-only work does not require inventing tests. The agreement may cover pre-implementation `User Check-in` markers. Other check-ins remain mandatory.

When drafting specifications, plans and acceptance criteria, preserve open questions, alternatives and unresolved decisions.
