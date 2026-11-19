# OpenAI ChatGPT Plus/Pro plan support

Status: draft for approval (2026-11-19, revision 5, after four docs-reviewer-gpt reviews)
Related: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`, `docs/superpowers/specs/2026-11-19-opencode-host-local-model-overrides-design.md`, `https://nono.sh/docs/cli/features/sandboxed-oauth-logins`

## Problem

OpenCode can use OpenAI models through a ChatGPT Plus/Pro subscription ("ChatGPT Pro/Plus" login, OAuth). This workspace supports only API-key providers whose real secrets stay outside the sandbox (credential-phasing spec). `auth.json` is not an accepted credential source, and no subscription-based path is supported.

The ChatGPT login stores OAuth access and refresh tokens in OpenCode's `auth.json`. Left alone, those tokens would be readable by the sandboxed agent.

## Goals

1. OpenCode inside the DevSpace pod, under nono, can log in with a ChatGPT Plus account and use the models OpenCode shows for that login that the signed-in plan authorizes. Pro uses the same flow and is labelled unverified unless a Pro account is tested (see gate 10).
2. The sandbox never holds real OAuth material from a supported ChatGPT login: `auth.json` contains only nono phantom tokens, and the intermediate device-flow credentials are also phantoms (see nono profile). The OAuth capture provider is present in every mode, so an unsupported in-session ChatGPT login also yields phantoms only. When `openai-chatgpt` is not enabled, the proxy also refuses to redeem those phantoms for ChatGPT requests (see Opt-out semantics). What the design does not enforce is listed under Auth-state guard.
3. The existing OpenAI API-key path keeps working, under a clearer name, with a defined cutover and rollback.
4. The ChatGPT-plan models appear as the `#3` fallback in the committed routing comments, and the previous `#3` becomes `#4`.

## Non-goals

- Using ChatGPT login outside the pod (a host-only OpenCode is out of scope).
- The "ChatGPT Pro/Plus (browser)" login method. It redirects to `localhost:1455`, which a browser outside the pod cannot reach, and its code exchange is not mediated by this design. Only the headless method is supported.
- Choosing models by hand: the model list is whatever OpenCode shows for the login.
- Using both ChatGPT OAuth and the OpenAI API key at the same time (see Decisions).
- Automatic fallback between providers (unchanged from the overrides spec).
- Any change to the K8s secret names, the `OPENAI_API_KEY` env var or the existing nono credential route names.
- Restricting the OAuth route with an `endpoint_policy`; it may be added later.

## Decisions

1. **Credential route: nono `oauth_capture`.** Login runs inside the sandbox; nono's proxy rewrites OAuth token material so OpenCode stores `nono_<64hex>` phantoms. Real tokens live in nono's capture store outside the sandbox. This keeps the credential-phasing spec's secrecy guarantee and needs no exception to its "no `auth.json` as credential source" rule, because `auth.json` holds only phantoms.
2. **Two enablement tokens, one OpenCode provider.** OpenCode uses the provider id `openai` for both API keys and ChatGPT OAuth. The repo's enablement manifest distinguishes them:
   - `openai-api`: the existing API-key path, renamed from `openai`. Behavior is unchanged.
   - `openai-chatgpt`: new, ChatGPT plan OAuth. It needs no API-key secret.
   Both map to OpenCode's `openai`. Enabling both is refused, because they would configure the same OpenCode provider with two different auth methods.
3. **The persisted auth entry decides the transport, so the launcher guards it.** OpenCode 1.19.6 chooses the ChatGPT transport from the persisted `openai` entry (`type: oauth`), not from this repo's manifest, and `enabled_providers` controls provider selection, not what the sandbox can read in `auth.json`. The manifest alone therefore cannot enforce the mode. A launch-time guard checks the `openai` entry against the enabled token, and a restricted operator recovery action clears a rejected entry (see Auth-state guard and Recovery). The guard enforces launch-time state only; the design does not claim to control what the user does inside a running session.
4. **Rename scope.** The rename changes only the enablement token (manifest, seed, provider policy, sync script, wrapper and generator mappings, tests, docs). The nono route name `openai`, the secret file `openai_api_key` and the env var `OPENAI_API_KEY` stay. The sync script and policy refuse a manifest that lists `openai`, with a message saying it was renamed to `openai-api`. The wrapper and the generator keep `openai` as a legacy alias of `openai-api` for one release, so stale generated outputs and mixed-version rollouts keep working (see Rollout and migration).
5. **Model list.** `openai-chatgpt` uses `mode: all`, like the other standard providers: no repo-owned model list.
6. **Fallback placement.** ChatGPT plan is `#3` and the old `#3` is `#4`, per role, as listed under Fallback chains.
7. **Image artifacts.** The profile template, the profile generator, the launch helper, the new recovery helper and the quarantine directory are root-owned image artifacts, so this change ships as a rebuilt and redeployed image, not as a checkout edit.

