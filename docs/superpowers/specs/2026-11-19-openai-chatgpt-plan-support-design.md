# OpenAI ChatGPT Plus/Pro plan support

Status: draft for approval (2026-11-19, revision 1)
Related: `docs/superpowers/specs/2026-07-14-devspace-model-credential-phasing-design.md`, `docs/superpowers/specs/2026-11-19-opencode-host-local-model-overrides-design.md`, `https://nono.sh/docs/cli/features/sandboxed-oauth-logins`

## Problem

OpenCode can use OpenAI models through a ChatGPT Plus/Pro subscription ("ChatGPT Pro/Plus" login, OAuth). This workspace supports only API-key providers whose real secrets stay outside the sandbox (credential-phasing spec). `auth.json` is not an accepted credential source, and no subscription-based path is supported.

The ChatGPT login stores OAuth access and refresh tokens in OpenCode's `auth.json`. Left alone, those tokens would be readable by the sandboxed agent.

## Goals

1. OpenCode inside the DevSpace pod, under nono, can log in with a ChatGPT Plus/Pro account and use every model OpenCode exposes for that plan.
2. The sandbox never holds real OAuth tokens: `auth.json` contains only nono phantom tokens.
3. The existing OpenAI API-key path keeps working, under a clearer name.
4. The ChatGPT-plan models appear as the `#3` fallback in the committed routing comments, and the previous `#3` becomes `#4`.

## Non-goals

- Hosting or using ChatGPT login outside the pod (a host-only OpenCode is out of scope).
- Choosing models by hand: the model list is whatever OpenCode exposes for the plan.
- Using both ChatGPT OAuth and the OpenAI API key at the same time (see Decisions).
- Automatic fallback between providers (unchanged from the overrides spec).
- Any change to the K8s secret names or the existing nono credential route names.

## Decisions

1. **Credential route: nono `oauth_capture`.** Login runs inside the sandbox; nono's proxy rewrites the OAuth token responses so OpenCode stores `nono_<64hex>` phantoms. Real tokens live in nono's capture store outside the sandbox. This keeps the credential-phasing spec's secrecy guarantee and needs no exception to its "no `auth.json` as credential source" rule, because `auth.json` holds only phantoms. This replaces the earlier idea of real tokens in `auth.json`.
2. **Two enablement tokens, one OpenCode provider.** OpenCode uses the provider id `openai` for both API keys and ChatGPT OAuth. The repo's enablement manifest distinguishes them:
   - `openai-api`: the existing API-key path, renamed from `openai`. Behavior is unchanged.
   - `openai-chatgpt`: new, ChatGPT plan OAuth. It needs no API-key secret.
   Both map to OpenCode's `openai`. Enabling both is refused, because they would configure the same OpenCode provider with two different auth methods.
3. **Rename scope.** The rename changes only the enablement token (manifest, seed, provider policy, sync script, wrapper and generator mappings, tests, docs). The nono route name `openai`, the secret file `openai_api_key` and the env var `OPENAI_API_KEY` stay as they are. A manifest that still lists `openai` is refused with a message saying it was renamed to `openai-api`.
4. **Model list.** `openai-chatgpt` uses `mode: all`, like the other standard providers: no repo-owned model list.
5. **Fallback placement.** ChatGPT plan is `#3` and the old `#3` is `#4`, per role, as listed under Fallback chains.

## Design

### Enablement and runtime

- `provider-enablement.seed.json` and `provider-policy.jsonc` list `openai-api` and `openai-chatgpt` (each `mode: all`, no models) in place of `openai`. In the seed, `openai-api` replaces `openai` and `openai-chatgpt` is not added, so ChatGPT login stays opt-in per host manifest.
- `bin/sync-provider-enablement` accepts the new tokens, refuses `openai-api` together with `openai-chatgpt`, and refuses a bare `openai` with the rename hint.
- The OpenCode-facing provider list (`enabled_providers` in `OPENCODE_CONFIG_CONTENT`) contains `openai` for either token, deduplicated, so host-local model overrides keep naming models as `openai/<model>`. The repo-side tokens remain available to the wrapper and the profile generator, which need them to choose secrets and nono routes. The exact runtime-file shape is decided in the plan; the contract is that the OpenCode config never sees a token name that is not an OpenCode provider id.
- Override validation does not check `openai/<model>` names against a list (no list exists for `all` mode), like `github-copilot`. A mistyped model fails on first use.
- The wrapper's secret mapping needs no secret for `openai-chatgpt`. `openai-api` keeps mapping to `openai_api_key`.

