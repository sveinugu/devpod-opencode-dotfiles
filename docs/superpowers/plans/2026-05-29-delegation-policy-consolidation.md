# Delegation Packet + Annex Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate delegation/session policy into one canonical `.config/opencode/AGENTS.md` chapter aligned with the approved “closed-schema Delegation Packet + Annex” design, then remove/migrate conflicting legacy packet formats with explicit user approval per item.

**Architecture:**
- Canonical policy lives in `.config/opencode/AGENTS.md` under a single “Delegation & Sessions (canonical)” chapter.
- Other surfaces (agent prompts, templates, docs) become pointers + minimal examples only.
- A doc-contract test suite (`tests/docs/*.sh`) mechanically checks for policy drift (docs only; not runtime routing enforcement).

**Tech Stack:** Markdown policy docs, bash + ripgrep (`rg`) doc-contract tests, git.

---

## Inputs / binding artifacts

- Binding design (approved): `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`
- Background: `docs/superpowers/retrospectives/2026-05-26-delegation-packet-skipped.md` (esp. section “#3 spec scattered across AGENTS.md”)

## Scope

### In scope

1. Land the spec addendum (non-blocking nits) into the binding design artifact:
   - `> ---` separator is **required** when quoting 2+ user messages.
   - Tighten: the only permitted non-packet text outside packet/Annex is the *required handoff wording* line.
   - Tighten Highlight markup: allow `**bold**` only (no `_italic_`).
2. Inventory all delegation-packet-like formats across the repo, including “adopted by reference” skill/template references.
3. Consolidate the delegation flow into a single sequential checklist in AGENTS.md.
4. Remove/migrate legacy packet formats (e.g. `Active slice:` / `Deliverables:` / `Provenance:`) **only after explicit user approval per item**.
5. Add doc-contract tests that catch policy drift and forbidden-field reintroduction.

### Out of scope

- Runtime router / plugin enforcement.
- Editing upstream `obra/superpowers` skill templates.
- Any non-policy code changes.

---

## File map (expected)

**Primary canonical policy**
- Modify: `.config/opencode/AGENTS.md`

**Secondary surfaces (become pointers + minimal examples)**
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/*.md` (only if they restate/conflict with packet schema)
- Modify: `docs/superpowers/templates/subagent-handoff-templates.md`

**Binding design artifact (addendum nits)**
- Modify: `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`

**Inventory record**
- Create: `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`

**Verification (doc-contract tests)**
- Create: `tests/docs/test_delegation_packet_policy_contract.sh`

---

## Success criteria (verifiable)

1. AGENTS.md contains one canonical “Delegation & Sessions (canonical)” chapter with:
   - Closed-schema Delegation Packet (allowed fields only)
   - Verbatim quoting contract (`>`-only; multi-message separator rule)
   - Annex structure + explicit forbidden content
   - Artifact handshake + stop-on-mismatch
   - Required handoff wording + session metadata visibility timing
2. No other repo policy surface defines a conflicting packet schema.
3. Doc-contract tests fail on:
   - forbidden packet fields in canonical surfaces, or
   - missing required anchor phrases.
4. Legacy packet removals/migrations happen only after user approves each inventory item.

---

## Task 0: Preflight — ensure the binding spec exists on this branch

Rationale: this plan treats the approved spec as binding; it must exist in the same branch so tests can reference it.

**Files:**
- Create/Modify: `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`

- [x] **Step 1: If the spec file is missing, bring it in from the branch that contains it**

Acceptable approaches:
- `git cherry-pick <commit>` that introduced the spec, or
- copy the file from the other worktree and commit it.

- [x] **Step 2: Commit (only if this step changed files)**

```bash
git add docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md
git commit -m "docs(spec): import approved delegation packet design"
```

---

## Task 1: Add spec addendum (nits) to the binding design artifact

**Files:**
- Modify: `docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md`

- [x] **Step 1: Add nit #1 — require `> ---` when 2+ messages are quoted**

In “Multi-message verbatim quoting”, add/adjust:

```text
If 2+ user messages are included, `> ---` MUST appear between messages.
If exactly 1 message is included, `> ---` MUST NOT appear.
```

- [x] **Step 2: Add nit #2 — tighten non-packet text allowance**

In “Reconciliation with ‘closed schema’ readers”, add/adjust:

```text
Outside the packet block and optional Annex, the ONLY permitted text in the dispatch message is the required handoff wording line.
No other free-form context is permitted outside the packet/Annex.
```

- [x] **Step 3: Tighten Highlight markup to `**` only**

In “Highlight (derived from verbatim)”, allow only `**bold**` and explicitly forbid `_italic_`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md
git commit -m "docs(spec): tighten delegation packet addendum nits"
```

**User Check-in (resolved):** spec addendum review approved per inventory decisions.

---

## Task 2: Packet-format inventory (draft → user decision → commit)

**Files:**
- Create: `docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md`

- [x] **Step 1: Draft the inventory document (do NOT commit yet)**

Inventory format:

```markdown
| ID | Location | Name/Label | Current schema/fields | Conflicts with approved spec? | User decision | Action taken |
|---:|---|---|---|---|---|---|
```

Rules:
- Include every packet-like schema/template.
- Include “adopted by reference” items: if AGENTS.md references a skill/template for delegation/prompting, list that reference.
- Do **not** read or quote upstream skill files; inventory only what we reference locally.

- [x] **Step 2: Fill the inventory by searching local markdown**

Suggested commands:

```bash
rg -n "^Delegation Packet$|^## Delegation Packet$|## Intent-preserving delegation packet|Active slice:|Deliverables:|Non-deliverables:|Provenance:|Verbatim user request:|Verbatim user context:|Annex \(non-authoritative" .
rg -n "subagent-handoff-templates|implementer-prompt|subagent-driven-development" .config/opencode docs
```

- [x] **Step 3: User Check-in — walk items one by one**

For each item, user chooses one:
- keep (unchanged)
- migrate to new canonical format
- mark deprecated/historical
- remove

- [x] **Step 4: Record decisions in the inventory file and commit it**

```bash
git add docs/superpowers/review-records/2026-05-29-delegation-policy-packet-inventory.md
git commit -m "docs(review-record): inventory delegation packet formats"
```

---

## Task 3: Draft canonical “Delegation & Sessions (canonical)” chapter in AGENTS.md (no removals yet)

**Files:**
- Modify: `.config/opencode/AGENTS.md`

- [x] **Step 1: Add the canonical chapter skeleton**

Add:

```markdown
# Delegation & Sessions (canonical)

## Delegation Packet (closed schema; Maestro → subagent only)
## Verbatim quoting contract
## Annex (non-authoritative; not part of Delegation Packet)
## Artifact semantics + handshake
## Required handoff wording + session metadata visibility
## Resume token routing semantics
## Stop-on-mismatch rules
```

- [x] **Step 2: Populate it from the binding spec**

Must include:
- Allowed packet fields (and *only* those)
- Forbidden packet fields (explicitly include the legacy ones we’re removing)
- Annex delimiter header line
- Highlight restrictions (`**` only)
- Subagent stop-rules (missing verbatim, highlight mismatch, artifact mismatch)
- Artifact handshake statement visibility requirement

- [x] **Step 3: Add a single sequential “anti-scatter” checklist**

3–5 steps max, in one place, covering:
1) required handoff wording line
2) Delegation Packet block
3) optional Annex block
4) timing: session metadata printed immediately after successful launch (router rule)

- [x] **Step 4: Mark any legacy packet sections as deprecated (do not delete yet)**

```markdown
> Deprecated: superseded by “Delegation & Sessions (canonical)”. Do not use for new delegations.
```

- [ ] **Step 5: Commit**

```bash
git add .config/opencode/AGENTS.md
git commit -m "docs(policy): add canonical delegation & sessions chapter"
```

**User Check-in (resolved):** canonical chapter review approved per inventory decisions.

---

## Task 4: Convert agent prompts into pointers (minimize duplication)

**Files:**
- Modify: `.config/opencode/agents/maestro.md`
- Modify: `.config/opencode/agents/*.md` (only where they redefine packet schema)

- [x] **Step 1: Remove conflicting packet schema from maestro.md**

Replace legacy schema definitions (e.g. `Active slice/Deliverables/Provenance`) with a pointer:

```markdown
Delegation Packet + Annex rules are defined in `.config/opencode/AGENTS.md` → “Delegation & Sessions (canonical)”.
```

Keep Maestro-only operational rules that do not redefine the packet schema.

- [x] **Step 2: Ensure any Maestro example handoff contains only permitted non-packet text**

If maestro.md includes example dispatch messages:
- The only non-packet/Annex text must be the required handoff wording line.

- [x] **Step 3: Update other agents only if they restate packet schema**

Goal: avoid “context spam” by keeping packet schema centralized in AGENTS.md.

- [ ] **Step 4: Commit**

```bash
git add .config/opencode/agents
git commit -m "docs(agents): de-duplicate delegation packet rules"
```

---

## Task 5: Update handoff template doc to match closed-schema Packet + Annex

**Files:**
- Modify: `docs/superpowers/templates/subagent-handoff-templates.md`

- [x] **Step 1: Replace any legacy packet fields in the template**

“Start” must include:
- required handoff wording line
- `Delegation Packet` block with allowed fields only
- optional Annex block with exact header

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/templates/subagent-handoff-templates.md
git commit -m "docs(templates): align handoff template with packet+annex"
```

---

## Task 6: Doc-contract tests (policy drift guardrails)

**Files:**
- Create: `tests/docs/test_delegation_packet_policy_contract.sh`

- [x] **Step 1: Write the failing doc-contract test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agents="$repo_root/.config/opencode/AGENTS.md"
maestro="$repo_root/.config/opencode/agents/maestro.md"
templates="$repo_root/docs/superpowers/templates/subagent-handoff-templates.md"
spec="$repo_root/docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md"

# Required anchors
rg -n "^# Delegation & Sessions \(canonical\)$" "$agents" >/dev/null
rg -n "^## Delegation Packet \(closed schema" "$agents" >/dev/null
rg -n "Annex \(non-authoritative; not part of Delegation Packet\)" "$agents" "$spec" >/dev/null

# Forbidden legacy fields in canonical surfaces
if rg -n "^\s*(Active slice:|Deliverables:|Non-deliverables:|Provenance:)" "$agents" "$templates" "$maestro"; then
  echo "FAIL: found forbidden legacy packet fields in canonical surfaces" >&2
  exit 1
fi

printf 'PASS test_delegation_packet_policy_contract\n'
```

- [x] **Step 2: Run and verify it fails before migration completes**

Run: `bash tests/docs/test_delegation_packet_policy_contract.sh`

- [x] **Step 3: Iterate test strictness to match final policy**

If too brittle, relax to anchor-phrase checks rather than exact text.

- [ ] **Step 4: Commit**

```bash
git add tests/docs/test_delegation_packet_policy_contract.sh
git commit -m "test(docs): add delegation policy drift contract"
```

---

## Task 7: Legacy packet removal/migration (per inventory; user-approved)

- [x] **Step 1: Apply the user decision for each inventory item**

Rules:
- Removing/migrating is only allowed after the user decision is recorded in the inventory doc.
- Migration target is always the canonical AGENTS chapter + (optionally) one compliant example.

- [x] **Step 2: Run doc-contract tests**

Run: `bash tests/docs/test_delegation_packet_policy_contract.sh`

- [x] **Step 3: Commit in small batches**

```bash
git add -A
git commit -m "docs(policy): migrate legacy delegation packet formats (batch <ids>)"
```

---

## Final verification

- [ ] `bash tests/docs/test_delegation_packet_policy_contract.sh`
- [ ] `git diff -- .config/opencode/AGENTS.md .config/opencode/agents/maestro.md docs/superpowers/templates/subagent-handoff-templates.md docs/superpowers/specs/2026-05-26-delegation-packet-annex-and-verbatim-contract-design.md tests/docs/test_delegation_packet_policy_contract.sh`

## Pragmatic Programmer diagnostic (target score ≥ 8/10)

- **DRY:** one canonical chapter; other docs are pointers.
- **Orthogonality:** Maestro-specific rules stay in maestro.md; shared delegation rules live in AGENTS.md.
- **Broken windows:** contradictory packet schemas removed/migrated with explicit approval.
