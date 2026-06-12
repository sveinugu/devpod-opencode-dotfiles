# Clean Code Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate `wondelai/clean-code` into the repo’s coding-task policy, add an explicit post-green refactor checkpoint, and protect the change with drift tests without broadening authority beyond the approved design.

**Architecture:** Treat `.config/opencode/AGENTS.md` as the canonical policy surface, `tests/docs/test_clean_code_policy_contract.sh` as the behavioral drift guard, `.config/opencode/skills-lock.json` as the skill registration surface, and `.config/opencode/PULL_REQUEST_TEMPLATE.md` as the reporting helper that should stay aligned with policy. Keep test-level choice and overall trade-offs anchored to existing repository policy plus `pragmatic-programmer`; `clean-code` only governs coding-task quality guidance, especially during the standalone refactor phase.

**Tech Stack:** Markdown policy docs, JSON config, bash + ripgrep (`rg`) doc-contract tests, git.

---

## Inputs / binding artifacts

- Approved design: `docs/superpowers/specs/2026-06-12-clean-code-integration-design.md`
- Canonical policy source: `.config/opencode/AGENTS.md`
- Reporting helper: `.config/opencode/PULL_REQUEST_TEMPLATE.md`
- Skill lock: `.config/opencode/skills-lock.json`

## Scope

### In scope

1. Add `wondelai/clean-code` to the policy skill priority list.
2. Require `clean-code` for coding tasks without globally auto-loading it for non-coding sessions.
3. Add a named standalone refactor-phase policy after green.
4. Preserve authority ordering, especially `pragmatic-programmer > clean-code` on conflict.
5. Add/align reporting surfaces for pragmatic-programmer + clean-code review outputs.
6. Add a focused doc-contract test that fails if the clean-code policy drifts.
7. Add the `clean-code` skill entry to `.config/opencode/skills-lock.json`.

### Out of scope

- Any implementation/runtime enforcement beyond policy and drift tests.
- Any change to project `opencode.json` / `opencode.jsonc`.
- Any change to delegation/session policy or unrelated agent prompts.
- Any edits under the currently untracked `.config/opencode/.agents/` tree unless the human explicitly expands scope.

---

## File map (expected)

**Canonical policy**
- Modify: `.config/opencode/AGENTS.md`

**Drift test**
- Create: `tests/docs/test_clean_code_policy_contract.sh`

**Reporting helper**
- Modify: `.config/opencode/PULL_REQUEST_TEMPLATE.md`

**Skill lock**
- Create or modify: `.config/opencode/skills-lock.json`

**No change expected**
- Preserve: `.config/opencode/opencode.jsonc`
- Preserve: `.config/opencode/agents/maestro.md`
- Preserve: `.config/opencode/agents/senior-implementer.md`

---

## Success criteria (verifiable)

1. `.config/opencode/AGENTS.md` lists `wondelai/clean-code` at priority 3 and moves `obra/superpowers` to priority 4.
2. `.config/opencode/AGENTS.md` requires loading `clean-code` before coding tasks, but does not add it to the always-load block.
3. `.config/opencode/AGENTS.md` contains a named `### Refactor phase policy` section with:
   - mandatory explicit post-green checkpoint,
   - explicit authority ordering,
   - explicit protection of chosen test level and approved scope,
   - explicit post-refactor re-verification requirement.
4. `.config/opencode/AGENTS.md` updates the short recipe to `red → verify red → green → verify green → refactor → verify green` semantics.
5. Post-implementation/reporting policy mentions both the pragmatic-programmer diagnostic and the clean-code checklist/score review.
6. `.config/opencode/PULL_REQUEST_TEMPLATE.md` gives implementers a place to record the clean-code review outcome alongside existing pragmatic evidence.
7. `.config/opencode/skills-lock.json` contains a valid `clean-code` entry using the exact source/path from the design.
8. `tests/docs/test_clean_code_policy_contract.sh` fails before the policy/config edits and passes afterward.
9. Existing doc-contract tests touching `AGENTS.md` still pass after the update.

---

## Task 0: Preflight and slice control

**Why:** This branch already contains unrelated untracked state. The implementation slice should stay narrowly scoped to the approved policy change.

**Files:**
- Observe only: `.config/opencode/.agents/`
- Observe only: `.config/opencode/skills-lock.json`

- [ ] Confirm the binding design exists on the current branch.
- [ ] Inspect `git status --short` and record which untracked files are pre-existing before any edits.
- [ ] Treat `.config/opencode/.agents/` as out of scope and do not stage it.
- [ ] Decide whether `.config/opencode/skills-lock.json` is being created or updated on this branch, then keep the later commit limited to the intended lock-file content.

**Verification:**
- `git status --short`
- `test -f docs/superpowers/specs/2026-06-12-clean-code-integration-design.md`

---

## Task 1: Add the failing clean-code policy contract test

**Files:**
- Create: `tests/docs/test_clean_code_policy_contract.sh`

- [ ] Write a focused doc-contract test that checks the approved policy outcomes, not implementation details.
- [ ] Make the test assert these anchors in `.config/opencode/AGENTS.md`:
  - skill priority list contains `wondelai/clean-code`,
  - coding-task-only clean-code loading rule exists,
  - `### Refactor phase policy` exists,
  - authority ordering states `pragmatic-programmer` wins on conflict,
  - short recipe includes explicit refactor checkpoint and second green verification,
  - post-implementation reporting includes both pragmatic-programmer and clean-code outputs.
- [ ] Make the test assert these guardrails:
  - the always-load block does **not** add `Agents must always load the "clean-code" skill!`,
  - no project `opencode.json` / `opencode.jsonc` requirement is introduced,
  - the refactor checkpoint can explicitly conclude “no refactor needed”.
