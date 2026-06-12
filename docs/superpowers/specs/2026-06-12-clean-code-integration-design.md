# Clean Code Integration + Standalone Refactor Phase Design

Date: 2026-06-12  
Status: Proposed

Binding policy source: `/workspaces/dotfiles/work/delegation-policy-consolidation-rebase/.config/opencode/AGENTS.md`

## Summary

This design adds `wondelai/clean-code` to the repository skill priority list, requires agents to load it for all coding tasks, makes refactoring a mandatory standalone TDD phase after green, and assigns `clean-code` to govern refactor-quality guidance during that phase.

The policy remains explicit that user instructions and repository policy win, and that `pragmatic-programmer` overrules `clean-code` if they conflict, including during refactoring. The design also adds a required clean-code checklist/score to review and post-implementation reporting.

## Goals

- Add `wondelai/clean-code` as priority 3 in the AGENTS skill list.
- Require `clean-code` to be loaded for all coding tasks.
- Make refactor a first-class, mandatory checkpoint after green for every TDD slice.
- Keep test-level selection governed by repository policy plus `pragmatic-programmer`.
- Make the authority ordering explicit, including `pragmatic-programmer > clean-code` on conflict.
- Add clean-code checklist/score reporting to reviews and post-implementation output.

## Non-goals

- Do not require `clean-code` for non-coding sessions such as pure brainstorming or delegation-only work.
- Do not let `clean-code` change test-level choice, approved scope, or tests-first discipline.
- Do not require a project `opencode.json` or `opencode.jsonc` change for this policy.

## Chosen approach

Use a formal named section in `AGENTS.md` for the refactor phase rather than only editing the short TDD recipe.

This keeps the policy easy to read later: test-level choice remains a repository/pragmatic-programmer concern, tests-first sequencing remains a superpowers concern, `clean-code` is present for all coding work, and refactor quality remains a named clean-code-governed phase.

## Authority ordering

The policy should say this precisely:

1. User instructions always win.
2. Repository policy in `AGENTS.md` always wins over skills.
3. `pragmatic-programmer` governs test-level selection, tracer-bullet scope, overall design trade-offs, and any conflict about refactoring choices.
4. `karpathy-guidelines` remains a cross-cutting aid for simplicity, ambiguity handling, and surgical changes, but does not override user instructions, repository policy, or `pragmatic-programmer`.
5. `obra/superpowers` governs process discipline such as brainstorming, planning, and tests-first TDD sequencing, except where repository policy narrows or overrides that workflow.
6. `clean-code` must be loaded for all coding tasks. It provides code-quality guidance throughout coding work, and governs refactor-quality guidance most directly during the standalone refactor phase. It may override conflicting `superpowers` quality/cleanup guidance, but it must yield to user instructions, repository policy, approved artifacts, `pragmatic-programmer`, and the chosen test level.

## Required AGENTS.md edits

### 1. Skill priority list

Replace:

```md
The configuration imports the following skills, in prioritized order:

- wondelai/pragmatic-programmer
- oc-plugin-karpathy-guidelines
- obra/superpowers
```

With:

```md
The configuration imports the following skills, in prioritized order:

- wondelai/pragmatic-programmer
- oc-plugin-karpathy-guidelines
- wondelai/clean-code
- obra/superpowers
```

### 2. Auto-loaded skills block

Keep the existing auto-loaded block unchanged, but append a coding-task rule immediately after it:

```md
Agents must load the "clean-code" skill before starting any coding task, including implementation, refactoring, code review, and post-implementation review.
```

### 3. Post-implementation review/reporting bullet

Replace:

```md
- Before marking a feature done, run pragmatic-programmer quick diagnostic; append score and 1–3 remediation tasks to PR if score < 8.
```

With:

```md
- Before marking a feature done, run the pragmatic-programmer quick diagnostic and a clean-code checklist/score review. Append both results to the PR, review summary, or handoff note. If the pragmatic-programmer score is < 8, append 1–3 remediation tasks. If the clean-code review finds material issues, append 1–3 cleanup/remediation tasks or explicitly justify why they are deferred.
```

### 4. New named section: `Refactor phase policy`

Insert after the existing `### Concrete policies` bullet list:

