# OpenAI ChatGPT plan support implementation plan

Status: draft for approval (2026-11-24).
Binding design: `docs/superpowers/specs/2026-11-19-openai-chatgpt-plan-support-design.md` (revision 6 with the evidence update in `5ca6905`).
Worktree: `/workspaces/dotfiles/work/openai-oauth`, branch `openai-oauth`.

## Goal

Implement the ChatGPT slice of the design: external login into the existing Kubernetes Secret, header injection by nono, and a stub in `OPENCODE_AUTH_CONTENT` for OpenCode 1.19.6. Remove the `openai` API-key path. The GitHub Copilot adapter is a separate slice after this plan.

## Constraints

- Real credentials never enter the sandbox. Tests and development use synthetic values only.
- Agents do not run a real login, read live credentials, run the `opencode` wrapper, or run `pod-outside-nono` or `host` tests. The human runs those and returns the output.
- Agents do not bypass context guards, including the guard in `tests/pod-inside-nono/test_workspace_manifest_contract.sh`.
- Keep `gpt-uio-yellow` and `gpt-uio-red` unchanged.
- Pin OpenCode 1.19.6 and nono 0.82.0. HTTP transport only.
- Tests follow the repository testing policy: behavior and parsed configuration, no prose or source-spelling assertions. Each mock is justified in the test header.

## Affected surfaces

| Area | Files |
| --- | --- |
| Enablement | `.config/opencode/provider-policy.jsonc`, `.config/opencode/provider-enablement.seed.json`, `bin/sync-provider-enablement` |
| Secret mapping and wrapper | `scripts/lib/nono-secret-env.sh`, `.config/opencode/bin/opencode` |
| Profile and generator | `.config/nono/profiles/devspace-opencode-secure.jsonc`, `scripts/lib/generate-nono-profile.py` |
| Launch | `scripts/lib/launch-opencode-nono.sh` |
| Header helper (new) | `scripts/lib/chatgpt-headers.py`, installed root-owned as `/usr/local/libexec/dotfiles-chatgpt-headers` |
| Image | `Dockerfile` (helper install, sudo `env_keep`) |
| Login command (new) | `ops/provider-login` (host) and `scripts/lib/provider-login-remote.sh` (pod side, run through `kubectl exec`) |
| Documentation | `nono-policy`, `devspace-bare-hub-usage` and `devspace-workspace-lifecycle` runbooks, pointer in the credential-phasing spec |

The connection signal is the presence of `OPENAI_CHATGPT_SESSION`: the wrapper exports it only for a valid session, and the generator and launch helper act on it. This keeps the existing sudo argument rules unchanged.

The sudo `env_keep` list replaces `OPENAI_API_KEY` with `OPENAI_CHATGPT_SESSION`, because the API-key mapping is removed. `OPENAI_API_KEY` stays in the profile's `deny_vars`.

## Acceptance tests

These tests are the primary deliverable before implementation. They define the interfaces for review. Existing tests are extended where they already own the behavior. Existing assertions that require the `openai` API-key route or `OPENAI_API_KEY` in `env_keep` change with the behavior.