## Design

### Enablement and runtime

- `provider-enablement.seed.json` and `provider-policy.jsonc` list `openai-api` and `openai-chatgpt` (each `mode: all`, no models) in place of `openai`. In the seed, `openai-api` replaces `openai` and `openai-chatgpt` is not added, so ChatGPT login stays opt-in per host manifest.
- `bin/sync-provider-enablement` accepts the new tokens, refuses `openai-api` together with `openai-chatgpt`, and refuses a bare `openai` with the rename hint.
- The OpenCode-facing provider list (`enabled_providers` in `OPENCODE_CONFIG_CONTENT`) contains `openai` for either token, deduplicated, so host-local model overrides keep naming models as `openai/<model>`. The repo-side tokens remain available to the wrapper and the profile generator, which need them to choose secrets and nono routes. The exact runtime-file shape is decided in the plan; the contract is that the OpenCode config never sees a token name that is not an OpenCode provider id.
- Override validation does not check `openai/<model>` names against a list (no list exists for `all` mode), like `github-copilot`. A mistyped model fails on first use.
- The wrapper's secret mapping needs no secret for `openai-chatgpt`. `openai-api` and the legacy alias `openai` keep mapping to `openai_api_key`.

### nono profile

In `.config/nono/profiles/devspace-opencode-secure.jsonc`, one `credential_providers.openai_chatgpt` entry of type `oauth_capture` with a matching `credential_routes` entry. OpenCode 1.19.6 uses these endpoints in the headless flow, and each is configured separately:

| Endpoint (on `https://auth.openai.com`) | Request body | Real material in the response | Phantomed response fields | Request fields where phantoms are resolved |
| --- | --- | --- | --- | --- |
| `/api/accounts/deviceauth/usercode` | JSON | none (`device_auth_id`, `user_code`: a poll handle and a code the user types) | none; not listed as a token endpoint | none |
| `/api/accounts/deviceauth/token` | JSON | `authorization_code`, `code_verifier` | `authorization_code` and `code_verifier`, both `opaque` | none |
| `/oauth/token` (code exchange and refresh) | form | `access_token`, `refresh_token`, `id_token` | `access_token`, `refresh_token` as `opaque`; `id_token` as `jwt` | `code`, `code_verifier`, `refresh_token` |

- The goal is that neither the device-flow `authorization_code` and `code_verifier` nor the final tokens are readable in real form by the sandbox. `id_token` is not persisted in `auth.json` by OpenCode, but it is real token material in the response, so it is phantomed as `jwt` for the client's local claim parsing.
- `api_hosts`: `https://auth.openai.com` and `https://chatgpt.com`. OpenCode 1.19.6 rewrites model requests to `https://chatgpt.com/backend-api/codex/responses` and sends the access token there as a bearer.
- `credential_store`: mandatory. A `file_json` entry for `$HOME/.local/share/opencode/auth.json` with `phantom_fields` `openai.access` and `openai.refresh` (the fields OpenCode persists; no `id_token`). The nono 0.82.0 schema accepts `file_json` with `path` and `phantom_fields`. The path must equal `<runtime XDG_DATA_HOME>/opencode/auth.json`; the wrapper's default runtime data home is `/home/agent/.local/share`, and a test asserts the two agree. If `nono profile validate` rejects the entry on the deployed nono (gate 1), the slice stops and the spec is revised; there is no silent downgrade.
- The existing `network.tls_intercept.ca_env_vars` already includes `NODE_EXTRA_CA_CERTS`, which OpenCode (Bun) honors; no new CA variable is expected.
- Whether nono passes through non-phantom values in the resolved request fields, and fails closed on token-shaped responses at unconfigured paths, is not documented. Gate 0 tests it. If the deployed nono cannot mediate the full exchange, stop and re-plan; do not ship a partial mediation.

`scripts/lib/generate-nono-profile.py` keeps the OAuth provider in the generated profile in every mode, so a ChatGPT login started inside a running session in any mode still stores phantoms, never real tokens. What the provider may redeem depends on the mode (see Opt-out semantics). `openai-api` (and the legacy alias `openai`) select the existing `openai` API-key route. The generator refuses an enabled provider token it does not know, instead of silently ignoring it as today.

