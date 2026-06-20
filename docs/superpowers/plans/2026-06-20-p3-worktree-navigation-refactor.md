# P3 Worktree/Navigation Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the worktree/navigation command family into smaller phase-oriented helpers while preserving every CLI surface, refusal string, side effect, and test-observed behavior.

**Architecture:** Keep the command entrypoints (`bin/new-worktree`, `bin/retire-worktree`, and optionally `bin/dre`/`bin/dwt`) thin, move cohesive orchestration phases into sourced helper libraries, and keep compatibility entrypoints such as `scripts/lib/hub-repo-core.sh` and `scripts/lib/managed-lane-registry.sh` stable for callers. Drive the refactor with one new structural contract test plus the existing behavior tests so the slice stays tests-first and behavior-preserving.

**Tech Stack:** Bash, sourced shell helper files under `scripts/lib/`, existing shell characterization tests under `tests/devspace/` and `tests/install/`, and one new structural contract test for this refactor family.

---

## Inputs and authority

- Governing audit artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Approved slice: `P3 — Refactor: worktree/navigation path`
- Reference plan format: `docs/superpowers/plans/2026-06-20-p1-docs-orientation.md`
- Prior structural-refactor example: `docs/superpowers/plans/2026-06-20-p2-install-sh-refactor.md`
- Primary hotspot surfaces:
  - `bin/new-worktree` (`HC-2`)
  - `bin/retire-worktree` (`HC-3`)
  - `scripts/lib/managed-worktree-cleanup.sh` (`HC-3`)
  - `scripts/lib/hub-repo-core.sh` (`HC-4`)
- Safety rails that must pass before and after the slice:
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_retire_worktree.sh`
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/devspace/test_workspace_navigation_path_contract.sh`
  - `tests/devspace/test_create_hub_repo.sh`
  - `tests/devspace/test_workspace_repair.sh`
  - `tests/install/test_workspace_navigation_shell.sh`
- Audit caveat to resolve before refactoring: `HC-7` notes earlier noisy baseline failures in `test_workspace_repair.sh` and `test_workspace_navigation_commands.sh`; this slice must start by proving those are green on the current branch or pause for re-scoping.
- Audit scope guard: audit lines `173-177` define this P3 slice as `HC-2`, `HC-3`, and `HC-4` only; `HC-5` (`managed-lane-registry.sh`) and `HC-6` (`dre`/`dwt`) are intentionally left for later and must remain untouched in this plan.

## Scope

### In scope

- Split `bin/new-worktree` into explicit phases for CLI parsing, repo-context resolution, worktree creation/attachment, and env/lane side effects.
- Split `bin/retire-worktree` into explicit phases for CLI parsing, target resolution, invariant validation, risk reporting, and destructive execution.
- Reorganize `scripts/lib/managed-worktree-cleanup.sh` around decision helpers vs cleanup primitives so the destructive path is easier to review.
- Partition `scripts/lib/hub-repo-core.sh` by cohesive families: source/branch resolution, bootstrap/worktree orchestration, and upstream/exclude helpers.
- Add structural contract coverage for the new helper layout.

### Out of scope

- No new flags, commands, or interactive prompts.
- No behavior changes.
- No changes to CLI usage strings.
- No changes to refusal or retry text.
- No lane-policy changes.
- No runbook, README, or policy edits.
- No changes to `scripts/lib/managed-lane-registry.sh`.
- No changes to `bin/dre` or `bin/dwt`.
- No changes to `.config/shell/workspace-navigation.zsh`.
- No remediation of unrelated failures outside the listed safety rails.

## Proposed file map

