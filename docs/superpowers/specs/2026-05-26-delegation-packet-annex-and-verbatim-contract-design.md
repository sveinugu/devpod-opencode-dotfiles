# Delegation Packet Annex + Verbatim Quoting Contract (Design)

Date: 2026-05-26  
Status: Approved (by user)

## Problem

Weak orchestrators (e.g. Maestro) frequently paraphrase user intent, accidentally smuggle inferred scope, or replace the user’s words with “helpful” summaries during delegation.

This breaks the point of the existing **Delegation Packet** (closed schema): lossless routing + self-contextualizing subagents.

We need:

1. A mechanically checkable way to carry **verbatim user text**.
2. A safe outlet for **helpful context** that does not become requirements by accident.
3. A clear rule for how subagents treat `Artifact path:` and how to stop when it looks wrong.

## Goals

- Keep the **Delegation Packet closed schema** unchanged.
- Make “verbatim” unambiguous and hard to fake.
- Allow non-authoritative helpful content without reintroducing paraphrase as requirements.
- Require **all subagents** to stop early when delegation is missing verbatim, has mismatched highlights, or points at the wrong artifact.

## Non-goals

- Do not implement runtime enforcement (plugin hooks) in this slice.
- Do not redesign the superpowers upstream skill templates; this policy defines how *this opencode harness* behaves.

---

## 1) Delegation Packet (closed schema, unchanged)

The Delegation Packet remains a closed-schema block used only for **Maestro → subagent scoped delegation**.

Allowed packet fields (unchanged):

- `Artifact path:` or `Artifact paths:` (exact path strings)
- `Verbatim user request:` (verbatim-only; see contract below)
- `Warnings:` (optional; warnings only)
- router-owned metadata: `Session:`, `Resume:`, `Owner:`, `Authority:`

Forbidden inside the packet block (unchanged policy):

- Any other headings/fields (e.g. `Instructions:`, `Summary:`, `Deliverables:`, etc.)
- Interpretative summaries, inferred scope/deliverables, implementation steering

**Important:** The Annex defined below is explicitly **outside** the Delegation Packet block and is not part of the packet schema.

---

## 2) Verbatim quoting contract

### 2.1 Contract (format)

Under `Verbatim user request:`, every non-empty line MUST be a Markdown blockquote line starting with `>`.

Example:

```text
Verbatim user request:
> do A
> then B
> then resume them for C
```

### 2.2 Contract (content)

- The quoted text MUST be **verbatim user-authored text**.
- Raw fragments and shorthand are allowed and encouraged (no “cleaning up”).
- Do not paraphrase. Do not rewrite into full sentences.
- Prefer quoting the **entire** relevant user message (to avoid misleading snips).

### 2.3 Subagent stop-rule (all subagents)

If a subagent receives a Delegation Packet where `Verbatim user request:` contains **zero** `>`-quoted lines (or is `N/A`), the subagent MUST:

1. Stop before doing substantive work.
2. Ask the delegator (chain of command) to provide the exact user text as `>` quotes.
3. If the delegator cannot/will not provide it, ask the user directly.

Rationale: this prevents weak orchestrators from silently substituting paraphrase for verbatim intent.

---

## 3) Annex structure (non-authoritative)

### 3.1 Purpose

The Annex exists to give the delegator a “friendly/helpful outlet” **without** modifying the Delegation Packet schema and without turning helpful prose into requirements.

The Annex is explicitly **non-authoritative**. It may contain useful pointers, questions, hypotheses, and raw evidence, but it must not override:

1. Global opencode policy (this repo’s `.config/opencode/*`)
2. Verbatim user text
3. Approved artifacts at `Artifact path:` (see artifact semantics)

### 3.2 Allowed Annex headings (fixed)

When present, the Annex MUST be a separate block after the Delegation Packet and may contain only the headings below.

```text
Annex (non-authoritative; not part of Delegation Packet)

Pointers:

Highlight (derived from verbatim; must match after stripping markup):

Open questions:

Hypotheses:

Evidence (verbatim, source: <label>):
```

#### Pointers

- May include file paths and URLs.
- One-line labels are allowed.
- Pointers are not requirements.

Example:

```text
Pointers:
- docs/superpowers/retrospectives/2026-05-26-delegation-packet-skipped.md (background)
- .config/opencode/AGENTS.md (policy)
```

#### Highlight (derived from verbatim)

