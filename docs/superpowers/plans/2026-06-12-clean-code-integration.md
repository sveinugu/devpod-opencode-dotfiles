# Clean Code Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate `wondelai/clean-code` into the repo’s coding-task policy, add an explicit post-green refactor checkpoint, and protect the change with drift tests without broadening authority beyond the approved design.

**Architecture:** Treat `.config/opencode/AGENTS.md` as the canonical policy surface, `tests/docs/test_clean_code_policy_contract.sh` as the behavioral drift guard, and `.config/opencode/skills-lock.json` as the required skill-registration surface. Keep this plan high-level to match the current AGENTS planning policy: the approved spec remains the binding source for clean-code requirements, while this plan sequences verification, canonical policy edits, and only the minimum supporting-surface changes warranted by direct drift.

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

## Constraints / policy guardrails

- The approved design at `docs/superpowers/specs/2026-06-12-clean-code-integration-design.md` remains the binding clean-code requirements source.
- The current `.config/opencode/AGENTS.md` planning policy applies to this artifact too: keep the plan high-level, define goals/tests/constraints/risks, and avoid low-level implementation scripting unless the human asks for it.
- `.config/opencode/AGENTS.md` remains canonical if policy and reporting helpers drift.
- `.config/opencode/PULL_REQUEST_TEMPLATE.md` is a reporting aid, not a required second source of truth; update it only if direct reporting drift is found or the human wants it aligned in the same slice.
- Preserve the current delegation/session policy wording and its doc-contract surfaces; this slice is about clean-code integration only.

---

## File map (expected)

**Canonical policy**
- Modify: `.config/opencode/AGENTS.md`

**Drift test**
- Create: `tests/docs/test_clean_code_policy_contract.sh`

**Skill lock**
- Create or modify: `.config/opencode/skills-lock.json`

**Conditional only if direct reporting drift is found**
- Modify: `.config/opencode/PULL_REQUEST_TEMPLATE.md`

**No change expected**
- Preserve: `.config/opencode/opencode.jsonc`
- Preserve: `.config/opencode/agents/maestro.md`
- Preserve: `.config/opencode/agents/senior-implementer.md`

---

## Acceptance criteria (verifiable)

1. `.config/opencode/AGENTS.md` lists `wondelai/clean-code` at priority 3 and moves `obra/superpowers` to priority 4.
2. `.config/opencode/AGENTS.md` requires loading `clean-code` before coding tasks, but does not add it to the always-load block.
3. `.config/opencode/AGENTS.md` contains a named `### Refactor phase policy` section with:
   - mandatory explicit post-green checkpoint,
   - explicit authority ordering,
   - explicit protection of chosen test level and approved scope,
   - explicit post-refactor re-verification requirement.
4. `.config/opencode/AGENTS.md` updates the short recipe to `red → verify red → green → verify green → refactor → verify green` semantics.
5. Post-implementation/reporting policy mentions both the pragmatic-programmer diagnostic and the clean-code checklist/score review.
6. `.config/opencode/skills-lock.json` contains a valid `clean-code` entry using the exact source/path from the design.
7. `tests/docs/test_clean_code_policy_contract.sh` fails before the policy/config edits and passes afterward.
8. Existing doc-contract tests touching `AGENTS.md` still pass after the update.
9. If `.config/opencode/PULL_REQUEST_TEMPLATE.md` is updated in this slice, it stays subordinate to `AGENTS.md` and does not become a second policy source.

---

## Risks and trade-offs

- **Policy/reporting drift:** The canonical AGENTS policy and supporting reporting aids can diverge unless the plan treats AGENTS as authoritative and keeps template updates conditional.
- **Scope creep:** It is easy to expand this slice into broader prompt/template cleanup. The plan should keep non-clean-code policy surfaces unchanged unless verification shows direct drift.
- **Docs-only false confidence:** Because this is a policy/docs slice, the main regression risk is weak verification. The clean-code contract test should anchor the clean-code-specific outcomes rather than relying on unrelated delegation tests alone.
- **Untracked state contamination:** The existing untracked `.config/opencode/.agents/` tree and `skills-lock.json` require staging discipline so unrelated work is not swept into the implementation commits.

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

## Task 1: Add or refresh the clean-code policy contract test first

**Files:**
- Create: `tests/docs/test_clean_code_policy_contract.sh`

- [ ] Start from a failing docs-only contract that checks the approved clean-code outcomes rather than implementation details.
- [ ] Make the test assert the clean-code-specific AGENTS anchors:
  - ordered skill list includes `wondelai/clean-code`,
  - coding-task-only clean-code loading rule exists,
  - `### Refactor phase policy` exists,
  - authority ordering keeps `pragmatic-programmer` above `clean-code`,
  - short recipe includes explicit post-green refactor checkpoint and second green verification,
  - post-implementation/reporting language includes both pragmatic-programmer and clean-code outputs.
- [ ] Make the test assert the clean-code guardrails:
  - the always-load block does **not** add `Agents must always load the "clean-code" skill!`,
  - no project `opencode.json` / `opencode.jsonc` change is required,
  - the refactor checkpoint may explicitly conclude “no refactor needed”.