#### Opt-out semantics

Decision: when `openai-chatgpt` is not enabled (modes `openai-api` and neither), opt-out means **no ChatGPT model traffic authenticated by this integration**: the proxy must not redeem a phantom for a request to the ChatGPT backend. It does not mean no outbound request to the ChatGPT host. The base profile allows all domains (`allow_domain: ["*"]`), the same as for every other host, and this design does not add a network-level deny for `chatgpt.com`; a request there carries no account credential unless the user supplies one inside the session. `enabled_providers` only controls OpenCode's selection; it does not limit what the proxy authorizes, so the profile enforces the narrower promise:

| Mode | Capture of token responses | `api_hosts` (where phantoms are redeemed) | Route `endpoint_policy` |
| --- | --- | --- | --- |
| `openai-chatgpt` | on | `https://auth.openai.com`, `https://chatgpt.com` | none (or an allowlist later) |
| `openai-api`, neither | on | `https://auth.openai.com` only | default deny, no allow rules |

- The two layers are deliberate: `chatgpt.com` is not a redemption host in the opt-out modes, and the route denies all provider API egress. A phantom sent to `chatgpt.com` is therefore not resolved in those modes. If the human later wants the stronger promise (no outbound requests to the ChatGPT backend at all), that needs a network-level deny and a test without a phantom; it is not part of this design.
- Capture stays on, so a ChatGPT login that a user starts in a running session in an opt-out mode produces phantoms and no real token reaches the sandbox.
- Remaining capability, stated for human approval: in the opt-out modes the proxy can still exchange or refresh a retained phantom at the `auth.openai.com` token endpoint (the `request_nonce_fields` resolution). That yields new phantoms and carries no model traffic.
- Logout removes the local `auth.json` entry, not the proxy's mappings (kept up to 90 days). The opt-out enforcement above holds regardless of retained mappings; in `openai-chatgpt` mode a retained mapping stays redeemable until it expires or the operator revokes it at OpenAI.
- nono 0.82.0's behavior for capture without redemption and for a deny-all route policy is not documented. Gate 0(d) tests it with a synthetic negative redemption against a positive control, including after logout and after a mode switch. If nono cannot enforce this, stop and return to the human with two options: drop the always-on capture (an in-session login in an opt-out mode would then store real tokens in `auth.json`), or accept the proxy's redemption capability in opt-out modes as UI selection only. Neither is assumed.

### Auth-state guard

Before the sandbox starts, the root-owned launch helper checks the persisted `openai` entry in `<runtime XDG_DATA_HOME>/opencode/auth.json` against the enabled token, using shapes only. "Phantom oauth" means `type: oauth` with `access` and `refresh` both phantom-shaped (`nono_` plus 64 hex).

| Enabled token | `openai` entry absent | Phantom oauth entry | Any other state (API key, `oauth` with non-phantom values, other type, unparseable file) |
| --- | --- | --- | --- |
| `openai-chatgpt` | launch (login pending) | launch | refuse |
| `openai-api` (or legacy `openai`) | launch | refuse (it would select the ChatGPT transport) | refuse |
| neither | launch | launch (harmless phantoms, kept for re-enable) | refuse |

What this enforces, and what it does not:

- **Enforced:** at launch, the `openai` entry holds no real credential. In API-key mode a persisted `type: api` entry is refused too, because that path delivers the key through nono injection and `auth.json` is not a credential source (credential-phasing spec). An entry for `openai` that is not a phantom is refused in every mode.
- **Enforced by the always-present OAuth capture:** a ChatGPT login completed in a running session, in any mode, stores phantoms. In the opt-out modes the proxy additionally refuses to redeem them for ChatGPT requests (Opt-out semantics).
- **Not enforced:** what the user types or selects inside a running session. OpenCode 1.19.6 still offers other login methods, including "Manually enter API Key", which writes a real key into `auth.json` where the sandbox can read it. The launcher cannot stop that. It is detected and refused at the next launch (the table above), and the runbook says to use only the headless method. A mode-incompatible change after launch therefore takes effect for the remainder of that session and is caught at the next start; the design does not claim otherwise.
- **Out of scope:** other providers' entries in `auth.json`. The guard reads, and its output reveals, only the `openai` entry's type and the shape of `access` and `refresh`.
- A refusal prints the entry name, the failing shape and the Recovery command. It never prints token values and never changes `auth.json`.
- The plan decides where the check runs and how the mode reaches it. The constraint is that it runs with access to the agent's data directory, before launch, and adds no sudo permission beyond the existing wildcard launch rule.