- Create: `tests/devspace/test_worktree_refactor_layout.sh` — structural contract for the new helper layout and thin-entrypoint call order.
- Create: `scripts/lib/new-worktree-flow.sh` — phase helpers extracted from `bin/new-worktree`.
- Create: `scripts/lib/retire-worktree-flow.sh` — phase helpers extracted from `bin/retire-worktree`.
- Create: `scripts/lib/hub-repo-core-source.sh` — source access + default-branch resolution helpers extracted from `hub-repo-core.sh`.
- Create: `scripts/lib/hub-repo-core-bootstrap.sh` — main worktree/bootstrap orchestration extracted from `hub-repo-core.sh`.
- Create: `scripts/lib/hub-repo-core-upstream.sh` — upstream/exclude helpers extracted from `hub-repo-core.sh`.
- Modify: `bin/new-worktree` — becomes a thin orchestrator.
- Modify: `bin/retire-worktree` — becomes a thin orchestrator.
- Modify: `scripts/lib/managed-worktree-cleanup.sh` — grouped into target-resolution, risk-evidence, and execution primitives.
- Modify: `scripts/lib/hub-repo-core.sh` — becomes a compatibility entrypoint sourcing the partition files.
- Verify only:
  - `tests/devspace/test_new_worktree.sh`
  - `tests/devspace/test_retire_worktree.sh`
  - `tests/devspace/test_managed_lane_registry.sh`
  - `tests/devspace/test_workspace_navigation_commands.sh`
  - `tests/devspace/test_workspace_navigation_path_contract.sh`
  - `tests/devspace/test_create_hub_repo.sh`
  - `tests/devspace/test_workspace_repair.sh`
  - `tests/install/test_workspace_navigation_shell.sh`

---

## Task 1: Establish a green characterization baseline, then add a failing structural contract

**Files:**
- Create: `tests/devspace/test_worktree_refactor_layout.sh`
- Verify only: the eight existing safety-rail tests listed above

- [ ] **Step 1: Prove the current branch is green before adding structural expectations**

Run:

```bash
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_retire_worktree.sh
bash tests/devspace/test_managed_lane_registry.sh
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/devspace/test_workspace_navigation_path_contract.sh
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/install/test_workspace_navigation_shell.sh
```

Expected: PASS for all eight commands. If either `test_workspace_navigation_commands.sh` or `test_workspace_repair.sh` still fails before the refactor starts, stop and ask the user whether that baseline repair is now part of scope; do not begin the refactor on a known-red baseline.

- [ ] **Step 2: Add a failing structural contract for the helper layout**

