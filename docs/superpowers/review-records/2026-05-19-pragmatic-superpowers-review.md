Title: pragmatic-superpowers — original code-review
Date: 2026-05-19

1) Summary & PR readiness

Assessment: Needs changes (not blocked).
Rationale: The branch is small and mostly coherent, but there are two material gaps: a broken README reference and an easily bypassed PR-body validation check that weakens the intended policy enforcement.

2) BASE_SHA and HEAD_SHA

I computed SHAs with git commands:

- `git rev-parse origin/main`
  - BASE_SHA: 90e9a12ab4a0c26fe54772f68e1cd5a1ce961307
- `git rev-parse work/pragmatic-superpowers`
  - HEAD_SHA: 4da5c79043423f9ebba3c4d2dc50cbce4e686a94

Note: the exact ref `pragmatic-superpowers` did not exist locally; the matching branch present was `work/pragmatic-superpowers` (verified via `git branch --all --verbose --no-abbrev`).

3) Files changed summary

Compared with: `git diff origin/main...work/pragmatic-superpowers`

Changed files (5 total):

1. A .config/opencode/.github/PULL_REQUEST_TEMPLATE.md
2. A .config/opencode/.github/workflows/pragmatic-check.yml
3. A .config/opencode/.github/workflows/pragmatic-pr-comment.yml
4. M .config/opencode/AGENTS.md
5. A .config/opencode/README.md

Diff stats:

- `git diff --shortstat ...` → 5 files changed, 139 insertions(+), 0 deletions
- `git log --oneline origin/main..work/pragmatic-superpowers` → 1 commit

4) Strengths

- Clear consolidation of pragmatic-programmer + superpowers policy in `AGENTS.md`.
- PR template checklist is practical and reviewer-oriented.
- Added automation intent (PR-body checks + reminder comment) aligns with process enforcement goals.
- Scope is surgical: only policy/docs/workflow config files touched.

5) Issues, grouped by severity

Critical (must-fix before merge)
- None found.

Important (should fix before proceeding)

1. Broken path in docs
   - Location: `.config/opencode/README.md:10`
   - Issue: README points to `.github/PULL_REQUEST_TEMPLATE.md`, but the template added in this branch is at `.config/opencode/.github/PULL_REQUEST_TEMPLATE.md`.
   - Why it matters: New contributors/reviewers will follow a non-existent path.
   - Suggested patch (minimal):
     - Update the path in README to `.config/opencode/.github/PULL_REQUEST_TEMPLATE.md`, or explicitly state that `.config/opencode/.github/*` is a source template and must be copied to root `.github/` only with maintainer approval.

2. PR-body “gate” is too weak (checks labels, not completed values)
   - Location: `.config/opencode/.github/workflows/pragmatic-check.yml:17-19`
   - Issue: Current regex checks only presence of strings like `Score (0-10):`, `I wrote failing test(s) first`, `Design approved and committed`; untouched template text will still pass.
   - Why it matters: Undermines the “Pragmatic Diagnostic Gate” and TDD evidence requirements.
   - Suggested patch (minimal):
     - Validate filled content, e.g.:
       - score line contains an actual number `0..10`
       - failing-test command is not placeholder
       - design path not empty / not `N/A` when applicable
     - Fail with specific actionable error messages per missing/invalid field.

Minor (suggestions / low priority)

1. Branch naming mismatch with requested ref
   - Context: Requested branch name `pragmatic-superpowers` does not exist; reviewed `work/pragmatic-superpowers`.
   - Suggestion: Standardize naming or document `work/*` convention to reduce reviewer/CI confusion.

2. Potential expectation mismatch about workflow activation
   - Context: Files are under `.config/opencode/.github/workflows/` (non-active for GitHub Actions by default).
   - Suggestion: Add a short note in README clarifying these are templates and how/when to install into repo-root `.github/workflows/` with explicit maintainer approval (per AGENTS policy).

6) Tests and linters run

I searched for common test/lint configs (`package.json`, `pytest.ini`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`) and ran discovered commands where applicable.

Commands run and outputs

- `npm run` in `/home/vscode/dotfiles/.config/opencode`
  - Output: (no scripts listed)
  - Exit code: 0

- `npm test` in `/home/vscode/dotfiles/.config/opencode`
  - Output excerpt:
    - `npm ERR! Missing script: "test"`
  - Exit code: 1

- `npm run lint` in `/home/vscode/dotfiles/.config/opencode`
  - Output excerpt:
    - `npm ERR! Missing script: "lint"`
  - Exit code: 1

- `npm run` in `/home/vscode/dotfiles/.opencode`
  - Output: (no scripts listed)
  - Exit code: 0

- `npm test` in `/home/vscode/dotfiles/.opencode`
  - Output excerpt:
    - `npm ERR! Missing script: "test"`
  - Exit code: 1

- `npm run lint` in `/home/vscode/dotfiles/.opencode`
  - Output excerpt:
    - `npm ERR! Missing script: "lint"`
  - Exit code: 1

Conclusion: no runnable project test/lint scripts are currently defined in detected package manifests.
Additional tests needed: If these workflow files are intended to be active later, add at least one validation step (e.g., actionlint in CI where workflows are active) and/or scripted checks for template completeness logic.

7) Suggested next steps + effort

1. Fix README template path mismatch.
   - Effort: small

2. Strengthen `pragmatic-check.yml` validation to enforce non-placeholder values.
   - Effort: medium

3. Add explicit README note on activation/install path for `.config/opencode/.github/workflows/*`.
   - Effort: small

8) Pragmatic-programmer quick diagnostic score

Score: 7/10

Remediation tasks (max 3):

1. Tighten PR validation from “field exists” to “field completed with valid value.”
2. Correct or clarify documentation paths for PR template/workflow installation.
3. Add one lightweight verification mechanism for workflow/template quality (in active CI context or pre-merge script).

9) CI / docs / release notes to accompany PR

- CI: If these checks are intended to run on GitHub, plan explicit installation into root `.github/workflows/` with maintainer approval (per AGENTS.md).
- Docs: Update README to avoid path ambiguity and mention inactive-template status under `.config/opencode/.github/`.
- Release notes: Not needed for end-user product release; add a short internal changelog/worklog note describing policy/process governance updates.

10) Author checklist before merge

- [ ] Fix `.config/opencode/README.md` PR template path or document template behavior.
- [ ] Update `pragmatic-check.yml` to validate completed values (not just labels).
- [ ] Clarify workflow/template activation behavior in docs.
- [ ] Confirm branch naming/ref used in review and PR metadata is consistent.
- [ ] Re-run any available verification commands after edits and attach outputs.

The code-reviewer subagent has completed the scoped work. Returning control to the Maestro for orchestration and next-step delegation.