### Recovery

A refusal must not block its own recovery. Logging out through the wrapper does not work for a rejected state, because the wrapper refuses to start. Recovery is therefore a separate, restricted operator action, not a session.

The helper:

- is `dotfiles-openai-auth-recover`, a root-owned executable in the image. The human operator runs it with `sudo`; it is not offered to harness agents, which cannot run outside-nono actions;
- removes only the `openai` key from `auth.json` and leaves every other entry unchanged;
- starts no OpenCode session, accepts no arguments, prints no values and touches no network.

Quarantine. The rejected credential must not stay readable by the next sandbox, so the helper never leaves a copy beside the live file or anywhere the profile grants:

- The quarantine directory is `/var/lib/dotfiles-auth-quarantine`, created by the image as `root:root`, mode `0700`, outside every path the profile grants to the sandbox, and not owned by `agent`. Each quarantined file is created `0600 root:root` under a timestamped name.
- The helper never deletes quarantined files; the operator removes them after checking. The runbook says they may hold real credentials and gives the removal step.
- For an unparseable `auth.json`, the whole file is copied into quarantine and then removed from the live path. For a parseable one, only the `openai` entry's previous state is saved (the rest of the file is not copied), and the live file is rewritten without it.

Identity and file safety. A root-owned executable does not have to run as root for every step, and the sandbox is the same UID as the live file, so it can plant symlinks there. The helper therefore:

- performs all reads and writes of the live file (`<runtime XDG_DATA_HOME>/opencode/auth.json` and its temporary file in the same directory) as the `agent` uid, with `O_NOFOLLOW`, and writes the new file atomically with the original owner and mode. Only the quarantine write needs root;
- refuses, without changing anything, a live path that is not a regular file, is a symlink or has a symlinked parent component, any other file type, a quarantine directory with the wrong type, owner or mode, and a directory it cannot open safely.

Sudoers. The addition is one line that names the helper with an explicit empty argument list, `""`, as in `vscode ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-openai-auth-recover ""`. A command path alone permits any arguments under sudoers semantics, so the `""` is what denies them. It is the only new sudo permission in this design. A static test checks that the line has the `""` form; the authorization itself is checked on the image (`sudo -l` with an extra argument must be denied), which only the human can run.

Recovery sequences:

- **Mode switch with a clean phantom state:** `opencode auth logout openai` through the wrapper in the original mode works, because the guard accepts that state. This is the normal path.
- **Rejected state (raw OAuth entry, API key entry, unparseable file, or phantom state in API mode):** run the recovery helper, then launch normally.
- **Rollback from ChatGPT to API mode:** log out through the wrapper in ChatGPT mode, or run the recovery helper, before switching the manifest. Because the guard refuses a phantom oauth entry in API mode, skipping this step surfaces as a refusal, and the recovery helper clears it.
- Real tokens from a ChatGPT login stay valid at OpenAI until revoked. The runbook tells an operator who is dropping ChatGPT access to revoke the session in their ChatGPT account.

### Login

Login runs through the wrapped launcher in the pod and uses the "ChatGPT Pro/Plus (headless)" method (device code). OpenCode 1.19.6 has two entrypoints that use the same `openai` provider auth definition and the same OAuth endpoints:

- `opencode auth login` (alias `opencode providers login`): the documented path, needing no running TUI session.
- `/connect` inside the TUI, which reaches the same flow through OpenCode's server API.

Both run inside the sandbox, so nono's rewriting applies to both. Whether they share identical code is not proven; gate 2 therefore checks each entrypoint from a clean auth state.

The nono runbook documents the steps, how to enable `openai-chatgpt` in the host manifest, how to switch modes (log out first; see Auth-state guard), how to collect diagnostics, and how to check `auth.json` by shape without printing token values.

### Diagnostics

The nono debug targets (`nono_proxy::oauth_capture`, `nono_proxy::tls_intercept`) are needed while verifying. The constrained `sudo` handoff does not preserve `RUST_LOG`: the launch helper builds the nono environment from fixed values, and `env_keep` lists only the provider secrets. The wrapped path therefore gets a fixed diagnostics switch implemented in the launch helper, not a pass-through of arbitrary environment:

