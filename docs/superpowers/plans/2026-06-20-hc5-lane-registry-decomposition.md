# HC-5 Managed Lane Registry Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose `scripts/lib/managed-lane-registry.sh` into smaller helper files while preserving every caller contract, registry/pointer side effect, and test-observed lane-safety behavior.

**Architecture:** Keep `scripts/lib/managed-lane-registry.sh` as the compatibility entrypoint and public API owner for `managed_lane_registry_record_binding`, extract path/invariant/TSV helpers into `scripts/lib/managed-lane-registry-path.sh`, and extract write/mutation helpers into `scripts/lib/managed-lane-registry-mutations.sh`. Follow the `hub-repo-core.sh` sourcing-state restore pattern from `4ac808d`, and drive the refactor with one new helper-layout contract test, one focused runtime-contract test, and the three existing DevSpace behavior tests so the slice stays tests-first and behavior-preserving.

**Tech Stack:** Bash, sourced shell helper files under `scripts/lib/`, existing shell behavior tests under `tests/devspace/`, one new structural contract test under `tests/devspace/`, and one new focused runtime-contract test under `tests/devspace/`.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved hotspot slice: `HC-5 — scripts/lib/managed-lane-registry.sh decomposition`
- Requested plan destination: `docs/superpowers/plans/2026-06-20-hc5-lane-registry-decomposition.md`
- Requested partition style reference: `docs/superpowers/plans/2026-06-20-p3-worktree-navigation-refactor.md` (Task 4 style)
- Reference implementation shape: commit `4ac808d` (`refactor(hub): partition repo core helpers`)
- Existing implementation surface:
  - `scripts/lib/managed-lane-registry.sh`
- Existing callers/consumers that must remain compatible and unchanged:
  - `scripts/lib/new-worktree-flow.sh`
  - `bin/new-worktree`
  - `scripts/lib/managed-worktree-cleanup.sh`
  - `bin/retire-worktree`
- Behavior safety rails that must remain green:
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_retire_worktree.sh`

## Scope

### In scope

- Extract the current non-mutating helpers from `scripts/lib/managed-lane-registry.sh` into `scripts/lib/managed-lane-registry-path.sh`.
- Extract the current file-mutation helpers from `scripts/lib/managed-lane-registry.sh` into `scripts/lib/managed-lane-registry-mutations.sh`.
- Keep `managed_lane_registry_record_binding` in `scripts/lib/managed-lane-registry.sh` as the stable public API and thin orchestrator.
- Preserve exactly:
  - the `lane_id\trepo_identity\tbranch\tworktree_path\tstate_path\tpointer_path\tparent_artifact_anchors\tsession_task_id\tsession_owner\trouting_state\tstatus` header
  - the `lane-binding.env` key set and write order
  - default values `routing_state=unbound` and `status=active`
  - pointer-path de-duplication semantics before appending a new record
  - refusal text for missing required fields
  - sourced-file `script_dir` restoration for callers such as `bin/new-worktree`
- Add one structural contract test that locks the helper layout and compatibility entrypoint shape.
- Add one focused runtime-contract test that locks sourced-file `script_dir` restoration, missing-field refusal text, pointer overwrite key order, and pointer-path de-duplication semantics.

### Out of scope

- No changes to `bin/new-worktree`, `scripts/lib/new-worktree-flow.sh`, `bin/retire-worktree`, or `scripts/lib/managed-worktree-cleanup.sh`.
- No changes to the registry schema, pointer schema, or field ordering.
- No new public API surface for callers beyond the existing `managed_lane_registry_record_binding` entrypoint.
- No lane-policy changes, cleanup-policy changes, CLI changes, or docs/policy edits outside this plan file.
- No remediation of unrelated baseline failures; if any safety rail is red before the refactor starts, pause and re-scope.

## Proposed file map

- Create: `tests/devspace/test_managed_lane_registry_layout.sh` — structural contract for helper layout and thin compatibility entrypoint.
- Create: `tests/devspace/test_managed_lane_registry_contracts.sh` — focused runtime contract for sourced-file restoration, refusal text, pointer key order, and pointer-path de-duplication.
- Create: `scripts/lib/managed-lane-registry-path.sh` — required-field guard, state-root/path helpers, pointer-path helper, and TSV escaping.
- Create: `scripts/lib/managed-lane-registry-mutations.sh` — registry header creation, pointer writes, pointer de-duplication, and record append.
- Modify: `scripts/lib/managed-lane-registry.sh` — becomes a thin compatibility entrypoint that sources the two helpers, restores caller sourcing state, and keeps `managed_lane_registry_record_binding`.
- Verify only:
  - `tests/devspace/test_managed_lane_registry_layout.sh`
  - `tests/devspace/test_managed_lane_registry_contracts.sh`
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_retire_worktree.sh`

