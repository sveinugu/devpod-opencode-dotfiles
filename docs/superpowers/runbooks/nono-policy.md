# nono Policy

This document is the canonical policy summary. The profile JSON and tests enforce the policy.

Primary enforcing artifacts:

- Spec: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- Profile: `.config/nono/profiles/devspace-opencode-secure.jsonc`
- Contracts: `tests/pod-inside-nono/test_nono_profile_layout.sh`, `tests/pod-inside-nono/test_opencode_secure_wrapper_contract.sh`, `tests/pod-inside-nono/test_nono_identity_integration_contract.sh`

## Quick orientation

`nono` is a kernel-enforced sandbox for running commands with explicit filesystem, environment, and network permissions.

Use this runbook to understand the practical policy for the repo-supported secure `opencode` path. Consult the spec, profile JSON, wrapper and tests for details.

## Supported path at a glance

- `opencode` by name resolves to the repo wrapper, not directly to the raw binary.
- The wrapper reads only the provider secrets needed for the enabled routes through the constrained pre-sandbox helper.
- The wrapper drops from `vscode` to the non-sudo `agent` identity with `setpriv` before the sandboxed process starts.
- `nono` launches `/usr/local/bin/opencode-raw` with the reviewed generated profile and filtered runtime configuration.

## In scope vs. out of scope

- In scope: the repo-supported secure path reached by invoking `opencode` from `PATH` after install.
- Out of scope: intentionally invoking `/usr/local/bin/opencode-raw` directly or using ad hoc user-defined providers outside this repo contract.

## Scope & authority

Start with this runbook for the repo-supported secure `opencode` path under `nono`. It summarizes the binding contract.

The design spec, profile JSON, wrapper/helper scripts, Kubernetes deployment and contract tests remain the enforcing artifacts.

Use this runbook to understand the supported path, then verify details against:

- `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- `.config/nono/profiles/devspace-opencode-secure.jsonc`
- `.config/opencode/bin/opencode`
- `scripts/lib/nono-secret-env.sh`
- `k8s/devspace-bare-hub/workspace-deployment.yaml`

Build-time sudoers toggle (workspace image only):

- `HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL=0` (default) removes broad `vscode` sudoers grants and keeps constrained sudoers rules only.
- `HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL=1` installs explicit broad `vscode` debug sudo (`vscode ALL=(ALL) NOPASSWD:ALL`) for temporary local debugging.
- This toggle changes operator convenience only. The supported secure launch path and its constrained wrapper contracts remain the canonical production-like target.

## What nono does by default

Assume the reader knows nothing about stock `nono` behavior.

The upstream engine default is not the same thing as the stock `default` profile or the stock `opencode` profile.

### Upstream engine defaults

Upstream `nono` defaults relevant here are:

- filesystem access is deny-by-default unless explicitly granted
- network access is allowed by default unless restricted
- all environment variables are inherited by default unless filtered

### Stock profiles and groups

The stock `default` profile and stock tool profiles add restrictions to the engine defaults. These include built-in sensitive-path deny groups and `dangerous_commands`-style command blocking.

Examples of upstream-sensitive paths called out in the `nono` docs include:

- `~/.ssh/`
- `~/.aws/`
- `~/.gnupg/`
- `~/.kube/`
- shell history and shell config files

### Repo-specific overrides

This repo-specific profile does **not** assume those defaults are obvious. It overrides and narrows behavior explicitly:

- it sets `workdir.access` to `readwrite`
- it defines exact filesystem grants instead of relying on the stock `opencode` profile
- it filters inherited environment variables with an explicit allow-list plus provider-key deny-list
- it excludes `dangerous_commands` and `dangerous_commands_linux` because the supported launch chain needs constrained pre-sandbox `sudo`

Protection here comes from filesystem, environment, identity and runtime-chain controls rather than a command denylist.

Upstream reference docs:

- `https://nono.sh/docs/introduction`
- `https://nono.sh/docs/cli/internals/overview`
- `https://nono.sh/docs/cli/features/profiles-groups`
- `https://nono.sh/docs/cli/features/environment`
- `https://nono.sh/docs/cli/features/networking`
- `https://nono.sh/docs/cli/features/credential-injection`

