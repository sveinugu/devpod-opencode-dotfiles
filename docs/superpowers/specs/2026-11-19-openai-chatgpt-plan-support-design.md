# OpenAI ChatGPT Plus/Pro plan support

Status: draft for approval (2026-11-23, revision 6). This revision replaces the `oauth_capture` design with external login and header injection.
Related: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`, `docs/superpowers/specs/2026-11-19-opencode-host-local-model-overrides-design.md`

## Problem

OpenCode can use OpenAI models through a ChatGPT Plus/Pro subscription. This workspace keeps real provider secrets outside the sandbox (credential-phasing spec), and `auth.json` is not an accepted credential source. No subscription-based path is supported.

OpenCode's native ChatGPT login stores OAuth tokens in `auth.json`, where a sandboxed agent could read them.

## Goals

1. OpenCode in the DevSpace pod, under nono, can use the ChatGPT models that the signed-in plan authorizes.
2. The sandbox never holds a real ChatGPT credential. OpenCode holds only a non-secret stub, and nono injects the real headers outside the sandbox.
3. One repeatable host command connects a provider login to the existing Kubernetes Secret. ChatGPT is the first provider. GitHub Copilot is a separate follow-up task.
4. The design keeps a small version boundary, so that it can move from OpenCode 1.19.6 to OpenCode 2 without a change to the credential path.

## Non-goals

- Direct OpenAI API-key support. This change removes the `openai` API-key route and does not add an `openai-api` provider.
- Changes to `gpt-uio-yellow` or `gpt-uio-red`. Their OpenAI-compatible protocol does not tie them to OpenCode's built-in `openai` provider.
- Automatic token refresh in the first version (see Refresh).
- WebSocket transport (see Transport).
- A new OAuth broker, an OpenCode fork or a dependency on the GitHub App broker.
- Prevention of unsupported login methods inside a running session. This is existing background behavior.
- Credential archives or quarantine.
- Role-specific fallback recommendations. These are a separate change.
- GitHub Enterprise login.

## Decisions

1. **External login, sandboxed use.** OpenCode's headless login runs outside the sandbox. nono's `cmd://` credential route injects the resulting headers. This reuses the built-in OpenCode ChatGPT transport.
2. **The existing Kubernetes Secret stores the credential.** `dotfiles-nono-provider-credentials` gets one optional key, `openai_chatgpt_session`. Its value is one JSON object with the access token, account ID, optional residency value and expiry, so these fields change together.
3. **The first version discards the refresh token.** The operator logs in again when the access token expires. Two observed logins on one account had a 240-hour (10-day) token lifetime.
4. **One enablement token.** `openai-chatgpt` replaces `openai` in the repo's enablement manifest, seed and policy. It maps to OpenCode's `openai` provider. The seed does not enable it, so ChatGPT stays opt-in per host.
5. **HTTP only.** The launcher does not enable OpenCode's WebSocket transport.
6. **The auth stub is an environment value.** On OpenCode 1.19.6, the launch helper passes the stub through `OPENCODE_AUTH_CONTENT`. The design does not write `auth.json`.
7. **Image artifacts.** The profile template, generator, launch helper and header helper are root-owned image artifacts. This change therefore needs an image rebuild and redeploy.

## Design

### Credential flow

```text
ops/provider-login chatgpt (host)
  -> kubectl exec: headless OpenCode login in a temporary directory in the pod
  -> extract session JSON and remove the temporary login
  -> kubectl patch: only openai_chatgpt_session
  -> kubelet updates the root-only Secret mount

opencode wrapper (each launch)
  -> reads the session through the existing constrained sudo path
  -> launch helper passes it to the nono supervisor environment
  -> profile environment filter keeps it out of the sandbox
  -> header helper prints the request headers for nono
  -> nono injects them on the ChatGPT route

sandboxed OpenCode
  -> receives only the auth stub through OPENCODE_AUTH_CONTENT
```

The header helper runs as `agent`, and the Secret mount is root-only. The helper therefore reads the session from the supervisor environment that nono 0.82.0 passes to credential commands. No agent-readable credential file exists.

