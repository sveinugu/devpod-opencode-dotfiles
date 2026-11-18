# Prompt compaction recovery

Recovered the interrupted working-tree edits after the IDE chat history was lost. The baseline for the initial size comparisons below is `a3fdd7a`, not the unavailable conversation. These counts precede the remote-policy integration below.

Shared policy now routes conditional procedures to five harness skills under `.config/opencode/skills/`: dispatch, sessions, managed worktrees, delivery workflow and Maestro override. Agent prompts retain role ownership and routing. Models and runtime configuration are unchanged.

Compared with `a3fdd7a`, whitespace-separated word counts (agent bodies exclude YAML frontmatter) were:

| Surface | Before | After |
| --- | ---: | ---: |
| Shared AGENTS.md | 7,051 | 220 |
| All agent bodies | 3,972 | 429 |
| Shared + Maestro body | 9,092 | 377 |

Skills add roughly 1,200 words loaded by context. These are word counts, not tokenizer measurements or measured runtime savings; skill metadata and external/plugin prompts also contribute context.

Recovery review restored concise safeguards for responsibility ownership, missing session IDs, lane-sensitive branch operations, artifact conflicts and planner scope. Seven changed contract scripts passed Bash syntax checks and their static assertions on the host with only the environment precondition omitted in memory. The repository's context guards remain intact. Skill frontmatter/body structure and `git diff --check` passed. DevPod/nono execution and live OpenCode skill loading still need validation in that environment.

Future work supplied by the user: OpenCode 2, herdr with Claude Code, and a stronger Maestro model. Reassess the v1 routing and defensive prompting then; this change preserves those mechanisms.

## Remote main integration

Fast-forwarded local main to `46f94a3`, including the upstream provider fix. Reconciled the prompt refactor with the general-agent exception and explicit pre-implementation checkpoint waivers. The shared prompt, general and Maestro roles, delivery/session skills, authoring roles and handoff template now agree on these exceptions. The six upstream regression assertions were retained at the corresponding new policy locations. Planning, workspace safety, TDD, refactoring and verification remain required; Maestro still needs its two-message override for specialist work.

Validation: the seven changed contract tests and both upstream provider tests passed their host-side checks, omitting only environment preconditions in memory. Bash syntax, skill structure and diff whitespace checks passed; no unresolved merge entries remain. Unrelated local edits, including `models.md`, were verified against the pre-integration backup. Live DevPod/nono validation remains outstanding.

## Override simplification

At the user’s request, one human `maestro-override: <scope>` message now authorizes Maestro immediately. The confirmation step is removed. Specific scope, the 120-character limit, refusal of broad/wildcard scopes, and exit back to delegation remain. This supersedes the two-message requirement described in the remote integration above.
