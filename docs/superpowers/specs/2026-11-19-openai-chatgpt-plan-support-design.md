# OpenAI ChatGPT Plus/Pro plan support

Status: draft for approval (2026-11-19, revision 2, after docs-reviewer-gpt review)
Related: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`, `docs/superpowers/specs/2026-11-19-opencode-host-local-model-overrides-design.md`, `https://nono.sh/docs/cli/features/sandboxed-oauth-logins`

## Problem

OpenCode can use OpenAI models through a ChatGPT Plus/Pro subscription ("ChatGPT Pro/Plus" login, OAuth). This workspace supports only API-key providers whose real secrets stay outside the sandbox (credential-phasing spec). `auth.json` is not an accepted credential source, and no subscription-based path is supported.

The ChatGPT login stores OAuth access and refresh tokens in OpenCode's `auth.json`. Left alone, those tokens would be readable by the sandboxed agent.

## Goals

1. OpenCode inside the DevSpace pod, under nono, can log in with a ChatGPT Plus account and use the models OpenCode shows for that login that the signed-in plan authorizes. Pro uses the same flow and is labelled unverified unless a Pro account is tested (see gate 10).
2. The sandbox never holds real OAuth material: `auth.json` contains only nono phantom tokens, and the intermediate device-flow credentials are also phantoms (see nono profile).
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
3. **The persisted auth entry decides the transport, so the launcher guards it.** OpenCode 1.19.6 chooses the ChatGPT transport from the persisted `openai` entry (`type: oauth`), not from this repo's manifest. The manifest alone therefore cannot enforce the mode. A launch-time guard checks the entry against the enabled token (see Auth-state guard).
4. **Rename scope.** The rename changes only the enablement token (manifest, seed, provider policy, sync script, wrapper and generator mappings, tests, docs). The nono route name `openai`, the secret file `openai_api_key` and the env var `OPENAI_API_KEY` stay. The sync script and policy refuse a manifest that lists `openai`, with a message saying it was renamed to `openai-api`. The wrapper and the generator keep `openai` as a legacy alias of `openai-api` for one release, so stale generated outputs and mixed-version rollouts keep working (see Rollout and migration).
5. **Model list.** `openai-chatgpt` uses `mode: all`, like the other standard providers: no repo-owned model list.
6. **Fallback placement.** ChatGPT plan is `#3` and the old `#3` is `#4`, per role, as listed under Fallback chains.
7. **Image artifacts.** The profile template, the profile generator and the launch helper are root-owned image artifacts, so this change ships as a rebuilt and redeployed image, not as a checkout edit.

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
- `credential_store`: a `file_json` entry for `$HOME/.local/share/opencode/auth.json` with `phantom_fields` `openai.access` and `openai.refresh` (those are the fields OpenCode persists; no `id_token`), if the schema accepts them. Its path must match the runtime `XDG_DATA_HOME` the launch helper sets, not `$HOME` by assumption.
- The existing `network.tls_intercept.ca_env_vars` already includes `NODE_EXTRA_CA_CERTS`, which OpenCode (Bun) honors; no new CA variable is expected.
- Whether nono passes through non-phantom values in the resolved request fields, and fails closed on token-shaped responses at unconfigured paths, is not documented. Gate 0 tests it. If the deployed nono cannot mediate the full exchange, stop and re-plan; do not ship a partial mediation.

`scripts/lib/generate-nono-profile.py` keeps the OAuth provider and route only when `openai-chatgpt` is enabled, and drops them otherwise, in the same way it filters API-key routes today. `openai-api` (and the legacy alias `openai`) select the existing `openai` route. The generator refuses an enabled provider token it does not know, instead of silently ignoring it as today.

### Auth-state guard

Before the sandbox starts, the root-owned launch helper checks the persisted `openai` entry in `<runtime XDG_DATA_HOME>/opencode/auth.json` against the enabled token, using shapes only:

| Enabled token | `openai` entry absent | `openai` entry `type: oauth`, `access` and `refresh` both phantom-shaped (`nono_` plus 64 hex) | Any other entry (API key, `oauth` with non-phantom values, other type, unparseable file) |
| --- | --- | --- | --- |
| `openai-chatgpt` | launch (login pending) | launch | refuse |
| `openai-api` (or legacy `openai`) | launch | refuse (stale ChatGPT state would select the ChatGPT transport) | launch if `type: api`; otherwise refuse |
| neither | launch; the OpenCode provider list excludes `openai`, so the entry is ignored | launch | launch |

- A refusal prints the provider entry name, the failing shape and the corrective step (log out of `openai` through the wrapped launcher in the mode that created it, then retry). It never prints token values, never deletes or edits `auth.json`, and never inspects other providers' entries.
- Phantom shape is checked only for the `openai` entry's `access` and `refresh` fields.
- The plan decides where the check runs and how the mode reaches it. The constraint is that it runs with access to the agent's data directory, before launch, and that it adds no new sudo permissions beyond the existing wildcard launch rule.

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
- Logs are redacted by construction (the two nono targets log matches and rewrites, not bodies); a shape check on the captured file is part of gate 0 evidence. The runbook says never to enable other log targets that dump request or response bodies.