Create `tests/devspace/test_worktree_refactor_layout.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_worktree_refactor_layout: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
new_worktree_script="$repo_root/bin/new-worktree"
retire_script="$repo_root/bin/retire-worktree"
new_worktree_flow="$repo_root/scripts/lib/new-worktree-flow.sh"
retire_flow="$repo_root/scripts/lib/retire-worktree-flow.sh"
hub_core="$repo_root/scripts/lib/hub-repo-core.sh"
hub_source="$repo_root/scripts/lib/hub-repo-core-source.sh"
hub_bootstrap="$repo_root/scripts/lib/hub-repo-core-bootstrap.sh"
hub_upstream="$repo_root/scripts/lib/hub-repo-core-upstream.sh"

[ -f "$new_worktree_script" ] || fail 'bin/new-worktree not found'
[ -f "$retire_script" ] || fail 'bin/retire-worktree not found'
[ -f "$new_worktree_flow" ] || fail 'scripts/lib/new-worktree-flow.sh not found'
[ -f "$retire_flow" ] || fail 'scripts/lib/retire-worktree-flow.sh not found'
[ -f "$hub_core" ] || fail 'scripts/lib/hub-repo-core.sh not found'
[ -f "$hub_source" ] || fail 'scripts/lib/hub-repo-core-source.sh not found'
[ -f "$hub_bootstrap" ] || fail 'scripts/lib/hub-repo-core-bootstrap.sh not found'
[ -f "$hub_upstream" ] || fail 'scripts/lib/hub-repo-core-upstream.sh not found'

grep -F 'source "$script_dir/../scripts/lib/new-worktree-flow.sh"' "$new_worktree_script" >/dev/null || fail 'new-worktree should source new-worktree-flow.sh'
grep -F 'new_worktree_parse_cli "$@"' "$new_worktree_script" >/dev/null || fail 'new-worktree should parse CLI through a phase helper'
grep -F 'new_worktree_resolve_repo_context' "$new_worktree_script" >/dev/null || fail 'new-worktree should resolve repo context through a phase helper'
grep -F 'new_worktree_create_or_attach_branch_worktree' "$new_worktree_script" >/dev/null || fail 'new-worktree should create/attach the worktree through a phase helper'
grep -F 'new_worktree_prepare_checkout_sidecars' "$new_worktree_script" >/dev/null || fail 'new-worktree should prepare env/state sidecars through a phase helper'
grep -F 'new_worktree_record_lane_binding' "$new_worktree_script" >/dev/null || fail 'new-worktree should record lane bindings through a phase helper'

grep -F 'source "$script_dir/../scripts/lib/retire-worktree-flow.sh"' "$retire_script" >/dev/null || fail 'retire-worktree should source retire-worktree-flow.sh'
grep -F 'retire_worktree_parse_cli "$@"' "$retire_script" >/dev/null || fail 'retire-worktree should parse CLI through a phase helper'
grep -F 'retire_worktree_resolve_target_record' "$retire_script" >/dev/null || fail 'retire-worktree should resolve targets through a phase helper'
grep -F 'retire_worktree_print_target_summary' "$retire_script" >/dev/null || fail 'retire-worktree should print target summary through a phase helper'
grep -F 'retire_worktree_assess_risk_and_maybe_refuse' "$retire_script" >/dev/null || fail 'retire-worktree should assess risk through a phase helper'
grep -F 'retire_worktree_execute' "$retire_script" >/dev/null || fail 'retire-worktree should execute cleanup through a phase helper'

grep -F 'source "$script_dir/hub-repo-core-source.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-source.sh'
grep -F 'source "$script_dir/hub-repo-core-bootstrap.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-bootstrap.sh'
grep -F 'source "$script_dir/hub-repo-core-upstream.sh"' "$hub_core" >/dev/null || fail 'hub-repo-core should source hub-repo-core-upstream.sh'

printf 'PASS test_worktree_refactor_layout\n'
```

- [ ] **Step 3: Verify RED**

Run:

```bash
bash tests/devspace/test_worktree_refactor_layout.sh
```

Expected: FAIL because none of the new helper files or thin-entrypoint source lines exist yet.

- [ ] **Step 4: Commit the red structural test**

```bash
git add tests/devspace/test_worktree_refactor_layout.sh
git commit -m "test(devspace): lock p3 worktree refactor layout"
```

---

## Task 2: Refactor `bin/new-worktree` into explicit phases

**Files:**
- Create: `scripts/lib/new-worktree-flow.sh`
- Modify: `bin/new-worktree`
- Test: `tests/devspace/test_worktree_refactor_layout.sh`
- Test: `tests/devspace/test_new_worktree.sh`
- Test: `tests/devspace/test_managed_lane_registry.sh`

- [ ] **Step 1: Create `scripts/lib/new-worktree-flow.sh` with a phase-oriented public shape**

Start the new helper with this exact top-level outline:

```bash
#!/usr/bin/env bash
set -euo pipefail

new_worktree_usage() { :; }
new_worktree_parse_cli() { :; }
new_worktree_infer_repo_name_from_pwd() { :; }
new_worktree_resolve_repo_context() { :; }
new_worktree_create_or_attach_branch_worktree() { :; }
new_worktree_prepare_checkout_sidecars() { :; }
new_worktree_record_lane_binding() { :; }
new_worktree_report_success() { :; }
```

Then fill those functions by moving the current logic from `bin/new-worktree` without changing any user-visible text:

