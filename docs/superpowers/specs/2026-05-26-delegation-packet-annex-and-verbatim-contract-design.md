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

### 1.1 Reconciliation with “closed schema” readers (AGENTS.md)

Some policy readers interpret “closed schema” as “nothing else may appear in the dispatch message.” This design is stricter:

- **The closed schema applies only to the contiguous `Delegation Packet` block** (from the line `Delegation Packet` through the last allowed packet field).
- **The Annex is allowed only after the packet ends** and is explicitly not part of the packet.

Implementation note: `.config/opencode/AGENTS.md`, the Maestro prompt, and any handoff templates must explicitly state that Annex content is permitted **after** the packet block (and forbidden **inside** it).

Outside the packet block and optional Annex, the ONLY permitted text in the dispatch message is the required handoff wording line.
No other free-form context is permitted outside the packet/Annex.

---

## 2) Verbatim quoting contract

### 2.1 Contract (format)

Under `Verbatim user request:`, every non-empty line MUST be a Markdown blockquote line starting with `>`.

### 2.1.1 Multi-message verbatim quoting

Delegations often depend on multiple user messages.

If multiple user messages are relevant, include them in `Verbatim user request:` in chronological order (oldest first, newest last) as `>` lines.

To make message boundaries mechanically checkable **without** paraphrase, the following message-boundary separator line is allowed as the only non-user-authored line within `Verbatim user request:`:

```text
> ---
```

Rules:

- If 2+ user messages are included, `> ---` MUST appear between messages.
- If exactly 1 message is included, `> ---` MUST NOT appear.
- No other non-user-authored boundary markers are permitted inside `Verbatim user request:`.

Example:

```text
Verbatim user request:
> do A
> ---
> then B
> ---
> then resume them for C
```

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

### 3.2.1 Packet/Annex delimiter (required)

To avoid ambiguity about where the packet ends and the Annex begins:

- The Annex MUST begin with the **exact** header line:
  
  `Annex (non-authoritative; not part of Delegation Packet)`

- The Annex header MUST be preceded by a blank line.
- No text is allowed between the end of the packet block and the Annex header besides that blank line.

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
  - emphasis markers: `**bold**` only (`_italic_` is forbidden due to variable naming collisions)
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

### 3.3 Forbidden content in the Annex (explicit)

The Annex is non-authoritative and must not become a backdoor for requirements or step-by-step task steering.

The following are FORBIDDEN anywhere in the Annex:

- Imperatives and instruction lists (e.g. “Do X”, “Implement Y”, “Follow these steps”, numbered step plans)
- Deliverables / non-deliverables / acceptance criteria
- New requirements language (e.g. “must/should/required to”) intended to bind the subagent
- Interpretative summaries of the user’s intent (the verbatim block is the source of truth)
- Anything that substitutes for the approved artifact as the requirements source

Clarification:

- `Open questions:` must be questions.
- `Hypotheses:` may speculate, but cannot instruct; it must remain explicitly non-authoritative.

### 3.4 Implementer prompt template conflict (explicit resolution)

Some upstream workflow templates encourage the delegator to paste full step-by-step task text and rich context directly into the implementer prompt.

This design requires the opposite:

- If an implementer needs step-by-step instructions or full task text, those MUST live in the approved artifact at `Artifact path:` (plan/spec), not in the Annex.
- The Annex may only provide pointers/questions/hypotheses/evidence, never a replacement “mini-plan”.

#### Open questions

- Questions the subagent should ask before committing to a choice.
- Preferred over “guidance prose”.

#### Hypotheses

- Must be explicitly non-authoritative.
- Each bullet MUST include the literal phrase: `confirm before relying`.

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
````text
rg: error: ...
````
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

### 4.2.1 Concrete examples of “mismatch” / “material conflict”

These examples are intentionally blunt. When in doubt, stop and ask rather than guessing.

**Example A — unrelated artifact (stop):**

- `Artifact path:` points to a plan about Kubernetes deployment.
- `Verbatim user request:` is about shell alias behavior.

Action: stop and ask delegator/user to confirm/correct artifact selection.

**Example B — policy conflict (stop):**

- Global policy forbids adding new deliverables via delegation.
- Artifact/Annex attempts to introduce a new deliverable (“also add a dashboard”) not present in user verbatim and not required by the artifact.

Action: stop and ask for clarification; do not implement the extra deliverable.

**Example C — artifact vs verbatim scope conflict (stop):**

- Artifact requires “CLI-only”.
- Verbatim user request explicitly asks for a TUI.

Action: stop and ask which source should govern; do not choose silently.

**Example D — highlight mismatch (stop):**

- `Highlight (derived from verbatim...)` contains words not present in the verbatim line after stripping markup.

Action: stop and request correction.

**Example E — non-material differences (proceed):**

- Artifact contains extra background sections that are not referenced by the verbatim request.
- No contradictions exist with policy or verbatim.

Action: proceed; treat artifact as binding requirements source, but ignore irrelevant sections unless needed.

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

### 4.4 Handshake statement visibility (required)

To enable fast correction, the subagent MUST include its 1–2 sentence artifact-summary statement in its **first response after receiving the delegation**.

If the subagent believes there is a mismatch, it must say so in that first response and ask for confirmation/correction before doing substantive work.

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
````text
[optional raw output]
````
```

---

## Risks and mitigations

- **Risk: Weak Maestro still paraphrases** → mitigated by verbatim contract + subagent stop-rule.
- **Risk: Helpful context becomes requirements** → mitigated by fixed Annex headings + no free-form “Considerations”.
- **Risk: Wrong artifact grants authority** → mitigated by artifact handshake + stop-on-mismatch.

## Follow-ups (not in this slice)

- Add runtime enforcement (plugin/tool hook) to block non-conforming packets.
- Add doc/prompt lint tests to ensure packet+annex grammar stays stable over time.