- [ ] Make the test assert supporting surfaces:
  - `.config/opencode/skills-lock.json` contains the `clean-code` skill entry with `source`, `sourceType`, and `skillPath`,
  - `.config/opencode/PULL_REQUEST_TEMPLATE.md` includes clean-code review/reporting space if this slice updates the template.
- [ ] Run the new test by itself and watch it fail for the expected missing-policy reasons.
- [ ] Commit the failing test first.

**Suggested commit:**
- `test(docs): add clean-code policy contract`

**Verification:**
- `bash tests/docs/test_clean_code_policy_contract.sh`

---

## Task 2: Update the canonical policy in `.config/opencode/AGENTS.md`

**Files:**
- Modify: `.config/opencode/AGENTS.md`

- [ ] Insert `wondelai/clean-code` into the ordered skill list exactly where the design requires it.
- [ ] Leave the existing always-load block intact, then add the coding-task-only clean-code loading rule immediately after it.
- [ ] Replace the current post-implementation review bullet with the expanded pragmatic-programmer + clean-code reporting rule from the design.
- [ ] Add the new `### Refactor phase policy` section after `### Concrete policies`, using the design’s required authority ordering and non-goals verbatim enough to avoid drift.
- [ ] Replace the short recipe so the sequence explicitly includes: choose test level, verify red, verify green, standalone refactor checkpoint, verify green again, then post-implementation reporting.
- [ ] Append the PR-reporting-template-policy bullet that calls for pragmatic-programmer score, clean-code checklist/score outcome, and follow-up items when relevant.
- [ ] Re-run the new contract test and confirm the remaining failures, if any, are limited to still-pending supporting-surface work.
- [ ] Commit the policy update once the AGENTS-specific assertions are green.

**Suggested commit:**
- `docs(policy): integrate clean-code refactor policy`

**Verification:**
- `bash tests/docs/test_clean_code_policy_contract.sh`
- `bash tests/docs/test_bare_hub_guardrails.sh`
- `bash tests/docs/test_delegation_packet_policy_contract.sh`
- `bash tests/docs/test_maestro_intent_preservation_policy.sh`

**User Check-in:** If the AGENTS wording needs to diverge materially from the approved design to fit existing policy structure, pause and get approval before inventing new wording.

---

## Task 3: Align supporting reporting and lock-file surfaces

**Files:**
- Modify: `.config/opencode/PULL_REQUEST_TEMPLATE.md`
- Create or modify: `.config/opencode/skills-lock.json`

- [ ] Add a clean-code reporting subsection to `.config/opencode/PULL_REQUEST_TEMPLATE.md` so the template reflects the new policy without removing the existing pragmatic-programmer evidence.
- [ ] Add a small refactor-checkpoint evidence prompt to the template (applied refactors or explicit “no refactor needed” outcome) so the mandatory checkpoint is reportable.
- [ ] Add the `clean-code` skill entry to `.config/opencode/skills-lock.json` with:
  - `source: "wondelai/skills"`
  - `sourceType: "github"`
  - `skillPath: "clean-code/SKILL.md"`
- [ ] If the repository already has a lock-generation/hash workflow, use it instead of inventing a hash; otherwise preserve the file’s current conventions and document the chosen approach in the handoff.
- [ ] Validate the JSON after editing the lock file.
- [ ] Re-run the clean-code contract test and confirm it is fully green.
- [ ] Commit the supporting-surface changes.

**Suggested commit:**
- `docs(template): align clean-code reporting`
- `chore(config): lock clean-code skill`

**Verification:**
- `python -m json.tool .config/opencode/skills-lock.json >/dev/null`
- `bash tests/docs/test_clean_code_policy_contract.sh`

**User Check-in:** If adding the template section feels broader than the approved slice, ask whether to keep it here or track it as an immediate follow-up. The recommended default is to keep it here to avoid policy/template drift.

---

## Task 4: Final verification, review evidence, and handoff

**Files:**
- Review only: `.config/opencode/AGENTS.md`
- Review only: `.config/opencode/PULL_REQUEST_TEMPLATE.md`
- Review only: `.config/opencode/skills-lock.json`
- Review only: `tests/docs/test_clean_code_policy_contract.sh`

- [ ] Run the targeted clean-code policy contract test again from a clean shell.
- [ ] Re-run the existing AGENTS-related doc tests to ensure this policy change did not break older guarantees.
- [ ] Inspect `git diff --stat` and a targeted `git diff --` for only the intended files.
- [ ] Record the pragmatic-programmer quick diagnostic and the clean-code review outcome in the implementation handoff/PR summary, including remediation tasks if either review demands them.
- [ ] Present the changed policy and template surfaces to the human for review before any merge/push step.

**Verification:**
- `bash tests/docs/test_clean_code_policy_contract.sh && bash tests/docs/test_bare_hub_guardrails.sh && bash tests/docs/test_delegation_packet_policy_contract.sh && bash tests/docs/test_maestro_intent_preservation_policy.sh`
- `git diff -- .config/opencode/AGENTS.md .config/opencode/PULL_REQUEST_TEMPLATE.md .config/opencode/skills-lock.json tests/docs/test_clean_code_policy_contract.sh`

---

## Notes for the implementer

- Keep the change surgical: this slice is policy + reporting + lock file + doc test only.
- Do not edit `.config/opencode/opencode.jsonc`; the design explicitly says no project config change is required.
- Do not “upgrade” clean-code into a global authority. The acceptance test should make that impossible to do accidentally.
- Treat the doc-contract test as the primary TDD artifact for this feature.