- Move current lines `9-11` into `new_worktree_usage` unchanged.
- Move current lines `13-51` into `new_worktree_parse_cli`, but store parsed values in globals named `new_worktree_repo_name`, `new_worktree_branch`, and `new_worktree_branch_set` instead of the current top-level locals.
- Move current lines `53-69` into `new_worktree_infer_repo_name_from_pwd`; preserve the exact refusal text `refused: unable to infer managed repo context; use --repo <hub|repo-name>`.
- Move current lines `71-105` into `new_worktree_resolve_repo_context`; split the current hub-vs-child layout variables into one coherent block that sets these globals and nothing else: `new_worktree_repo_root`, `new_worktree_bare_dir`, `new_worktree_repo_default_branch`, `new_worktree_target`, `new_worktree_state_dir`, `new_worktree_tmp_dir`, `new_worktree_hub_kind`, `new_worktree_repo_for_env`, and `new_worktree_lane_repo_identity`.
- Move current lines `107-138` into `new_worktree_create_or_attach_branch_worktree`; keep the exact reserved-default-branch refusal and the exact branch-creation order (`origin/<branch>` if present, otherwise base on `main` or the detected child default branch).
- Move current lines `140-162` into `new_worktree_prepare_checkout_sidecars`; keep the `worktree-env.sh` calls unchanged and preserve the rule that the hub main checkout gets `.envrc` only when missing.
- Move current lines `142-175` lane-field assembly into `new_worktree_record_lane_binding`; keep the exact environment variable names `MANAGED_LANE_ID`, `MANAGED_LANE_PARENT_ARTIFACTS`, `MANAGED_LANE_SESSION_TASK_ID`, `MANAGED_LANE_SESSION_OWNER`, and `MANAGED_LANE_ROUTING_STATE`.
- Move current line `177` into `new_worktree_report_success` unchanged.

- [ ] **Step 2: Replace `bin/new-worktree` with a thin orchestrator**

Replace the command body with this exact orchestration shape:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"

# shellcheck source=scripts/lib/managed-lane-registry.sh
source "$script_dir/../scripts/lib/managed-lane-registry.sh"
# shellcheck source=scripts/lib/new-worktree-flow.sh
source "$script_dir/../scripts/lib/new-worktree-flow.sh"

new_worktree_parse_cli "$@"
new_worktree_resolve_repo_context
new_worktree_create_or_attach_branch_worktree
new_worktree_prepare_checkout_sidecars
new_worktree_record_lane_binding
new_worktree_report_success
```

Important preservation rules for this step:

- Keep the exact `usage: new-worktree [--repo <hub|repo-name>] <branch>` text.
- Keep `validate_hub_repo_root.sh` invocation semantics unchanged for both hub and child flows.
- Do not change the order of `.envrc` generation relative to lane registry writes.
- Do not change `printf 'ok: created worktree at %s\n'`.

- [ ] **Step 3: Verify GREEN on the structural contract and focused behavior tests**

Run:

```bash
bash tests/devspace/test_worktree_refactor_layout.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_managed_lane_registry.sh
```

Expected: PASS for all three commands.

- [ ] **Step 4: Commit the `new-worktree` phase split**

```bash
git add bin/new-worktree scripts/lib/new-worktree-flow.sh
git commit -m "refactor(worktree): phase new-worktree flow"
```

---

## Task 3: Separate `retire-worktree` decision flow from cleanup execution

**Files:**
- Create: `scripts/lib/retire-worktree-flow.sh`
- Modify: `bin/retire-worktree`
- Modify: `scripts/lib/managed-worktree-cleanup.sh`
- Test: `tests/devspace/test_worktree_refactor_layout.sh`
- Test: `tests/devspace/test_retire_worktree.sh`
- Test: `tests/devspace/test_managed_lane_registry.sh`

- [ ] **Step 1: Create `scripts/lib/retire-worktree-flow.sh` and move command-level phases into it**

Start the file with this exact public shape:

```bash
#!/usr/bin/env bash
set -euo pipefail

