# Review and completion

## Review ownership and order

Offer the user first review and manual testing. Unless the user has instructed otherwise, wait until the user is content before dispatching automated review. Facilitate direct user-author discussion when needed or requested.

Route committed work to the appropriate reviewer. Return feedback to the original author. The author commits revisions and may explain disagreements to the reviewer.

Continue until the reviewer approves or the review exceeds ten iterations. The iteration limit is not approval.

Keep feedback conversational. Create a review record only when requested or required by the plan/spec. The reviewer owns it unless explicitly reassigned. GitHub review history suffices for PR review.

## Completion evidence

Before marking a feature done, run the pragmatic-programmer diagnostic and clean-code review. Report their results in the PR, review summary or handoff.

- For a pragmatic-programmer score below 8, list 1–3 remediation tasks.
- For material clean-code issues, list 1–3 cleanup/remediation tasks or explicit reasons for deferral.

The OpenCode PR template is optional. Use relevant sections or N/A. Honor the user's preferred format while retaining the evidence. Record policy deviations in the PR with a one-line justification and explicit human approval.

## Next steps and branch completion

Before dependent work or the next phase, wait for user approval unless the user already authorized it or explicitly waived that pre-implementation checkpoint.

Maestro owns GitHub and top-level branch completion. Rebase onto main/master before local merge unless directed otherwise.