---

## Task 1: Prove the baseline and add failing contract tests

**Files:**
- Create: `tests/devspace/test_managed_lane_registry_layout.sh`
- Create: `tests/devspace/test_managed_lane_registry_contracts.sh`
- Verify only:
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_retire_worktree.sh`

- [ ] **Step 1: Prove the current hotspot slice is green before changing structure**

Run:

```bash
bash tests/devspace/test_managed_lane_registry.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_retire_worktree.sh
```

Expected: PASS for all three commands. If any command fails before the helper split starts, stop and ask the user whether baseline repair is now in scope.

- [ ] **Step 2: Add a failing structural contract for the new helper layout**

Create `tests/devspace/test_managed_lane_registry_layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_lane_registry_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
entrypoint="$repo_root/scripts/lib/managed-lane-registry.sh"
path_helper="$repo_root/scripts/lib/managed-lane-registry-path.sh"
mutation_helper="$repo_root/scripts/lib/managed-lane-registry-mutations.sh"

[ -f "$entrypoint" ] || fail 'scripts/lib/managed-lane-registry.sh not found'
[ -f "$path_helper" ] || fail 'scripts/lib/managed-lane-registry-path.sh not found'
[ -f "$mutation_helper" ] || fail 'scripts/lib/managed-lane-registry-mutations.sh not found'

grep -F 'source "$script_dir/managed-lane-registry-path.sh"' "$entrypoint" >/dev/null || fail 'entrypoint should source managed-lane-registry-path.sh'
grep -F 'source "$script_dir/managed-lane-registry-mutations.sh"' "$entrypoint" >/dev/null || fail 'entrypoint should source managed-lane-registry-mutations.sh'
grep -F 'if [ -n "${BASH_SOURCE[1]:-}" ]; then' "$entrypoint" >/dev/null || fail 'entrypoint should restore caller sourcing state when sourced'
grep -F 'script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd -P)"' "$entrypoint" >/dev/null || fail 'entrypoint should restore caller script_dir after sourcing helpers'
grep -F 'unset script_dir' "$entrypoint" >/dev/null || fail 'entrypoint should unset script_dir when no caller exists'
grep -F 'managed_lane_registry_record_binding() {' "$entrypoint" >/dev/null || fail 'entrypoint should keep managed_lane_registry_record_binding public API'
grep -F 'managed_lane_registry_ensure_header "$registry_path"' "$entrypoint" >/dev/null || fail 'entrypoint should orchestrate header creation through mutation helper'
grep -F 'managed_lane_registry_write_pointer \' "$entrypoint" >/dev/null || fail 'entrypoint should orchestrate pointer writes through mutation helper'
grep -F 'managed_lane_registry_remove_existing_for_pointer "$registry_path" "$pointer_path"' "$entrypoint" >/dev/null || fail 'entrypoint should preserve pointer de-duplication call'
grep -F 'managed_lane_registry_append_record \' "$entrypoint" >/dev/null || fail 'entrypoint should append through mutation helper'

grep -F 'managed_lane_registry_require_non_empty() {' "$path_helper" >/dev/null || fail 'path helper should own required-field guard'
grep -F 'managed_lane_registry_resolve_state_root() {' "$path_helper" >/dev/null || fail 'path helper should own state-root resolution'
grep -F 'managed_lane_registry_registry_path() {' "$path_helper" >/dev/null || fail 'path helper should own registry path resolution'
grep -F 'managed_lane_registry_pointer_path() {' "$path_helper" >/dev/null || fail 'path helper should own pointer path resolution'
grep -F 'managed_lane_registry_escape_tsv() {' "$path_helper" >/dev/null || fail 'path helper should own TSV escaping'

grep -F 'managed_lane_registry_ensure_header() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own header creation'
grep -F 'managed_lane_registry_write_pointer() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own pointer writes'
grep -F 'managed_lane_registry_remove_existing_for_pointer() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own pointer de-duplication'
grep -F 'managed_lane_registry_append_record() {' "$mutation_helper" >/dev/null || fail 'mutation helper should own record appends'

