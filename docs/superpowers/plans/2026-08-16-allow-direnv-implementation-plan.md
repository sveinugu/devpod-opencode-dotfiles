# Allow Direnv Managed Worktrees Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a small operator-facing `bin/allow-direnv-managed-worktrees` helper that defaults to dry-run discovery, refuses hub-root execution, repairs missing managed env sidecars through `scripts/lib/worktree-env.sh`, and runs serial `direnv allow` only when explicitly requested.

**Architecture:** Keep the command shell-only and surgical. Use one thin CLI wrapper at `bin/allow-direnv-managed-worktrees`, one focused library helper to centralize discovery/classification/execution, and a minimal refactor in `scripts/lib/worktree-env.sh` only if needed to compare existing `.envrc` files against generated managed content without duplicating that logic. Drive the work with integration-style shell tests first, then update the operator runbook after the command behavior is green.

**Tech Stack:** Bash commands/helpers, managed git worktree metadata under `state/`, `direnv`, existing `.envrc` generation in `scripts/lib/worktree-env.sh`, shell contract tests, and Markdown runbook updates.

**Spec:** `docs/superpowers/specs/2026-08-16-allow-direnv-managed-worktrees-design.md`

**Implementation branch:** `work/allow-direnv-managed-worktrees`

## Global Constraints

- the top-level default checkout is `main` only;
- child repos use their exact managed default-branch checkout from local metadata;
- hub root (`/workspaces/dotfiles`) remains an administrative path and must be refused;
- the tool should remain simple and operator-readable: human output plus a plain summary line, no JSON output in v1;
- execution is serial only;
- `--force` without `--allow` is a usage error;
- running from hub root is a safety refusal, not a usage error;
- launch is valid only from a managed checkout class already defined by the repo;
- missing managed env sidecars must be repaired by reusing `scripts/lib/worktree-env.sh` rather than duplicating generation rules;
- divergent/manual `.envrc` files may be rewritten only under `--allow --force`;
- keep changes minimal and surgical; do not widen scope into `bin/repair-workspace`, `bin/new-worktree`, or nono-profile changes in this slice.

---

## File map

### Create

- `bin/allow-direnv-managed-worktrees`
- `scripts/lib/allow-direnv-managed-worktrees.sh`
- `tests/devspace/test_allow_direnv_managed_worktrees.sh`
- `tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh`
- `tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh`
- `tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh`
- `tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh`
- `tests/devspace/test_allow_direnv_managed_worktrees_failures.sh`

### Modify

- `scripts/lib/worktree-env.sh`
- `docs/superpowers/runbooks/devspace-bare-hub-usage.md`

### Do not modify unless a User Check-in approves it

- `tests/run.sh` — current runner is execution-context based, while this plan intentionally follows the explicit `tests/devspace/` request.

---

## Acceptance test matrix

| Test file | Purpose | Acceptance criteria |
| --- | --- | --- |
| `tests/devspace/test_allow_direnv_managed_worktrees.sh` | dry-run discovery and classification | exits `0`; prints `plan:` lines and one `summary:` line; reports `allowed`, `not allowed`, `unknown`, `missing .envrc (repair+allow pending)`, `missing .envrc.local (repair+allow pending)`, and `divergent .envrc (force required)`; performs no mutations |
| `tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh` | usage and launch-safety rules | `--help` exits `0`; `--force` without `--allow` exits `2`; extra positional args exit `2`; hub-root execution exits `3` with exact `Refused — hub-root CWD detected. Provide explicit worktree path.` text; unmanaged launch exits `3` with a clear refusal |
| `tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh` | missing `.envrc` repair flow | `--allow` repairs missing `.envrc`, creates `.envrc.local`, runs `direnv allow`, prints `ok:` action lines, and leaves managed content in place |
| `tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh` | missing `.envrc.local` repair flow | `--allow` recreates `.envrc.local`, still runs allow behavior for the target, and reports success without forcing a divergent rewrite |
| `tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh` | divergent `.envrc` handling | dry-run reports `divergent .envrc (force required)`; `--allow` alone leaves file untouched; `--allow --force` creates `.envrc.bak.*`, rewrites managed content, and re-runs `direnv allow` |
| `tests/devspace/test_allow_direnv_managed_worktrees_failures.sh` | continue-after-failure behavior | when one `direnv allow` fails, command prints `error:` for that target, continues to later targets, and exits `1` overall |
| `tests/pod-inside-nono/test_new_worktree.sh` | regression for `scripts/lib/worktree-env.sh` | still exits `0`; managed `.envrc` generation/repair behavior remains unchanged for existing worktree flows |

