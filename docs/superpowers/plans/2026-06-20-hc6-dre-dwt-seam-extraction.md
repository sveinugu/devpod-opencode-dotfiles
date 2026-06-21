# HC-6 dre/dwt Seam Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the exact duplicated helper seams from `bin/dre` and `bin/dwt` while preserving every caller contract, exit code, error string, repair hint, and suggestion output already locked by the navigation tests.

**Architecture:** Keep `bin/dre` and `bin/dwt` as the owners of command-specific argument handling, managed-repo resolution, and inline metadata loading/validation. Extract only the exact duplicated helper families into `scripts/lib/did-you-mean.sh` and `scripts/lib/managed-repo-metadata.sh`, sourced by both commands without widening the abstraction boundary or introducing any new public CLI surface. Drive the refactor with tests first: one helper-layout contract, one focused helper-runtime contract, and the two existing navigation behavior suites.

**Tech Stack:** Bash, sourced shell helpers under `scripts/lib/`, existing behavior tests under `tests/devspace/` and `tests/install/`, no shell-completion or documentation changes in this slice.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved hotspot slice: `HC-6 — optional dre/dwt seam extraction`
- Requested plan destination: `docs/superpowers/plans/2026-06-20-hc6-dre-dwt-seam-extraction.md`
- User-approved extraction boundary:
  - extract `did_you_mean()` into `scripts/lib/did-you-mean.sh`
  - extract `metadata_refusal()`, `metadata_repair_hint()`, and `fail_metadata()` into `scripts/lib/managed-repo-metadata.sh`
  - do **not** extract the metadata loading/validation blocks from `bin/dre` or `bin/dwt`
- Existing implementation surfaces:
  - `bin/dre`
  - `bin/dwt`
- Existing behavior safety rails that must remain green:
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/install/test_workspace_navigation_shell.sh`

## Scope

### In scope

- Extract the exact `did_you_mean()` function body from both commands into `scripts/lib/did-you-mean.sh`.
- Extract the exact `metadata_refusal()`, `metadata_repair_hint()`, and `fail_metadata()` function bodies from both commands into `scripts/lib/managed-repo-metadata.sh`.
- Source both helpers from `bin/dre` and `bin/dwt` near the top of each script.
- Preserve exactly:
  - `usage: dre <repo>` and `usage: dwt [name]`
  - the `refused: repo "%s" not found` and `refused: worktree "%s" not found` caller behavior
  - the `did you mean: %s` output format
  - the `refused: managed child default branch metadata is missing or invalid for "%s"` refusal text
  - the `to repair, run:` line and the exact runnable helper command shape
  - caller exit codes and argument-count behavior
  - caller-owned `workspace_root` and `script_dir` variable usage
- Add one structural contract test that locks the helper-file layout and the removal of inline duplication from the callers.
- Add one focused helper-runtime contract test that locks suggestion output plus metadata refusal/repair output.

### Out of scope

- No extraction of the metadata loading/validation logic that reads `repo.env`, checks `DYN_REPO_DEFAULT_BRANCH`, checks `DYN_REPO_DEFAULT_DIR`, or performs canonicalization with `readlink -f`.
- No changes to `.config/shell/workspace-navigation.zsh`, completion behavior, or any doc/runbook text.
- No changes to `bin/clone-repo`, `scripts/lib/write-managed-repo-env.sh`, or managed-child onboarding behavior.
- No changes to the public CLI contract for `dre` or `dwt`.
- No changes to unrelated navigation commands such as `dhub`.
- No widening of the abstraction beyond the five duplicated helper functions already identified by the user.

## Proposed file map

- Create: `tests/devspace/test_workspace_navigation_helper_layout.sh` — structural contract for helper existence, caller sourcing, and removal of inline duplicate helper definitions.
- Create: `tests/devspace/test_workspace_navigation_helper_contracts.sh` — focused runtime contract for `did_you_mean()` output and metadata refusal/repair output.
- Create: `scripts/lib/did-you-mean.sh` — shared `did_you_mean()` helper only.
- Create: `scripts/lib/managed-repo-metadata.sh` — shared `metadata_refusal()`, `metadata_repair_hint()`, and `fail_metadata()` helpers only.
- Modify: `bin/dre` — source the new helper files and remove the duplicated inline helper definitions.
- Modify: `bin/dwt` — source the new helper files and remove the duplicated inline helper definitions.
- Verify only:
  - `tests/devspace/test_workspace_navigation_helper_layout.sh`
  - `tests/devspace/test_workspace_navigation_helper_contracts.sh`
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/install/test_workspace_navigation_shell.sh`