- The switch sets only those two debug targets for the nono process, and writes nono's log to a file in a fixed location the operator can read.
- It adds no sudo rules and no env pass-through; the existing wildcard launch rule must already accept the extra argument, which the plan confirms.
- Logs are redacted by construction (the two nono targets log matches and rewrites, not bodies), but that is an assumption, not a proof. Gate 0 therefore checks, under the real launcher with synthetic credentials, that no synthetic credential value appears in the log file.
- The log file lives outside every path the profile grants to the sandbox. The nono supervisor writes it as `agent`, the same UID as the child, so only Landlock keeps the child away from it. Gate 0 checks that the child can neither read nor modify the file, so the operator's evidence cannot be tampered with from inside.
- The runbook says never to enable other log targets that dump request or response bodies.

### Rollout and migration

The generator, profile template and launch helper are installed into root-owned paths by the Dockerfile, so an image rebuild and redeploy is part of this change. The wrapper and sync script run live from the install-branch checkout, so mixed versions are possible during rollout. An old image's generator silently drops provider tokens it does not know, which would remove the API route without any error.

Operator order:

1. Build and deploy the candidate image. Its generator accepts both `openai` (legacy alias) and the new tokens, and refuses unknown tokens.
2. Stop every running OpenCode session (a running session keeps its old profile, so a mode switch is not effective until it restarts). Update the host manifest: rename `openai` to `openai-api` if present, and add `openai-chatgpt` if wanted (not both). Provision copies the seed only when the manifest is absent, so existing manifests are edited by the operator.
3. Update the install-branch checkout (the new wrapper, sync script and policy).
4. Run provision or sync to regenerate `provider-runtime.json` and `provider-verification.json`.
5. Run gates 0 and 1 with synthetic credentials only (preflight and generated-profile validation against the deployed nono), and only then the gates that need a real login.

Rollback:

1. If a ChatGPT login exists, clear it first (see Recovery): log out through the wrapper in ChatGPT mode, or run the recovery helper.
2. Restore the previous manifest and the previous checkout commit, then rerun sync. The new image keeps the legacy alias, so both the old and new checkout generate a correct profile on it.
3. Rolling back the image itself needs a manifest with neither new token, because the old generator ignores unknown tokens.
4. Verify with a wrapped launch (and, where `openai-api` is enabled, an API-key smoke test).

The sudoers line for the recovery helper is part of the new image; an older image has neither the helper nor the guard.

On this host the manifest lists only `gpt-uio-yellow` and `github-copilot`, so there is no `openai` entry to rename. The API-key smoke test applies to workspaces that enable `openai-api` and is recorded as not applicable here unless an operator enables it.

### Fallback chains

ChatGPT plan is inserted as `#3` and the former `#3` becomes `#4` in `opencode.jsonc` and in agent frontmatter comments. The model per role follows the role's current tier: strong `openai/gpt-6.2-sol`, balanced `openai/gpt-6.1-terra`, light `openai/gpt-6-luna`. These ids pass the model filter OpenCode 1.19.6 applies to ChatGPT logins (`gpt-6-luna` is on its allowlist; `gpt-6.1-terra` and `gpt-6.2-sol` pass its "newer than 5.4" rule). Passing the filter shows visibility, not entitlement, so gate 8 checks a real request for each.

| Chain | Tier | New `#3` |
| --- | --- | --- |
| top-level `model` | balanced | `openai/gpt-6.1-terra` |
| `build`, `plan` | strong | `openai/gpt-6.2-sol` |
| `general` (config and agent file) | balanced | `openai/gpt-6.1-terra` |
| `explore` | light | `openai/gpt-6-luna` |
| `maestro`, `brainstormer`, `policy-implementer`, `docs-writer` | balanced | `openai/gpt-6.1-terra` |
| `planner`, `senior-implementer`, `code-reviewer`, `docs-reviewer-gpt` | strong | `openai/gpt-6.2-sol` |
| `junior-implementer` | light | `openai/gpt-6-luna` |

Not changed: chains labelled "(local)" (`small_model`, `title`, `summary`, `compaction`) and `docs-reviewer-claude` (it must keep a non-GPT fallback). Existing explanatory lines (for example the "Opposite family" note in `code-reviewer.md`) stay. An id the signed-in plan does not authorize is replaced by the nearest authorized id of the same tier.

### Documentation

- The nono-policy runbook lists the new route, the per-endpoint phantom behavior, the opt-out promise and its limit (no network-level deny for the ChatGPT host), the auth-state guard and its limits, the recovery helper and sequences, the diagnostics switch and the login procedure. It tells the operator to stop every session started in the previous mode before treating a mode switch as effective, because a running session keeps the profile it started with.
- The model-routing cheatsheet gets a ChatGPT-plan section and describes chains as `#1` to `#4`.
- The bare-hub and lifecycle runbooks use `openai-api` where they name the API-key provider and describe the rollout order.
- The credential-phasing spec gets a short pointer to this spec (its existing contract lines stay unchanged, since contract tests pin them).