## Threat model / goals

- least privilege
- explicit credential routing
- reproducible startup chain

Keep real provider credentials out of ordinary agent bash scope while preserving normal `opencode` usability through the wrapped secure path.

The supported path provides practical hardening, not absolute isolation. It does not prevent misuse of already-authorized proxy-routed provider access.

## Filesystem policy

- no broad grants for `/home/agent` or `~/.local/share`
- explicit subdir grants only
- precreate runtime dirs via init container

The sandbox gets broad managed-workspace access through `/workspaces/dotfiles`. Other access is limited to a narrow set of OpenCode runtime directories under `/home/agent`, `/tmp`, the direnv allow-list directory under `$XDG_DATA_HOME/direnv`, and the single raw binary path.

The reviewed profile allows only the runtime surfaces OpenCode needs, plus the fixed raw binary path `/usr/local/bin/opencode-raw` as `allow_file`.

Runtime state is pinned under `/home/agent` with specific XDG paths. Before daily use, the deployment creates those directories through an init container.

Default path-variable values in this launch chain are:

- `$HOME` = `/home/agent`
- `$XDG_CACHE_HOME` = `/home/agent/.cache`
- `$XDG_CONFIG_HOME` = `/home/agent/.config`
- `$XDG_DATA_HOME` = `/home/agent/.local/share`
- `$XDG_STATE_HOME` for the `nono` process = `/home/agent/.local/state`
- `$XDG_STATE_HOME` for the wrapped `opencode` child = `/home/agent/.local/state`

Fixed-path grants for the sandboxed agent are exactly:

- `/home/agent/.cache/opencode` (`$XDG_CACHE_HOME/opencode`) — read+write
- `/home/agent/.config/opencode` (`$XDG_CONFIG_HOME/opencode`) — read+write
- `/home/agent/.local/share/opencode` (`$XDG_DATA_HOME/opencode`) — read+write
- `/home/agent/.local/share/opentui` (`$XDG_DATA_HOME/opentui`) — read+write
- `/home/agent/.local/state/opencode` (the app-specific state subdirectory under `$XDG_STATE_HOME`) — read+write
- `/home/agent/.local/share/direnv` (`$XDG_DATA_HOME/direnv`) — read+write, for `direnv allow` to write its allow-list file inside the sandbox
- `/home/agent/.opencode` (`$HOME/.opencode`) — read+write
- `/home/agent/.gitconfig` (`$HOME/.gitconfig`) — read-only, so git `safe.directory` trust config is visible without granting write to home-level git config
- `/etc/gitconfig` — read-only, so system-level git `safe.directory` trust config remains readable to sandboxed git processes
- `/usr/local/bin/git`, `/usr/local/bin/git-upload-pack`, `/usr/local/bin/git-receive-pack`, and `/usr/local/bin/git-upload-archive` — allowed by explicit command policy. Sandbox constraints use these stable absolute executable paths, not ephemeral `/tmp/nono-tool-sandbox-*` shim globs.
- `/tmp` — read+write temporary workspace
- `/workspaces/dotfiles` — read+write, for broader hub filesystem access by the sandboxed agent
- `/usr/local/bin/opencode-raw` (`allow_file`) — single-file read/execute target, not directory access

Workspace-scoped grants are:

- `/workspaces/dotfiles` — read+write for managed top-level checkout(s), worktrees, shared bare repo metadata, and child repo trees
- `/workspaces/dotfiles/**/.zprofile` — read-only, with explicit bypass through the upstream shell-config deny group
- `/workspaces/dotfiles/**/.zshrc` — read-only, with explicit bypass through the upstream shell-config deny group

At runtime, the wrapper pins these paths under the `agent` identity, centered on `/home/agent` plus `/workspaces/dotfiles`.

The sandboxed agent is not granted broad access to `/home/agent`, `/home/agent/.local/share`, `/usr/local/bin`, or `/var/run/secrets/nono/providers`.
It receives no blanket exceptions for shell configs outside the managed workspace root. Only `/workspaces/dotfiles/**/.zshrc` and `/workspaces/dotfiles/**/.zprofile` are exempted from the upstream shell-config deny group.