retire_worktree_usage() { :; }
retire_worktree_parse_cli() { :; }
retire_worktree_resolve_target_record() { :; }
retire_worktree_print_target_summary() { :; }
retire_worktree_assess_risk_and_maybe_refuse() { :; }
retire_worktree_execute() { :; }
```

Populate it by moving current `bin/retire-worktree` logic verbatim into the new function boundaries:

- Move current lines `10-12` into `retire_worktree_usage` unchanged.
- Move current lines `20-61` into `retire_worktree_parse_cli`; keep the exact `--force`/`--force-token` refusal text.
- Move current lines `63-129` into `retire_worktree_resolve_target_record`; preserve the exact refusals for missing registry/bare repo, missing child metadata, default checkout target, ambiguous target, canonical-layout failure, and branch/worktree attachment mismatch.
- Move current lines `132-136` into `retire_worktree_print_target_summary` unchanged.
- Move current lines `137-222` into `retire_worktree_assess_risk_and_maybe_refuse`; keep the exact output order: tracked modifications, untracked files, upstream safety, local-only commits, then `force-token:` and the retry command.
- Move current lines `224-232` into `retire_worktree_execute`; keep the dry-run early return before destructive cleanup.

- [ ] **Step 2: Restructure `scripts/lib/managed-worktree-cleanup.sh` around clearer boundaries without changing output**

Keep the file name and existing low-level behaviors, but regroup it so reviewers can scan it by concern:

- **Identity + registry path helpers:** current lines `8-60`.
- **Candidate parsing + path/attachment invariants:** current lines `62-105` plus `149-178`.
- **Risk evidence primitives:** current lines `107-147` plus `180-241`.
- **Destructive execution + registry retirement:** current lines `243-269`.

Add three intent-revealing wrappers that the new flow helper can call instead of assembling the whole operation inline:

```bash
managed_cleanup_resolve_single_target_record() { :; }
managed_cleanup_collect_risk_report() { :; }
managed_cleanup_execute_retirement() { :; }
```

Implement those wrappers by composing the existing primitives rather than rewriting them. Preserve all current evidence strings, hash/token generation, and retry-command formatting byte-for-byte.

- [ ] **Step 3: Replace `bin/retire-worktree` with a thin orchestrator**

Use this exact orchestration shape:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
workspace_root="${HUB_WORKSPACE_ROOT:-/workspaces/dotfiles}"

# shellcheck source=scripts/lib/managed-worktree-cleanup.sh
source "$script_dir/../scripts/lib/managed-worktree-cleanup.sh"
# shellcheck source=scripts/lib/retire-worktree-flow.sh
source "$script_dir/../scripts/lib/retire-worktree-flow.sh"

retire_worktree_parse_cli "$@"
retire_worktree_resolve_target_record
retire_worktree_print_target_summary
retire_worktree_assess_risk_and_maybe_refuse
retire_worktree_execute
```

- [ ] **Step 4: Verify GREEN on the structural contract and destructive-flow behavior tests**

Run:

```bash
bash tests/devspace/test_worktree_refactor_layout.sh
bash tests/devspace/test_retire_worktree.sh
bash tests/devspace/test_managed_lane_registry.sh
```

Expected: PASS for all three commands.

- [ ] **Step 5: Commit the `retire-worktree` phase split**

```bash
git add bin/retire-worktree scripts/lib/retire-worktree-flow.sh scripts/lib/managed-worktree-cleanup.sh
git commit -m "refactor(retire): split managed cleanup flow"
```

---

## Task 4: Partition `hub-repo-core.sh`

**Files:**
- Create: `scripts/lib/hub-repo-core-source.sh`
- Create: `scripts/lib/hub-repo-core-bootstrap.sh`
- Create: `scripts/lib/hub-repo-core-upstream.sh`
- Modify: `scripts/lib/hub-repo-core.sh`
- Test: `tests/devspace/test_worktree_refactor_layout.sh`
- Test: `tests/devspace/test_create_hub_repo.sh`
- Test: `tests/devspace/test_new_worktree.sh`
- Test: `tests/devspace/test_managed_lane_registry.sh`

- [ ] **Step 1: Split `hub-repo-core.sh` into three cohesive helper files**

Create `scripts/lib/hub-repo-core-source.sh` and move these helpers into it:

