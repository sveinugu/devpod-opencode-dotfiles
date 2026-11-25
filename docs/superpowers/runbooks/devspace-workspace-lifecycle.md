# DevSpace Workspace Lifecycle

> What changed for implementers: `dhub` is the install-root navigation helper; child repo default branches must be preserved exactly instead of being normalized to `main`.

## Choose your environment

- **HOST:** Stay in this runbook for `devspace run-pipeline provision`, `doctor`, `repair`, `destroy`, `verify-ssh`, and `login`.
- **HOST, first-time setup:** If the bare-hub layout does not exist yet, start with [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).
- **POD:** Switch to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) for `bash install.sh`, `dhub`, `dre`, `dwt`, `bin/new-worktree`, `bin/clone-repo`, and `bin/retire-worktree`.

## Host lifecycle commands (canonical)

This runbook is the canonical source for host-side DevSpace lifecycle commands. It intentionally routes in-pod install, navigation, and managed worktree details to [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md) instead of repeating them here.

For operational/security changes shipped between full spec/plan rounds, see [Manual Additions Log](../change-records/manual-additions-log.md).

For quick model-switch procedures and fallback routing across OpenCode agents, see [OpenCode Model Routing Fallback Cheat Sheet](opencode-model-routing-fallback-cheatsheet.md).

## Required provider credential secret (before deployment)

Create this secret before deploying the workspace.

Run in the same namespace as the workspace Deployment/Pod:

```bash
kubectl create secret generic dotfiles-nono-provider-credentials \
  --from-literal=anthropic_api_key='<anthropic_api_key>' \
  --from-literal=github_token='<github_token>' \
  --from-literal=gpt_uio_yellow_api_key='<gpt_uio_yellow_api_key>' \
  --from-literal=gpt_uio_red_api_key='<gpt_uio_red_api_key>'
```

