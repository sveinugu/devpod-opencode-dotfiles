# nono Policy

This document is canonical policy summary; profile JSON + tests are enforcing artifacts.

Primary enforcing artifacts:

- Spec: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- Profile: `.config/nono/profiles/devspace-opencode-secure.jsonc`
- Contracts: `tests/devspace/test_nono_profile_layout.sh`, `tests/devspace/test_opencode_secure_wrapper_contract.sh`, `tests/devspace/test_nono_identity_integration_contract.sh`

## Scope & authority

This runbook is the first-read policy surface for the repo-supported secure `opencode` path under `nono`.
It summarizes the binding contract, while the design spec, profile JSON, wrapper/helper scripts, Kubernetes deployment, and contract tests remain the enforcing artifacts.

Use this runbook to understand the supported path, then verify details against:

- `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`
- `.config/nono/profiles/devspace-opencode-secure.jsonc`
- `.config/opencode/bin/opencode`
- `scripts/lib/nono-secret-env.sh`
- `k8s/devspace-bare-hub/workspace-deployment.yaml`

## What nono does by default

Assume the reader knows nothing about stock `nono` behavior.

Upstream `nono` defaults relevant here are:

- filesystem access is deny-by-default unless explicitly granted
- network access is allowed by default unless restricted
- all environment variables are inherited by default unless filtered
- the stock default profile includes sensitive-path deny groups and `dangerous_commands`-style command blocking

Examples of upstream-sensitive paths called out in the `nono` docs include:

- `~/.ssh/`
- `~/.aws/`
- `~/.gnupg/`
- `~/.kube/`
- shell history and shell config files

This repo-specific profile does **not** assume those defaults are obvious. It overrides and narrows behavior explicitly:

- it sets `workdir.access` to `readwrite`
- it defines exact filesystem grants instead of relying on the stock `opencode` profile
- it filters inherited environment variables with an explicit allow-list plus provider-key deny-list
- it excludes `dangerous_commands` and `dangerous_commands_linux` because the supported launch chain needs constrained pre-sandbox `sudo`; protection here comes from filesystem, environment, identity, and runtime-chain controls rather than a command denylist

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

Operationally, the goal is to keep real provider credentials out of ordinary agent bash scope while preserving normal `opencode` usability through the wrapped secure path.
The supported path is practical hardening, not a claim of absolute isolation, and it does not prevent misuse of already-authorized proxy-routed provider access.

## Filesystem policy

- no broad grants for `/home/agent` or `~/.local/share`
- explicit subdir grants only
- precreate runtime dirs via init container

The reviewed profile allows only the runtime surfaces OpenCode needs, plus the fixed raw binary path `/usr/local/bin/opencode-raw` as `allow_file`.
Runtime state is pinned under `/home/agent` with specific XDG paths, and the deployment precreates those directories via an init container before daily use.

Default path-variable values in this launch chain are:

- `$HOME` = `/home/agent`
- `$WORKDIR` = `<current active worktree>`
- `$XDG_CACHE_HOME` = `/home/agent/.cache`
- `$XDG_CONFIG_HOME` = `/home/agent/.config`
- `$XDG_DATA_HOME` = `/home/agent/.local/share`
- `$XDG_STATE_HOME` for the `nono` process = `/home/agent/.local/state/nono`
- `$XDG_STATE_HOME` for the wrapped `opencode` child = `/home/agent/.local/state/opencode`

Fixed-path grants for the sandboxed agent are exactly:

- `/home/agent/.cache/opencode` (`$XDG_CACHE_HOME/opencode`) — read+write
- `/home/agent/.config/opencode` (`$XDG_CONFIG_HOME/opencode`) — read+write
- `/home/agent/.local/share/opencode` (`$XDG_DATA_HOME/opencode`) — read+write
- `/home/agent/.local/share/opentui` (`$XDG_DATA_HOME/opentui`) — read+write
- `/home/agent/.local/state/nono/opencode` (`$XDG_STATE_HOME/opencode` in the profile template) — read+write
- `/home/agent/.opencode` (`$HOME/.opencode`) — read+write
- `/tmp` — read+write temporary workspace
- `/usr/local/bin/opencode-raw` (`allow_file`) — single-file read/execute target, not directory access

Worktree-dependent grants are:

- `<current active worktree>` (`$WORKDIR`) — read+write worktree access
- `<current active worktree>/.zprofile` (`$WORKDIR/.zprofile`) — read-only, with explicit bypass through the upstream shell-config deny group
- `<current active worktree>/.zshrc` (`$WORKDIR/.zshrc`) — read-only, with explicit bypass through the upstream shell-config deny group

At runtime, the wrapper pins these paths under the `agent` identity, centered on `/home/agent` plus the worktree.

The sandboxed agent is not granted broad access to `/home/agent`, `/home/agent/.local/share`, `/usr/local/bin`, or `/var/run/secrets/nono/providers`.
It also does not receive blanket exceptions for shell configs: only `$WORKDIR/.zshrc` and `$WORKDIR/.zprofile` are exempted from the upstream shell-config deny group.

