# Maestro Intent-Preservation Mitigations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce intent evaporation during Maestro-to-subagent delegation by making handoffs lossless, scope-explicit, provenance-labeled, and biased toward resuming existing sessions instead of reinterpreting or respawning work.

**Architecture:** Treat delegation as a documented packet contract shared by `.config/opencode/AGENTS.md`, the Maestro prompt, and the subagent handoff templates. Implement the contract in priority order: first preserve the exact artifact path, active slice, verbatim user context, and explicit deliverables; then add subagent restatement and resume-routing bias; finally add ergonomic preview and rollout enforcement.

**Tech Stack:** Markdown policy docs, agent prompt markdown, shell contract tests, `rg`, `git`.

---

## Policy baseline

- Planner owns this plan artifact and the commit for this plan update.
- This plan covers policy/prompt/template changes only. It does **not** implement runtime router code, exported transcript code, or unrelated agent rewrites.
- The already-discussed mitigation set is treated as the approved design basis for this plan.

## Why this plan exists

The failure mode is not mainly “missing session ids” anymore; it is **intent evaporation** between the human, Maestro, and the delegated subagent.

The practical problem is that a weaker Maestro can unintentionally compress away key instructions when delegating. When that happens, the subagent may receive a cleaned-up summary instead of the exact scope the user approved. The mitigation strategy here is to make delegation more like a lossless packet than a narrative reinterpretation.

## Priority summary

| Priority | Mitigation | Why it comes first |
| --- | --- | --- |
| **P0** | Exact artifact path, active slice, verbatim user-context block, explicit deliverables/non-deliverables, and “no silent extra deliverables” | These directly preserve user intent at handoff time. |
| **P0** | Subagent restatement of received scope before doing work | This catches handoff drift immediately instead of after the wrong work starts. |
| **P1** | Provenance labels and stronger “lossless routing over reinterpretation” wording for Maestro | Makes summaries auditable and reduces paraphrase damage from the weaker orchestrator. |
| **P1** | Resume/continue/switch bias toward reusing the existing relevant session | Prevents accidental fresh sessions that shed context. |
| **P2** | Optional packet preview plus phased warning→enforcement rollout | Useful and low risk, but not as critical as preserving the core packet fields. |

## File map

### Core policy and prompt changes
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `docs/superpowers/templates/subagent-handoff-templates.md`

### Verification
- Create: `tests/docs/test_maestro_intent_preservation_policy.sh`

## Out of scope

- Runtime message-router implementation outside prompt/policy/template changes
- Transcript export formatting changes
- PR template changes unless they become strictly necessary during implementation review
- Unrelated subagent prompt rewrites

## Success criteria

1. Every delegated handoff example includes the exact artifact path when one exists, the active slice, a verbatim user-context block, explicit deliverables, explicit non-deliverables, and provenance labels.
2. AGENTS and Maestro both state that weaker orchestrators must prefer lossless routing over reinterpretation.
3. AGENTS and Maestro both state that no silent extra deliverables may be added during delegation.
4. The subagent contract requires a first-pass restatement of active slice, deliverables, and non-deliverables before substantive work.
5. The policy/test coverage states that “switch”, “continue”, and `$ses_<id>` should favor existing-session resume rather than spawning a fresh session.
6. A single contract test fails before the policy text exists and passes after the doc/prompt/template updates land.

## Risks and trade-offs

- **Longer handoffs:** Delegation packets become more verbose. This is intentional; preserving intent beats concise but lossy summaries.
- **Prompt duplication risk:** Similar rules will exist in AGENTS, Maestro, and templates. Keep wording aligned and test for anchor phrases.
- **Over-enforcement risk:** If packet requirements are too rigid for tiny tasks, Maestro may feel heavy. Mitigate by keeping the packet short but lossless.
- **False confidence risk:** This plan improves policy-level behavior, not runtime guarantees. Keep scope honest.

## Phased rollout

1. **Phase 1 — P0 contract:** Update AGENTS, Maestro, and handoff templates; add a failing shell contract test and make it pass.
2. **Phase 2 — P1 routing bias:** Strengthen resume/switch semantics and provenance labels in AGENTS and Maestro; extend the contract test.
3. **Phase 3 — P2 ergonomics/enforcement:** Add optional preview wording and decide whether the shell contract test should remain a manual verification step or become part of CI/review policy.

---

## Task 1: P0 — Define the lossless delegation packet in AGENTS

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Create: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] **Step 1: Write the failing contract test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"