### Rollout and migration

The generator, profile template and launch helper are installed into root-owned paths by the Dockerfile, so an image rebuild and redeploy is part of this change. The wrapper and sync script run live from the install-branch checkout, so mixed versions are possible during rollout. An old image's generator silently drops provider tokens it does not know, which would remove the API route without any error.

Operator order:

1. Build and deploy the candidate image. Its generator accepts both `openai` (legacy alias) and the new tokens, and refuses unknown tokens.
2. Update the host manifest: rename `openai` to `openai-api` if present, and add `openai-chatgpt` if wanted (not both). Provision copies the seed only when the manifest is absent, so existing manifests are edited by the operator.
3. Update the install-branch checkout (the new wrapper, sync script and policy).
4. Run provision or sync to regenerate `provider-runtime.json` and `provider-verification.json`.
5. Validate the generated profile against the deployed nono (gate 1), then run the verification gates.

Rollback: restore the previous manifest and the previous checkout commit, then rerun sync. The new image keeps the legacy alias, so both the old and new checkout generate a correct profile on it. Rolling back the image itself needs a manifest with neither new token, because the old generator ignores unknown tokens.

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

- The nono-policy runbook lists the new route, the per-endpoint phantom behavior, the auth-state guard, the diagnostics switch and the login procedure.
- The model-routing cheatsheet gets a ChatGPT-plan section and describes chains as `#1` to `#4`.
- The bare-hub and lifecycle runbooks use `openai-api` where they name the API-key provider and describe the rollout order.
- The credential-phasing spec gets a short pointer to this spec (its existing contract lines stay unchanged, since contract tests pin them).

## Verification gates

Blocking, recorded with evidence before the slice counts as done. Gates 0 to 10 need the rebuilt image running in the pod under nono and, from gate 2 on, a real ChatGPT account, so the human runs them; agents cannot run them. Gate 0 runs before any real login.

0. **Synthetic mediation (before the first real login).** With the production profile structure pointed at a local test issuer and synthetic credentials, the full headless sequence runs through nono. The sandbox sees only phantoms for `authorization_code`, `code_verifier`, `access_token`, `refresh_token` and `id_token`; the synthetic real values never appear in the child's environment, files or logs; a token-shaped response at an unconfigured path fails closed; and non-phantom values in the resolved request fields are handled as the design assumes. If nono cannot mediate the full exchange, stop and re-plan.
1. **Generated profile.** After the image rebuild and redeploy, the **generated** profile for each manifest case (`openai-api`, `openai-chatgpt`, neither) validates against the deployed nono binary (`nono profile show` or `validate`), and the nono version is recorded.
2. **Login entrypoints, independent.** Starting from a clean auth state (`opencode auth logout openai` through the wrapper, `openai` entry confirmed absent), a headless login via `opencode auth login` leaves only phantom `openai.access` and `openai.refresh` values (shape check, no values printed), and debug logs show `matched OAuth capture endpoint` and `rewrote OAuth token response fields to phantoms` for each configured endpoint. Repeat from a clean state via `/connect` in the TUI, so neither check can pass on the other's phantoms.
3. A prompt and a tool-using task run end to end through the wrapped launcher using the phantom-only `auth.json`, including a token refresh.
4. **Account id.** OpenCode 1.19.6 derives the ChatGPT account id from `chatgpt_account_id` claims in `id_token` or `access_token`. A synthetic phantom `id_token` has no such claim and the opaque access phantom is not JWT-shaped, so the `ChatGPT-Account-Id` header is likely missing at login (a refresh keeps any previously stored value). Confirm a personal Plus account works without it. If not, stop and re-plan; do not weaken the phantom guarantee.
5. The token request body formats and the backend host seen in debug logs match the table above; correct the profile if they differ.
6. **Capture store.** The capture store survives a pod restart; otherwise the runbook documents re-login after restart.
7. **Capture store inaccessible to the sandbox.** From inside the wrapped session, reading the capture store location is denied (`nono why --self --path <store> --op read` reports a denial, and a read attempt fails). Owner-only permissions are not accepted as proof, because the nono supervisor and the sandboxed child both run as the `agent` UID. The plan identifies the store path from nono's behavior; if the store lands where the child can read it, move it (the launch helper already gives the supervisor and the child separate `XDG_STATE_HOME` values) and retest.
8. **Entitlement and usability.** Catalog evidence (`opencode models openai`) is recorded separately from request evidence. One successful representative request per model used in the fallback table (`gpt-6.2-sol`, `gpt-6.1-terra`, `gpt-6-luna`) is required; a model the plan does not authorize is replaced as described under Fallback chains.
9. No real token or exchange credential appears in `env`, `/proc/*/environ`, logs or shell-visible files inside the sandbox.
10. **Plan scope.** The support claim is verified for Plus. Pro is labelled unverified unless the human also runs gates 2 to 4 and 8 on a Pro account.