## Verification gates

Blocking, recorded with evidence before the slice counts as done. All gates need the rebuilt image running in the pod under nono, so the human runs them; agents cannot run them. **Gates 0 and 1 use only synthetic credentials and must pass before any real ChatGPT login.** Gates 2 to 10 use a real ChatGPT account.

0. **Synthetic preflight, before the first real login.** Under the actual candidate launcher, with the production profile structure pointed at a local test issuer and synthetic credentials, and with a **populated** capture store and a populated diagnostics log:
   - (a) *Mediation.* The full headless sequence runs through nono. The sandbox sees only phantoms for `authorization_code`, `code_verifier`, `access_token`, `refresh_token` and `id_token`; the synthetic real values never appear in the child's environment, files or logs; a token-shaped response at an unconfigured path fails closed; non-phantom values in the resolved request fields are handled as the design assumes.
   - (b) *Store isolation.* From inside the wrapped session, reading the capture store is denied (`nono why --self --path <store> --op read` reports a denial, and a read attempt fails). Owner-only permissions are not accepted as proof, because the supervisor and child run as the same `agent` UID. If the store is reachable, move it and retest.
   - (c) *Diagnostics file.* No synthetic credential value appears in the diagnostics log, and the sandbox can neither read nor modify it.
   - (d) *Opt-out semantics.* In `openai-api` and neither-token modes, a ChatGPT login started inside the session still yields phantoms only, and the proxy does not redeem those phantoms for a request to the ChatGPT host. The test has a positive control and a negative step:
     - *Positive control:* in `openai-chatgpt` mode, the same synthetic phantom is redeemed for a request to the synthetic ChatGPT upstream, which sees the synthetic real token.
     - *Negative step:* in a **fresh** opt-out launch (stop every session started in the enabled mode first, because a running session keeps its old profile), with the same persisted mapping, the same request is denied and the synthetic upstream sees no real token.
     - Repeat the negative step after `opencode auth logout openai` and after switching the mode from `openai-chatgpt` to an opt-out mode, so retained proxy mappings are covered. A denial without the positive control proves nothing.
     If nono cannot enforce this, stop and return to the human (see Opt-out semantics).
   If any part fails, stop and re-plan; do not proceed to a real login.
1. **Generated profile.** After the image rebuild and redeploy, the **generated** profile for each manifest case (`openai-api`, `openai-chatgpt`, neither) validates against the deployed nono binary, including the `credential_store` entry, and the nono version is recorded.
2. **Login entrypoints, independent.** Starting from a clean auth state (`opencode auth logout openai` through the wrapper, `openai` entry confirmed absent), a headless login via `opencode auth login` leaves only phantom `openai.access` and `openai.refresh` values (shape check, no values printed), and debug logs show `matched OAuth capture endpoint` and `rewrote OAuth token response fields to phantoms` for each token-bearing endpoint. Repeat from a clean state via `/connect` in the TUI, so neither check can pass on the other's phantoms.
3. A prompt and a tool-using task run end to end through the wrapped launcher using the phantom-only `auth.json`, including a token refresh.
4. **Account id.** OpenCode 1.19.6 derives the ChatGPT account id from `chatgpt_account_id` claims in `id_token` or `access_token`. A synthetic phantom `id_token` has no such claim and the opaque access phantom is not JWT-shaped, so the `ChatGPT-Account-Id` header is likely missing at login (a refresh keeps any previously stored value). Confirm a personal Plus account works without it. If not, stop and re-plan; do not weaken the phantom guarantee.
5. The token request body formats and the backend host seen in debug logs match the table above; correct the profile if they differ.
6. **Capture store persistence.** The capture store survives a pod restart; otherwise the runbook documents re-login after restart.
7. **Store isolation with real tokens.** Gate 0(b) repeated after the real login: the store now holds real tokens, and the child is still denied.
8. **Entitlement and usability.** Catalog evidence (`opencode models openai`) is recorded separately from request evidence. One successful representative request per model used in the fallback table (`gpt-6.2-sol`, `gpt-6.1-terra`, `gpt-6-luna`) is required; a model the plan does not authorize is replaced as described under Fallback chains.
9. No real token or exchange credential appears in `env`, `/proc/*/environ`, logs or shell-visible files inside the sandbox.
10. **Plan scope.** The support claim is verified for Plus. Pro is labelled unverified unless the human also runs gates 2 to 4 and 8 on a Pro account.
11. **Recovery and rollback.** The refusal → recovery → launch sequences from the Recovery section run on the real image, including ChatGPT-to-API rollback after a successful login. In the next wrapped session after recovery, the quarantined file is unreadable and unmodifiable (`nono why` reports a denial and a read attempt fails), a planted symlink at the live path is refused, and `sudo` denies the helper when an argument is added.

