# Working agreements

Stay within your assigned role. Relay the user's words verbatim between agents. Only a router reports session metadata. The latest clear correction supersedes the earlier request. Ask when intent is ambiguous.

Named specialists own their work and commits. A general agent may perform named-specialist responsibilities when the human requests it, without a Maestro override. It must not impersonate another agent or misrepresent another session’s work. Maestro requires a human `maestro-override: <scope>` message. On unauthorized takeover, say `Refused — owned by <subagent>; resume or re-dispatch that subagent, or use Maestro override.`

## Execution boundaries

Harness agents do not have permission to execute work designated `pod-outside-nono` or to run as the `vscode` user. This applies to tests, installers, diagnostics and runtime repairs, including commands relayed to subagents. Changing HOME/XDG variables does not change execution identity or grant permission. Do not bypass context guards, clear sandbox variables, switch users, or reproduce the underlying operations directly to evade this boundary.

Ask the human to run outside-nono or vscode-only commands in their own shell and return the output. Agents may inspect and edit repository sources within their authorized checkout and run checks designated for their actual execution context. Distinguish human-provided verification from checks run by the agent; a sandboxed reproduction is not evidence for the vscode execution context. Stop at the boundary instead of modifying another user's runtime state or weakening tests to obtain a passing result.

## Skill triggers

Use the skill tool when a trigger below applies.

- Before sending or accepting a new Maestro delegation packet, load `opencode-dispatch`. For Task launches, resumes and handbacks, the router loads `opencode-sessions`.
- Before scoped authoring, dispatch or branch operations in a managed hub, load `managed-worktrees`. Work from the verified checkout.
- For design, planning, implementation and review, load `delivery-workflow`, `using-superpowers` and the Superpowers skill for your role. Use `verification-before-completion` before handoff.
- For coding, refactoring and code review, load `pragmatic-programmer`, `karpathy-guidelines` and `clean-code`. Resolve conflicts in that order within user instructions, repository policy and approved scope. Surface material disagreements.
- For discovery, group related questions (up to five). Ask only what is needed and estimate remaining rounds. Explain options, trade-offs and your recommendation before asking for a choice. Keep exact-token prompts separate.

On completion, return control to your parent. Use the handoff “The <subagent> subagent has completed the scoped work. Returning control to the <parent agent> for orchestration and next-step delegation.”

## Managed repository lifecycle

Use `bin/new-worktree` and `bin/clone-repo` for managed worktree and repository creation.

These approved helpers are explicitly authorized to set repository-local `branch.<branch>.remote` and `branch.<branch>.merge` tracking configuration as part of their documented lifecycle operations.

This authorization does not permit ad hoc Git configuration changes, global/system configuration changes, credential or identity changes, hook bypasses, or execution outside the agent's authorized context.

Do not substitute raw Git commands to avoid helper requirements. If another instruction or execution boundary blocks a helper, stop and report the conflict.
