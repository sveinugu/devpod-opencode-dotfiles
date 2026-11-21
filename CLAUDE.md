# Repository instructions

This repository manages a personal DevPod/OpenCode bare-git workspace hub on Kubernetes through DevSpace. It contains zsh configuration, agent configuration and workspace lifecycle scripts.

Before acting, read the [shared policy](.config/opencode/AGENTS.md) unless its full current text is already supplied in context. This also applies to Claude Code; do not assume that OpenCode loaded it. Follow its skill and reference triggers. If no skill tool is available, read the named skill's `SKILL.md` and required references directly. Report unavailable required guidance rather than silently skipping it.

`/workspaces/dotfiles` is the bare hub root, not an editable checkout. Never work directly in it. Use an explicit worktree path: `/workspaces/dotfiles/main`, `/workspaces/dotfiles/work/<branch>`, or a managed child checkout under `/workspaces/dotfiles/repos/<name>/`. Install and provision scripts refuse the hub root.

Read these references when their conditions apply:

- Before install, provisioning, navigation or harness-layout work: [repository reference](docs/superpowers/runbooks/repository-reference.md).
- Before selecting or running checks: [test guidance](tests/README.md).
- Before authoring in `docs/superpowers/`, and before committing or handing back changes to this repository: [authoring and committed-work logging rules](docs/superpowers/AGENTS.md). Delegators read these rules when verifying the author's log maintenance.

These repository-specific references do not impose dotfiles logging duties on managed child repositories.