rg -n '^## Intent-preserving delegation packet$' "$agents" >/dev/null
rg -n 'Artifact path:' "$agents" >/dev/null
rg -n 'Active slice:' "$agents" >/dev/null
rg -n 'Verbatim user context:' "$agents" >/dev/null
rg -n 'Deliverables:' "$agents" >/dev/null
rg -n 'Non-deliverables:' "$agents" >/dev/null
rg -n 'Provenance:' "$agents" >/dev/null
rg -n 'No silent extra deliverables' "$agents" >/dev/null
rg -n 'prefer lossless routing over reinterpretation' "$agents" >/dev/null

printf 'PASS test_maestro_intent_preservation_policy\n'
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: `rg` exits non-zero because `## Intent-preserving delegation packet` and the packet fields do not exist yet.

- [ ] **Step 3: Add the P0 packet section to AGENTS**

Insert a section like this near the delegation rules:

```markdown
## Intent-preserving delegation packet

- Before delegating scoped work that depends on an approved plan/spec/artifact, the delegating agent MUST pass a lossless delegation packet.
- Required packet fields:
  - `Artifact path:` the exact approved plan/spec path when one exists
  - `Active slice:` the exact portion of that artifact being delegated now
  - `Verbatim user context:` a quoted block with the user’s exact relevant words
  - `Deliverables:` only the outputs explicitly requested or required by the approved artifact
  - `Non-deliverables:` work explicitly excluded from the delegated scope
  - `Provenance:` label each packet item as `verbatim-user`, `approved-artifact`, or `agent-inference`
- No silent extra deliverables: if an output is not explicitly requested or required by the approved artifact, do not add it to the delegated scope.
- Weaker orchestrators must prefer lossless routing over reinterpretation. When in doubt, pass through the original wording and ask one routing question rather than compressing meaning into a summary.
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: `PASS test_maestro_intent_preservation_policy`

- [ ] **Step 5: Commit the P0 AGENTS packet change**

```bash
git add .config/opencode/AGENTS.md tests/docs/test_maestro_intent_preservation_policy.sh
git commit -m "docs(policy): add intent-preserving delegation packet"
```

---

## Task 2: P0 — Require subagent restatement and update handoff templates

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Modify: `docs/superpowers/templates/subagent-handoff-templates.md`
- Modify: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] **Step 1: Extend the failing contract test for restatement and templates**

Add these checks to `tests/docs/test_maestro_intent_preservation_policy.sh`:

```bash
templates="$repo_root/docs/superpowers/templates/subagent-handoff-templates.md"

rg -n 'Subagent restatement:' "$agents" "$templates" >/dev/null
rg -n 'Artifact path:' "$templates" >/dev/null
rg -n 'Active slice:' "$templates" >/dev/null
rg -n 'Verbatim user context:' "$templates" >/dev/null
rg -n 'Non-deliverables:' "$templates" >/dev/null
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: failure because the template file does not yet contain the new packet fields or `Subagent restatement:`.

- [ ] **Step 3: Add restatement requirements and template examples**

Add this AGENTS rule:

```markdown
- Subagent restatement: before doing substantive work, the owning subagent MUST restate `Active slice:`, `Deliverables:`, and `Non-deliverables:` in its own words and stop immediately if anything appears mismatched.
```

Update the template file so the start handoff looks like this:

```text
Switching you to the planner subagent now — please interact directly with it; I will remain available for orchestration.
Session: ses_123
Resume: $ses_123 <your reply>
Owner: planner
Authority: only the owning subagent may perform planner responsibilities unless a human-approved Maestro override is active
Artifact path: docs/superpowers/plans/2026-05-22-subagent-session-communication-policy.md
Active slice: Update the approved plan file and commit only that file
Verbatim user context:
> OK, could you turn this into a plan, with mitigations ordered by priority?
> write to file and commit
Deliverables:
- Update the existing plan file
- Commit only the intended plan file
Non-deliverables:
- Do not implement AGENTS.md or template changes in this slice
Provenance:
- Artifact path — approved-artifact
- Active slice — verbatim-user
- Non-deliverables — approved-artifact
Subagent restatement: required before substantive work begins
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: `PASS test_maestro_intent_preservation_policy`

- [ ] **Step 5: Commit the restatement/template change**

```bash
git add .config/opencode/AGENTS.md docs/superpowers/templates/subagent-handoff-templates.md tests/docs/test_maestro_intent_preservation_policy.sh
git commit -m "docs(policy): add subagent restatement contract"
```

---

## Task 3: P1 — Teach Maestro to preserve provenance and avoid reinterpretation

**Files:**
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] **Step 1: Extend the failing contract test for Maestro wording**

Add these checks:

```bash
maestro="$repo_root/.config/opencode/agents/maestro.md"

rg -n 'prefer lossless routing over reinterpretation' "$maestro" >/dev/null
rg -n 'No silent extra deliverables' "$maestro" >/dev/null
rg -n 'Artifact path:' "$maestro" >/dev/null
rg -n 'Verbatim user context:' "$maestro" >/dev/null
rg -n 'Provenance:' "$maestro" >/dev/null
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: failure because Maestro does not yet define the packet fields or the stronger routing language.