printf 'PASS test_managed_lane_registry_layout\n'
```

- [ ] **Step 3: Add a failing runtime-contract test for restoration and behavior preservation**

Create `tests/devspace/test_managed_lane_registry_contracts.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_managed_lane_registry_contracts: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
entrypoint="$repo_root/scripts/lib/managed-lane-registry.sh"

[ -f "$entrypoint" ] || fail 'scripts/lib/managed-lane-registry.sh not found'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

caller_dir="$tmpdir/caller"
mkdir -p "$caller_dir"
caller_script="$caller_dir/load-managed-lane-registry.sh"

cat > "$caller_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
script_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd -P)"
source "$entrypoint"
[ "\$script_dir" = "$caller_dir" ] || {
  printf 'restored-script-dir=%s\n' "\$script_dir" >&2
  exit 91
}
EOF
chmod +x "$caller_script"

if ! bash "$caller_script" >"$tmpdir/script-dir.out" 2>"$tmpdir/script-dir.err"; then
  cat "$tmpdir/script-dir.err" >&2
  fail 'sourcing entrypoint should restore caller script_dir'
fi

set +e
missing_output="$(bash -c 'set -euo pipefail; source "$1"; managed_lane_registry_require_non_empty "" workspace_root' _ "$entrypoint" 2>&1)"
missing_rc="$?"
set -e

[ "$missing_rc" = '1' ] || fail 'required-field guard should fail with exit code 1'
printf '%s\n' "$missing_output" | grep -F 'refused: managed lane registry missing required workspace_root' >/dev/null || fail 'required-field guard should preserve exact refusal text'

workspace_root="$tmpdir/workspace"
state_path="$workspace_root/state/hub/work/feature/demo"
mkdir -p "$state_path"

bash -c 'set -euo pipefail; source "$1"; managed_lane_registry_record_binding "$2" hub lane-one feature/demo-a /worktree/one "$3" docs/superpowers/specs/first.md ses_first planner bound active' _ "$entrypoint" "$workspace_root" "$state_path"
bash -c 'set -euo pipefail; source "$1"; managed_lane_registry_record_binding "$2" hub lane-two feature/demo-b /worktree/two "$3" docs/superpowers/specs/second.md ses_second planner bound active' _ "$entrypoint" "$workspace_root" "$state_path"

registry_path="$workspace_root/state/hub/lanes/registry.tsv"
pointer_path="$state_path/lane-binding.env"

[ -f "$registry_path" ] || fail 'registry file should exist after record_binding calls'
[ -f "$pointer_path" ] || fail 'pointer file should exist after record_binding calls'

record_count="$(awk 'END { print NR - 1 }' "$registry_path")"
[ "$record_count" = '1' ] || fail 're-recording the same pointer path should replace the existing registry row'
grep -F $'lane-two\thub\tfeature/demo-b\t/worktree/two\t' "$registry_path" >/dev/null || fail 'registry should keep the replacement row for the repeated pointer path'
if grep -F $'lane-one\thub\tfeature/demo-a\t/worktree/one\t' "$registry_path" >/dev/null; then
  fail 'registry should not retain the superseded row for the repeated pointer path'
fi

expected_pointer_content="$(cat <<EOF
LANE_ID=lane-two
REPO_IDENTITY=hub
BRANCH_NAME=feature/demo-b
WORKTREE_PATH=/worktree/two
STATE_PATH=$state_path
PARENT_ARTIFACT_ANCHORS=docs/superpowers/specs/second.md
SESSION_TASK_ID=ses_second
SESSION_OWNER=planner
ROUTING_STATE=bound
STATUS=active
EOF
)"
actual_pointer_content="$(cat "$pointer_path")"

[ "$actual_pointer_content" = "$expected_pointer_content" ] || fail 'pointer file should preserve key order and replacement values'

printf 'PASS test_managed_lane_registry_contracts\n'
```

- [ ] **Step 4: Verify RED**

Run:

```bash
bash tests/devspace/test_managed_lane_registry_layout.sh
bash tests/devspace/test_managed_lane_registry_contracts.sh
```

Expected: FAIL because the two helper files, the sourcing-state restore pattern, and the new runtime-contract surface do not exist yet.

- [ ] **Step 5: Commit the red structural and runtime contracts**

```bash
git add tests/devspace/test_managed_lane_registry_layout.sh \
  tests/devspace/test_managed_lane_registry_contracts.sh
