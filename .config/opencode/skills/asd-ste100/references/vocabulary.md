# Harness vocabulary

Use these distinctions when writing about the shared harness. The [shared policy](../../../AGENTS.md) and [delivery workflow](../../delivery-workflow/SKILL.md) define authority and procedure. This reference explains their terminology without adding requirements. Preserve a managed repository's own terminology for its domain.

| Term | Meaning to preserve |
| --- | --- |
| Review | Examine work against intent, requirements and evidence. A review is not automatically approval. |
| Approval | An authorized decision to accept work or permit a step within a stated scope. Do not infer it from silence or a review iteration limit. |
| Verification | Establish evidence about an outcome. State what the evidence covers and what it does not cover. |
| Test | An executable check of specific behavior or functionality. Tests can support verification; they are not its only form. |
| Structural validation | Check machine-consumed metadata, configuration or required files. It does not prove that an agent follows prose policy. |
| Commit | A recorded Git change. It does not by itself establish verification, review approval or completion. |
| Completion | Fulfillment of the scoped task and its applicable handoff requirements. Do not equate it with an attempted action or a commit. |
| Task / session | A task is scoped work. A session carries its working context and continuity; completing work does not by itself authorize discarding that continuity. |
| Delegation / handoff | Delegation assigns work within role boundaries. A handoff transfers results or control; it does not itself expand authority. |

Preserve the distinction between obligation (`must`), prohibition (`must not`), recommendation (`should`), permission and capability (`can`). If `may` is ambiguous, use `is permitted to` for permission or `might` for possibility, but only when the intended meaning is established.

Prefer familiar words when equivalent: `use` for `utilize`, `before` for `prior to`, and `start` for `commence`. These are contextual suggestions, not automatic substitutions.

Keep precise terms such as `worktree`, `rebase`, `sandbox`, `idempotent` and `behavioral test`. Preserve actual role and skill names. Do not replace `verification`, `validation`, `review` and `approval` with one generic verb when they refer to different actions.

This is a small project glossary, not the official STE dictionary or an allowed-word list. Extend it only for demonstrated ambiguity, and keep the governing rules in their authoritative policy files.
