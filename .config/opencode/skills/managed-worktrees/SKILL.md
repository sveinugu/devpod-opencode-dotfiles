---
name: managed-worktrees
description: Resolve a managed bare-hub lane before dispatch, editing or branch operations.
---

## Resolve a checkout

Before dispatching scoped authoring, resolve or create a dedicated checkout. The hub's default checkout is `/workspaces/dotfiles/main`. Child checkouts use `repos/<repo>/<default-branch>` and `repos/<repo>/work/<branch>`.

Use `bin/clone-repo` and `bin/new-worktree` to create checkouts. Use `bin/retire-worktree` to remove them safely. Do not substitute raw Git commands to avoid helper requirements.

Consult `state/hub/etc/install.env` for the install branch. In the secured DevPod, the user applies host-side changes.

At a hub root, stop with `Refused — hub-root CWD detected. Provide explicit worktree path.`

## Identify and verify the lane

Resolve intent from these sources, in this order:

1. Validated lane-qualified session.
2. Artifact paths.
3. Distinguishing user text.
4. Explicit lane/branch/worktree names.

Sibling lanes that share an artifact are separate targets. Ask if the target is ambiguous.

Before substantive work, independently check the local checkout, branch and lane registry against that intent. Stop when:

- Evidence is unresolved or conflicting.
- The checkout is on main for a dedicated lane.
- Unrelated active lanes would share a checkout.

A consistent registry alone cannot establish which sibling the user meant. Before branch operations, resolve the target lane. Refuse a checkout bound to another active lane.

## Authorization: managed helper Git config

The managed helpers are explicitly authorized to set repository-local branch tracking configuration as part of their lifecycle:

- `branch.<branch>.remote = origin`
- `branch.<branch>.merge = refs/heads/<branch>`

This authorization covers only the repository-local settings above, within the helpers' documented flow. It does not permit:

- ad hoc Git configuration changes
- global/system Git configuration changes
- identity or credential changes
- hook bypasses
- execution outside the agent's authorized context

If another instruction or execution boundary blocks these helpers, stop and report the conflict. Do not fall back to raw Git worktree commands.