## Acceptance tests

Repo-file contract tests in `tests/pod-inside-nono/` run by the agent, written first (red) and offered for the human's review before implementation:

1. **Provider policy:** `openai-api` and `openai-chatgpt` are supported with `mode: all`; bare `openai` is no longer supported.
2. **Sync:** the manifest accepts either new token, refuses both together, and refuses bare `openai` with the rename hint; the OpenCode-facing provider list contains `openai` once.
3. **Wrapper:** `openai-api` and the legacy alias `openai` still export `OPENAI_API_KEY` from `openai_api_key`; `openai-chatgpt` requires no secret and exports none.
4. **Profile generator:** with `openai-chatgpt` enabled the generated profile contains the OAuth provider and route; without it, it contains neither; `openai-api` and the legacy alias `openai` select the existing `openai` route; an unknown provider token is refused.
5. **Template shape:** the committed profile's OAuth provider declares the three endpoints with the per-endpoint request bodies, response fields and request fields from the table, `api_hosts` including `https://chatgpt.com`, `credential_store` fields `openai.access` and `openai.refresh`, and the `NODE_EXTRA_CA_CERTS` path stays configured.
6. **Auth-state guard:** each cell of the guard table behaves as specified against fixture `auth.json` files: both switch directions, the disabled mode, and a pre-existing non-phantom entry; a refusal prints no token values, other providers' entries are neither read into output nor modified, and the file is unchanged afterwards.
7. **Upgrade and rollback:** starting from a fixture manifest containing `openai`, the new sync script refuses it with the hint; the renamed manifest regenerates correct outputs; the generator given pre-migration outputs (`openai`) still yields the API route; and a generator from the new commit run against an old-style runtime does not drop the API route.
8. **Fallback layout:** each chain in the table above has `#3` set to the ChatGPT-plan model and `#4` set to the former `#3`, and the excluded chains are unchanged.
9. **Diagnostics switch:** the launch helper's diagnostics option sets only the two nono debug targets and a log file path, and passes no other environment through.
10. **Docs contract:** the runbooks and cheatsheet carry the new anchors. Existing contract tests that pin `openai` are updated deliberately, not weakened.

The `pod-outside-nono` blocking-matrix probe for `openai` is updated for the rename and run by the human, together with a wrapped API-key smoke test on any workspace that enables `openai-api`.

## Tasks

Done in a managed worktree created with `bin/new-worktree`, reaching `main` only by merge.

1. Write failing acceptance tests 1 to 10. **User Check-in:** the human reviews the interface-defining tests.
2. Implement enablement, sync, wrapper and generator changes (rename, legacy alias, unknown-token refusal, `openai-chatgpt`); make tests 1 to 4 and 7 pass.
3. Add the OAuth provider and route to the nono profile; make test 5 pass.
4. Implement the auth-state guard and the diagnostics switch in the launch helper; make tests 6 and 9 pass.
5. Update fallback comments, runbooks, cheatsheet and the credential-phasing pointer; make tests 8 and 10 pass.
6. **User Check-in:** the human builds and deploys the candidate image, follows the rollout order, and runs gates 0 and 1. If gate 0 fails, stop and re-plan.
7. **User Check-in:** the human enables `openai-chatgpt`, logs in from clean states, and returns the evidence for gates 2 to 10.
8. Correct the profile or fallback ids from the gate results, and rerun the affected tests.

## Risks

- **Mediation of the full exchange** (gate 0). nono's handling of the device-flow intermediates and of non-phantom values in resolved request fields is undocumented. Mitigation: gate 0 runs before any real login, and a failure stops the slice.
- **Phantom `id_token` lacks the account claim** (gate 4). This is the most likely failure at the API layer. Mitigation: gate 4; the answer may require a nono profile change or an upstream fix.
- **Capture store reachable by the child** (gate 7). The supervisor and child share a UID, so only Landlock separates them. Mitigation: gate 7, and moving the store through the supervisor's separate `XDG_STATE_HOME`.
- **Stale persisted auth** selects the wrong transport after a mode switch. Mitigation: the auth-state guard and its tests.
- **Mixed-version rollout** silently drops the API route on an old generator. Mitigation: legacy alias, unknown-token refusal and the operator order above.
- **Image rebuild is required.** Checkout edits alone will not change the launcher. Mitigation: Decision 7 and the rollout order.
- **Model ids differ by plan.** The ChatGPT backend authorizes a subset of the catalog. Mitigation: gate 8.
- **Terms and quota.** Subscription use through a third-party client is governed by OpenAI's terms and the plan's usage limits, outside this repo's control.
- **A newer nono version** may change `oauth_capture` behavior. Mitigation: validate the generated profile with `nono profile show` at each nono upgrade (gate 1).