The Secret must exist, because the Deployment mounts it. It needs a key only for each provider in `HUB_ENABLED_PROVIDERS` (see [Provider enablement](#provider-enablement-host-env)); leave out the others:

| Provider | Secret key |
| --- | --- |
| `anthropic` | `anthropic_api_key` |
| `github-copilot` | `github_token`, written by `devspace run-pipeline login -p copilot` |
| `gpt-uio-yellow` | `gpt_uio_yellow_api_key`, written by `devspace run-pipeline login -p uio-yellow` |
| `gpt-uio-red` | `gpt_uio_red_api_key`, written by `devspace run-pipeline login -p uio-red` |
| `openai-chatgpt` | `openai_chatgpt_session`, written by `devspace run-pipeline login -p chatgpt` |

OpenCode refuses to launch when a key for an enabled provider is missing. A missing ChatGPT session only leaves ChatGPT out.

If the workspace was already deployed before the secret existed, the pod may need a restart or you may need to re-apply the deployment.

## Provider logins and API keys

`devspace run-pipeline login -p <provider>` stores or replaces one key in the Secret, from the host, in the namespace devspace uses. `--reset` removes the key instead; it does not revoke the credential at the provider. Every value is checked before it is stored, so a failed login or a rejected key leaves the Secret unchanged. The value reaches the cluster only through standard input of one `kubectl patch` that changes only that key.

| `-p` (`--provider`) | Secret key | How the value is obtained | Check before storing |
| --- | --- | --- | --- |
| `chatgpt` | `openai_chatgpt_session` | OpenCode login in the pod (see below) | session shape and expiry |
| `copilot` | `github_token` | OpenCode's GitHub Copilot login in the pod. It answers the deployment-type question with GitHub.com itself; open the printed URL and enter the code. GitHub Enterprise is refused. | test call to `https://api.githubcopilot.com/models` must return 200 |
| `uio-yellow`, `uio-red` | `gpt_uio_yellow_api_key`, `gpt_uio_red_api_key` | Prompt on the host; input is hidden | test call to `https://gpt.uio.no/api/v1/models` must return 200 |

For `copilot`, the stored value is the long-lived GitHub OAuth token from OpenCode's login; nono sends it as the bearer token to `api.githubcopilot.com`. After `--reset` of `github_token` or a UiO key, OpenCode refuses to launch while that provider is enabled, until a new value is stored.

New sessions use a new value after the kubelet updates the Secret mount, usually within a minute. Restart running sessions to use it.

## ChatGPT plan login (optional)

ChatGPT Plus/Pro models are available when `openai-chatgpt` is in `HUB_ENABLED_PROVIDERS` in the host `.env` (see [Provider enablement](#provider-enablement-host-env)) and a login is stored in the provider Secret. The design is in [the ChatGPT plan support spec](../specs/2026-11-19-openai-chatgpt-plan-support-design.md).

Log in from the host, in the namespace of the workspace:

```bash
devspace run-pipeline login -p chatgpt
```

The pipeline runs `ops/provider-login chatgpt` in the namespace devspace uses (`-n` in `DEVSPACE_FLAGS` in `.env`). The script refuses to run without the `DEVSPACE_NAMESPACE` value that devspace supplies. If it cannot reach the workspace Deployment, it stops before any login and does not change the Secret.

The command runs OpenCode's login in the pod, outside nono, using the pod's install branch checkout (`HUB_INSTALL_BRANCH_DIR`). The login selects OpenAI's ChatGPT Plus/Pro headless method itself and asks no questions. Open the printed URL in a browser and enter the code. The command stores only the session in the Secret key `openai_chatgpt_session` and prints the expiry date. It does not keep the refresh token, so log in again before the login expires (about every 10 days). Provisioning does not log in.

New sessions use the login after the kubelet updates the Secret mount, usually within a minute. Running sessions keep the login they started with. Restart them to use a new login.

Launch behavior when `openai-chatgpt` is enabled:

- Valid login: OpenCode gets the ChatGPT models through nono.
- Login expires within 24 hours: as above, with a warning.
- No login, or an expired or invalid login: OpenCode starts without ChatGPT and prints the login command.
- An `openai/*` model selected with `--model` or as the top-level `model`, without a valid login: the launch is refused.
- An agent role that uses an `openai/*` model without a valid login fails when that role is first used.

To disconnect, run `devspace run-pipeline login -p chatgpt --reset` and stop running sessions. This does not revoke the login at OpenAI; do that in the ChatGPT account settings. Logging out inside OpenCode does not disconnect ChatGPT.

The `openai` API-key provider and its `openai_api_key` Secret key are removed. A manifest that lists `openai` is refused.

## Provision

Run the full provision + connect sequence from the host:

```bash
devspace run-pipeline provision
devspace dev
ssh -o BatchMode=yes workspace.dotfiles.devspace 'pwd'
devspace run-pipeline verify-ssh
```

To force tool refresh during provision (pyenv):

```bash
devspace run-pipeline provision --refresh-tools
HUB_PROVISION_ARGS='--refresh-tools' devspace run-pipeline provision
```

To provision using a non-`main` install checkout via environment override:

```bash
HUB_INSTALL_BRANCH=feature/env-override devspace run-pipeline provision
```

If `HUB_INSTALL_BRANCH` is not set, provision defaults to `main`.

OpenCode is now image-installed as a pinned root-owned binary (`/usr/local/bin/opencode-raw`) and is no longer user-installed during `provision`.

Provision/doctor/repair pipelines stage helper scripts under dedicated `/tmp/dotfiles-*-staging` paths and clean them automatically at pipeline exit.

## Update pinned OpenCode version

Use the helper to bump pinned OpenCode version + linux checksums in `Dockerfile`:

```bash
bin/update-opencode-version --latest
# or
bin/update-opencode-version --version v1.18.5
```

Then rebuild + redeploy:

```bash
devspace build
devspace deploy
```

## Provider enablement (host `.env`)

For the secure-path policy summary and verification checklist behind this workflow, see [nono Policy](nono-policy.md).

Set the enabled providers in the host `.env`, next to `HUB_INSTALL_BRANCH`. Separate providers with spaces or commas:

```bash
HUB_ENABLED_PROVIDERS="gpt-uio-yellow github-copilot openai-chatgpt"
```

This is the only provider enablement setting. If it is unset or empty, no provider is enabled. Supported providers are the keys of `supported_providers` in `.config/opencode/provider-policy.jsonc`. To apply a change, run `devspace run-pipeline provision`. Start new OpenCode sessions after it; running sessions keep their configuration.

Provision passes the value to `bin/sync-provider-enablement --enabled` from the install branch. The command refuses unknown providers, duplicates and the removed `openai` token, and then changes nothing. Otherwise it writes these read-only generated files in the pod:

```text
/workspaces/dotfiles/state/hub/etc/provider-enablement.json
<install branch>/.config/opencode/provider-runtime.json
<install branch>/.config/opencode/provider-verification.json
```

Do not edit them in the pod; the next provision replaces them. The wrapped `opencode` reads the install-branch runtime file.

`bash install.sh` regenerates the runtime files of the checkout it installs from the same manifest. That checkout's policy may not support every provider in the manifest, for example one added on another branch. Such a provider is skipped with a warning and listed under `skipped_providers` in `provider-verification.json`; the strict check applies only to the `.env` value in provision.

## Rebuild workspace image

```bash
devspace build
```

Optional local-development override to keep broad `sudo` during image iteration:

```bash
devspace build --var HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL=1
```

The variable is declared in `devspace.yaml` via `vars` with `source: env` and `default: "0"`; `--var` is the explicit CLI override path for one-off builds.

This repo also sets `DEVSPACE_ENV_FILE` to `.env` in `devspace.yaml`, so project-local `.env` values can override defaults without shell exports.

Default behavior is hardened (`HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL=0`), which removes `/etc/sudoers.d/vscode` and keeps only the constrained sudoers rules used by the secure launch chain.
Use the override only for temporary local debugging; do not keep it enabled for shared or production-like images.

Then redeploy:

```bash
devspace deploy
```

If your Kubernetes cluster cannot pull from your local image store, push to a registry and use a registry-qualified image name in `devspace.yaml`.

## Doctor

Run a read-only health checklist from the host:

```bash
devspace run-pipeline doctor
```

Behavior:

- exit `0`: all required checks pass
- exit `1`: one or more required checks failed
- exit `2`: invalid CLI usage

The v1 checklist includes Deployment/PVC presence, pod reachability, top-level bare-hub validity, managed directory existence, canonical `state/hub/main` and `tmp/hub/main` paths, `/home/vscode` symlink targets, and installed-branch reporting from `state/hub/etc/install.env` when present.

## Repair

Run non-destructive structural recovery:

```bash
devspace run-pipeline repair
```

Behavior:

- recreates missing managed directories (`work/`, `repos/`, `state/`, `tmp/`)
- recreates canonical top-level paths (`state/hub/main`, `tmp/hub/main`)
- reattaches `main` only when `.bare` is valid and recognizable
- preserves valid non-`main` `/home/vscode` symlink targets
- resolves install source in this order: explicit `HUB_INSTALL_BRANCH`, then `state/hub/etc/install.env`, then `main`
- keeps `/workspaces/dotfiles/main` attached to `main` even when install source is non-`main`
- refuses when identity is ambiguous, `.bare` is invalid, or managed paths conflict by type

Inspect installed-branch state before repair:

```bash
cat /workspaces/dotfiles/state/hub/etc/install.env
```

`repair` is best-effort and non-destructive; it does not delete existing files or worktrees.

Child repo note: preserve the exact child remote default branch name when reconstructing or validating managed child checkouts.

## Destroy

Run destructive reset:

```bash
devspace run-pipeline destroy
```

Behavior:

- deletes Deployment/pod
- deletes PVC
- does not preserve uncommitted work, runtime session data, or `/home/vscode` content on the deleted PVC

After `destroy`, run `devspace run-pipeline provision` to recreate from scratch.

## After the host step, continue in pod

Once `devspace dev` is open and `/workspaces/dotfiles` is mounted:

- run `bash /workspaces/dotfiles/main/install.sh` from an explicit checkout
- use `dhub`, `dre`, and `dwt` for navigation
- create managed worktrees with `/workspaces/dotfiles/main/bin/new-worktree`
- onboard child repos with `/workspaces/dotfiles/main/bin/clone-repo`
- retire managed worktrees with `/workspaces/dotfiles/main/bin/retire-worktree`

Secure `opencode` launch reminder after install:

```bash
command -v opencode
type -a opencode
```

Expected:

- wrapped path first: `$HOME/.config/opencode/bin/opencode`
- raw path still available only by explicit absolute path (for example `/usr/local/bin/opencode-raw`)

Current secure-launch runtime shape:

- wrapped launch uses constrained `sudo` + `setpriv` handoff to the non-sudo `agent` identity
- nono runtime profile is generated under `/etc/nono/profiles/runtime`
- wrapped runtime state uses `/home/agent` (`HOME` + XDG runtime paths)

For those in-pod commands, use [DevSpace Bare Hub Usage](devspace-bare-hub-usage.md). For first-time host layout creation, use [Host Bare-Hub Bootstrap](host-bare-hub-bootstrap.md).

In pod, interactive `new-worktree` / `clone-repo` shell wrappers auto-jump to created checkouts by default; set `HUB_WORKSPACE_NAV_DISABLE_AUTO_CD=1` to opt out.