git commit -m "test(devspace): lock lane registry helper layout"
```

---

## Task 2: Extract helper families and thin the compatibility entrypoint

**Files:**
- Create: `scripts/lib/managed-lane-registry-path.sh`
- Create: `scripts/lib/managed-lane-registry-mutations.sh`
- Modify: `scripts/lib/managed-lane-registry.sh`
- Test: `tests/devspace/test_managed_lane_registry_layout.sh`
- Test: `tests/devspace/test_managed_lane_registry_contracts.sh`
- Test: `tests/devspace/test_managed_lane_registry.sh`
- Test: `tests/devspace/test_new_worktree.sh`
- Test: `tests/devspace/test_retire_worktree.sh`

- [ ] **Step 1: Create `scripts/lib/managed-lane-registry-path.sh` and move the non-mutating helpers into it**

Create `scripts/lib/managed-lane-registry-path.sh` and move these functions into it without changing behavior or wording:

- current lines `4-11`: `managed_lane_registry_require_non_empty`
- current lines `13-23`: `managed_lane_registry_resolve_state_root`
- current lines `25-31`: `managed_lane_registry_registry_path`
- current lines `33-36`: `managed_lane_registry_pointer_path`
- current lines `38-44`: `managed_lane_registry_escape_tsv`

Preserve the exact missing-field refusal text:

```text
refused: managed lane registry missing required %s
```

- [ ] **Step 2: Create `scripts/lib/managed-lane-registry-mutations.sh` and move the write helpers into it**

Create `scripts/lib/managed-lane-registry-mutations.sh` and move these functions into it without changing behavior:

- current lines `46-55`: `managed_lane_registry_ensure_header`
- current lines `57-83`: `managed_lane_registry_write_pointer`
- current lines `85-95`: `managed_lane_registry_remove_existing_for_pointer`
- current lines `97-124`: `managed_lane_registry_append_record`

Preserve exactly:

- the registry header line and column order
- the `cat > "$pointer_path" <<EOF` pointer write format
- the `awk -F '\t'` removal logic keyed by escaped pointer path
- the TSV append field order and escaping calls
- pointer replacement semantics when the same `state_path` is recorded twice

- [ ] **Step 3: Reduce `scripts/lib/managed-lane-registry.sh` to a thin compatibility entrypoint**

Replace the top-level structure with this orchestration shape:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/managed-lane-registry-path.sh"
source "$script_dir/managed-lane-registry-mutations.sh"
if [ -n "${BASH_SOURCE[1]:-}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd -P)"
else
  unset script_dir
fi

managed_lane_registry_record_binding() {
  local workspace_root="${1:?workspace_root required}"
  local repo_identity="${2:?repo_identity required}"
  local lane_id="${3:?lane_id required}"
  local branch="${4:?branch required}"
  local worktree_path="${5:?worktree_path required}"
  local state_path="${6:?state_path required}"
  local parent_artifact_anchors="${7-}"
  local session_task_id="${8-}"
  local session_owner="${9-}"
  local routing_state="${10:-unbound}"
  local status="${11:-active}"

  managed_lane_registry_require_non_empty "$workspace_root" 'workspace_root'
  managed_lane_registry_require_non_empty "$repo_identity" 'repo_identity'
  managed_lane_registry_require_non_empty "$lane_id" 'lane_id'
  managed_lane_registry_require_non_empty "$branch" 'branch'
  managed_lane_registry_require_non_empty "$worktree_path" 'worktree_path'
  managed_lane_registry_require_non_empty "$state_path" 'state_path'

  local registry_path pointer_path
  registry_path="$(managed_lane_registry_registry_path "$workspace_root" "$repo_identity")"
  pointer_path="$(managed_lane_registry_pointer_path "$state_path")"

  managed_lane_registry_ensure_header "$registry_path"
  managed_lane_registry_write_pointer \
    "$pointer_path" \
    "$lane_id" \
    "$repo_identity" \
    "$branch" \
    "$worktree_path" \
    "$state_path" \
    "$parent_artifact_anchors" \
    "$session_task_id" \
    "$session_owner" \
    "$routing_state" \
    "$status"

  managed_lane_registry_remove_existing_for_pointer "$registry_path" "$pointer_path"
  managed_lane_registry_append_record \
    "$registry_path" \
    "$lane_id" \
    "$repo_identity" \
    "$branch" \
    "$worktree_path" \
    "$state_path" \
    "$pointer_path" \
    "$parent_artifact_anchors" \
    "$session_task_id" \
    "$session_owner" \
    "$routing_state" \
    "$status"
}
```

