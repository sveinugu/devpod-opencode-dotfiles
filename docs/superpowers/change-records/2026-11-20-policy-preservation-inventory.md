# Policy preservation after prompt compaction

This inventory maps the shared policy and agent responsibilities before `77fbe497` (`77fbe497^`) to their maintained locations after restoration. It covers policy meaning, including conditions and exceptions, rather than requiring duplicate wording. Shared triggers remain in `.config/opencode/AGENTS.md`; conditional procedures remain in harness skills.

Statuses: **Retained** means the obligation survived compaction; **Restored** means missing or weakened obligations are explicit again; **Intentional change** identifies an accepted difference; **Removed** identifies redundant or obsolete material and its reason. A row may group closely related obligations, but each names the behavior to preserve. This inventory is a change record, not a second source of policy.

## Delivery requirements

| Original requirement | Status | Maintained location and behavior |
| --- | --- | --- |
| Every agent loads pragmatic-programmer and Karpathy | Restored | [Shared triggers](../../../.config/opencode/AGENTS.md#skill-triggers), including design and planning. |
| Clean-code loads for coding, refactoring and reviews | Retained | Shared triggers; the workflow protects approved scope, test level and behavior. |
| Pragmatic → Karpathy → clean-code → Superpowers precedence; surface disagreements | Restored | Shared triggers and [delivery workflow](../../../.config/opencode/skills/delivery-workflow/SKILL.md#implementation) distinguish design authority, TDD discipline and refactor quality. |
| TDD tests express meaningful behavior, not necessarily units | Restored | Delivery workflow, “What tests mean”; select the level that drives the goal. |
| Subcomponent tests need general usefulness or architectural importance | Restored | Test definition; avoid tests coupled to implementation details that obstruct refactoring. |
| Tests explore interfaces, functionality, architecture and design with the user before implementation | Restored | Test definition prioritizes this discussion for new interfaces or architectures unless the user directs otherwise. |
| Brainstorm before planning; plan before implementation | Retained | Delivery workflow, “Design and planning”; brainstorming remains a recommendation where useful. |
| Authors write/commit specs and plans, present path and commit, and obtain phase approval | Retained | Design and planning, subject to explicitly agreed pre-implementation waivers. |
| An adequate approved spec or acceptance document can authorize implementation without another plan | Retained | Design and planning; no mandatory redundant artifact. |
| Plans focus on goals, tests, constraints, risks and user checkpoints | Restored | Tests are primary deliverables; high-level plans explicitly override detailed `writing-plans` instructions unless the user requests details. |
| Checkpoint waivers do not waive planning, workspace safety, TDD, refactoring or verification | Retained | Design and planning; only agreed pre-implementation check-ins may be waived. |
| Acceptance-test documents stay behavioral; check-in markers belong in plans/specs | Retained | Design and planning and test definition. |
| Cross-layer/tracer work starts with integration or contract tests; isolated logic with focused units | Retained | Implementation; the restored test-level authority governs tracer-bullet scope. |
| Prefer real interactions; justify unavoidable mocks in test headers | Retained | Implementation. |
| Isolate prototypes in worktrees or prototype branches; remove or convert before merge | Retained | Implementation; prototype code cannot pass through unchanged. |
| Offer interface-test review; surface divergence and test-discovered gaps before dependent work | Retained | Implementation; pause for material divergence and update scope with applicable approval. |
| Red, verify red, green, verify green, refactor, verify green | Retained | Implementation. |
| Every slice has a standalone refactor checkpoint, even when no refactor is needed | Restored | Implementation explicitly covers every TDD slice and records cleanup or the no-change conclusion. |
| Inspect changed and connected code for naming, duplication, boundaries and readability | Restored | Refactor checkpoint; record follow-up cleanups and rerun relevant tests. |
| Refactors that change behavior or make irreversible architectural changes outside scope require approval | Restored | Explicit refactor pause, alongside existing scope protections. |
| User first review/manual testing completes before automated review unless directed otherwise | Restored | Review and completion; wait until the user is content and facilitate direct author discussion. |
| Review committed work; return feedback to original author; author commits revisions | Retained | Review and completion; author may explain disagreements. |
| Iterate until reviewer approval or more than ten iterations; do not auto-advance phases | Retained | Review and completion; iteration limit does not confer approval. |
| Conversational review by default; durable record only if requested or required | Retained | Reviewer owns a required record unless reassigned; GitHub review history suffices for PR review. |
| Run both diagnostics before declaring feature completion | Restored | Completion gate reports pragmatic diagnostic and clean-code results in PR, review summary or handoff. |
| Score below 8 requires 1–3 remediation tasks; material clean-code issues require 1–3 tasks or justified deferral | Restored | Completion gate restores explicit timing and bounded cleanup follow-up. |
| PR template is optional; relevant sections/N/A; requested format preserves evidence | Restored | Completion reporting; template is a reporting aid, not authority. |
| Policy deviations need justification and explicit human approval recorded in PR | Restored | Completion reporting preserves location and explicit approval. |

## Ownership and routing requirements

| Original requirement | Status | Maintained location and behavior |
| --- | --- | --- |
| Named specialists own work and commits; no impersonation or takeover | Retained | Shared working agreements and agent prompts. |
| General may perform specialist work when the human requests it | Retained | Shared policy and general prompt; no Maestro override needed. |
| Maestro delegates through actual Task launches and does not claim failed launches succeeded | Retained | Maestro prompt and [sessions](../../../.config/opencode/skills/opencode-sessions/SKILL.md). |
| At most one routing-only question, at most 18 words | Retained | Maestro prompt; discovery belongs to the specialist. |
| Skill instructions addressed to “you” follow specialist ownership | Restored | Maestro prompt explicitly interprets “you” as the owning specialist. |
| Explicit role-to-Superpowers skill mapping | Restored | [Role and skill assignments](../../../.config/opencode/skills/delivery-workflow/SKILL.md#role-and-skill-assignments) covers Maestro, implementers, authors and reviewers; load each skill when performing its responsibility. |
| Maestro/senior/junior do not use executing-plans; policy implementer does | Restored | Role assignments retain the code/policy workflow distinction. |
| Senior chooses junior delegation and owns its workflow until handback; juniors do not delegate | Retained | Senior/junior prompts and role assignments; senior code/model-selection responsibility is explicit. |
| Maestro monitors TDD, verifies subagent verification and checks spec/plan/implementation alignment | Restored | Maestro prompt; senior also checks junior TDD and verification before accepting work. |
| Planner supports TDD; reviewers understand TDD and report noncompliance | Restored | Role assignments alongside the existing review and planning duties. |
| Brainstormer/planner code is limited to disposable experiments and plan examples | Retained | Respective prompts; planner test examples support interface discussion. |
| Docs writer maintains docstrings, automated doctests and shared documentation; no production work beyond doctests | Retained | Docs-writer prompt; macros remain appropriate when useful. |
| Reviewers leave changes to authors and clean up review scripts | Retained | Reviewer prompts. |
| Maestro owns top-level parallel dispatch, worktrees, GitHub and branch completion; rebase before local merge by default | Retained | Maestro prompt, role assignments and workflow completion rules. |
| One role/work-item/lane per session; exact task IDs and immediate launch/resume/handback metadata | Retained | Sessions; IDs remain opaque and validated, never invented or normalized. |
| Preserve existing sessions for overlapping work, even after completion | Restored | Sessions checks before every launch; follow-up questions and revisions return to the existing owner. Explicit user direction is needed for another overlapping session. |
| Explicit resume token routes unchanged to its exact owner; ambiguous tokenless requests require clarification | Retained | Sessions; distinct plans and sibling lanes use separate sessions. |
| No automatic retry/replacement on failure; preserve token and ask for direction | Retained | Sessions; senior forwards recovery to Maestro, with transcript fallback. |
| Recovery must not reinterpret intent; user-reported misdelivery counts as failed resume | Restored | Sessions explicitly covers both rules. |
| Return control to parent with required completion handoff | Retained | Shared working agreements. |

## Dispatch and workspace requirements

| Original requirement | Status | Maintained location and behavior |
| --- | --- | --- |
| Closed packet schema, exact artifact/worktree paths, verbatim quoted user text | Retained | [Dispatch skill](../../../.config/opencode/skills/opencode-dispatch/SKILL.md); new scoped delegation only. |
| Full message default; chronological multi-message separators; factual warnings only | Retained | Dispatch skill; interpretations, steering, inferred deliverables and extra prose prohibited. |
| Annex has fixed headings, matching whole-line highlights, questions, labelled hypotheses and raw evidence | Retained | Dispatch skill; Annex cannot add requirements. |
| Preview required for partial/multiple messages, warnings, Annex, new artifacts or interpretation choices | Retained | Dispatch skill; validates before launch and refuses invalid packets. |
| Exact single-token preview response tied to the displayed content | Restored | Dispatch skill explicitly rejects punctuated/expanded approval tokens and restricts preview wrapper content. |
| Edit invalidates prior approval; cancellation discards attempt and requires a new cycle | Restored | Dispatch skill spells out cancellation lifecycle alongside existing edit/revalidate/preview rules. |
| No rebuilding approved content from memory; textual identity checked before launch | Restored | Dispatch skill; mismatch requires refusal and fresh approval, with only launch-generated metadata excepted. |
| Missing quotes, N/A request, mismatched highlight or conflicting artifacts stop substantive work | Retained | Dispatch receiver rules; read all binding artifacts, summarize in first response, escalate to delegator then user. |
| Delegation design provenance remains discoverable | Restored | Dispatch skill names the original packet design and preview-identity follow-on, without asserting runtime enforcement. |
| Hub roots are not editable; resolve dedicated checkout before dispatch | Retained | [Managed worktrees](../../../.config/opencode/skills/managed-worktrees/SKILL.md); exact hub-root refusal remains. |
| Lane intent order, independent checkout/branch/registry checks, stop on ambiguity or conflicting lanes | Retained | Managed worktrees; a consistent registry does not establish user intent. |
| Resolve lane before branch operations; distinct sibling lanes cannot share targets accidentally | Retained | Managed worktrees and sessions. |
| Host changes are applied by the human; secured environment boundaries | Retained | Managed worktrees plus newer shared execution-boundary rules. |
| Batch discovery questions, cap at five, avoid filler, estimate remaining rounds, explain choices | Retained | Shared triggers. |
| Batching overrides one-question-at-a-time skills; no rhetorical/loaded choice framing | Restored | Shared triggers explicitly preserve the override and framing restriction. |
| Clear immediate corrections supersede previous intent; ambiguity requires asking | Retained | Shared working agreements and sessions. |
| Keep cross-references current and check changed policy contracts | Restored | Shared policy maintenance; use current test paths and required execution contexts. |

## Intentional changes and removed duplication

| Difference from the old text | Status | Reason |
| --- | --- | --- |
| One-message Maestro override replaces confirmation exchange | Intentional change | User-requested change recorded in [prompt compaction recovery](2026-11-18-prompt-compaction.md#override-simplification). Specific scope, 120-character limit, refusal outside scope and exit remain. |
| Opposite-model-family document review | Intentional change | Preserve the subsequent current configuration using docs-reviewer-gpt and docs-reviewer-claude; do not resurrect the former single docs-reviewer. |
| Managed lifecycle helpers and execution boundaries are stricter in current policy | Intentional change | Preserve subsequent policy; do not regress to the old helper preference or remove sandbox/context guards. |
| Shared AGENTS as the sole procedure source | Intentional change | Keep the compact shared triggers and canonical skill procedures, with role mappings centralized in the delivery skill. |
| Duplicate packet sections, repeated session instructions and repeated bare-hub guidance | Removed | Canonical skill procedures now cover these requirements; duplication is not needed for preservation. |
| Mandatory planner authorship of specs despite brainstormer owning design specs | Removed | Resolve the old internal inconsistency using named author ownership: brainstormer authors design specs, planner authors plans, subject to existing exceptions. |
| Historical hardware example, introductory team branding and bootstrap change banner | Removed | These are context, not delivery obligations; operational workspace rules remain. |
| Suggested introductory subagent greeting and repetitive troubleshooting examples | Removed | Optional wording is unnecessary; actual launch, failure handling, ownership and required handoff rules remain. |
| Links to obsolete tests/docs paths | Removed | Policy maintenance points to relevant current contract tests in their designated contexts. |

## Contract coverage and validation

The changed contracts protect delivery semantics, explicit role assignments, supervision, session continuity, interaction overrides and preview identity. They are static document contracts, not live-agent behavioral tests, and do not prove that an agent follows the instructions.

Run these in the required DevPod/nono context:

```sh
bash tests/pod-inside-nono/test_clean_code_policy_contract.sh
bash tests/pod-inside-nono/test_maestro_intent_preservation_policy.sh
bash tests/pod-inside-nono/test_multi_question_interaction_policy.sh
bash tests/pod-inside-nono/test_delegation_packet_policy_contract.sh
```

Host validation is limited to shell syntax, diff whitespace and documentation link inspection. The contract tests and live OpenCode skill loading still require their actual runtime context; guards must not be bypassed to claim validation.