---

## Shared fixture strategy for the new tests

- Each new `tests/devspace/*.sh` file should source:

  ```bash
  repo_root="$(git rev-parse --show-toplevel)"
  # shellcheck source=tests/lib/context-guards.sh
  source "$repo_root/tests/lib/context-guards.sh"
  # shellcheck source=tests/lib/git-fixtures.sh
  source "$repo_root/tests/lib/git-fixtures.sh"
  require_pod_inside_nono_test 'test_allow_direnv_managed_worktrees'
  ```

- Reuse the temp-workspace fixture style from `tests/pod-inside-nono/test_new_worktree.sh`:
  - create a bare hub at `$tmpdir/workspace/.bare`;
  - attach `$workspace_root/main` and at least one top-level `work/*` checkout;
  - create one child repo with `state/repos/<repo>/etc/repo.env` metadata;
  - inject a mock `direnv` binary ahead of `PATH` so tests can script `allow` success/failure and synthetic trust-state answers;
  - write per-checkout trust-state fixture files instead of depending on real user allow-list internals.

- Keep all test workspaces isolated under the temp root resolved from the managed `.envrc` environment.

---

## Task 1: Lock the CLI, refusal, and dry-run contract first

**Files:**
- Create: `tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh`
- Create: `tests/devspace/test_allow_direnv_managed_worktrees.sh`

**Interfaces:**
- Consumes: `bin/allow-direnv-managed-worktrees [--allow] [--force]`
- Produces: a stable CLI contract with exit codes `0`, `1`, `2`, `3`; stable output prefixes `plan:`, `ok:`, `skip:`, `warning:`, `error:`, `refused:`, `summary:`

- [ ] **Step 1: Write the failing refusal test**

  ```bash
  set +e
  (
    cd "$workspace_root"
    HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script"
  ) >"$tmpdir/hub-root.out" 2>&1
  hub_root_rc="$?"
  set -e

  [ "$hub_root_rc" = "3" ] || fail "expected hub-root refusal exit 3"
  grep -F 'Refused — hub-root CWD detected. Provide explicit worktree path.' "$tmpdir/hub-root.out" >/dev/null || fail "missing exact hub-root refusal"
  ```

- [ ] **Step 2: Add red cases for usage errors**

  ```bash
  set +e
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --force >"$tmpdir/force-only.out" 2>&1
  force_only_rc="$?"
  set -e

  [ "$force_only_rc" = "2" ] || fail "expected --force without --allow to exit 2"
  grep -F 'usage: allow-direnv-managed-worktrees [--allow] [--force]' "$tmpdir/force-only.out" >/dev/null || fail "missing usage text"
  ```

- [ ] **Step 3: Write the dry-run classification test with all required states**

  ```bash
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" >"$tmpdir/dry-run.out"

  grep -F 'plan: ' "$tmpdir/dry-run.out" >/dev/null || fail 'expected plan lines'
  grep -F 'allowed' "$tmpdir/dry-run.out" >/dev/null || fail 'missing allowed state'
  grep -F 'not allowed' "$tmpdir/dry-run.out" >/dev/null || fail 'missing not allowed state'
  grep -F 'unknown' "$tmpdir/dry-run.out" >/dev/null || fail 'missing unknown state'
  grep -F 'missing .envrc (repair+allow pending)' "$tmpdir/dry-run.out" >/dev/null || fail 'missing .envrc status'
  grep -F 'missing .envrc.local (repair+allow pending)' "$tmpdir/dry-run.out" >/dev/null || fail 'missing .envrc.local status'
  grep -F 'divergent .envrc (force required)' "$tmpdir/dry-run.out" >/dev/null || fail 'missing divergent status'
  grep -F 'summary:' "$tmpdir/dry-run.out" >/dev/null || fail 'missing summary line'
  ```