Preservation rules for this step:

- Source `managed-lane-registry-path.sh` before `managed-lane-registry-mutations.sh` so escaping/path helpers are available to mutation helpers.
- Restore `script_dir` to the caller path using `BASH_SOURCE[1]` immediately after sourcing the helpers, and `unset script_dir` when no caller exists.
- Keep `managed_lane_registry_record_binding` as the only caller-facing function defined in `scripts/lib/managed-lane-registry.sh`.
- Do not change any caller source paths or function invocations.

- [ ] **Step 4: Verify GREEN on the helper layout and behavior safety rails**

Run:

```bash
bash tests/devspace/test_managed_lane_registry_layout.sh
bash tests/devspace/test_managed_lane_registry_contracts.sh
bash tests/devspace/test_managed_lane_registry.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_retire_worktree.sh
```

Expected: PASS for all five commands.

- [ ] **Step 5: Commit the helper split**

```bash
git add scripts/lib/managed-lane-registry.sh \
  scripts/lib/managed-lane-registry-path.sh \
  scripts/lib/managed-lane-registry-mutations.sh
git commit -m "refactor(lanes): partition registry helpers"
```

- [ ] **Step 6: User Check-in**

Pause here and show the user:

- the thin `scripts/lib/managed-lane-registry.sh` entrypoint
- the new helper file list under `scripts/lib/`

Ask whether the split between path/invariant helpers and mutation helpers is clear enough before closing the hotspot slice.

---

## Task 3: Final verification, mandatory refactor checkpoint, and handoff

**Files:**
- Review only: `scripts/lib/managed-lane-registry.sh`
- Review only: `scripts/lib/managed-lane-registry-path.sh`
- Review only: `scripts/lib/managed-lane-registry-mutations.sh`
- Verify only:
  - `tests/devspace/test_managed_lane_registry_layout.sh`
  - `tests/devspace/test_managed_lane_registry_contracts.sh`
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_retire_worktree.sh`

- [ ] **Step 1: Re-run the full HC-5 safety-rail suite from a clean working state**

Run:

```bash
bash tests/devspace/test_managed_lane_registry_layout.sh
bash tests/devspace/test_managed_lane_registry_contracts.sh
bash tests/devspace/test_managed_lane_registry.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_retire_worktree.sh
```

Expected: PASS for all five commands.

- [ ] **Step 2: Confirm only the intended commits and files were added for this slice**

Run:

```bash
git show --stat --oneline HEAD~2..HEAD
```

Expected commit subjects:

- `test(devspace): lock lane registry helper layout`
- `refactor(lanes): partition registry helpers`

- [ ] **Step 3: Mandatory refactor checkpoint**

Review the final slice against the approved architecture:

- `scripts/lib/managed-lane-registry.sh` should read like orchestration only.
- `scripts/lib/managed-lane-registry-path.sh` should own required-field, path, and TSV-escaping logic only.
- `scripts/lib/managed-lane-registry-mutations.sh` should own file writes and registry mutation logic only.
- `tests/devspace/test_managed_lane_registry_contracts.sh` should prove sourced-file `script_dir` restoration, missing-field refusal text, pointer key order, and pointer-path replacement semantics.
- `tests/devspace/test_managed_lane_registry.sh`, `tests/devspace/test_new_worktree.sh`, and `tests/devspace/test_retire_worktree.sh` should still be proving unchanged runtime behavior.
- `scripts/lib/new-worktree-flow.sh`, `bin/new-worktree`, `scripts/lib/managed-worktree-cleanup.sh`, and `bin/retire-worktree` should remain unchanged in this slice.
- `registry.tsv` and `lane-binding.env` shapes should remain byte-for-byte compatible with the pre-refactor contract surfaces.

If this checkpoint uncovers behavior-preserving cleanup, apply it and rerun the Step 1 verification suite.

- [ ] **Step 4: Handoff note**

Report back with:

- the exact verification commands rerun
- confirmation that callers remained unchanged
- the final helper file list
- confirmation that no registry or pointer schema changes were introduced
