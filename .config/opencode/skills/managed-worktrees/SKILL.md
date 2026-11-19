---
name: managed-worktrees
description: Resolve a managed bare-hub lane before dispatch, editing or branch operations.
---

Resolve or create a dedicated checkout before dispatching scoped authoring. `/workspaces/dotfiles/main` is the hub's default checkout. Child checkouts use `repos/<repo>/<default-branch>` and `repos/<repo>/work/<branch>`. Use `bin/clone-repo` and `bin/new-worktree` — do not substitute raw Git commands to avoid helper requirements. Consult `state/hub/etc/install.env` for the install branch. In the secured DevPod, the user applies host-side changes.

Resolve intent in order from validated lane-qualified session, artifact paths, distinguishing user text, then explicit lane/branch/worktree names. Sibling lanes sharing an artifact are separate targets. Ask if ambiguous.

Before substantive work, independently check the local checkout, branch and lane registry against that intent. Stop on unresolved or conflicting evidence, on main for a dedicated lane, or when unrelated active lanes would share a checkout. A consistent registry alone cannot establish which sibling the user meant.

Resolve the target lane before branch operations; refuse a checkout bound to another active lane.

At a hub root, stop with `Refused — hub-root CWD detected. Provide explicit worktree path.`

## Authorization: managed helper Git config

The managed helpers are explicitly authorized to set repository-local branch tracking configuration as part of their lifecycle:

- `branch.<branch>.remote = origin`
- `branch.<branch>.merge = refs/heads/<branch>`

This authorization is limited to the repository-local settings above and only within the helpers' documented flow. It does not permit:

- ad hoc Git configuration changes
- global/system Git configuration changes
- identity or credential changes
- hook bypasses
- execution outside the agent's authorized context

If any other instruction or execution boundary blocks these helpers, stop and report the conflict rather than falling back to raw Git worktree commands.