- current lines `11-23`: `hub_git_non_interactive`, `hub_is_non_interactive_access_failure`
- current lines `25-57`: `hub_source_default_branch`
- current lines `59-88`: `hub_source_has_branch`

While moving them, preserve behavior and return codes exactly, including:

- `hub_source_has_branch`: `0` for present, `10` for missing branch, `20` for access failure
- `hub_source_default_branch`: `20` for non-interactive access failure
- the current access-failure regex text in `hub_is_non_interactive_access_failure`

Create `scripts/lib/hub-repo-core-upstream.sh` and move these helpers into it unchanged:

- current lines `113-121`: `hub_set_branch_upstream`
- current lines `123-137`: `hub_ensure_bare_excludes`

Create `scripts/lib/hub-repo-core-bootstrap.sh` and move these helpers into it:

- current lines `90-98`: `hub_is_valid_worktree`
- current lines `100-111`: `hub_remove_empty_non_git_main_dir`
- current lines `139-250`: `create_bare_hub`

`create_bare_hub` should remain mostly verbatim; only replace direct references with calls to the newly sourced helper families.

- [ ] **Step 2: Reduce `scripts/lib/hub-repo-core.sh` to a compatibility entrypoint**

Keep only the default-branch constant, `hub_fail`, `script_dir`, and source statements in the top-level file:

```bash
#!/usr/bin/env bash

# Default to main for v1 bootstrap behavior.
HUB_BOOTSTRAP_BRANCH="${HUB_BOOTSTRAP_BRANCH:-main}"

hub_fail() {
  printf '%s\n' "$1" >&2
  return 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/hub-repo-core-source.sh"
source "$script_dir/hub-repo-core-upstream.sh"
source "$script_dir/hub-repo-core-bootstrap.sh"
```

Do not change any callers such as `bin/clone-repo`; they should continue to source `scripts/lib/hub-repo-core.sh` exactly as before.

- [ ] **Step 3: Verify GREEN on helper partitions and caller behavior**

Run:

```bash
bash tests/devspace/test_worktree_refactor_layout.sh
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_managed_lane_registry.sh
```

Expected: PASS for all four commands.

- [ ] **Step 4: Commit the helper partition slice**

```bash
git add scripts/lib/hub-repo-core.sh \
  scripts/lib/hub-repo-core-source.sh \
  scripts/lib/hub-repo-core-bootstrap.sh \
  scripts/lib/hub-repo-core-upstream.sh
git commit -m "refactor(hub): partition repo core helpers"
```

- [ ] **Step 5: User Check-in**

Pause here and show the user:

- the thin `bin/new-worktree` and `bin/retire-worktree` entrypoints
- the new helper file list under `scripts/lib/`

Ask whether the command-family split is clear enough before moving on to later hotspot families that were intentionally deferred by the audit.

---

## Task 5: Final verification, mandatory refactor checkpoint, and handoff

**Files:**
- Review only: `bin/new-worktree`
- Review only: `bin/retire-worktree`
- Review only: `scripts/lib/new-worktree-flow.sh`
- Review only: `scripts/lib/retire-worktree-flow.sh`
- Review only: `scripts/lib/managed-worktree-cleanup.sh`
- Review only: `scripts/lib/hub-repo-core.sh`
- Review only: `scripts/lib/hub-repo-core-source.sh`
- Review only: `scripts/lib/hub-repo-core-bootstrap.sh`
- Review only: `scripts/lib/hub-repo-core-upstream.sh`

- [ ] **Step 1: Re-run the full safety-rail suite from a clean working state**

Run:

```bash
bash tests/devspace/test_worktree_refactor_layout.sh
bash tests/devspace/test_new_worktree.sh
bash tests/devspace/test_retire_worktree.sh
bash tests/devspace/test_managed_lane_registry.sh
bash tests/devspace/test_workspace_navigation_commands.sh
bash tests/devspace/test_workspace_navigation_path_contract.sh
bash tests/devspace/test_create_hub_repo.sh
bash tests/devspace/test_workspace_repair.sh
bash tests/install/test_workspace_navigation_shell.sh
```