- [ ] **Step 4: Verify RED**

  Run:

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees.sh
  ```

  Expected: both fail because the command does not exist yet.

- [ ] **Step 5: Commit the red test slice**

  ```bash
  git add tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh tests/devspace/test_allow_direnv_managed_worktrees.sh
  git commit -m "test(devspace): lock allow-direnv dry-run contract"
  ```

**User Check-in 1:** pause before editing `tests/run.sh` or relocating these tests into execution-context folders. The approved spec allows current layout or `tests/devspace/`; this plan intentionally uses `tests/devspace/` because the request asked for it explicitly.

---

## Task 2: Implement the minimal dry-run command surface

**Files:**
- Create: `bin/allow-direnv-managed-worktrees`
- Create: `scripts/lib/allow-direnv-managed-worktrees.sh`
- Modify: `scripts/lib/worktree-env.sh`

**Interfaces:**
- Consumes: `scripts/lib/worktree-env.sh CHECKOUT_DIR HUB_KIND [REPO_NAME]`; child metadata at `state/repos/<repo>/etc/repo.env`
- Produces:
  - `bin/allow-direnv-managed-worktrees [--allow] [--force]`
  - `allow_direnv_managed_worktrees_main "$@"` → command entrypoint, exits per spec
  - `allow_direnv_discover_targets "$workspace_root"` → prints canonical managed checkout records
  - `allow_direnv_classify_target "$checkout_dir" "$hub_kind" "$repo_name"` → prints one status token

- [ ] **Step 1: Add the thin wrapper first**

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  # shellcheck source=scripts/lib/allow-direnv-managed-worktrees.sh
  source "$script_dir/../scripts/lib/allow-direnv-managed-worktrees.sh"
  allow_direnv_managed_worktrees_main "$@"
  ```

- [ ] **Step 2: Implement only enough library logic to turn Task 1 green**
  - parse `--help`, `--allow`, `--force`;
  - reject extra positional args;
  - refuse hub-root launch with the exact spec string and exit `3`;
  - discover only canonical managed checkouts;
  - classify all discovered targets without mutating them;
  - print one summary line with discovery counts.

- [ ] **Step 3: Refactor `scripts/lib/worktree-env.sh` only if needed to compare generated managed content without duplicating it**
  - preferred seam: an internal helper function or opt-in environment variable that writes candidate managed `.envrc` content to a temp path;
  - do **not** change default user-visible behavior of `worktree-env.sh`;
  - do **not** add a new public operator command unless a check-in approves it.

- [ ] **Step 4: Verify GREEN for the dry-run slice**

  Run:

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees.sh
  ```

  Expected: PASS.

- [ ] **Step 5: Mandatory refactor checkpoint**
  - keep checkout discovery separate from status classification;
  - keep summary counting in one place;
  - keep hub/child default-checkout handling driven by existing repo metadata, not duplicated path rules scattered through the script.

- [ ] **Step 6: Commit the green dry-run slice**

  ```bash
  git add bin/allow-direnv-managed-worktrees scripts/lib/allow-direnv-managed-worktrees.sh scripts/lib/worktree-env.sh
  git add tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh tests/devspace/test_allow_direnv_managed_worktrees.sh
  git commit -m "feat(devspace): add direnv-managed-worktree dry-run helper"
  ```

**User Check-in 2:** if divergence detection cannot reuse `scripts/lib/worktree-env.sh` without adding a new public CLI flag, pause and confirm the smallest acceptable seam before hardening that interface.

---

## Task 3: Add missing-sidecar repair and ordinary `--allow` execution

**Files:**
- Create: `tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh`
- Create: `tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh`
- Modify: `scripts/lib/allow-direnv-managed-worktrees.sh`

**Interfaces:**
- Consumes: dry-run command surface from Task 2; `scripts/lib/worktree-env.sh` for repair
- Produces:
  - `allow_direnv_execute_target "$checkout_dir" "$hub_kind" "$repo_name" "$status" "$force"`
  - stable `ok:` / `skip:` / `error:` execution lines

- [ ] **Step 1: Write the failing missing-`.envrc` repair test**

  ```bash
  rm -f "$target_checkout/.envrc" "$target_checkout/.envrc.local"

  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --allow >"$tmpdir/envrc-repair.out"

  [ -f "$target_checkout/.envrc" ] || fail 'expected .envrc repair'
  [ -f "$target_checkout/.envrc.local" ] || fail 'expected .envrc.local creation'
  grep -F "allow $target_checkout" "$direnv_log" >/dev/null || fail 'expected direnv allow call'
  grep -F 'ok:' "$tmpdir/envrc-repair.out" >/dev/null || fail 'expected success reporting'
  ```

- [ ] **Step 2: Write the failing missing-`.envrc.local` test**

  ```bash
  rm -f "$target_checkout/.envrc.local"

  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --allow >"$tmpdir/envrc-local-repair.out"

  [ -f "$target_checkout/.envrc.local" ] || fail 'expected .envrc.local recreation'
  grep -F 'ok:' "$tmpdir/envrc-local-repair.out" >/dev/null || fail 'expected success reporting'
  ```

- [ ] **Step 3: Verify RED**

  Run:

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh
  ```

  Expected: FAIL until `--allow` execution exists.