## Acceptance tests

Repo-file contract tests in `tests/pod-inside-nono/` run by the agent, written first (red) and offered for the human's review before implementation:

1. **Provider policy:** `openai-api` and `openai-chatgpt` are supported with `mode: all`; bare `openai` is no longer supported.
2. **Sync:** the manifest accepts either new token, refuses both together, and refuses bare `openai` with the rename hint; the OpenCode-facing provider list contains `openai` once.
3. **Wrapper:** `openai-api` and the legacy alias `openai` still export `OPENAI_API_KEY` from `openai_api_key`; `openai-chatgpt` requires no secret and exports none.
4. **Profile generator:** run against a **fixture** template that already contains the OAuth provider, so it does not depend on Task 3's committed template, the OAuth provider is present in the generated profile for `openai-chatgpt`, `openai-api` and neither token. In `openai-chatgpt` mode its `api_hosts` include `https://chatgpt.com` and its route has no deny-all policy; in `openai-api` and neither modes its `api_hosts` are only `https://auth.openai.com` and its route policy is default deny with no allow rules. `openai-api` and the legacy alias `openai` select the existing `openai` API-key route, and `openai-chatgpt` and neither do not. An unknown provider token is refused.
5. **Template shape:** the committed profile's OAuth provider lists exactly the two token-bearing endpoints, `/api/accounts/deviceauth/token` and `/oauth/token`, and does not list `/api/accounts/deviceauth/usercode`; each endpoint declares the request body, response fields and request fields from the table; `api_hosts` includes `https://auth.openai.com` and `https://chatgpt.com`; the mandatory `credential_store` is `file_json` with `phantom_fields` `openai.access` and `openai.refresh`, and its path equals `<wrapper default runtime data home>/opencode/auth.json`; the `NODE_EXTRA_CA_CERTS` path stays configured; and the profile passes `nono profile validate` offline where nono is available in the test context. After Task 3, test 4's assertions also run with the committed template and the generator together, so the template and generator are verified as a pair.
6. **Auth-state guard:** each cell of the guard table behaves as specified against fixture `auth.json` files, including both switch directions, `type: api` in API mode, the neither-token mode with phantom and non-phantom entries, and an unparseable file; a refusal prints no token values, other providers' entries are neither read into output nor modified, and the file is unchanged afterwards. **After-launch change:** a fixture `auth.json` that passes at launch and is then changed to a mode-incompatible state (for example a real API key entry) is refused at the next launch. The test does not claim in-session prevention.
7. **Supported combinations, upgrade and rollback:** wrapper, generator and runtime are exercised together for these combinations, each with its own expected outcome:
   - new generator with a new-token runtime: the profile follows the mode table;
   - **legacy rollback:** new generator and new wrapper with a runtime as the previous sync would produce it (enabled `openai`): the API route is present and no ChatGPT transport is selected. The previous sync itself runs from the restored checkout, which a repo test cannot start, so that step is covered by gate 11;
   - **neither-token rollback:** the new sync with a manifest that has neither token: the runtime has neither, the generated profile has no `openai` API route, the OAuth capture provider is still present in its opt-out form, and the wrapper requires no OpenAI secret.
   Starting from a fixture manifest containing `openai`, the new sync script refuses it with the hint. Old-image combinations cannot run in a repo test and are covered by gates 1 and 11 and the operator order, not by this test. The full post-login rollback sequence is part of test 8, because it needs the recovery helper.
8. **Recovery helper:** for each rejected state (raw OAuth entry, API key entry, unparseable file, phantom state in API mode), the sequence refusal → recovery → successful launch works. The helper changes only the `openai` entry (other entries are semantically unchanged); the quarantine directory is `root:root` `0700`, each quarantined file is `0600 root:root`, and the quarantine path is not under any path the generated profile grants; no copy of the rejected value remains beside the live file; the helper prints no values and rejects any argument; it refuses a live path that is a symlink, a non-regular file or has a symlinked parent, and a quarantine directory with the wrong owner, mode or type; and the sudoers line has the `""` empty-argument form, with no wildcard. The full ChatGPT-to-API rollback after a login (clear the login, restore the previous manifest, rerun sync, launch) ends with the API route present and no ChatGPT transport selected. The actual sudo denial of an extra argument and the next-session unreadability of the quarantine are human-run image checks (gate 11).
9. **Fallback layout:** each chain in the table above has `#3` set to the ChatGPT-plan model and `#4` set to the former `#3`, and the excluded chains are unchanged.
10. **Diagnostics switch:** the launch helper's diagnostics option sets only the two nono debug targets and a log file path outside the profile's granted paths, and passes no other environment through.
11. **Docs contract:** the runbooks and cheatsheet carry the new anchors. Existing contract tests that pin `openai` are updated deliberately, not weakened.

