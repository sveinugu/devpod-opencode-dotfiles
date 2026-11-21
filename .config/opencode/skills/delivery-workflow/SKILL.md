---
name: delivery-workflow
description: Apply local phase approvals, behavioral TDD and review rules to a delivery task.
---

Read this core for design, planning, implementation and review. Read the references below before performing, reviewing or supervising the corresponding work. They are binding procedures, not optional background. Apply every matching trigger; load a later phase before entering it.

## Required references

- [Planning](references/planning.md): before designing or planning, or reviewing/supervising specs, plans or acceptance criteria.
- [Implementation](references/implementation.md): before implementing, debugging or refactoring executable behavior, or planning, reviewing or supervising that work. This includes executable examples in plans or documentation.
- [Review and completion](references/review-completion.md): before arranging or performing review, responding to review, accepting delegated work, declaring completion, handing back work or completing a branch. Planners also read it when defining acceptance or completion criteria.

## Approval boundaries

Plan before implementation. An approved spec, plan or acceptance document defining the work is sufficient implementation authority. Pre-implementation checkpoints may be waived only by explicit human-agent agreement. A waiver does not waive planning, workspace safety, applicable TDD/refactoring or verification. Other check-ins remain mandatory.

Before dependent work or the next phase, wait for approval unless already authorized or that pre-implementation checkpoint was explicitly waived. Follow the detailed phase procedures above.

## What tests mean

TDD does not mean unit testing. Tests must describe specific behavior and functionality that matter to the human partner. Choose the test level that best drives the current goal.

Prioritize tests of individual software subcomponents only when they are generally useful or particularly important to the architecture. Avoid tests coupled to low-level implementation details that make behavior-preserving refactoring require extensive test rewrites.

Before implementation, use tests with the human partner to explore and define interfaces, functionality, architecture and design. When considering new interfaces or architectures, prioritize discussion around those tests unless the human says otherwise.

## Testing scope

Changes to executable behavior need verification of meaningful outcomes and applicable TDD. This includes scripts, plugins, permissions and runtime configuration. Prefer behavioral tests and parsed configuration checks over assertions about source spelling.

Documentation and policy prose normally need semantic review and relevant structural validation. They do not normally need new tests or a manufactured red/green cycle. Check meaning, consistency, references and retained, changed or removed obligations.

Keep lightweight checks for machine-consumed metadata, configuration and required files. Validate links and executable examples when relevant. These checks do not establish that an agent follows a policy.

Do not freeze policy sentences, prose headings, Markdown table rows or formatting with exact-text assertions, snapshots or keyword checks. Do not retain recurring acceptance tests for historical plans, review records or completed documentation migrations. Use the preservation inventory as a review aid, not another executable specification. Use targeted behavioral evaluations only when evidence about actual agent behavior is needed.

Put read-only repository checks in the `static` suite. They can run on host or in the pod. Tests that exercise a runtime must keep their required environment and guards. This distinction does not authorize bypassing guards or moving runtime operations into the static suite.

## Skill responsibilities

Repository policy and `pragmatic-programmer` govern test-level selection, tracer-bullet scope and design trade-offs. `karpathy-guidelines` supports simplicity, ambiguity handling and surgical changes within that policy. `obra/superpowers` governs tests-first execution discipline.

`clean-code` governs refactor quality. It may override conflicting Superpowers cleanup techniques or code-quality heuristics. `pragmatic-programmer` wins over `clean-code`.

`clean-code` must not override user instructions, repository policy, approved artifacts, the chosen test level or test protection of behavior.

## Role and skill assignments

Each [agent role prompt](../../agents/) owns its skills and responsibilities. Load those skills when performing the assigned responsibilities, alongside the shared triggers. Before delegating or supervising a role, read that role's skills and responsibilities. This preserves the general-agent exception and scoped human Maestro overrides; it does not authorize takeover or changing identity or tool permissions.

Maestro, senior-implementer and junior-implementer must not use `executing-plans`. Policy-implementer uses it for policy and document plans. All roles use `using-superpowers` and `verification-before-completion` under the shared triggers. General follows the skills for the work the human requests. Maestro communicates relevant skill usage to the user and subagents.

## Implementation

The [implementation procedure](references/implementation.md) owns TDD, prototypes, refactoring and scope-change pauses. The shared testing scope above determines applicability.

## Technical writing and review outputs

Follow the shared `asd-ste100` triggers for documentation, policy, specs, plans, agent instructions, review outputs and responses. Routine coding, routing and brief conversation do not require loading it solely for style. It supports wording within the existing precedence and does not change role ownership.