- [ ] **Step 4: Implement the minimal execution path**
  - require `direnv` in `PATH` for real execution;
  - act only on `not allowed`, `unknown`, `missing .envrc (repair+allow pending)`, and `missing .envrc.local (repair+allow pending)`;
  - call `scripts/lib/worktree-env.sh` before `direnv allow` whenever a sidecar repair is needed;
  - skip already-allowed targets unless `--force` is also present.

- [ ] **Step 5: Verify GREEN**

  Run:

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees.sh
  ```

  Expected: PASS.

- [ ] **Step 6: Mandatory refactor checkpoint**
  - one function decides whether a target is actionable;
  - one function performs repair;
  - one function performs allow;
  - no duplicated status strings.

- [ ] **Step 7: Commit the ordinary allow slice**

  ```bash
  git add scripts/lib/allow-direnv-managed-worktrees.sh
  git add tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh
  git commit -m "feat(devspace): repair managed env sidecars before direnv allow"
  ```

---

## Task 4: Add `--force` divergent rewrite behavior and failure continuation

**Files:**
- Create: `tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh`
- Create: `tests/devspace/test_allow_direnv_managed_worktrees_failures.sh`
- Modify: `scripts/lib/allow-direnv-managed-worktrees.sh`

**Interfaces:**
- Consumes: execution path from Task 3
- Produces:
  - `--allow --force` semantics for all eligible managed checkouts
  - final command exit `1` when any target action fails

- [ ] **Step 1: Write the failing divergent-file test**

  ```bash
  printf 'export MANUAL=1\n' > "$divergent_checkout/.envrc"

  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" >"$tmpdir/divergent-dry-run.out"
  grep -F 'divergent .envrc (force required)' "$tmpdir/divergent-dry-run.out" >/dev/null || fail 'expected divergent dry-run status'

  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --allow >"$tmpdir/divergent-allow.out"
  grep -F 'export MANUAL=1' "$divergent_checkout/.envrc" >/dev/null || fail 'allow without force must not rewrite divergent envrc'

  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" bash "$script" --allow --force >"$tmpdir/divergent-force.out"
  ls "$divergent_checkout"/.envrc.bak.* >/dev/null 2>&1 || fail 'expected backup file'
  grep -F 'export HUB_DIR=' "$divergent_checkout/.envrc" >/dev/null || fail 'expected managed envrc after force rewrite'
  ```

- [ ] **Step 2: Write the failing continuation-after-error test**

  ```bash
  set +e
  HUB_WORKSPACE_ROOT="$workspace_root" HOME="$home_dir" DIRENV_FAIL_FOR="$failing_checkout" bash "$script" --allow --force >"$tmpdir/failures.out" 2>&1
  command_rc="$?"
  set -e

  [ "$command_rc" = "1" ] || fail 'expected overall exit 1 when one target fails'
  grep -F 'error:' "$tmpdir/failures.out" >/dev/null || fail 'expected error reporting'
  grep -F "ok: allowed $later_checkout" "$tmpdir/failures.out" >/dev/null || fail 'expected later target to continue'
  ```

- [ ] **Step 3: Verify RED**

  Run:

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_failures.sh
  ```

  Expected: FAIL until force handling and failure aggregation exist.

- [ ] **Step 4: Implement the smallest force/failure changes**
  - in `--allow --force`, include already-allowed targets with existing `.envrc`;
  - treat divergent `.envrc` as actionable only in force mode;
  - continue to later targets after a single `direnv allow` failure;
  - return `1` if any target action failed.

- [ ] **Step 5: Verify GREEN**

  Run:

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_failures.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh
  ```

  Expected: PASS.

- [ ] **Step 6: Mandatory refactor checkpoint**
  - keep failure accounting explicit and centralized;
  - keep force-only rewrite logic separate from ordinary repair logic;
  - keep the output prefixes stable.

- [ ] **Step 7: Commit the force/failure slice**

  ```bash
  git add scripts/lib/allow-direnv-managed-worktrees.sh
  git add tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh tests/devspace/test_allow_direnv_managed_worktrees_failures.sh
  git commit -m "feat(devspace): add forced direnv envrc refresh handling"
  ```

**User Check-in 3:** if real `direnv` trust-state detection proves too brittle to separate `allowed` from `not allowed` portably, pause before shipping parser changes broader than the mocked contract; the approved fallback is `unknown`, not guesswork.

---

## Task 5: Update operator docs and finish verification

**Files:**
- Modify: `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- Review: changed command/test files from Tasks 1-4

**Interfaces:**
- Consumes: final CLI behavior
- Produces: operator runbook coverage for dry-run-first usage and force semantics