Repo anchors for this contract:

- `.config/nono/profiles/devspace-opencode-secure.jsonc`
- `k8s/devspace-bare-hub/workspace-deployment.yaml`
- `../../../tests/pod-inside-nono/test_nono_profile_layout.sh`

## Execution chain policy

- wrapped launcher → constrained sudo → setpriv drop to `agent` → `nono` → raw `opencode`
- raw binary path and ownership contract
- nono launched with `--allow-cwd --no-rollback-prompt --silent` to suppress interactive prompts

The supported launch path is implemented by `.config/opencode/bin/opencode`.
The wrapper reads the generated provider runtime contract. It generates a filtered runtime `nono` profile through `/usr/local/libexec/dotfiles-generate-nono-profile`. Only after the setpriv drop to `agent` does it launch the pinned raw binary at `/usr/local/bin/opencode-raw`.

The launch helper (`scripts/lib/launch-opencode-nono.sh`) appends three nono flags to every invocation:

- `--allow-cwd` — allow the current working directory without interactive prompting, so the wrapped `opencode` launch does not pause for cwd confirmation
- `--no-rollback-prompt` — skip the post-exit rollback review prompt that would otherwise require the user to press ESC to dismiss
- `--silent` — suppress nono output: banner, session summary and status messages. Post-session breach reports go to the audit trail but are not displayed interactively.

Raw `opencode` remains available only by explicit absolute path and is out-of-scope manual use.

This profile intentionally does **not** rely on upstream dangerous-command blocking for the supported path.

The security boundary consists of the documented wrapped launcher, constrained `sudo`, `setpriv` drop to `agent`, fixed secret mount surface, filtered environment and reviewed filesystem grants above.

Repo anchors for this contract:

- `.config/opencode/bin/opencode`
- `../../../tests/pod-inside-nono/test_opencode_secure_wrapper_contract.sh`
- `../../../tests/pod-inside-nono/test_nono_identity_integration_contract.sh`

## Credential policy

- provider-secret source, env mapping, generated runtime profile filtering

Provider secrets are sourced from the fixed Kubernetes mount `/var/run/secrets/nono/providers`.
For the supported path, only the constrained non-interactive `sudo -n` helper contract in `scripts/lib/nono-secret-env.sh` reads secrets. It maps mounted secret files to the environment variables needed for the wrapped launch path. Examples include `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `GPT_UIO_YELLOW_API_KEY`, and `GPT_UIO_RED_API_KEY`.

Before `nono` launches, the generated runtime profile is filtered to the enabled provider set. Disabled provider credential routes do not remain in the active runtime profile.
Interactive shell startup files, repo files, `.env` files, and agent-readable auth storage are not supported credential-bearing surfaces for this path.

Allowed inherited environment variables in this profile are exactly:

- `PATH`, `HOME`, `TERM`, `LANG`, `LC_ALL`, `USER`, `SHELL`, `PWD`
- `XDG_*`, `HUB_*`, `OPENCODE_*`

This profile explicitly strips `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `GPT_UIO_YELLOW_API_KEY`, and `GPT_UIO_RED_API_KEY` from inherited sandbox environment state.
Before sandbox entry, the constrained helper loads real provider secrets. The wrapped launch path then consumes them. It does not inherit them from the caller shell.

These secrets are not ordinary interactive-shell environment variables.

During the constrained pre-sandbox step, the helper reads them from `/var/run/secrets/nono/providers`. They persist only across the one documented `sudo` handoff. The wrapped launch path then consumes them for proxy setup and launch.
The sudoers contract keeps only the launch-step provider variables needed for that handoff; it is not a general-purpose shell inheritance path.

The constrained sudoers runtime launch rule delegates to one root-owned launch helper (`/usr/local/libexec/dotfiles-launch-opencode-nono`). It does not match the full wrapped launch command inline. This reduces drift risk and keeps argument validation and least-privilege boundaries explicit in one audited helper.

The wrapper always emits an end-of-options marker (`--`) before forwarding user args. The sudoers contract must therefore allow both launch-helper forms: with trailing argv (`-- *`) and without trailing argv (`--`).