---

## Task 1: Prove the current navigation slice and add failing `did_you_mean` seam tests

**Files:**
- Create: `tests/devspace/test_workspace_navigation_helper_layout.sh`
- Create: `tests/devspace/test_workspace_navigation_helper_contracts.sh`
- Verify only:
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Prove the current navigation behavior baseline is green before refactoring structure**

Run:

```bash
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/install/test_workspace_navigation_shell.sh
```

Expected: PASS for both commands. If either suite is already red before the seam extraction begins, stop and ask the user whether baseline repair is now in scope.

- [ ] **Step 2: Add a failing helper-layout contract for the shared `did_you_mean` seam**

Create `tests/devspace/test_workspace_navigation_helper_layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_helper_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
dre_script="$repo_root/bin/dre"
dwt_script="$repo_root/bin/dwt"
did_you_mean_helper="$repo_root/scripts/lib/did-you-mean.sh"

[ -f "$dre_script" ] || fail 'bin/dre not found'
[ -f "$dwt_script" ] || fail 'bin/dwt not found'
[ -f "$did_you_mean_helper" ] || fail 'scripts/lib/did-you-mean.sh not found'

grep -F 'source "$script_dir/../scripts/lib/did-you-mean.sh"' "$dre_script" >/dev/null || fail 'dre should source did-you-mean helper'
grep -F 'source "$script_dir/../scripts/lib/did-you-mean.sh"' "$dwt_script" >/dev/null || fail 'dwt should source did-you-mean helper'

if grep -F 'did_you_mean() {' "$dre_script" >/dev/null; then
  fail 'dre should no longer define did_you_mean inline'
fi
if grep -F 'did_you_mean() {' "$dwt_script" >/dev/null; then
  fail 'dwt should no longer define did_you_mean inline'
fi

grep -F 'did_you_mean() {' "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should define did_you_mean'
grep -F 'suggestion="$(python3 - "$needle" "$@" <<'"'"'PY'"'"'' "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should keep the Python difflib suggestion path'
grep -F "printf 'did you mean: %s\\n' \"\$suggestion\" >&2" "$did_you_mean_helper" >/dev/null || fail 'did-you-mean helper should preserve exact suggestion output wording'

printf 'PASS test_workspace_navigation_helper_layout\n'
```

- [ ] **Step 3: Add a failing focused runtime contract for `did_you_mean()` behavior**

Create `tests/devspace/test_workspace_navigation_helper_contracts.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_workspace_navigation_helper_contracts: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
did_you_mean_helper="$repo_root/scripts/lib/did-you-mean.sh"

[ -f "$did_you_mean_helper" ] || fail 'scripts/lib/did-you-mean.sh not found'

suggestion_output="$(bash -c 'set -euo pipefail; source "$1"; did_you_mean alpa alpha beta' _ "$did_you_mean_helper" 2>&1)"
[ "$suggestion_output" = 'did you mean: alpha' ] || fail 'did_you_mean should preserve exact suggestion output for close matches'

no_match_output="$(bash -c 'set -euo pipefail; source "$1"; did_you_mean zzz alpha beta' _ "$did_you_mean_helper" 2>&1)"
[ -z "$no_match_output" ] || fail 'did_you_mean should stay silent when no suggestion exists'

printf 'PASS test_workspace_navigation_helper_contracts\n'
```

- [ ] **Step 4: Verify RED for the new `did_you_mean` seam tests**

Run:

```bash
bash tests/devspace/test_workspace_navigation_helper_layout.sh
bash tests/devspace/test_workspace_navigation_helper_contracts.sh
```

