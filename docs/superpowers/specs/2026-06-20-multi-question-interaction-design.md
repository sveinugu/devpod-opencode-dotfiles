# Multi-question Interaction + Choice Framing Design

Date: 2026-06-20  
Status: Proposed (direction approved; awaiting user review)

Binding policy source: `/workspaces/dotfiles/work/policy_multiple_questions/.config/opencode/AGENTS.md`

## Problem

The current repository policy still carries a one-question-at-a-time interaction default for subagents:

- the recommended first subagent message says "I will ask one question at a time"
- the subagent interaction rules say "Ask one clarifying question per message"

That default creates unnecessary back-and-forth for ordinary discovery and design work. It also conflicts with the user's preferred interaction style for this repository: related questions should usually be grouped so the user can answer efficiently.

The current policy also under-specifies how agents should ask the user to choose between options. In practice that allows weak behaviors such as:

- asking for a choice without enough decision-relevant background
- hiding the agent's recommendation inside a rhetorical or loaded question
- failing to tell the user whether more unanswered questions are still coming

This slice is therefore about interaction policy quality, not implementation logic: the repository should prefer concise, informative multi-question batches for normal clarification work, while keeping narrowly-scoped protocol prompts mechanically reliable.

## Goals

- Make multi-question batching the default for ordinary clarifying and discovery questions asked by subagents.
- Cap a single question batch at five questions.
- Keep batching as a preference, not a mandate: if only one meaningful question is needed, ask one.
- Require agents to say when more questions are still pending and give a rough estimate of remaining questions or follow-up rounds.
- Require enough background, recommendation, and reasoning when the user is being asked to choose.
- Prevent loaded or rhetorical choice framing from substituting for clear guidance.
- Preserve short, mechanically reliable protocol prompts where ambiguity would be harmful.

## Non-goals

- Do not require agents to manufacture filler questions just to reach a multi-question batch.
- Do not remove or weaken exact-token / protocol-sensitive prompts such as preview approval (`ok / edit / cancel`) or similar mechanically constrained control flows.
- Do not edit read-only external skill packages; this repository will override them in `AGENTS.md`.
- Do not change the Maestro's separate pre-dispatch routing-question limit in this slice; that rule serves delegation control rather than ordinary subagent discovery.
- Do not prescribe a rigid formatting template for every question message beyond the policy requirements below.

## Chosen policy direction

Add an explicit repository-level override in `AGENTS.md` that changes subagent discovery behavior from **one question per message** to **batch related questions when useful, up to five per message**.

This should remain a `SHOULD`/preferred behavior rather than a hard `MUST`, because interaction quality depends on context:

- if several related questions are needed, batching reduces latency and helps the user answer in one pass
- if only one question matters, the agent should ask only that question
- if a prompt depends on exact control tokens or other protocol reliability, it may stay isolated

The same policy block should also require better choice framing: context first, options/trade-offs second, recommendation third, then the actual question or question batch.

## Required `AGENTS.md` changes

### 1. Update the recommended first subagent message

Replace the current one-question promise:

```md
"I’m the <subagent> subagent. I’ll work with you directly; I will ask one question at a time and return control to the Maestro when the scoped work is complete."
```

with wording that does not promise one-at-a-time interaction and instead leaves room for useful batching.

The replacement should communicate that the subagent may ask one or more related questions directly, while preserving the rest of the handoff intent.

### 2. Replace the one-question-per-message rule with a batching default

Replace the current rule:

```md
- Ask one clarifying question per message (repeat as needed — there is no single-question-per-session cap).
```

with policy equivalent to:

```md
- For ordinary clarifying or discovery exchanges, subagents SHOULD ask multiple related questions in the same message when that helps the user answer efficiently.
- Ask at most five questions in one message.
- If only one meaningful question is needed, ask only one; do not invent filler questions just to force a batch.
- If more questions are still pending after the current batch, say so and give a rough estimate of the remaining question count or follow-up rounds.
- Exact-token or other protocol-sensitive prompts may remain isolated when batching would reduce reliability or make the required reply ambiguous.
```

### 3. Add an explicit repository-policy override note

Because some loaded skills still instruct agents to ask one question at a time, `AGENTS.md` should make the precedence explicit for this repository.

Add wording equivalent to:

```md
- Repository policy override: when a loaded skill or subagent prompt prefers one-question-at-a-time discovery, subagents in this repository should follow the batching policy above unless a stricter protocol or routing rule in `AGENTS.md` applies.
```

This avoids leaving the override implicit.

### 4. Expand the question-framing guidance

The current line:

```md
- Ordinary subagent pause / question messages should be direct and minimal.
```

is too weak on its own for the behavior the user wants. Keep the intent of concision, but add a companion rule that says choice prompts must be informative rather than merely terse.

Add policy equivalent to:

```md
- When asking the user to choose between options, provide enough background for an informed choice, summarize the main trade-offs, state your recommendation when you have one, and briefly explain why.
- Do not hide your recommendation inside a rhetorical or loaded question.
- Prefer the order: context, options/trade-offs, recommendation, then the actual question or question batch.
```

## Acceptance criteria

- `AGENTS.md` no longer tells subagents to ask one clarifying question per message.
- The recommended first subagent message no longer promises one-question-at-a-time interaction.
- `AGENTS.md` makes multi-question batching the default for ordinary clarifying/discovery exchanges, with a batch cap of five questions.
- The policy explicitly says agents must not invent filler questions when only one meaningful question exists.
- The policy requires agents to disclose when more questions are pending and provide a rough remaining-count or remaining-rounds estimate.
- The policy preserves an exception for exact-token or otherwise protocol-sensitive prompts where batching would reduce reliability.
- The policy requires background + recommendation + brief reasoning when the user is asked to choose between options.
- The policy explicitly forbids hiding recommendations in rhetorical or loaded questions.
- The repository-level override for one-question-at-a-time skill guidance is written in `AGENTS.md` rather than left implicit.

## Risks / trade-offs

- **Risk: agents ask too many questions at once and overwhelm the user.**  
  Mitigation: keep batching to related questions only, cap at five, and preserve single-question messages when that is genuinely clearer.

- **Risk: pending-question estimates will sometimes be wrong.**  
  Mitigation: require only a rough estimate, not a commitment.

- **Risk: recommendation guidance turns into verbose mini-essays.**  
  Mitigation: keep the requirement to brief background and brief reasons; the goal is informed choice, not long persuasion.

- **Risk: external skill text still nudges authors toward one-at-a-time behavior.**  
  Mitigation: make the repository override explicit in `AGENTS.md` so local policy wins without editing packaged skills.

## Follow-up implementation notes

- The implementation slice should update `.config/opencode/AGENTS.md` only where needed for this policy change.
- If any local docs, prompts, or tests in this repository assert the old one-question wording, they should be aligned with the new policy in the same implementation slice.
- After the policy edit is made, the user should restart opencode if the running session needs to pick up the updated config-time instructions.
