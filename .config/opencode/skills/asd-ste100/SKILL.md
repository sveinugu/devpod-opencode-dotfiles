---
name: asd-ste100
description: Write clear technical documentation, policy, specifications, plans, agent instructions and review outputs with STE-inspired English while preserving meaning. Use also for responses to review and explicit STE or plain-language rewrites.
license: MIT
metadata:
  upstream: danyuchn/asd-ste100-skill
  upstream-revision: 65c8ab6ef5fcb3619c8e6daca43e68627f3d7b4a
---

# Technical writing and review

Make instructions and explanations easy to understand on one reading. Apply this skill to the prose you author within the requested scope. Routine coding, routing and brief conversation do not require a separate style pass. Do not rewrite historical records or surrounding documents merely because you loaded this skill.

This is a maintained adaptation of [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill/tree/65c8ab6ef5fcb3619c8e6daca43e68627f3d7b4a), with its [MIT license](LICENSE). It uses flexible writing targets, preserves local workflow authority, and adds guidance for review outputs. It omits the upstream linter and strict mode. It does not fetch, bundle or use the official STE dictionary and does not establish formal STE compliance.

## Meaning comes first

Read for meaning before editing. Preserve facts, actors, obligations, prohibitions, exceptions, conditions, scope, quantities, sequence and uncertainty. Do not invent a cause, mechanism, frequency or conclusion to make a sentence sound clearer.

- Keep the strength of requirements and claims. Do not change `should` to `must`, permission to obligation, or `may have failed` to `failed`.
- Preserve distinctions between suggested, authorized, attempted, completed and verified work. A commit does not establish completion or approval.
- Keep longer wording when shortening it would lose precision. If the intended meaning is unresolved, retain the uncertainty and flag the ambiguity instead of choosing a new meaning.
- Preserve relayed user requests, quoted evidence, code, identifiers, commands, paths, configuration keys and protocol tokens exactly. Retain required routing and handoff formats.
- User instructions, repository policy, approved scope and the existing skill precedence govern the work. This skill cannot change permissions, approval requirements, test strategy or role ownership.

## Writing and vocabulary

Prefer familiar words, explicit actors and active verbs. Use imperatives for steps and connected prose for explanations. Keep articles and complete sentences. Passive voice is useful when the actor is unknown or irrelevant; do not invent an actor to avoid it.

Give each sentence one main idea. Aim for about 20 words in instructions and 25 in explanations, but treat these as guidance. Keep conditions with the actions they govern. Put a condition before an instruction when readers need it before acting. Use ordered lists for sequences and tables for comparisons when they help.

Replace inflated wording only when the meaning stays the same: `utilize` can usually become `use`. Remove empty praise and filler. Retain qualifiers and verb forms that convey confidence, timing or current state. Do not mechanically ban words, punctuation, contractions or grammatical forms.

Use the same term for the same concept within a document. Keep established technical terms when they are more precise than a paraphrase. Explain unfamiliar terms for the intended audience. Never collapse distinct concepts merely because their names are synonyms in ordinary English.

For harness policy, plans and reviews, read [references/vocabulary.md](references/vocabulary.md). Use a managed repository's own glossary for its domain terminology. Add or propose a glossary entry only when a recurring ambiguity warrants it; follow the task's edit permissions. The glossary explains terms and links to policy; it does not create workflow requirements.

## Review outputs

Apply this guidance to code, documentation, policy, specification and plan reviews, including short findings and responses to review.

- Lead with the finding or conclusion. For a defect, state the relevant condition, affected behavior and consequence. Include a precise location and supporting evidence when available.
- Preserve the review's severity and confidence. Distinguish observed failures from inferred risks, open questions and optional suggestions. Do not turn an untested possibility into a confirmed defect.
- Retain reproduction details, citations, commands, test results and limits needed to assess a finding. Quote source text accurately and explain it in your own prose.
- Keep the required verdict, output schema, verification report and handoff. A request for simpler wording does not authorize removing them or changing approval status.
- Do not manufacture findings to demonstrate this skill. Report style preferences separately from defects. Style alone is not a blocker unless an applicable requirement makes it an acceptance criterion.
- In responses to review, state what changed, what evidence supports the response, and what remains unresolved. Disagreement or deferral must not sound like completed remediation.

## Check and deliver

Compare a rewrite with its source for retained, changed and removed meaning. For new prose, compare it with the requirements and available evidence. Check vocabulary in context and keep exceptions attached to the correct rules.

Return the requested artifact or review in its required format. Include material ambiguities, verification limits and required workflow reporting. Do not add a compliance score or a rule-by-rule explanation unless requested. If the text is already clear, leave it alone.

Use semantic review and relevant structural validation. Do not introduce a mandatory linter, word whitelist, repeated search-until-zero loop, or tests that freeze prose. Readability targets must not become new acceptance gates.