Credential routes configured in this profile are exactly `openai`, `anthropic`, `github-copilot`, `gpt-uio-yellow`, and `gpt-uio-red`.
Their configured upstreams are:

- `openai` → `https://api.openai.com`
- `anthropic` → `https://api.anthropic.com`
- `github-copilot` → `https://api.githubcopilot.com` (Authorization: `Bearer <token>`)
- `gpt-uio-yellow` → `https://gpt.uio.no/api/v1`
- `gpt-uio-red` → `https://gpt.uio.no/api/v1`

The reviewed template also limits TLS-intercept trust propagation to these CA environment variables only:

- `SSL_CERT_FILE`
- `REQUESTS_CA_BUNDLE`
- `NODE_EXTRA_CA_CERTS`
- `CURL_CA_BUNDLE`
- `GIT_SSL_CAINFO`

At the template-file level, these credential routes and CA-propagation variables are the explicit network-related settings present in `.config/nono/profiles/devspace-opencode-secure.jsonc`.
For broader upstream behavior and secure-path runtime semantics, use the wrapper contract, runtime tests, and the upstream networking / credential-injection docs linked above.

Repo anchors for this contract:

- `scripts/lib/nono-secret-env.sh`
- `.config/opencode/provider-runtime.json`
- `.config/nono/profiles/devspace-opencode-secure.jsonc`
- `../../../tests/pod-inside-nono/test_opencode_secure_wrapper_contract.sh`

## Change policy

- how to add a new writable path/provider safely
- required tests to update

When adding a new writable path, prefer the smallest explicit runtime subdirectory. If the path must exist before runtime, update both the reviewed profile and the deployment/init-container contract.
Do not add broad grants for `/home/agent`, `~/.local/share`, or unrelated parent directories.

When adding or changing a provider, first update the spec/plan contract if the supported provider set changes. Then keep the profile, generated runtime contract, helper mapping and runbooks aligned.
If a supported-provider verification fails, stop shipment for the slice. Resume shipment only after the route is fixed or the provider set is explicitly re-approved with updated docs and acceptance criteria.

Update the enforcing runtime contracts affected by a behavior or configuration change. Review prose changes for meaning and consistency. Validate references where relevant. Do not add exact-wording documentation tests.

If a change depends on a stock `nono` behavior, document that dependency explicitly instead of assuming readers know it.

## Verification checklist

Minimal runtime checks after changes to the secure launch behavior or configuration (run in their required context):

```bash
command -v opencode
type -a opencode
bash tests/pod-inside-nono/test_nono_profile_layout.sh
bash tests/pod-inside-nono/test_opencode_secure_wrapper_contract.sh
bash tests/pod-inside-nono/test_nono_identity_integration_contract.sh
```

Expected shape:

- `command -v opencode` resolves to the wrapped launcher first
- `type -a opencode` shows the wrapped path before the raw binary path
- the three runtime contract tests stay green

For broader secure-path validation, also use the design-spec verification matrix in `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`.

## `nono why --self` workaround (Linux pod / OpenCode)

- Use `nono-why --self ...` instead of `nono why --self ...` when diagnostics run from Linux pod OpenCode sessions that hit stdin/PTY drift.
- The wrapper lives at `~/.config/opencode/bin/nono-why` and rebases volatile `NONO_CAP_FILE` entries (`/dev/stdin`, `/proc/self`, `/dev/fd`, and stdio aliases) before invoking `nono why`.
- This is a temporary operator workaround for `nono why --self` session-state path drift in this environment.
- Track upstream status at `https://github.com/nolabs-ai/nono/issues/1647`; remove this workaround once `nono why --self` is robust in this Linux pod context.

## More information

Upstream `nono` documentation:

- Introduction: `https://nono.sh/docs/introduction`
- Architecture overview: `https://nono.sh/docs/cli/internals/overview`
- Profiles & groups: `https://nono.sh/docs/cli/features/profiles-groups`
- Environment filtering: `https://nono.sh/docs/cli/features/environment`
- Networking: `https://nono.sh/docs/cli/features/networking`
- Credential injection: `https://nono.sh/docs/cli/features/credential-injection`