Expected: FAIL because `scripts/lib/did-you-mean.sh` does not exist yet and the callers still define `did_you_mean()` inline.

- [ ] **Step 5: Commit the red `did_you_mean` seam tests**

```bash
git add tests/devspace/test_workspace_navigation_helper_layout.sh \
  tests/devspace/test_workspace_navigation_helper_contracts.sh
git commit -m "test(devspace): lock did-you-mean seam"
```

---

## Task 2: Extract the shared `did_you_mean()` helper and keep navigation behavior green

**Files:**
- Create: `scripts/lib/did-you-mean.sh`
- Modify: `bin/dre`
- Modify: `bin/dwt`
- Test: `tests/devspace/test_workspace_navigation_helper_layout.sh`
- Test: `tests/devspace/test_workspace_navigation_helper_contracts.sh`
- Test: `tests/devspace/test_workspace_navigation_commands.sh`
- Test: `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Create `scripts/lib/did-you-mean.sh` with the exact shared helper body**

Move the current `did_you_mean()` function body into `scripts/lib/did-you-mean.sh` without changing behavior or wording:

- preserve `local needle="$1"`
- preserve `shift`
- preserve `[ "$#" -gt 0 ] || return 0`
- preserve the inline Python `difflib.get_close_matches(..., n=1, cutoff=0.5)` block
- preserve `printf 'did you mean: %s\n' "$suggestion" >&2`

Do not add any new wrapper function or argument parsing around it.

- [ ] **Step 2: Source the helper from both callers and remove the inline duplicate function definitions**

Update both `bin/dre` and `bin/dwt` so they source the new helper near the top:

```bash
source "$script_dir/../scripts/lib/did-you-mean.sh"
```

Then delete the inline `did_you_mean()` definition from both files. Do not change any call sites.

- [ ] **Step 3: Verify GREEN for the extracted suggestion seam**

Run:

```bash
bash tests/devspace/test_workspace_navigation_helper_layout.sh
bash tests/devspace/test_workspace_navigation_helper_contracts.sh
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/install/test_workspace_navigation_shell.sh
```

Expected: PASS for all four commands.

- [ ] **Step 4: Commit the `did_you_mean()` extraction**

```bash
git add scripts/lib/did-you-mean.sh bin/dre bin/dwt
git commit -m "refactor(nav): extract did-you-mean helper"
```

---

## Task 3: Add failing metadata-helper seam tests

**Files:**
- Modify: `tests/devspace/test_workspace_navigation_helper_layout.sh`
- Modify: `tests/devspace/test_workspace_navigation_helper_contracts.sh`

- [ ] **Step 1: Extend the helper-layout contract to require the metadata helper seam**

Update `tests/devspace/test_workspace_navigation_helper_layout.sh` to add these assertions:

- `scripts/lib/managed-repo-metadata.sh` must exist
- both `bin/dre` and `bin/dwt` must contain:

```bash
source "$script_dir/../scripts/lib/managed-repo-metadata.sh"
```

- neither caller may still define any of these functions inline:
  - `metadata_refusal() {`
  - `metadata_repair_hint() {`
  - `fail_metadata() {`
- `scripts/lib/managed-repo-metadata.sh` must define all three functions
- the helper file must preserve these exact output strings:

```text
refused: managed child default branch metadata is missing or invalid for "%s"
to repair, run:
```

- [ ] **Step 2: Extend the helper-runtime contract to lock metadata refusal and repair output**

Update `tests/devspace/test_workspace_navigation_helper_contracts.sh` so it also sources `scripts/lib/managed-repo-metadata.sh` and proves `fail_metadata()` behavior in isolation.

Add a temporary workspace fixture and assert these exact contracts:

1. For a repo root that contains `main/`, this command:

```bash
bash -c 'set -euo pipefail; workspace_root="$2"; script_dir="$3"; source "$1"; fail_metadata beta "$4"' _ \
  "$repo_root/scripts/lib/managed-repo-metadata.sh" \
  "$workspace_root" \
  "$repo_root/bin" \
  "$workspace_root/repos/beta"
```

must exit `1` and print exactly:

```text
refused: managed child default branch metadata is missing or invalid for "beta"
to repair, run:
  HUB_WORKSPACE_ROOT="<workspace_root>" bash <repo_root>/scripts/lib/write-managed-repo-env.sh "beta" "main" "<workspace_root>/repos/beta/main"
```

2. For a repo root that contains `master/` but not `main/`, the same `fail_metadata` path must still exit `1` and must suggest `"master"` in the repair command.

Keep the existing `did_you_mean()` assertions in the same test file.

- [ ] **Step 3: Verify RED for the metadata seam tests**

Run:

```bash
bash tests/devspace/test_workspace_navigation_helper_layout.sh
bash tests/devspace/test_workspace_navigation_helper_contracts.sh
```

Expected: FAIL because `scripts/lib/managed-repo-metadata.sh` does not exist yet and the metadata helper trio is still duplicated inline in both callers.

- [ ] **Step 4: Commit the red metadata seam tests**

```bash
git add tests/devspace/test_workspace_navigation_helper_layout.sh \
  tests/devspace/test_workspace_navigation_helper_contracts.sh
git commit -m "test(devspace): lock metadata helper seam"
```

---

## Task 4: Extract the shared managed-repo metadata helpers and keep the callers inline where approved

**Files:**
- Create: `scripts/lib/managed-repo-metadata.sh`
- Modify: `bin/dre`
- Modify: `bin/dwt`
- Test: `tests/devspace/test_workspace_navigation_helper_layout.sh`
- Test: `tests/devspace/test_workspace_navigation_helper_contracts.sh`
- Test: `tests/devspace/test_workspace_navigation_commands.sh`
- Test: `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Create `scripts/lib/managed-repo-metadata.sh` with the exact shared helper bodies**

Move these function bodies into the new helper file without changing output or control flow:

- `metadata_refusal()`
- `metadata_repair_hint()`
- `fail_metadata()`

Preserve exactly:

- the `helper_path` derivation from `"$script_dir/../scripts/lib"`
- the `main`-then-`master`-then-default-`main` branch suggestion logic
- the two-line repair intro plus exact runnable command shape
- `exit 1` inside `fail_metadata()`

Do not add metadata-file reading, canonicalization, or repo-root resolution logic to this helper.

- [ ] **Step 2: Source the metadata helper from both callers and delete the inline metadata helper trio**

Update both `bin/dre` and `bin/dwt` so they source the new helper near the top:

```bash
source "$script_dir/../scripts/lib/managed-repo-metadata.sh"
```

Then remove the inline `metadata_refusal()`, `metadata_repair_hint()`, and `fail_metadata()` definitions from both files.

Preservation rules for this step:

- Keep the metadata loading/validation blocks inline in each caller.
- Keep all `fail_metadata "$repo" "$target"` and `fail_metadata "$repo_name" "$repo_root"` call sites unchanged.
- Do not alter the surrounding `repo.env` source, `readlink -f`, or `case` validation logic.

- [ ] **Step 3: Verify GREEN on the full HC-6 seam-extraction safety rail suite**

Run:

```bash
bash tests/devspace/test_workspace_navigation_helper_layout.sh
bash tests/devspace/test_workspace_navigation_helper_contracts.sh
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/install/test_workspace_navigation_shell.sh
```

Expected: PASS for all four commands.

- [ ] **Step 4: Commit the metadata helper extraction**

```bash
git add scripts/lib/managed-repo-metadata.sh bin/dre bin/dwt
git commit -m "refactor(nav): extract managed repo metadata helper"
```

- [ ] **Step 5: User Check-in**

Pause here and show the user:

- the two new helper files under `scripts/lib/`
- the top of `bin/dre`
- the top of `bin/dwt`

Ask whether the seam boundary is clear enough now that only the exact duplicated helpers moved and the metadata loading/validation blocks stayed inline as requested.

---

## Task 5: Final verification, mandatory refactor checkpoint, and handoff

**Files:**
- Review only: `scripts/lib/did-you-mean.sh`
- Review only: `scripts/lib/managed-repo-metadata.sh`
- Review only: `bin/dre`
- Review only: `bin/dwt`
- Verify only:
  - `tests/devspace/test_workspace_navigation_helper_layout.sh`
  - `tests/devspace/test_workspace_navigation_helper_contracts.sh`
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/install/test_workspace_navigation_shell.sh`

- [ ] **Step 1: Re-run the full HC-6 seam-extraction verification suite from a clean working state**

Run:

```bash
bash tests/devspace/test_workspace_navigation_helper_layout.sh
bash tests/devspace/test_workspace_navigation_helper_contracts.sh
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/install/test_workspace_navigation_shell.sh
```

Expected: PASS for all four commands.

- [ ] **Step 2: Confirm only the intended commits and files were added for this slice**

Run:

```bash
git show --stat --oneline HEAD~4..HEAD
```

Expected commit subjects:

- `test(devspace): lock did-you-mean seam`
- `refactor(nav): extract did-you-mean helper`
- `test(devspace): lock metadata helper seam`
- `refactor(nav): extract managed repo metadata helper`

- [ ] **Step 3: Mandatory refactor checkpoint**

Review the final slice against the approved architecture:

- `scripts/lib/did-you-mean.sh` should own only the suggestion helper.
- `scripts/lib/managed-repo-metadata.sh` should own only the metadata refusal/repair helper trio.
- `bin/dre` and `bin/dwt` should still own argument handling, repo/worktree lookup, `repo.env` loading, canonicalization, and caller-specific resolution logic.
- The metadata loading/validation blocks should remain inline and visibly separate between the two callers.
- The helper files should rely on caller-owned `workspace_root` and `script_dir` rather than introducing a new global initialization pattern.
- `tests/devspace/test_workspace_navigation_commands.sh` and `tests/install/test_workspace_navigation_shell.sh` should still be proving unchanged user-visible behavior.
- No completion, doc, onboarding, or unrelated navigation files should change in this slice.

If this checkpoint uncovers behavior-preserving cleanup inside the touched files, apply it and rerun the Step 1 verification suite.

- [ ] **Step 4: Handoff note**

Report back with:

- the exact verification commands rerun
- the final helper file list
- confirmation that the metadata loading/validation blocks remained inline in both callers
- confirmation that error wording, repair hints, suggestion output, and exit codes stayed unchanged

## Final verification checklist

- [ ] Run the focused regression suite:
  - `bash tests/devspace/test_workspace_navigation_helper_layout.sh`
  - `bash tests/devspace/test_workspace_navigation_helper_contracts.sh`
  - `bash tests/devspace/test_workspace_navigation_commands.sh`
  - `bash tests/install/test_workspace_navigation_shell.sh`
- [ ] Re-read the user-approved HC-6 extraction boundary and confirm each requirement is covered:
  1. `did_you_mean()` moved to `scripts/lib/did-you-mean.sh`.
  2. `metadata_refusal()`, `metadata_repair_hint()`, and `fail_metadata()` moved to `scripts/lib/managed-repo-metadata.sh`.
  3. `bin/dre` and `bin/dwt` still own metadata loading/validation inline.
  4. Exact refusal text, repair hints, and `did you mean` output stayed unchanged.
  5. Caller behavior, argument handling, and exit codes stayed unchanged.
- [ ] Record the mandatory post-implementation checks in the handoff/PR note:
  - pragmatic-programmer diagnostic score,
  - clean-code review outcome,
  - any remediation items if either review finds material gaps.

## Notes for the implementing agent

- Follow strict TDD for each extraction slice: red → verify red → green → verify green → refactor → verify green.
- Keep the tests at the contract level already used in this repo; do not add low-value unit tests for shell internals beyond the two focused helper contract files in this plan.
- Keep the seam extraction minimal and reversible: extract only the five duplicated helper functions and nothing else.
- If implementation pressure suggests extracting the metadata loading/validation blocks too, stop and ask the user first; that is explicitly out of scope for HC-6.