- [ ] Make the test assert the required supporting surface in `.config/opencode/skills-lock.json`, and treat any PR-template assertion as conditional on whether that file is intentionally updated in this slice.
- [ ] Re-run the current AGENTS-related docs tests after adding the new contract so clean-code coverage augments, rather than accidentally contradicts, the newer delegation-policy checks.
- [ ] Commit the failing/initial verification coverage before policy edits.

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
- [ ] Re-run the clean-code contract test and the existing AGENTS-related docs tests once the canonical wording is updated.
- [ ] **User Check-in:** if the AGENTS wording must diverge materially from the approved design to fit the current policy structure, pause for approval before finalizing the secondary surfaces.

**Suggested commit:**
- `docs(policy): integrate clean-code refactor policy`

**Verification:**
- `bash tests/docs/test_clean_code_policy_contract.sh`
- `bash tests/docs/test_bare_hub_guardrails.sh`
- `bash tests/docs/test_delegation_packet_policy_contract.sh`
- `bash tests/docs/test_maestro_intent_preservation_policy.sh`

---

## Task 3: Align required supporting surfaces; keep reporting-helper edits conditional

**Files:**
- Create or modify: `.config/opencode/skills-lock.json`
- Modify only if needed: `.config/opencode/PULL_REQUEST_TEMPLATE.md`

- [ ] Add the `clean-code` skill entry to `.config/opencode/skills-lock.json` with:
  - `source: "wondelai/skills"`
  - `sourceType: "github"`
  - `skillPath: "clean-code/SKILL.md"`
- [ ] If the repository already has a lock-generation/hash workflow, use it instead of inventing a hash; otherwise preserve the file’s current conventions and document the chosen approach in the handoff.
- [ ] Update `.config/opencode/PULL_REQUEST_TEMPLATE.md` only if implementation finds direct reporting drift worth fixing in the same slice.
- [ ] If the template is updated, keep the change minimal and explicitly subordinate to the canonical AGENTS policy.
- [ ] Validate the JSON after editing the lock file.
- [ ] Re-run the clean-code contract test and confirm it is fully green.
- [ ] **User Check-in:** if the implementation wants to change the PR template for convenience rather than direct drift, ask whether to keep that as part of this slice or defer it.

**Suggested commit:**
- `chore(config): lock clean-code skill`
- Optional if template changed: `docs(template): align clean-code reporting`

**Verification:**
- `python -m json.tool .config/opencode/skills-lock.json >/dev/null`
- `bash tests/docs/test_clean_code_policy_contract.sh`

---

## Task 4: Final verification, review evidence, and handoff

**Files:**
- Review only: `.config/opencode/AGENTS.md`
- Review only: `.config/opencode/skills-lock.json`
- Review only: `tests/docs/test_clean_code_policy_contract.sh`
- Review only if changed: `.config/opencode/PULL_REQUEST_TEMPLATE.md`

- [ ] Run the targeted clean-code policy contract test again from a clean shell.
- [ ] Re-run the existing AGENTS-related doc tests to ensure this policy change did not break older guarantees.
- [ ] Inspect `git diff --stat` and a targeted `git diff --` for only the intended files.
- [ ] Record the pragmatic-programmer quick diagnostic and the clean-code review outcome in the implementation handoff/PR summary, including remediation tasks if either review demands them.
- [ ] Present the changed policy and template surfaces to the human for review before any merge/push step.

**Verification:**
- `bash tests/docs/test_clean_code_policy_contract.sh && bash tests/docs/test_bare_hub_guardrails.sh && bash tests/docs/test_delegation_packet_policy_contract.sh && bash tests/docs/test_maestro_intent_preservation_policy.sh`
- `git diff -- .config/opencode/AGENTS.md .config/opencode/PULL_REQUEST_TEMPLATE.md .config/opencode/skills-lock.json tests/docs/test_clean_code_policy_contract.sh`

---

## Final verification checklist

- [ ] `bash tests/docs/test_clean_code_policy_contract.sh`
- [ ] `bash tests/docs/test_bare_hub_guardrails.sh`
- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `bash tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] `git diff -- .config/opencode/AGENTS.md .config/opencode/skills-lock.json tests/docs/test_clean_code_policy_contract.sh`
- [ ] If the template changed, review `git diff -- .config/opencode/PULL_REQUEST_TEMPLATE.md` separately and confirm it still acts only as a reporting aid.

## Pragmatic Programmer diagnostic (target score ≥ 8/10)

- **DRY:** keep the clean-code policy authoritative in AGENTS; avoid forcing the PR template to become a duplicate policy source.
- **Orthogonality:** separate canonical policy, skill-lock registration, and doc-contract verification so future policy edits can change one surface with predictable verification fallout.
- **Reversibility:** keep the template change optional and the plan high-level so later reviewers can tighten or defer supporting aids without reopening the clean-code policy decision.

---

## Notes for the implementer

- Keep the change surgical: this slice is policy + reporting + lock file + doc test only.
- Do not edit `.config/opencode/opencode.jsonc`; the design explicitly says no project config change is required.
- Do not “upgrade” clean-code into a global authority. The acceptance test should make that impossible to do accidentally.
- Treat the doc-contract test as the primary TDD artifact for this feature.
- Prefer the existing AGENTS-related tests as compatibility checks, but let the new clean-code contract test carry the clean-code-specific assertions.