Purpose: make multi-topic user messages readable without editing the verbatim block.

Rules:

- Each highlighted `>` line MUST be a **full-line copy** of a line from `Verbatim user request:`.
- Highlight may add ONLY:
  - emphasis markers: `**bold**`, `_italic_`
  - inline code markers: `` `like this` ``
- Highlight MUST NOT:
  - delete words
  - add words
  - use ellipses (`...`)
  - re-order text
- Mechanically: the highlighted line MUST match an original verbatim line after stripping the allowed markup.

Example:

```text
Verbatim user request:
> Delegate two subagents to investigate A and B, then do something else, and then resume both of them to do C?

Highlight (derived from verbatim; must match after stripping markup):
> Delegate two subagents to **investigate A** and B, then do something else, and then resume **both of them to do C**?
```

**Subagent stop-rule:** If Highlight is present but does not match verbatim lines after stripping markup, the subagent MUST stop and request correction.

Highlight is OPTIONAL (recommended when the user message is multi-topic).

#### Open questions

- Questions the subagent should ask before committing to a choice.
- Preferred over “guidance prose”.

#### Hypotheses

- Must be explicitly non-authoritative.
- Each bullet MUST include “confirm before relying” (or equivalent).

#### Evidence (verbatim)

Use for raw command output / error logs / traces when helpful.

Rules:

- Must be raw output only inside a fenced block.
- Must include a `source:` label.
- Any interpretation MUST be expressed as a Hypothesis, not inside the evidence.
- Multiple evidence blocks are allowed.

Example:

```text
Evidence (verbatim, source: maestro-local-bash):
```text
rg: error: ...
```
```

---

## 4) Artifact semantics + handshake

### 4.1 Default semantics

When `Artifact path:` is present, the referenced artifact is treated as a **binding requirements source by default**.

This is intentional: it enables implementers/reviewers/specialists to self-contextualize without Maestro pasting rich context.

### 4.2 Authority ordering on conflict

If there is a material conflict between:

- global opencode policy,
- verbatim user request, and
- the artifact,

the subagent MUST stop and ask for clarification rather than “resolving” the conflict silently.

### 4.3 Artifact handshake (all subagents)

If `Artifact path:` is present, the subagent MUST:

1. Open/read the artifact.
2. Form a short statement of what the artifact appears to specify (1–2 sentences).
3. Compare it to the verbatim user request.
4. If the artifact seems unrelated or materially conflicting with verbatim intent/global policy:
   - stop before substantive work
   - ask the delegator to confirm/correct the artifact selection (chain of command)
   - if unresolved, ask the user

Note: “Mismatch” does NOT mean “the delegated task must already be written in the artifact.” Adjacent/connecting work is fine; the handshake is about ensuring the artifact is a plausible authoritative context anchor for the delegated work.

---

## Worked example (packet + annex)

```text
Delegation Packet
Session: ses_abc123
Resume: $ses_abc123 <your reply>
Owner: senior-implementer
Authority: only the owning subagent may perform senior-implementer responsibilities unless a human-approved Maestro override is active
Artifact path: docs/superpowers/plans/2026-05-XX-some-plan.md
Verbatim user request:
> Delegate two subagents to investigate A and B, then do something else, and then resume both of them to do C?
Warnings:
- Ambiguity: “do something else” not specified

Annex (non-authoritative; not part of Delegation Packet)
Pointers:
- docs/superpowers/retrospectives/2026-05-26-delegation-packet-skipped.md (background)
Highlight (derived from verbatim; must match after stripping markup):
> Delegate two subagents to **investigate A** and B, then do something else, and then resume **both of them to do C**?
Open questions:
- What is the “something else” step?
Hypotheses:
- Hypothesis: “C” means a second pass after initial findings; confirm before relying.
Evidence (verbatim, source: user-pasted):
```text
[optional raw output]
```
```

---

## Risks and mitigations

- **Risk: Weak Maestro still paraphrases** → mitigated by verbatim contract + subagent stop-rule.
- **Risk: Helpful context becomes requirements** → mitigated by fixed Annex headings + no free-form “Considerations”.
- **Risk: Wrong artifact grants authority** → mitigated by artifact handshake + stop-on-mismatch.

## Follow-ups (not in this slice)

- Add runtime enforcement (plugin/tool hook) to block non-conforming packets.
- Add doc/prompt lint tests to ensure packet+annex grammar stays stable over time.
