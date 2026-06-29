# HC-7 Bare Hub Guardrails Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the remaining HC-7 doc-contract test so it checks the SSH-related host lifecycle commands in the canonical lifecycle runbook and stops failing on the approved runbook consolidation.

**Architecture:** Keep this slice test-only and minimal. Do not edit either runbook; change only the two stale assertions in `tests/docs/test_bare_hub_guardrails.sh` so the host-side `ssh` and `verify-ssh` checks point at `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`, while every other assertion remains unchanged.

**Tech Stack:** Bash doc-contract test, Markdown runbooks under `docs/superpowers/runbooks/`.

---

## Inputs and authority

- Governing artifact: `docs/superpowers/review-records/2026-06-20-repo-documentation-and-refactor-audit.md`
- Editable repo root: `/workspaces/dotfiles/work/refactor-and-document`
- Requested destination: `docs/superpowers/plans/2026-06-21-hc7-bare-hub-guardrails-fix.md`
- Remaining baseline failure: `tests/docs/test_bare_hub_guardrails.sh`
- Confirmed root cause: P2 moved host SSH/lifecycle commands from `docs/superpowers/runbooks/devspace-bare-hub-usage.md` to `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`, but the test still checks the old location.

## Scope

### In scope

- Update the `ssh -o BatchMode=yes workspace.dotfiles.devspace` assertion to check `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`.
- Update the `devspace run-pipeline verify-ssh` assertion to check `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`.
- Re-run `tests/docs/test_bare_hub_guardrails.sh` before and after the change.

### Out of scope

- No runbook edits.
- No changes to any other assertion in `tests/docs/test_bare_hub_guardrails.sh`.
- No broader test-suite cleanup or unrelated baseline remediation.
- No implementation beyond this one-file, two-line contract update.

## File map

- Modify: `tests/docs/test_bare_hub_guardrails.sh` — repoint the two stale SSH/lifecycle assertions to the lifecycle runbook.
- Reference only: `docs/superpowers/runbooks/devspace-bare-hub-usage.md` — remains the canonical in-pod runbook and should not change in this slice.
- Reference only: `docs/superpowers/runbooks/devspace-workspace-lifecycle.md` — already contains the canonical host-side `ssh` and `verify-ssh` commands.
- Verify only: `bash tests/docs/test_bare_hub_guardrails.sh`

---

## Task 1: Repoint the two stale host-command assertions with tests first

**Files:**
- Modify: `tests/docs/test_bare_hub_guardrails.sh`
- Verify only: `bash tests/docs/test_bare_hub_guardrails.sh`

- [ ] **Step 1: Verify RED on the current baseline**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: FAIL because the test still looks for `ssh -o BatchMode=yes workspace.dotfiles.devspace` and `devspace run-pipeline verify-ssh` in `docs/superpowers/runbooks/devspace-bare-hub-usage.md` even though those host commands now live in `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`.

- [ ] **Step 2: Make the minimal one-file, two-line test fix**

Update only these two assertions in `tests/docs/test_bare_hub_guardrails.sh`:

```diff
-grep -F 'ssh -o BatchMode=yes workspace.dotfiles.devspace' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
-grep -F 'devspace run-pipeline verify-ssh' docs/superpowers/runbooks/devspace-bare-hub-usage.md >/dev/null
+grep -F 'ssh -o BatchMode=yes workspace.dotfiles.devspace' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
+grep -F 'devspace run-pipeline verify-ssh' docs/superpowers/runbooks/devspace-workspace-lifecycle.md >/dev/null
```

- [ ] **Step 3: Verify GREEN on the targeted contract test**

Run:

```bash
bash tests/docs/test_bare_hub_guardrails.sh
```

Expected: `PASS test_bare_hub_guardrails`

- [ ] **Step 4: Commit the minimal HC-7 fix**

```bash
git add tests/docs/test_bare_hub_guardrails.sh
git commit -m "test(docs): fix hc7 bare hub guardrails contract"
```

## User Check-in

If `bash tests/docs/test_bare_hub_guardrails.sh` still fails after the two-line update, stop and ask whether the remaining failure is still in scope for this minimal HC-7 slice before touching any additional assertions or runbooks.
