---
name: managed-worktrees
description: Resolve a managed bare-hub lane before dispatch, editing or branch operations.
---

Resolve or create a dedicated checkout before dispatching scoped authoring. `/workspaces/dotfiles/main` is the hub's default checkout. Child checkouts use `repos/<repo>/<default-branch>` and `repos/<repo>/work/<branch>`. Prefer `bin/clone-repo` and `bin/new-worktree`. Consult `state/hub/etc/install.env` for the install branch. In the secured DevPod, the user applies host-side changes.

Resolve intent in order from validated lane-qualified session, artifact paths, distinguishing user text, then explicit lane/branch/worktree names. Sibling lanes sharing an artifact are separate targets. Ask if ambiguous.

Before substantive work, independently check the local checkout, branch and lane registry against that intent. Stop on unresolved or conflicting evidence, on main for a dedicated lane, or when unrelated active lanes would share a checkout. A consistent registry alone cannot establish which sibling the user meant.

Resolve the target lane before branch operations; refuse a checkout bound to another active lane.

At a hub root, stop with `Refused — hub-root CWD detected. Provide explicit worktree path.`