### Provider login command

`ops/provider-login <provider>` runs on the host that has `kubectl` access. The pod gets no permission to change Secrets.

For every provider, the command must:

- run OpenCode's device login in a `vscode`-only temporary directory in the pod, with the pinned OpenCode version;
- extract only the required values and remove the temporary login, including on failure or interrupt;
- validate the new value before it changes the Secret;
- patch only the provider's Secret key, with the value on standard input. It must not use `--from-literal` or replace the whole Secret;
- print no token, account ID or email address;
- tell the operator that new sessions get the value after the kubelet updates the mount, and that running sessions must restart to use it.

The ChatGPT adapter also supports `--reset`. It removes `openai_chatgpt_session` and tells the operator to stop running sessions.

Provisioning does not run a login. It only reports when an enabled provider is not connected and prints the login command.

### nono profile

The profile replaces the `openai` API-key route with an `openai-chatgpt` custom credential route:

- upstream `https://chatgpt.com/backend-api/codex`;
- `credential_key` `cmd://openai-chatgpt`;
- a route variable that does not produce `OPENAI_BASE_URL`, because that would change OpenCode's request path;
- a `credential_capture` entry that runs the root-owned header helper, with `cache_ttl_secs: 0`;
- `allow_headers` for `Authorization`, `ChatGPT-Account-Id` and `x-openai-internal-codex-residency`.

The header helper emits the residency header only when the session has a constrained residency value. OpenCode cannot derive that value from a stub.

`OPENAI_CHATGPT_SESSION` is added to the sudo `env_keep` list and to the profile's `deny_vars`. The generator includes the route and its capture entry only when ChatGPT is enabled and connected. It refuses an enabled provider token that it does not know.

### Auth stub and lifecycle

The stub is a fake credential: an `openai` entry of `type: oauth` with non-secret `access` and `refresh` values and a far-future `expires`. It selects OpenCode's ChatGPT transport and prevents OpenCode from attempting a refresh.

The launch helper owns a fixed stub value and sets `OPENCODE_AUTH_CONTENT` only when the wrapper reports a valid ChatGPT session. The caller does not supply the stub content. OpenCode 1.19.6 then reads this value instead of `auth.json`, so other entries in that file are hidden while ChatGPT is connected. This host has no `auth.json` for the `agent` user (checked on 2026-11-23).

The Kubernetes Secret is the only source of truth for the connection state.

Lifecycle meanings:

- **Native logout** does not disconnect ChatGPT. The stub returns at the next launch. The runbook directs the operator to `--reset`.
- **Local reset** removes the Secret key. It keeps no archive and needs running sessions to stop, because each session holds a launch-time snapshot.
- **Upstream revocation** is a separate, deliberate operator action. Local reset does not revoke the login at OpenAI.

An in-session login or logout makes OpenCode write its current auth content to `auth.json`, and this can persist the stub. Such a file can select the ChatGPT transport in a later launch without the route. Those requests fail closed. The operator can remove the file deliberately.

### Launch behavior

When `openai-chatgpt` is enabled:

| Session state | Launch behavior |
| --- | --- |
| Valid session | Launch with the ChatGPT route and stub. |
| Expires within 24 hours | Launch with the route and stub, and print a warning with the login command. |
| Missing, invalid or expired session | Launch without ChatGPT and print the login command. |
| ChatGPT explicitly selected but unavailable | Refuse launch and print the login command. |

"Explicitly selected" means the launch `--model` argument or the top-level `model` setting. The launcher does not check each agent role. A role that uses an `openai/*` model while ChatGPT is disconnected fails at first use.

Other providers keep working when ChatGPT is not connected. A token that expires during a session fails closed. OpenCode 1.19.6 took 76 seconds to fail in the synthetic test, and this design accepts that delay for a running session.

### Refresh

Refresh is deferred. No existing tool owns refresh outside the sandbox, so it needs a separate component. Reconsider it if the 10-day login becomes a burden or if observed token lifetimes become much shorter. That component must run outside the agent pod and must account for refresh-token rotation.