```md
### Refactor phase policy

- After reaching green, agents MUST enter a standalone refactor phase for every TDD slice.
- This refactor phase is a mandatory checkpoint even when the agent expects no code changes. The agent may conclude that no refactoring is needed, but the checkpoint itself MUST still happen explicitly.
- The refactor phase should review the changed slice and nearby connected code for maintainability improvements that preserve behavior, including naming, duplication, boundaries, readability, and small local cleanups that reduce future change cost.
- Agents must load the "clean-code" skill before starting any coding task, including implementation, refactoring, code review, and post-implementation review.
- Authority ordering for TDD and refactoring: user instructions and repository policy always win. Repository policy plus `pragmatic-programmer` govern test-level selection, tracer-bullet scope, overall design trade-offs, and conflict resolution for refactoring choices. `karpathy-guidelines` remains a cross-cutting aid for simplicity, ambiguity handling, and surgical changes, but does not override higher-priority policy or `pragmatic-programmer`. `obra/superpowers` governs tests-first execution discipline (`red → verify red → green → verify green → refactor → verify green`). `clean-code` is loaded for all coding tasks and governs refactor-quality guidance most directly during the standalone refactor phase. It may override conflicting `superpowers` guidance about cleanup technique or code-quality heuristics. If `clean-code` conflicts with `pragmatic-programmer`, `pragmatic-programmer` wins.
- `clean-code` MUST NOT override user instructions, repository policy, approved artifacts, the chosen test level, or the requirement to keep behavior protected by tests.
- The refactor phase should end with an explicit clean-code review outcome: either the applied refactors, or an explicit conclusion that no refactor was needed, plus any follow-up cleanup items discovered during the checkpoint.
- After refactoring, agents MUST rerun the relevant tests and keep behavior green. If the refactor would require behavior changes or a hard-to-reverse architectural shift outside the approved slice, pause and ask the human partner before proceeding.
```

### 5. Short TDD recipe replacement

Replace:

```md
### How to reconcile in practice (short recipe for agents)

1. Brainstorm → write lightweight design and define tracer bullet (verification: design committed).
2. Plan → select tech stack, break down into verifiable tasks, define acceptance tests, describe the task with enough detail to be implemented by a specialist subagent.
2. Choose test level for tracer bullet (integration/contract preferred for E2E; unit for focused logic).
3. TDD at chosen level: write failing test, watch fail, implement minimal code, refactor.
4. Post-implementation: run pragmatic-programmer diagnostic, score, and add remediation if needed.
5. If prototype used, ensure it lives in worktree and is removed/converted before merge.
```

With:

```md
### How to reconcile in practice (short recipe for agents)

1. Brainstorm → write lightweight design and define tracer bullet (verification: design committed).
2. Plan → select tech stack, break down into verifiable tasks, define acceptance tests, describe the task with enough detail to be implemented by a specialist subagent.
3. Choose test level for the tracer bullet (integration/contract preferred for E2E; unit for focused logic).
4. TDD at the chosen level → write a failing test, watch it fail, implement minimal code, and verify green.
5. Coding work → keep `clean-code` loaded while implementing and reviewing code quality.
6. Refactor phase → perform the mandatory refactor checkpoint on the changed slice and connected code, refactor if warranted or explicitly conclude that no refactor is needed, then verify green again.
7. Post-implementation → run the pragmatic-programmer diagnostic and the clean-code checklist/score review; record results and remediation tasks in the PR, review summary, or handoff note if needed.
8. If a prototype was used, ensure it lives in a worktree and is removed or converted before merge.
```

### 6. PR reporting template policy adjustment

Append this bullet under `### PR reporting template policy`:

```md
- When relevant, PR descriptions, review summaries, or handoff notes should include the pragmatic-programmer score, the clean-code checklist/score outcome, and any resulting remediation or cleanup follow-up items.
```

## Required config changes

### `.config/opencode/skills-lock.json`

Add this entry under `skills`:

```json
"clean-code": {
  "source": "wondelai/skills",
  "sourceType": "github",
  "skillPath": "clean-code/SKILL.md"
}
```

If the repository’s lock workflow computes skill hashes, the final implementation should generate the correct `computedHash` instead of inventing one in the document edit.

### `opencode.json` / `opencode.jsonc`

No project config edit is required for this change. The current repository state does not show a project `opencode.json` or `opencode.jsonc`, and this design only needs policy plus skill-lock updates.

## Acceptance criteria

- `AGENTS.md` lists `wondelai/clean-code` at priority 3 and moves `obra/superpowers` to priority 4.
- `AGENTS.md` requires loading `clean-code` before starting any coding task, including implementation, refactoring, code review, and post-implementation review.
- `AGENTS.md` does not globally auto-load `clean-code` for non-coding sessions.
- `AGENTS.md` contains a named `### Refactor phase policy` section.
- The policy makes refactor a mandatory explicit checkpoint after green, even when no code changes are made.
- The policy explicitly states that `pragmatic-programmer` overrides `clean-code` on conflict, including during refactoring.
- The policy allows `clean-code` to override only conflicting `superpowers` refactor-quality guidance.
- The short recipe includes a standalone refactor phase and post-refactor verification.
- Post-implementation and review reporting includes both pragmatic-programmer and clean-code review outputs.
- `.config/opencode/skills-lock.json` adds the `clean-code` skill entry.
- No `opencode.json` or `opencode.jsonc` edit is required.

## Risks

- **Risk: clean-code is treated as a global authority over all tasks instead of a coding-task authority.**  
  Mitigation: require it for coding tasks while explicitly excluding pure brainstorming, planning-only, and delegation-only work.

- **Risk: agents skip the explicit refactor checkpoint when no edits are needed.**  
  Mitigation: require a reported clean-code outcome even when the result is “no refactor needed.”

- **Risk: refactor-quality guidance changes test scope or architecture without review.**  
  Mitigation: keep test-level authority with repository policy plus `pragmatic-programmer`, and require a pause before behavior changes or hard-to-reverse shifts.