Repo anchors for this contract:

- `.config/nono/profiles/devspace-opencode-secure.jsonc`
- `k8s/devspace-bare-hub/workspace-deployment.yaml`
- `tests/devspace/test_nono_profile_layout.sh`

## Execution chain policy

- wrapped launcher → constrained sudo → setpriv drop to `agent` → `nono` → raw `opencode`
- raw binary path and ownership contract

The supported launch path is implemented by `.config/opencode/bin/opencode`.
That wrapper reads the generated provider runtime contract, generates a filtered runtime `nono` profile through `/usr/local/libexec/dotfiles-generate-nono-profile`, and then launches the pinned raw binary at `/usr/local/bin/opencode-raw` only after the setpriv drop to `agent`.

This chain is expected to be the default command resolution for `opencode` by name.
Raw `opencode` remains available only by explicit absolute path and is out-of-scope manual use.

Important restriction detail: this profile intentionally does **not** rely on upstream dangerous-command blocking for the supported path.
Instead, the security boundary is the documented wrapped launcher, constrained `sudo`, `setpriv` drop to `agent`, the fixed secret mount surface, the filtered environment, and the reviewed filesystem grants above.

Repo anchors for this contract:

- `.config/opencode/bin/opencode`
- `tests/devspace/test_opencode_secure_wrapper_contract.sh`
- `tests/devspace/test_nono_identity_integration_contract.sh`

## Credential policy

- provider-secret source, env mapping, generated runtime profile filtering

Provider secrets are sourced from the fixed Kubernetes mount `/var/run/secrets/nono/providers`.
For the supported path, secret reads happen only through the constrained non-interactive `sudo -n` helper contract in `scripts/lib/nono-secret-env.sh`, which maps mounted secret files into the specific env vars needed for the wrapped launch path, such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `GPT_UIO_YELLOW_API_KEY`, and `GPT_UIO_RED_API_KEY`.

The generated runtime profile is filtered to the enabled provider set before `nono` launch so disabled provider credential routes do not remain in the active runtime profile.
Interactive shell startup files, repo files, `.env` files, and agent-readable auth storage are not supported credential-bearing surfaces for this path.

Allowed inherited environment variables in this profile are exactly:

- `PATH`, `HOME`, `TERM`, `LANG`, `LC_ALL`, `USER`, `SHELL`, `PWD`
- `XDG_*`, `HUB_*`, `OPENCODE_*`

This profile explicitly strips `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, `GPT_UIO_YELLOW_API_KEY`, and `GPT_UIO_RED_API_KEY` from inherited sandbox environment state.
Real provider secrets are loaded before sandbox entry by the constrained helper and are then consumed by the wrapped launch path, rather than being inherited from the caller shell.

Credential routes configured in this profile are exactly `openai`, `anthropic`, `github-copilot`, `gpt-uio-yellow`, and `gpt-uio-red`.
Their configured upstreams are:

- `openai` → `https://api.openai.com`
- `anthropic` → `https://api.anthropic.com`
- `github-copilot` → `https://api.github.com`
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
- `tests/devspace/test_opencode_secure_wrapper_contract.sh`

## Change policy

- how to add a new writable path/provider safely
- required tests to update

When adding a new writable path, prefer the smallest explicit runtime subdirectory and update both the reviewed profile and the deployment/init-container contract if the path must exist before runtime.
Do not add broad grants for `/home/agent`, `~/.local/share`, or unrelated parent directories.

When adding or changing a provider, update the spec/plan contract first when the supported provider set changes, then keep the profile, generated runtime contract, helper mapping, and runbooks aligned.
If a supported-provider verification fails, stop shipment for the slice until the route is fixed or the provider set is explicitly re-approved with updated docs and acceptance criteria.

Required tests to update are the relevant docs contracts plus the enforcing runtime contracts affected by the change.

If a change depends on a stock `nono` behavior, document that dependency explicitly instead of assuming readers know it.

## Verification checklist

Minimal checks after policy-affecting changes:

```bash
command -v opencode
type -a opencode
bash tests/devspace/test_nono_profile_layout.sh
bash tests/devspace/test_opencode_secure_wrapper_contract.sh
bash tests/devspace/test_nono_identity_integration_contract.sh
bash tests/docs/test_nono_policy_runbook_contract.sh
```

Expected shape:

- `command -v opencode` resolves to the wrapped launcher first
- `type -a opencode` shows the wrapped path before the raw binary path
- the three DevSpace contract tests and the docs contract stay green

For broader secure-path validation, also use the design-spec verification matrix in `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`.

## More information

Upstream `nono` documentation:

- Introduction: `https://nono.sh/docs/introduction`
- Architecture overview: `https://nono.sh/docs/cli/internals/overview`
- Profiles & groups: `https://nono.sh/docs/cli/features/profiles-groups`
- Environment filtering: `https://nono.sh/docs/cli/features/environment`
- Networking: `https://nono.sh/docs/cli/features/networking`
- Credential injection: `https://nono.sh/docs/cli/features/credential-injection`
