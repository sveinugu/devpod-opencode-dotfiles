# Implementation and refactoring

Apply these procedures to executable behavior. Prose-only work uses the semantic review and structural validation in [delivery-workflow](../SKILL.md#testing-scope).

## Tests and prototypes

Before implementation, offer the user review of interface-defining tests. Use a failing integration/contract test for cross-layer slices and a focused unit test for isolated logic. Prefer real interactions. Justify unavoidable mocks in the test header.

Keep prototypes isolated in a worktree or `prototype/*` branch. Before merge, remove them or convert them to tests and design.

## TDD and refactoring

Follow red → verify red → green → verify green → refactor → verify green.

For every TDD slice, perform a standalone refactor checkpoint after reaching green, even when no changes seem necessary. Review the changed slice and nearby connected code for naming, duplication, boundaries, readability and small behavior-preserving cleanups.

At the checkpoint, record the cleanup or why none was needed. Record follow-up cleanup items and rerun the relevant tests after refactoring. Before a refactor changes behavior or makes a hard-to-reverse architectural change outside the approved slice, pause for human approval.

Pause for material plan divergence, gaps exposed by tests, unclear irreversible choices and every unwaived `User Check-in`. When scope changes, update the design or plan. Obtain any applicable approval before dependent work.
