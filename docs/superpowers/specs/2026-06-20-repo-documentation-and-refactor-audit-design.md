# Repo Documentation + Refactor Audit Design

Date: 2026-06-20  
Status: Proposed

Relevant policy source: `/workspaces/dotfiles/work/refactor-and-document/.config/opencode/AGENTS.md`

## Summary

This design defines the first slice for the requested documentation and refactoring program as a combined governing audit/spec.

The audit will assess the current repository state surface-by-surface, inventory documentation gaps and readability/refactor hotspots, and turn those findings into a sequenced roadmap of follow-on slices. The audit is balanced across users/operators, developers, and agents, but it is organized by repository surface so the outputs map directly to real files and workflows.

Broad policy cleanup is out of scope. Small enabling policy improvements are allowed only when they directly support better documentation, readability, or safer future refactoring.

## Goals

- Inventory the current documentation surfaces and identify the highest-value gaps.
- Inventory the current clean-code/refactor hotspots that materially hurt readability or maintainability.
- Assess findings across users/operators, developers, and agents without turning the audit into three separate workstreams.
- Produce a small, sequenced roadmap of follow-on documentation and refactoring slices.
- Keep future planning grounded in current repository evidence rather than assumptions.

## Non-goals

- Do not perform the documentation updates or code refactors in this design slice.
- Do not open a broad policy cleanup or policy rewrite project.
- Do not treat policy as a primary workstream.
- Do not prescribe speculative architectural changes unrelated to current repo pain.
- Do not encourage repo-wide cleanup that is not tied to clear hotspots.

## Chosen approach

Use a surface-first audit with a balanced audience lens.

This structure fits the repository better than an audience-first or risk-first document because the main current problem appears to be uneven entry points, uneven discoverability, and a few concentrated shell/script hotspots. A surface-first structure keeps the audit anchored to concrete files such as `README.md`, runbooks, `install.sh`, and the `bin/` command layer, while still recording which audiences are affected by each issue.

## Scope boundaries

### In scope

- Missing, thin, fragmented, or hard-to-navigate documentation.
- Existing documentation that is strong in isolation but poorly surfaced or weakly cross-linked.
- Clean-code hotspots where naming, function size, mixed abstraction levels, duplication, or orchestration density make maintenance harder.
- Follow-on documentation slices, refactor slices, and combined slices.
- Small enabling policy improvements when they are tightly justified by documentation/readability needs.

### Out of scope

- Broad policy cleanup, policy rewrites for their own sake, or policy-only slices.
- Immediate implementation of the resulting documentation or refactor roadmap.
- Large speculative architecture changes not supported by current evidence.
- Low-value micro-cleanup that does not materially improve clarity or maintainability.

### Policy exception rule

If the audit finds low-hanging-fruit policy issues that materially contribute to poor documentation or readability behavior, they may be included only as subordinate supporting work. The audit must not let those findings grow into a parallel policy program.

## Surfaces to audit

### 1. Entry and orientation surfaces

Examples:

- `README.md`
- top-level install and DevSpace entry points
- high-level orientation paths for new readers

Likely concerns:

- weak top-level onboarding
- missing audience-specific entry guidance
- insufficient links into stronger downstream docs

### 2. Operational and runbook surfaces

Examples:

- `docs/superpowers/runbooks/devspace-bare-hub-usage.md`
- `docs/superpowers/runbooks/devspace-workspace-lifecycle.md`
- host/bootstrap runbooks

Likely concerns:

- better content depth than the top-level entry points
- discoverability and overlap problems
- unclear "when to use which runbook" guidance

### 3. Developer command and workflow surfaces

Examples:

- `install.sh`
- `bin/new-worktree`
- `bin/dre`
- `bin/dwt`
- major `scripts/` and `scripts/lib/` flows behind them

Likely concerns:

- command behavior described more clearly in tests than in user-facing docs
- concentrated shell-script readability hotspots
- orchestration-heavy files that mix parsing, validation, environment setup, and user messaging

### 4. Agent-facing guidance and orientation surfaces

Examples:

- `.config/opencode/AGENTS.md`
- related docs under `docs/superpowers/`
- orientation/indexing aids for agent readers

Likely concerns:

- strong policy density
- weaker discoverability/orientation than policy detail
- small guidance nudges that may better reinforce documentation and readability behavior

## Audit method

For each surface, the audit will record the same fields so findings remain comparable.

### Per-surface template

1. **Current role** — what the surface is supposed to help someone do.
2. **Primary audiences** — users/operators, developers, agents.
3. **Current assets** — docs, commands, scripts, tests, or guidance already covering the surface.
4. **Documentation gaps** — missing entry points, weak framing, weak cross-links, density problems, or outdated framing.
5. **Readability/refactor hotspots** — large files, mixed abstraction levels, unclear names, duplication, or multi-purpose flows.
6. **Risk of change** — low / medium / high.
7. **Recommended slice type** — doc-only, refactor-only, combined, or small enabling policy touchup.