### Transport

nono 0.82.0 cannot allow WebSocket upgrades on `cmd://` custom credential routes. HTTP is therefore the supported transport. On OpenCode 1.19.6, the launcher must not set `OPENCODE_EXPERIMENTAL_WEBSOCKETS`.

A later WebSocket change needs nono support for `upgrades` on these routes and a defined reset behavior, because an open socket can outlive a credential reset.

### Version boundary

The stable parts are the Secret, header helper, nono route and injected headers. The OpenCode adapter is version-specific:

- **OpenCode 1.19.6:** the stub in `OPENCODE_AUTH_CONTENT`.
- **OpenCode 2 (source review of v2.4.0 only):** this variable does not exist. The external-credential interface should replace the stub, and the adapter must set `transport: "http"`, because the OpenAI provider defaults to WebSocket. This path is not tested.

### Enablement and removal

- The policy and sync script accept `openai-chatgpt`. A manifest with `openai` is refused with a hint.
- The OpenCode-facing provider list contains `openai` only when ChatGPT is enabled and connected.
- The wrapper maps `openai-chatgpt` to the optional `openai_chatgpt_session` key. A missing key does not stop other providers.
- The `openai_api_key` mapping and `openai` API-key route are removed. `OPENAI_API_KEY` stays in `deny_vars`.
- This host's manifest lists only `gpt-uio-yellow` and `github-copilot`, so it needs no manifest migration.

### GitHub Copilot follow-up

`ops/provider-login copilot` reuses the same command with a Copilot adapter:

- It writes OpenCode's Copilot OAuth token to the existing `github_token` key.
- It reuses the existing `env://GITHUB_TOKEN` route, with no header helper and no sandbox change.
- It supports GitHub.com only.
- It must make a successful test call to Copilot with the new token before it changes the Secret, because many agent roles default to Copilot models.

This follow-up must not delay or change the ChatGPT slice.

### Documentation

The nono-policy, bare-hub and lifecycle runbooks describe the login command, Secret key, lifecycle operations, launch states, re-login interval and removal of the API-key path. The credential-phasing spec gets a short pointer to this spec.

## Evidence

The human ran these checks on 2026-11-23 and 2026-11-24 with OpenCode 1.19.6 and nono 0.82.0.

| Check | Credential | Result |
| --- | --- | --- |
| Header injection under nono's `default` profile, two concurrent sessions, expiry and restore | Synthetic | Pass |
| OpenCode transport with stub | Synthetic | Pass |
| Isolation under the production profile and privilege drop | Synthetic | Pass |
| Login, injected headers and one OpenCode prompt to `chatgpt.com` | Real Plus/Pro login, plan not recorded | Pass with `gpt-6-luna` |
| Session in the supervisor environment, `deny_vars`, header helper reads it, expired session refused, stub through `OPENCODE_AUTH_CONTENT` with no `auth.json` | Synthetic | Pass |

The backend rejected `gpt-5.5` for this account with HTTP 400.

The environment-path check used the production profile with only the `deny_vars` entry and a synthetic route added. The sandbox did not find the session in its environment, the supervisor environment or any readable process data, also while a helper held it. nono makes the supervisor non-dumpable, so its environment was denied even to its own UID outside the sandbox. A positive control showed that the same UID outside the sandbox could read the session from a running helper. OpenCode created no `auth.json` and attempted no refresh.

Limits of this evidence:

- The environment-path check used a synthetic launch, not the production launch helper or wrapper. Gates S1 and S3 test the deployed path.
- A process running as `agent` outside nono can read the session from a header helper while that helper runs.
- The real-account check narrowed outbound access to the ChatGPT route. It did not test production's `allow_domain: ["*"]` together with other provider routes.
- The real-account check sent one short prompt. It did not cover tool use, long sessions or real token expiry.
- The sandbox can signal processes of the same UID on this kernel (6.8), so a sandboxed agent can probably stop a nono supervisor. This is existing behavior and is an availability risk, not a credential exposure.

## Verification gates

The human runs these gates on the rebuilt image. Agents cannot run them.