- [ ] **Step 3: Update the Maestro prompt with explicit packet rules**

Add a section like this to `.config/opencode/agents/maestro.md`:

```markdown
# Intent-preserving delegation

- Before dispatching scoped work, send a delegation packet with `Artifact path:`, `Active slice:`, `Verbatim user context:`, `Deliverables:`, `Non-deliverables:`, and `Provenance:`.
- No silent extra deliverables. Do not widen the delegated scope beyond the user-approved slice.
- Prefer lossless routing over reinterpretation. If a direct quote preserves intent better than a summary, pass the quote.
- If you had to compress or infer anything material, mark it in `Provenance:` as `agent-inference`.
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: `PASS test_maestro_intent_preservation_policy`

- [ ] **Step 5: Commit the Maestro packet wording**

```bash
git add .config/opencode/agents/maestro.md tests/docs/test_maestro_intent_preservation_policy.sh
git commit -m "docs(maestro): prefer lossless delegation routing"
```

---

## Task 4: P1 — Strengthen resume/continue semantics around existing sessions

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] **Step 1: Extend the failing contract test for resume bias**

Add these checks:

```bash
rg -n 'switch' "$agents" "$maestro" >/dev/null
rg -n 'continue' "$agents" "$maestro" >/dev/null
rg -n 'Do not silently spawn a new session' "$agents" "$maestro" >/dev/null
rg -n 'route the message to that session immediately and verbatim' "$agents" "$maestro" >/dev/null
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: failure if the exact stronger wording does not yet exist in both policy sources.

- [ ] **Step 3: Tighten AGENTS and Maestro resume language**

Use wording along these lines in both files:

```markdown
- When the user says "switch", "continue", or supplies `$ses_<id>`, prefer resuming the existing relevant session over spawning a new one.
- Do not silently spawn a new session as a fallback for lost context.
- If a valid `$ses_<id>` token is present, route the message to that session immediately and verbatim.
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: `PASS test_maestro_intent_preservation_policy`

- [ ] **Step 5: Commit the resume-bias change**

```bash
git add .config/opencode/AGENTS.md .config/opencode/agents/maestro.md tests/docs/test_maestro_intent_preservation_policy.sh
git commit -m "docs(policy): prefer session resume over respawn"
```

---

## Task 5: P2 — Add optional preview and finish rollout guidance

**Files:**
- Modify: `.config/opencode/AGENTS.md`
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `docs/superpowers/templates/subagent-handoff-templates.md`
- Modify: `tests/docs/test_maestro_intent_preservation_policy.sh`

- [ ] **Step 1: Extend the failing contract test for preview wording**

Add these checks:

```bash
rg -n 'Preview:' "$maestro" "$templates" >/dev/null
rg -n 'available on request before dispatch' "$maestro" "$templates" >/dev/null
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: failure until preview wording is added.

- [ ] **Step 3: Add optional preview language without making it mandatory noise**

Add wording like this:

```markdown
- `Preview:` optional; provide the exact outgoing delegation packet on request, or before dispatch when the orchestrator materially compressed earlier context.
```

Update the template example to include:

```text
Preview: available on request before dispatch
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `bash tests/docs/test_maestro_intent_preservation_policy.sh`

Expected: `PASS test_maestro_intent_preservation_policy`

- [ ] **Step 5: Commit the preview/rollout change**

```bash
git add .config/opencode/AGENTS.md .config/opencode/agents/maestro.md docs/superpowers/templates/subagent-handoff-templates.md tests/docs/test_maestro_intent_preservation_policy.sh
git commit -m "docs(policy): add delegation preview guidance"
```

---

## Final verification checklist

- [ ] Run `bash tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] Run `git diff -- .config/opencode/AGENTS.md .config/opencode/agents/maestro.md docs/superpowers/templates/subagent-handoff-templates.md tests/docs/test_maestro_intent_preservation_policy.sh`
- [ ] Read the changed handoff example and confirm it names the exact artifact path, active slice, verbatim user context, deliverables, non-deliverables, provenance, and preview status.
- [ ] Re-read AGENTS and Maestro and confirm they both prefer lossless routing over reinterpretation and existing-session resume over respawn.

## Pragmatic Programmer diagnostic

- **Current score target:** 8/10 or better.
- **If below 8:**
  1. Reduce duplicated policy wording by choosing one canonical phrase per requirement and copying it exactly.
  2. Narrow any packet fields that read like implementation speculation rather than approved scope.
  3. Keep rollout reversible: warning/manual verification first, stricter enforcement second.