### nono profile

In `.config/nono/profiles/devspace-opencode-secure.jsonc`:

- A `credential_providers.openai_chatgpt` entry of type `oauth_capture`, with:
  - token endpoints on `https://auth.openai.com`: `/oauth/token` and the device-auth paths OpenCode's headless login uses (`/api/accounts/deviceauth/token`; `/api/accounts/deviceauth/usercode` carries no token and is not listed);
  - `response_fields`: `access_token` and `refresh_token` as `opaque`, `id_token` as `jwt`;
  - `request_body`: `form`, with `request_nonce_fields: ["refresh_token"]` (the verification gates confirm the body format OpenCode actually sends);
  - `api_hosts`: `https://auth.openai.com` plus the ChatGPT backend host OpenCode calls, which the verification gates confirm;
  - a `credential_store` of type `file_json` for `$HOME/.local/share/opencode/auth.json`, if the schema accepts OpenCode's field names, so nono can check that stored tokens are phantoms.
- A matching `credential_routes` entry.
- The existing `network.tls_intercept.ca_env_vars` already includes `NODE_EXTRA_CA_CERTS`, which OpenCode (Bun) honors; no new CA variable is expected.

`scripts/lib/generate-nono-profile.py` keeps the OAuth provider and route only when `openai-chatgpt` is enabled, and drops them otherwise, in the same way it filters API-key routes today. The `openai-api` token keeps selecting the existing `openai` route.

### Login

Login runs through the wrapped launcher in the pod and uses the "ChatGPT Pro/Plus (headless)" method (device code), which needs no loopback callback port; the browser variant redirects to `localhost:1455`, which a browser outside the pod cannot reach. OpenCode 1.19.6 has two entrypoints that use the same `openai` provider auth definition and the same OAuth endpoints:

- `opencode auth login` (alias `opencode providers login`): the documented path, needing no running TUI session.
- `/connect` inside the TUI, which reaches the same flow through OpenCode's server API.

Both run inside the sandbox, so nono's token-response rewriting applies to both. Whether they share identical code is not proven; gate 2 therefore checks each entrypoint. The nono runbook documents the steps, how to enable `openai-chatgpt` in the host manifest, how to enable nono debug logging (`RUST_LOG=nono_proxy::oauth_capture=debug,nono_proxy::tls_intercept=debug`) while verifying, and how to check that `auth.json` holds only phantoms by shape, never by printing token values.

### Fallback chains

ChatGPT plan is inserted as `#3` and the former `#3` becomes `#4` in `opencode.jsonc` and in agent frontmatter comments. The model per role follows the role's current tier: strong `openai/gpt-6.2-sol`, balanced `openai/gpt-6.1-terra`, light `openai/gpt-6-luna`.

| Chain | Tier | New `#3` |
| --- | --- | --- |
| top-level `model` | balanced | `openai/gpt-6.1-terra` |
| `build`, `plan` | strong | `openai/gpt-6.2-sol` |
| `general` (config and agent file) | balanced | `openai/gpt-6.1-terra` |
| `explore` | light | `openai/gpt-6-luna` |
| `maestro`, `brainstormer`, `policy-implementer`, `docs-writer` | balanced | `openai/gpt-6.1-terra` |
| `planner`, `senior-implementer`, `code-reviewer`, `docs-reviewer-gpt` | strong | `openai/gpt-6.2-sol` |
| `junior-implementer` | light | `openai/gpt-6-luna` |

Not changed: chains labelled "(local)" (`small_model`, `title`, `summary`, `compaction`) and `docs-reviewer-claude` (it must keep a non-GPT fallback). Existing explanatory lines (for example the "Opposite family" note in `code-reviewer.md`) stay. Model ids are checked against `opencode models openai` after the first login; an id the plan does not expose is replaced by the nearest exposed id of the same tier.

### Documentation

- The nono-policy runbook lists the new route, the phantom-token behavior and the login procedure.
- The model-routing cheatsheet gets a ChatGPT-plan section and describes chains as `#1` to `#4`.
- The bare-hub and lifecycle runbooks use `openai-api` where they name the API-key provider.
- The credential-phasing spec gets a short pointer to this spec (its existing contract lines stay unchanged, since contract tests pin them).