### Evidence sources

The audit should prefer observable repository evidence:

- top-level repo files
- runbooks and existing specs/plans where relevant
- `bin/` and `scripts/` command surfaces
- tests as indicators of intended behavior and workflow contracts
- agent-facing guidance as evidence of current orientation burden and density

The audit should avoid inventing intended usage where the repository does not support it.

## Prioritization model

Findings should be ranked with four practical factors:

1. **Audience impact** — how many audiences are affected and how severely.
2. **Task-blocking severity** — whether the issue slows onboarding, safe operation, maintenance, or agent execution.
3. **Change leverage** — whether one fix would improve multiple surfaces or audiences.
4. **Implementation safety** — whether the likely follow-on change is local and reversible or broad and risky.

### Priority buckets

- **P1 — foundation blockers**: high-impact issues that distort onboarding, comprehension, or safe change.
- **P2 — important structural improvements**: important soon, but not blocking the first follow-on slice.
- **P3 — opportunistic cleanups**: useful, but best grouped with nearby work.
- **Supporting policy nudge**: a narrowly scoped policy/guidance adjustment that directly enables better future documentation or refactoring.

## Expected outputs of the audit

The governing audit/spec should produce:

1. A surface inventory of the current repository state.
2. A documentation gap inventory with affected audiences and likely fix types.
3. A clean-code hotspot inventory with likely refactor shapes and risk levels.
4. A prioritized set of follow-on slices.
5. A sequencing rationale explaining why certain slices come first.

## Follow-on slice model

The first audit/spec should not collapse all work into one implementation plan. It should identify a small roadmap of slice types such as:

1. **Docs foundation slice** — improve top-level orientation and route readers into the right runbooks and command references.
2. **Docs navigation slice** — reduce overlap and improve cross-linking across existing documentation.
3. **Refactor hotspot slice: install/bootstrap path** — clean up the largest readability hotspot under characterization-test protection.
4. **Refactor hotspot slice: worktree/navigation path** — clean up the next most important workflow scripts.
5. **Small enabling policy/guidance slice** — only if clearly justified by repeated documentation/readability ambiguity.

## Initial likely findings to validate

These are hypotheses to validate during the audit, not pre-approved conclusions:

- `README.md` is likely the clearest documentation foundation gap because it is much thinner than the surrounding runbooks.
- Existing runbooks likely contain substantial useful content but need better top-level surfacing and navigational framing.
- `install.sh` is likely the strongest initial readability hotspot because it combines argument parsing, source detection, validation, state writing, shell guidance, dependency setup, symlink management, and OpenCode bootstrap.
- `bin/new-worktree` is likely the next most important workflow refactor candidate because it combines CLI parsing, repo inference, repo branching rules, worktree creation, environment bootstrapping, and lane registry binding.
- Smaller focused files such as `scripts/lib/resolve-install-target.sh` are useful examples of the style the later refactor slices should preserve.

## Recommended sequencing

The roadmap should prefer this order unless the audit finds stronger contrary evidence:

1. clarify entry-point orientation
2. improve documentation navigation and cross-linking
3. refactor the highest-leverage readability hotspot
4. refactor the next workflow hotspot
5. include small supporting policy nudges only where they reduce repeated future mistakes

This sequencing makes the repository easier to understand before it tackles the highest-cost code cleanup work.

## Success criteria

This design is successful if the resulting audit/spec lets a later planner or implementer answer all of the following without guesswork:

- what the biggest documentation gaps are
- what the biggest readability/refactor hotspots are
- which issues affect users/operators, developers, and agents
- what the first, second, and later follow-on slices should be
- which policy changes are out of scope and which small enabling nudges may still be allowed

## Risks

- **Risk: the audit becomes too broad and turns into a pseudo-implementation plan.**  
  Mitigation: keep findings at the level of surfaces, hotspots, priorities, and follow-on slices.

- **Risk: policy work crowds out documentation and refactoring work.**  
  Mitigation: keep policy subordinate and allow only tightly justified supporting nudges.

- **Risk: hotspot ranking overfits first impressions.**  
  Mitigation: treat early hotspot statements as hypotheses to validate against direct file and test evidence.

- **Risk: the roadmap optimizes for one audience at the expense of the others.**  
  Mitigation: keep a balanced audience lens inside every surface section.

## User check-ins

### User Check-in 1

Review and approve this governing audit/spec before writing the implementation plan.

### User Check-in 2

When the later plan is written, confirm which follow-on slice should execute first: docs foundation, docs navigation, install/bootstrap refactor, worktree/navigation refactor, or a justified small supporting policy nudge.
