# dre/dwt Navigation + Completion Behavior Design

Date: 2026-06-20  
Status: Proposed (approved direction; implementation pending)

## Problem

Current `dre`/`dwt` behavior has several UX and contract gaps:

1. `dre <repo>` resolves to `repos/<repo>` (repo hub root), not the child repo default-branch checkout.
2. `dre` completion can clear typed prefixes unexpectedly (for example `dre om<TAB>` resetting to `dre `).
3. No-match completion feedback is weak and can remove user context instead of preserving typed input.
4. Refinement after selection (typing more chars then `TAB`) can insert separators/spaces and break same-token refinement.
5. Backspace with list shown can hide list without deleting token characters.
6. `dwt` completion treats slash-containing worktree names hierarchically (`spec/` first) instead of offering full worktree names directly.

Additionally, when child repo metadata (`state/repos/<repo>/etc/repo.env`) is missing/invalid, there is no dedicated user-facing repair command. Existing hints must therefore be accurate and minimally disruptive.

## Goals

- Make `dre <repo>` resolve to managed child default checkout (`DYN_REPO_DEFAULT_DIR`) and fail clearly when metadata is invalid.
- Improve `dre`/`dwt` completion ergonomics:
  - preserve typed prefixes,
  - expand by longest unambiguous prefix,
  - support menu selection,
  - support same-token refinement and backspace editing.
- Make `dwt` completion list full slash-containing worktree names directly.
- Provide actionable repair guidance for missing child metadata without recloning or touching unrelated repo content.
- Keep scope small and safe for this slice.

## Non-goals

- No new public command in this slice (for example no `bin/repair-repo-metadata` yet).
- No broad global completion-system redesign in `.zshrc` / Oh My Zsh defaults.
- No unrelated navigation behavior changes (`dhub`, top-level bootstrap rules, alias policies).

## Chosen Design

### 1) Child metadata writer helper (internal)

Add a focused internal helper:

- `scripts/lib/write-managed-repo-env.sh`

Purpose:

- (a) centralize `repo.env` creation/update currently embedded in `bin/clone-repo`, and
- (b) provide a stable internal repair action to reference in error hints.

Contract (high-level):

- Inputs: repo name; optional default-branch override.
- Validates managed child repo exists and has `.bare`.
- Resolves default branch (explicit override or detectable branch); validates branch existence in managed bare repo.
- Computes default dir `repos/<repo>/<default-branch>`.
- Writes `state/repos/<repo>/etc/repo.env` with:
  - `export DYN_REPO_DEFAULT_BRANCH=...`
  - `export DYN_REPO_DEFAULT_DIR=...`
- Ensures related canonical metadata directories exist.

`bin/clone-repo` will call this helper instead of duplicating inline file-writing logic.

### 2) `dre` runtime target contract

Update `bin/dre` so successful resolution returns the managed child default checkout directory from `repo.env` (`DYN_REPO_DEFAULT_DIR`), not `repos/<repo>`.

Failure mode for missing/invalid metadata:

- Keep refusal semantics (non-zero exit).
- Add a repair hint using existing internal tooling, e.g. invoking the new helper script for the repo.

This preserves explicit behavior and prevents dropping users into a context where `dwt` is unusable.

### 3) `dwt` candidate generation for slash-containing names

Replace path-hierarchy style completion for worktrees with explicit candidate generation from managed worktree names.

Result:

- `dwt` can complete `spec/limit-peek-elements-design` as one candidate.
- Avoids `_path_files` directory-first behavior that surfaces only `spec/` initially.

Default-branch alias completion remains present.

### 4) Completion UX behavior (`dre` and `dwt`)

Command-scoped completion behavior should target:

- Longest unambiguous prefix insertion on `TAB`.
- Menu display for ambiguous matches.
- No-match keeps typed token intact and provides failure feedback.
- Refinement after selection stays in the same token (no extra separator insertion).
- Backspace deletes token characters (not only hiding the list).

Implementation should prefer command-local completion tuning (function behavior and command-scoped completion styles) over global shell-option churn.

## Acceptance Criteria

1. `dre <repo>` changes directory to `DYN_REPO_DEFAULT_DIR` when metadata is valid.
2. If child metadata is missing/invalid, `dre` fails with clear reason and repair hint referencing the internal metadata writer helper.
3. `dwt` completion candidates include full slash-containing worktree names.
4. `dre`/`dwt` completion keeps typed prefixes on no-match and supports continued refinement without inserted-space token splitting.
5. Backspace behavior in completion context edits the current token as expected.

## Testing Strategy

### Automated

- Extend `tests/devspace/test_workspace_navigation_commands.sh`:
  - verify `dre` resolves to default checkout directory from metadata,
  - verify metadata-missing/invalid failure message includes repair hint.
- Extend `tests/install/test_workspace_navigation_shell.sh`:
  - verify `dwt` completion surfaces slash-containing worktree names directly,
  - verify completion helper behavior preserves intended candidate insertion semantics.

Where interactive Zsh behavior is hard to fully assert in CI transcripts, keep scripted checks focused on candidate generation and command contracts.

### Manual verification

- Validate expected interactive UX in a real shell session for:
  - prefix expansion,
  - no-match behavior,
  - refinement by typing additional chars + `TAB`,
  - backspace while completion list is visible.

User Check-in: confirm interactive completion feel is acceptable on your environment before final completion signoff.

## Risks / Trade-offs

- Zsh completion UX is influenced by broader environment/plugins; exact menu persistence while editing may vary.
- This slice prioritizes predictable token behavior and re-openable menus over deep global completion rewiring.
- A dedicated public repair command is deferred to follow-up.

## Follow-up (out of current scope)

- Add a user-facing `bin/repair-repo-metadata <repo>` command that wraps the internal metadata writer helper for safer discoverability.