Expected: PASS for all nine commands.

- [ ] **Step 2: Confirm only the intended commits and files were added for this slice**

```bash
git show --stat --oneline HEAD~4..HEAD
```

Expected commit subjects:

- `test(devspace): lock p3 worktree refactor layout`
- `refactor(worktree): phase new-worktree flow`
- `refactor(retire): split managed cleanup flow`
- `refactor(hub): partition repo core helpers`

- [ ] **Step 3: Mandatory refactor checkpoint**

Review the final slice against the approved architecture:

- `bin/new-worktree` should read like orchestration only.
- `bin/retire-worktree` should read like orchestration only.
- `scripts/lib/new-worktree-flow.sh` should separate parse → resolve → create/attach → sidecars → lane binding.
- `scripts/lib/managed-worktree-cleanup.sh` should expose clear target-resolution, risk-evidence, and execution boundaries.
- `scripts/lib/hub-repo-core.sh` should be a compatibility entrypoint, not a 250-line mixed-concern file.
- `scripts/lib/managed-lane-registry.sh`, `bin/dre`, and `bin/dwt` should remain behavior guards only and should not be structurally changed in this slice.

If this checkpoint uncovers cleanup that preserves behavior, apply it and rerun the same verification commands from Step 1.

- [ ] **Step 4: Final User Check-in**

Show the user:

- the new helper file list
- the thin entrypoint bodies for `bin/new-worktree` and `bin/retire-worktree`
- confirmation that `managed-lane-registry.sh`, `bin/dre`, and `bin/dwt` were intentionally left unchanged for a later slice

Ask whether the command family is now easier to review and maintain before moving on to the next hotspot family.

- [ ] **Step 5: Final handoff note**

Report:

- changed files for the required slice
- fresh verification commands run
- confirmation that all CLI surfaces and refusal texts stayed unchanged
- confirmation that the refactor remained structural-only

---

## Final verification checklist

- [ ] `bash tests/devspace/test_worktree_refactor_layout.sh`
- [ ] `bash tests/devspace/test_new_worktree.sh`
- [ ] `bash tests/devspace/test_retire_worktree.sh`
- [ ] `bash tests/devspace/test_managed_lane_registry.sh`
- [ ] `bash tests/devspace/test_workspace_navigation_commands.sh`
- [ ] `bash tests/devspace/test_workspace_navigation_path_contract.sh`
- [ ] `bash tests/devspace/test_create_hub_repo.sh`
- [ ] `bash tests/devspace/test_workspace_repair.sh`
- [ ] `bash tests/install/test_workspace_navigation_shell.sh`
- [ ] Re-read `HC-2` through `HC-4` in `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md` and confirm each hotspot now maps to a smaller, clearer phase/helper boundary.
- [ ] Confirm `bin/new-worktree`, `bin/retire-worktree`, `bin/dre`, and `bin/dwt` still accept the exact same CLI syntax as before.
- [ ] Confirm every existing refusal message and retry command text remained byte-for-byte unchanged.
- [ ] Confirm no new environment variables, flags, or side effects were introduced.
- [ ] Confirm `scripts/lib/managed-lane-registry.sh`, `bin/dre`, and `bin/dwt` were not modified in this slice.

## Notes for the implementing agent

- Prefer moving existing blocks verbatim into helpers instead of rewriting logic.
- Preserve message text first; naming cleanup is valuable only when it does not perturb user-visible strings.
- Keep helper APIs narrow and command-owned. Do not introduce a generic “command framework.”
- If any helper split starts forcing new conditionals that obscure the flow more than the original file, stop and ask before proceeding.
- Leave `scripts/lib/managed-lane-registry.sh`, `bin/dre`, and `bin/dwt` alone; they are explicitly deferred by the governing audit.
- Treat `test_workspace_repair.sh` and `test_workspace_navigation_commands.sh` as must-stay-green characterization guards, not optional downstream checks.