## Verification gates

Blocking, recorded with evidence before the slice counts as done. Gates 1 to 6 need a real ChatGPT Plus account and run in the pod under nono, so the human runs them; agents cannot run them.

1. Debug logs show `matched OAuth capture endpoint` and `rewrote OAuth token response fields to phantoms` for the login.
2. `auth.json` contains only phantom-shaped token values (shape check, no values printed), after a login from each entrypoint: `opencode auth login` and `/connect` in the TUI.
3. A prompt and a tool-using task run end to end through the wrapped launcher using the phantom-only `auth.json`, including a token refresh.
4. **Account id.** OpenCode derives the ChatGPT account id from `chatgpt_account_id` claims in `id_token` or `access_token`. A synthetic phantom `id_token` has no such claim, so the `ChatGPT-Account-Id` header may be missing. Confirm a personal Plus account works without it. If not, stop and re-plan; do not weaken the phantom guarantee.
5. The ChatGPT backend host and the token request body format are confirmed from debug logs and the profile is corrected if the first guess differs.
6. The capture store survives a pod restart (it sits under nono's state directory); otherwise the runbook documents re-login after restart.
7. No real token appears in `env`, `/proc/*/environ`, logs or shell-visible files inside the sandbox.
8. `opencode models openai` lists the ids used in the fallback table, or the table is corrected.

## Acceptance tests

Repo-file contract tests in `tests/pod-inside-nono/` run by the agent, written first (red) and offered for the human's review before implementation:

1. **Provider policy:** `openai-api` and `openai-chatgpt` are supported with `mode: all`; bare `openai` is no longer supported.
2. **Sync:** the manifest accepts either new token, refuses both together, and refuses bare `openai` with the rename hint; the OpenCode-facing provider list contains `openai` once.
3. **Wrapper:** `openai-api` still exports `OPENAI_API_KEY` from `openai_api_key`; `openai-chatgpt` requires no secret and exports none.
4. **Profile generator:** with `openai-chatgpt` enabled the generated profile contains the OAuth provider and route; without it, it contains neither; `openai-api` still selects the existing `openai` route.
5. **Template shape:** the committed profile's OAuth provider declares the token endpoints, `jwt` for `id_token`, and the `NODE_EXTRA_CA_CERTS` path stays configured.
6. **Fallback layout:** each chain in the table above has `#3` set to the ChatGPT-plan model and `#4` set to the former `#3`, and the excluded chains are unchanged.
7. **Docs contract:** the runbook and cheatsheet carry the new anchors. Existing contract tests that pin `openai` are updated deliberately, not weakened.

The `pod-outside-nono` blocking-matrix probe for `openai` is updated for the rename and run by the human.

## Tasks

Done in a managed worktree created with `bin/new-worktree`, reaching `main` only by merge.

1. Write failing acceptance tests 1 to 7. **User Check-in:** the human reviews the interface-defining tests.
2. Implement enablement, sync, wrapper and generator changes (rename plus `openai-chatgpt`); make tests 1 to 4 pass.
3. Add the OAuth provider and route to the nono profile; make test 5 pass.
4. Update fallback comments, runbooks, cheatsheet and the credential-phasing pointer; make tests 6 and 7 pass.
5. **User Check-in:** the human enables `openai-chatgpt` in the host manifest, runs the login, and returns the evidence for verification gates 1 to 8.
6. Correct the profile or fallback ids from the gate results, and rerun the affected tests.

## Risks

- **Phantom `id_token` lacks the account claim** (gate 4). This is the most likely failure. Mitigation: gate 4 runs first; the answer may require a nono profile change or an upstream fix.
- **Unverified endpoints.** The backend host and request body format come from the nono page and OpenCode's behavior, not a live run. Mitigation: gate 5.
- **Capture store location and lifetime.** The store is outside the sandbox but its persistence across pod restarts is unknown. Mitigation: gate 6.
- **Model ids differ by plan.** The ChatGPT backend exposes a subset of the catalog. Mitigation: gate 8.
- **Terms and quota.** Subscription use through a third-party client is governed by OpenAI's terms and the plan's usage limits, outside this repo's control.
- **A stricter nono version** may change `oauth_capture` behavior. Mitigation: the profile is validated with `nono profile show` at each nono upgrade.