| # | Behavior | Test home | Context |
| --- | --- | --- | --- |
| A1 | Policy and sync accept `openai-chatgpt`, refuse `openai` with a hint, and the seed does not enable ChatGPT. | `test_provider_enablement_sync_contract.sh`, `test_opencode_provider_policy_contract.sh` | pod-inside-nono |
| A2 | The session key is optional. Launch state is correct for valid, expiring within 24 hours, expired, missing and malformed sessions. Other providers keep working without ChatGPT. An explicitly selected `openai/*` model without a valid session refuses launch. | `test_opencode_secure_wrapper_contract.sh` | pod-inside-nono |
| A3 | The generator emits the ChatGPT route and capture entry only when ChatGPT is enabled and connected, emits no `openai` API-key route, and refuses unknown enablement tokens. | `test_nono_profile_layout.sh` or a new generator test | pod-inside-nono |
| A4 | The generated ChatGPT route has the required upstream, allowed headers, zero cache and a route variable that does not produce `OPENAI_BASE_URL`. `OPENAI_CHATGPT_SESSION` is in `deny_vars`. | Same as A3, using parsed profile output | pod-inside-nono |
| A5 | The header helper prints `Authorization` and `ChatGPT-Account-Id`, prints residency only when constrained, and on expired or malformed input exits non-zero with no output. | New helper test with synthetic sessions | pod-inside-nono |
| A6 | The launch helper sets the fixed stub only for a valid session, accepts no caller-supplied stub, never passes the session to the OpenCode process, and never sets `OPENCODE_EXPERIMENTAL_WEBSOCKETS`. | `test_nono_secret_boundary_contract.sh` or a new launch test | pod-inside-nono |
| A7 | `provider-login chatgpt` patches only `openai_chatgpt_session`, sends the value on standard input, never in arguments, prints no value, cleans up the pod directory on success, failure and interrupt, and does not patch on invalid login output. `--reset` removes only the key. | New test with fake `kubectl` | pod-inside-nono |
| A8 | The image installs the header helper root-owned and keeps `OPENAI_CHATGPT_SESSION` across the constrained sudo path. | `test_workspace_preinstalled_tools_contract.sh`, `test_nono_identity_integration_contract.sh`, `tests/host/test_dockerfile_opencode_helper_contract.sh` | pod-inside-nono, host |

A7 uses a fake `kubectl` because a real Secret patch and a real login are out of scope for automated tests. The fake records arguments and standard input so the test can check what would reach the cluster.

A8's host part is run by the human.

## Tasks

1. Write the failing acceptance tests A1 to A8. Run the pod-inside-nono tests to confirm the expected failures. Ask the human to run the host test.
   **User Check-in:** the human reviews the interface-defining tests, especially A2 (launch states), A6 (launch helper interface) and A7 (login command interface).
2. Enablement and removal: A1. Replace the `openai` token with `openai-chatgpt` in the policy, seed and sync script.
3. Secret mapping, wrapper launch states and launch helper: A2 and A6.
4. Profile template, generator and header helper: A3, A4 and A5.
5. Image changes: A8. Agents edit the `Dockerfile`. The human builds the image.
6. Login command with the ChatGPT adapter and `--reset`: A7. This includes extraction of the session JSON from OpenCode's temporary login output and removal of the refresh token.
7. Runbooks and the credential-phasing pointer. Semantic review only, no prose tests.
8. Each task ends with a refactor checkpoint and a run of the related pod-inside-nono tests. After task 7, run `bash tests/run.sh static` and the full pod-inside-nono suite.
   **User Check-in:** the human reviews the branch and does manual testing before automated review.
9. **User Check-in:** the human builds and deploys the image and runs synthetic gates S1 to S4 from the spec. Agents supply the S1 and S3 tests and the S2 and S4 handover checks. If a gate fails, stop and re-plan.
10. **User Check-in:** the human runs real-account gates R1 to R6.
11. Completion evidence: pragmatic-programmer diagnostic and clean-code review in the PR or handoff.

The Copilot adapter follows in a separate plan after task 10.

## Risks

- **Existing tests assert the API-key path.** Several tests reference `OPENAI_API_KEY` or the `openai` route. Changing them is part of the behavior change, not a bypass. The review in task 1 covers these changes.
- **Login output format.** Extraction depends on how OpenCode 1.19.6 writes its temporary login. A7 uses a synthetic file in that format. Gate R1 confirms it against a real login.
- **Agents cannot run the deployed path.** Tasks 9 and 10 depend on the human. Any failure there returns to planning.

## Gate tests

Gates S1 and S3 become `pod-outside-nono` tests, so they can be rerun at each OpenCode or nono upgrade. Only the human runs them. Gates S2 and S4 are one-off handover checks.
