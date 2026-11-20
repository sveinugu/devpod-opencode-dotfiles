# Working agreements

Stay within your assigned role. Relay the user's words verbatim between agents. Only a router reports session metadata. The latest clear correction supersedes the earlier request. Ask when intent is ambiguous.

Named specialists own their work and commits. A general agent may perform named-specialist responsibilities when the human requests it, without a Maestro override. It must not impersonate another agent or misrepresent another session’s work. Maestro requires a human `maestro-override: <scope>` message. On unauthorized takeover, say `Refused — owned by <subagent>; resume or re-dispatch that subagent, or use Maestro override.`

## Execution boundaries

Harness agents do not have permission to execute work designated `pod-outside-nono` or to run as the `vscode` user. This applies to tests, installers, diagnostics and runtime repairs, including commands relayed to subagents. Changing HOME/XDG variables does not change execution identity or grant permission. Do not bypass context guards, clear sandbox variables, switch users, or reproduce the underlying operations directly to evade this boundary.

All temporary file operations must use the environment's `TMPDIR` (or `TMP` / `TEMP`) variable. Ignore any tool-suggested defaults (e.g., `/home/agent/.cache/opencode/tmp`) in favor of the hub-provided temporary directories.

Ask the human to run outside-nono or vscode-only commands in their own shell and return the output. Agents may inspect and edit repository sources within their authorized checkout and run checks designated for their actual execution context. Distinguish human-provided verification from checks run by the agent; a sandboxed reproduction is not evidence for the vscode execution context. Stop at the boundary instead of modifying another user's runtime state or weakening tests to obtain a passing result.

## Skill triggers

Use the skill tool when a trigger below applies.

- Before sending or accepting a new Maestro delegation packet, load `opencode-dispatch`. For Task launches, resumes and handbacks, the router loads `opencode-sessions`.
- Before scoped authoring, dispatch or branch operations in a managed hub, load `managed-worktrees`. Work from the verified checkout.
- For design, planning, implementation and review, load `delivery-workflow`, `using-superpowers` and the Superpowers skill for your role. Use `verification-before-completion` before handoff.
- All agents must load `pragmatic-programmer` and `karpathy-guidelines`, including for design and planning. For coding, refactoring and code review, also load `clean-code`.
- Load `asd-ste100` when authoring or substantially revising technical documentation, policy, specifications, plans or agent instructions, and when writing review outputs or responses to review. Apply it to your own prose while preserving quoted material and required formats.
- For discovery, group related questions (up to five). Ask only what is needed and estimate remaining rounds. Explain options, trade-offs and your recommendation before asking for a choice. Keep exact-token prompts separate. This batching policy overrides skill or subagent preferences for one-question-at-a-time discovery, except where a stricter routing or protocol rule applies. Do not hide recommendations in rhetorical or loaded questions.

Within user instructions, repository policy and approved scope, skill precedence is `pragmatic-programmer` → `karpathy-guidelines` → `clean-code` → `obra/superpowers`. Surface material disagreements. The `delivery-workflow` skill defines how these skills share planning, TDD and refactoring responsibilities.

`asd-ste100` supports wording within that precedence. It must preserve meaning, obligations, exceptions, uncertainty and technical distinctions. It does not change workflow authority, review criteria or required reporting. Use plain English and project terminology; do not fetch or use the official STE dictionary, claim formal STE compliance, or introduce prose lint gates.

On completion, return control to your parent. Use the handoff “The <subagent> subagent has completed the scoped work. Returning control to the <parent agent> for orchestration and next-step delegation.”

## Managed repository lifecycle

Use `bin/new-worktree` and `bin/clone-repo` for managed worktree and repository creation.

These approved helpers are explicitly authorized to set repository-local `branch.<branch>.remote` and `branch.<branch>.merge` tracking configuration as part of their documented lifecycle operations.

This authorization does not permit ad hoc Git configuration changes, global/system configuration changes, credential or identity changes, hook bypasses, or execution outside the agent's authorized context.

Do not substitute raw Git commands to avoid helper requirements. If another instruction or execution boundary blocks a helper, stop and report the conflict.

## Policy maintenance

Keep policy and documentation cross-references current when changing their targets. Shared rules and triggers live here; the linked harness skills own their procedures and role-to-skill assignments. Templates and historical records support those rules and do not replace them. Review policy changes for retained, changed and removed obligations. Use relevant structural validation for documentation and policy; do not add tests that freeze prose, headings or Markdown formatting. The testing policy in `delivery-workflow` distinguishes these edits from changes to executable behavior. Run applicable checks in their designated execution context and report checks that could not run.

For committed changes to `devpod-opencode-dotfiles` itself, the author must assess and update `docs/superpowers/change-records/manual-additions-log.md` after the implementation commit and before handoff for still-current operational, security, harness/workflow or verification-strategy changes outside a full spec/plan cycle. Follow the log's organizing principles: group related commits, record scope/change/rationale and actual commit references, and omit routine typo fixes, test-only repairs and refactors that preserve approved behavior. Link existing specs/runbooks rather than duplicating them. Never log uncommitted work or use pending placeholders. Delegators verify that the author handled the log; this does not authorize takeover, an extra commit or a new prose test. Do not apply this repository-specific log requirement to managed child repositories.
