Title: pragmatic-superpowers — review record
Date: 2026-05-19

Summary
-------
Recorded code-review and context for the pragmatic-superpowers branch trial. This document captures the reviewer findings, SHAs, files changed, and recommended fixes so this cycle can be re-run and audited later.

Review metadata
---------------
- BASE_SHA (origin/main): 90e9a12ab4a0c26fe54772f68e1cd5a1ce961307
- HEAD_SHA (reviewed branch tip at review time): 4da5c79043423f9ebba3c4d2dc50cbce4e686a94
- Current local tip after implementer edits: a53fccf9c678bbc4a928f732f9c14d293c3b25ad

Files changed (summary)
-----------------------
5 files changed, 139 insertions(+), 0 deletions

Changed files:
- A .config/opencode/.github/PULL_REQUEST_TEMPLATE.md
- A .config/opencode/.github/workflows/pragmatic-check.yml
- A .config/opencode/.github/workflows/pragmatic-pr-comment.yml
- M .config/opencode/AGENTS.md
- A .config/opencode/README.md

Reviewer strengths
------------------
- Consolidated pragmatic-programmer + superpowers policy in AGENTS.md
- Practical PR template and reviewer checklist
- Automation intent to enforce process
- Surgical scope: only doc/workflow files changed

Issues (grouped)
----------------
Important:
1) Broken README reference
   - README points to `.github/PULL_REQUEST_TEMPLATE.md`, but the template lives at `.config/opencode/.github/PULL_REQUEST_TEMPLATE.md`.
   - Fix: update README to reference `.config/opencode/.github/PULL_REQUEST_TEMPLATE.md` or explain templates must be copied to root `.github/` with maintainer approval.

2) PR-body gate too weak
   - `pragmatic-check.yml` only checks for labels; it does not validate filled values.
   - Fix: require `Score (0-10):` to be numeric 0-10; require `I wrote failing test(s) first:` to be `yes` or `no`; add actionable failure messages.

Minor:
- Branch naming mismatch: requested `pragmatic-superpowers` vs implemented `work/pragmatic-superpowers`.
- Workflow activation expectation: files under `.config/opencode/.github/` are not active for GitHub Actions until copied to `.github/`; clarify this in README.

Pragmatic-programmer quick diagnostic
-------------------------------------
Score: 7/10

Reviewer recommended fixes
-------------------------
1) Update `.config/opencode/README.md` to reference the real template path or add clarification about template lifecycle.
2) Strengthen `.config/opencode/.github/workflows/pragmatic-check.yml` to validate filled values and provide clear failure messages.
3) Add a note in README clarifying that workflows under `.config/opencode/.github/` are source templates and must be installed into `.github/` with maintainer approval.

Notes for implementers
----------------------
- The implementer made two commits (README path fix and workflow validation) and later added an activation note; attempts to push and create PR failed due to missing GitHub credentials in the agent environment.
- The preferred long-term approach is a GitHub App with a helper script using `@octokit/auth-app` to generate installation tokens for the agent at runtime.

Recorded-by
-----------
Maestro / senior-implementer session (2026-05-19). See agent worklog for command outputs and errors regarding push/PR creation (auth failures).