The `pod-outside-nono` blocking-matrix probe for `openai` is updated for the rename and run by the human, together with a wrapped API-key smoke test on any workspace that enables `openai-api`.

## Tasks

Done in a managed worktree created with `bin/new-worktree`, reaching `main` only by merge.

1. Write failing acceptance tests 1 to 11. **User Check-in:** the human reviews the interface-defining tests.
2. Implement enablement, sync, wrapper and generator changes (rename, legacy alias, unknown-token refusal, `openai-chatgpt`, OAuth capture in every mode with mode-dependent redemption); make tests 1 to 3, 4 (fixture template) and 7 pass (test 7 does not include the post-login rollback; that is test 8).
3. Add the OAuth provider and route to the nono profile; make test 5 pass, and make test 4 pass with the committed template and the generator together.
4. Implement the auth-state guard, the recovery helper with its sudoers line, and the diagnostics switch in the image artifacts; make tests 6, 8 (including the full post-login rollback) and 10 pass, after the recovery helper exists.
5. Update fallback comments, runbooks, cheatsheet and the credential-phasing pointer; make tests 9 and 11 pass.
6. **User Check-in:** the human builds and deploys the candidate image and follows the rollout order, then runs gates 0 and 1 with synthetic credentials only. If either fails, stop and re-plan. No real ChatGPT login happens before this check-in passes.
7. **User Check-in:** the human enables `openai-chatgpt`, logs in from clean states, and returns the evidence for gates 2 to 11.
8. Correct the profile or fallback ids from the gate results, and rerun the affected tests.

## Risks

- **Mediation of the full exchange** (gate 0). nono's handling of the device-flow intermediates and of non-phantom values in resolved request fields is undocumented. Mitigation: gate 0 runs before any real login, and a failure stops the slice.
- **Phantom `id_token` lacks the account claim** (gate 4). This is the most likely failure at the API layer. Mitigation: gate 4; the answer may require a nono profile change or an upstream fix.
- **Capture store or diagnostics file reachable by the child** (gates 0(b), 0(c), 7). The supervisor and child share a UID, so only Landlock separates them. Mitigation: the denial checks run on a populated synthetic store before any real login and again after it; the store and log are moved if reachable.
- **In-session auth changes.** The launcher cannot stop a user from entering a real key or choosing another login method inside a running session. Mitigation: OAuth capture in every mode for ChatGPT logins (with redemption denied in the opt-out modes), refusal at the next launch, and the runbook; the residual risk is explicit under Auth-state guard.
- **Recovery helper is a new sudo permission.** Mitigation: one sudoers line with an explicit empty argument list, operator-only, `agent`-uid I/O on the live file with `O_NOFOLLOW`, root only for the quarantine write, and the checks in test 8 and gate 11.
- **Quarantine holds real credentials.** Mitigation: root-owned `0700` directory outside the profile grants, never read by the sandbox; the operator removes the files.
- **Opt-out enforcement depends on nono.** nono's handling of capture without redemption and of a deny-all route policy is undocumented. Mitigation: gate 0(d), with a defined stop-and-ask rule if it fails.
- **Stale persisted auth** selects the wrong transport after a mode switch. Mitigation: the auth-state guard, the recovery path and their tests.
- **Mixed-version rollout** silently drops the API route on an old generator. Mitigation: legacy alias, unknown-token refusal and the operator order above.
- **Image rebuild is required.** Checkout edits alone will not change the launcher. Mitigation: Decision 7 and the rollout order.
- **Model ids differ by plan.** The ChatGPT backend authorizes a subset of the catalog. Mitigation: gate 8.
- **Terms and quota.** Subscription use through a third-party client is governed by OpenAI's terms and the plan's usage limits, outside this repo's control.
- **A newer nono version** may change `oauth_capture` behavior. Mitigation: validate the generated profile with `nono profile show` at each nono upgrade (gate 1).