Synthetic gates must pass before any real-account gate:

- **S1. Environment isolation.** The sandbox cannot see `OPENAI_CHATGPT_SESSION` in its environment or read it from the supervisor or a running header helper. Injection still works.
- **S2. Generated profile.** The generated profile validates on the deployed nono for ChatGPT enabled, disabled and disconnected states. The ChatGPT route works together with production's domain policy and other provider routes.
- **S3. Stub and lifecycle.** OpenCode selects the ChatGPT transport from `OPENCODE_AUTH_CONTENT` with no `auth.json`, and does not attempt a refresh. Each launch state, reset and native logout behaves as specified. Without a valid session, the launcher does not set the variable.
- **S4. Login command.** With a fake Secret target and fake login output, the command patches only its key, leaks no value and removes temporary files on success, failure and interrupt.

Real-account gates:

- **R1.** `ops/provider-login chatgpt` connects a clean workspace.
- **R2.** A prompt and a tool-using task run through the wrapper with no real credential in the sandbox.
- **R3.** The login survives a pod restart.
- **R4.** A re-login reaches new sessions after the mount update, and a restart moves a running session to the new login.
- **R5.** One request succeeds for each model that the operator plans to use.
- **R6.** The tested plan is recorded. Other plans stay labelled unverified.

## Acceptance tests

Repo-file tests in `tests/pod-inside-nono/` define these behaviors and are written first:

1. Policy and sync accept `openai-chatgpt` and refuse `openai` with a hint.
2. The wrapper treats the session key as optional and selects the correct launch state for valid, expiring, expired, missing and malformed sessions.
3. The generator includes the route and capture entry only when ChatGPT is enabled and connected, and refuses unknown tokens.
4. The profile has no `openai` API-key route, and its ChatGPT route has the required upstream, headers and zero cache.
5. The header helper emits the required headers, emits residency only when constrained, fails closed on expired or malformed input and prints nothing on failure.
6. The launch helper sets the fixed stub only for a valid session, accepts no caller-supplied stub content and never passes the real session to the OpenCode process.
7. The login command patches only the provider key, passes no value in process arguments and cleans up after failure.

## Tasks

Work happens in a managed worktree and reaches `main` only by merge.

1. Write failing acceptance tests. **User Check-in:** the human reviews the interface-defining tests.
2. Implement enablement, wrapper, generator, profile, helpers and image changes.
3. Implement `ops/provider-login` with the ChatGPT adapter.
4. Update runbooks and the credential-phasing pointer.
5. **User Check-in:** the human deploys the image and runs gates S1 to S4. If a gate fails, stop and re-plan.
6. **User Check-in:** the human runs gates R1 to R6.
7. In a separate slice, add the Copilot adapter and verify a login-issued token on the existing route before it replaces the current token.

## Risks

- **A sandboxed agent can use the credential through the route** while a session is valid. It cannot read the token. This is inherent to proxy injection.
- **The sandbox is the barrier around the supervisor environment.** The supervisor and child share a UID. nono makes the supervisor non-dumpable, but a header helper is readable by its UID while it runs. Nothing may run as `agent` outside nono. Gate S1 tests this path.
- **Token lifetime can change.** The 10-day value comes from two logins on one account. Launch-time expiry checks do not depend on that value.
- **A running session keeps its snapshot** after re-login or reset. The login command and runbook state this.
- **Backend behavior can change.** The route depends on OpenCode's ChatGPT transport and an unversioned backend. Pin versions and rerun the gates at each OpenCode or nono upgrade.
- **`OPENCODE_AUTH_CONTENT` is version-specific.** OpenCode 1.19.6 has it and v2.4.0 does not. Gate S3 must pass again at each OpenCode upgrade.
- **The variable hides `auth.json`.** A future provider that depends on that file stops working while ChatGPT is connected.
- **Terms and quota.** OpenAI's terms and the plan's usage limits govern subscription use through a third-party client.

## Open questions

- Does the design work on Pro or other plans?
- Does the OpenCode 2 external-credential path work with the same route?