- [ ] **Step 1: Update the runbook only after command behavior is green**

  Add a runbook section containing:

  ```bash
  /workspaces/dotfiles/main/bin/allow-direnv-managed-worktrees
  /workspaces/dotfiles/main/bin/allow-direnv-managed-worktrees --allow
  /workspaces/dotfiles/main/bin/allow-direnv-managed-worktrees --allow --force
  ```

  And these bullets:

  - default mode is dry-run only
  - missing managed `.envrc` / `.envrc.local` files are repaired through the managed helper before allow
  - divergent/manual `.envrc` requires `--allow --force`
  - hub-root execution is refused

- [ ] **Step 2: Run the targeted acceptance suite**

  ```bash
  bash tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh
  bash tests/devspace/test_allow_direnv_managed_worktrees_failures.sh
  bash tests/pod-inside-nono/test_new_worktree.sh
  ```

  Expected: all PASS.

- [ ] **Step 3: Collect verification evidence**
  - save the full stdout/stderr for each new test run;
  - capture one dry-run transcript containing all six status classes plus the final `summary:` line;
  - capture one `--allow` transcript showing repair + allow for a missing `.envrc` target;
  - capture one `--allow --force` transcript showing divergent backup creation and rewritten managed content;
  - capture `git diff --stat` and `git status --short` showing only the planned files changed.

- [ ] **Step 4: Run the mandatory refactor and review checkpoint**
  - bin wrapper remains thin;
  - shared library owns path discovery, classification, counting, and execution;
  - `scripts/lib/worktree-env.sh` remains the single authority for managed `.envrc` content;
  - output wording stays operator-readable and consistent;
  - no unrelated files changed.

- [ ] **Step 5: Record the required quality reviews in the handoff note**
  - Clean-code checklist:
    - command wrapper is trivial and readable;
    - each helper function has one job;
    - status strings and summary counters come from one place;
    - no duplicate hub/child metadata logic where existing helpers already provide it;
    - refusal vs usage vs execution failures are clearly separated by exit code.
  - Pragmatic-programmer diagnostic target: `9/10` or better.
    - likely failure rows if score drops: DRY knowledge around `.envrc` generation, orthogonality between discovery and mutation, or missing tracer-bullet verification.
    - remediation if score < `8`: extract duplicated path logic, remove brittle `direnv` parsing, and tighten acceptance evidence.

- [ ] **Step 6: Commit the docs/verification slice**

  ```bash
  git add docs/superpowers/runbooks/devspace-bare-hub-usage.md
  git commit -m "docs(devspace): add allow-direnv managed worktree workflow"
  ```

**Final User Check-in:** before adding any `tests/run.sh` wiring or broadening this helper into a general repair command, stop and ask. Those are separate scope decisions.

---

## Exact local commands for the implementer

### Create the implementation worktree/branch

```bash
bin/new-worktree --repo hub work/allow-direnv-managed-worktrees
```

### Red/green commands by slice

```bash
bash tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh
bash tests/devspace/test_allow_direnv_managed_worktrees.sh

bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh
bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh

bash tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh
bash tests/devspace/test_allow_direnv_managed_worktrees_failures.sh
```

### Final verification commands

```bash
bash tests/devspace/test_allow_direnv_managed_worktrees_refusals.sh
bash tests/devspace/test_allow_direnv_managed_worktrees.sh
bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_repair.sh
bash tests/devspace/test_allow_direnv_managed_worktrees_envrc_local_repair.sh
bash tests/devspace/test_allow_direnv_managed_worktrees_force_repair.sh
bash tests/devspace/test_allow_direnv_managed_worktrees_failures.sh
bash tests/pod-inside-nono/test_new_worktree.sh
git status --short
git diff --stat
```

---

## Risks and pause points

- **Shared-helper risk:** `scripts/lib/worktree-env.sh` is already used by `provision-workspace` and `new-worktree`; any refactor there must preserve current behavior, proved by `bash tests/pod-inside-nono/test_new_worktree.sh`.
- **Layout risk:** `tests/devspace/` is not part of the current aggregated runner layout in this checkout. Do not quietly edit `tests/run.sh`; get an explicit check-in first.
- **Trust-state risk:** use `unknown` when `direnv` state cannot be classified safely. Do not ship a parser that guesses.
- **Rewrite risk:** divergent/manual `.envrc` rewrite is force-only. Any broader rewrite behavior requires a new approval.
- **Scope risk:** keep the helper focused on managed-checkout discovery + repair + allow. Do not turn it into a generic workspace repair command.
