# Working agreements

Stay within your assigned role. Relay the user's words verbatim between agents. Only a router reports session metadata. The latest clear correction supersedes the earlier request. Ask when intent is ambiguous.

Named specialists own their work and commits. When the human requests it, a general agent may perform named-specialist responsibilities without a Maestro override. The general agent must not impersonate another agent or misrepresent another session’s work.

Maestro requires a human `maestro-override: <scope>` message. On unauthorized takeover, say `Refused — owned by <subagent>; resume or re-dispatch that subagent, or use Maestro override.`

On completion, return control to your parent. Use this handoff:

“The <subagent> subagent has completed the scoped work. Returning control to the <parent agent> for orchestration and next-step delegation.”

## Execution boundaries

Harness agents must not execute work designated `pod-outside-nono` or run as the `vscode` user. This restriction covers tests, installers, diagnostics and runtime repairs, including commands relayed to subagents. Changing HOME/XDG variables does not change execution identity or grant permission.

Do not evade this boundary by:

- Bypassing context guards.
- Clearing sandbox variables.
- Switching users.
- Reproducing the underlying operations directly.

For outside-nono or vscode-only commands, ask the human to run them in their own shell and return the output. Agents may inspect and edit repository sources within their authorized checkout. They may run checks designated for their actual execution context.

Distinguish verification supplied by the human from checks run by the agent. A sandboxed reproduction is not evidence for the vscode execution context. Stop at the boundary. Do not modify another user's runtime state or weaken tests to obtain a passing result.

For all temporary file operations, use the environment's `TMPDIR` (or `TMP` / `TEMP`) variable. Use the hub-provided temporary directories instead of tool-suggested defaults such as `/home/agent/.cache/opencode/tmp`.

## Skill triggers

When a trigger below applies, use the skill tool:

- Before sending or accepting a new Maestro delegation packet, load `opencode-dispatch`.
- For Task launches, resumes and handbacks, the router loads `opencode-sessions`.
- Before scoped authoring, dispatch or branch operations in a managed hub, load `managed-worktrees`. Work from the verified checkout.
- For design, planning, implementation and review, load `delivery-workflow`, `using-superpowers` and the Superpowers skill for your role. Before handoff, use `verification-before-completion`.
- All agents must load `pragmatic-programmer` and `karpathy-guidelines`, including for design and planning. For coding, refactoring and code review, also load `clean-code`.
- When authoring or substantially revising technical documentation, policy, specifications, plans or agent instructions, load `asd-ste100`. Also load it when writing review outputs or responses to review. Apply it to your own prose. Preserve quoted material and required formats.

Within user instructions, repository policy and approved scope, skill precedence is:

`pragmatic-programmer` → `karpathy-guidelines` → `clean-code` → `obra/superpowers`

Surface material disagreements. The `delivery-workflow` skill defines how these skills share planning, TDD and refactoring responsibilities.

`asd-ste100` supports wording within that precedence. It must preserve meaning, obligations, exceptions, uncertainty and technical distinctions. It does not change workflow authority, review criteria or required reporting.

Use plain English and project terminology. Do not fetch or use the official STE dictionary, claim formal STE compliance, or introduce prose lint gates.

## Discovery questions

During discovery, group up to five related questions. Ask only what is needed and estimate the remaining rounds. Before asking for a choice, explain the options, trade-offs and your recommendation. Keep exact-token prompts separate. Do not hide recommendations in rhetorical or loaded questions.

This batching policy overrides skill or subagent preferences for one-question-at-a-time discovery. A stricter routing or protocol rule takes precedence over batching.

## Managed repository lifecycle

Use `bin/new-worktree` and `bin/clone-repo` for managed worktree and repository creation.

These approved helpers may set repository-local `branch.<branch>.remote` and `branch.<branch>.merge` tracking configuration during their documented lifecycle operations. This authorization does not permit:

- Ad hoc Git configuration changes.
- Global or system configuration changes.
- Credential or identity changes.
- Hook bypasses.
- Execution outside the agent's authorized context.

Do not substitute raw Git commands to avoid helper requirements. If another instruction or execution boundary blocks a helper, stop and report the conflict.

## Policy maintenance

When changing policy or documentation targets, update their cross-references. Shared rules and triggers live here. The linked harness skills own their procedures and role-to-skill assignments. Templates and historical records support these rules and do not replace them.

Review policy changes for retained, changed and removed obligations. For documentation and policy, use relevant structural validation. Do not add tests that freeze prose, headings or Markdown formatting. The testing policy in `delivery-workflow` distinguishes these edits from changes to executable behavior.

Run applicable checks in their designated execution context. Report checks that could not run.

### Manual additions log

This requirement applies to committed changes to `devpod-opencode-dotfiles` itself. Do not apply it to managed child repositories.

For still-current operational, security, harness/workflow or verification-strategy changes outside a full spec/plan cycle, the author must assess and update `docs/superpowers/change-records/manual-additions-log.md`. Do this after the implementation commit and before handoff.

Follow the log's organizing principles:

- Group related commits.
- Record the scope, change, rationale and actual commit references.
- Omit routine typo fixes, test-only repairs and refactors that preserve approved behavior.
- Link existing specs or runbooks instead of duplicating them.
- Never log uncommitted work or use pending placeholders.

Delegators must verify that the author handled the log. This verification does not authorize takeover, an extra commit or a new prose test.
