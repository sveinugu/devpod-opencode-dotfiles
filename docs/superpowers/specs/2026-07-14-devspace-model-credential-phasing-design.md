# DevSpace Direct-Provider Hardening with nono Design

Date: 2026-07-14  
Status: Proposed  
Related: `docs/superpowers/specs/2026-05-23-devspace-bare-hub-workspace-design.md`, `docs/superpowers/explorations/2026-05-23-devpod-alternatives.md`, `https://github.com/nolabs-ai/nono`, `https://nono.sh/docs/introduction`

## Executive Summary

This design retires the earlier Phase 1/Phase 2 framing and replaces it with one direct-provider design path for OpenCode in the DevSpace workspace.

The chosen path is:

- operator-managed provider secrets
- OpenCode running under `nono`
- `nono` proxy credential injection as the only supported credential route
- provider support limited to integrations that can satisfy that route

This design is contingent on a hard verification gate: if `nono` is not suitable in this Kubernetes workspace pod, the design must be reconsidered rather than silently degraded to weaker credential exposure paths.

## Problem Statement

OpenCode runs inside the same workspace trust boundary as the agent workload. If raw provider API keys are directly exposed to that runtime through ordinary environment variables, repo files, shell startup files, ad hoc PVC-backed files, or agent-readable auth storage, the workspace can likely use and extract them.

The goal here is not to build a full broker platform now. The goal is to make direct-provider OpenCode use materially safer in this workspace by ensuring real provider credentials do not enter agent bash scope for supported providers.

## Assumptions and Risk Model

- The workspace already runs inside a Kubernetes pod rather than directly on a developer laptop.
- The main secrets of concern are provider/API credentials used by OpenCode.
- Those credentials are rotatable.
- The expected providers are either local to UiO or sanctioned by UiO for the user's use case.
- The current baseline tolerated by the user and institutional context is weaker than the proposed `nono`-guarded path.
- The design must remain honest: this is a practical hardening design, not an absolute proof of isolation.

## Goals

- Remove provider credentials from tracked repo files, shell startup files, and ad hoc PVC-backed files.
- Keep OpenCode usable with supported direct providers in the DevSpace workspace.
- Keep real provider credentials out of agent bash scope for supported providers.
- Keep provider enablement host/operator controlled rather than hard-coded as always-on repo behavior.
- Support UiO-specific OpenCode integration cleanly, including full current model lists for the UiO providers.
- Make the secure wrapped OpenCode launch path the default so normal `opencode` usage does not accidentally bypass `nono`.
- Keep the design simple enough to operate and verify.

## Non-Goals

- Do not design a general broker/model-gateway platform in this slice.
- Do not support providers that cannot satisfy the `nono` proxy injection route.
- Do not support plain env-var credential exposure to the agent sandbox as an accepted steady-state route.
- Do not treat `auth.json` as the credential source of truth for supported providers.
- Do not own standard-provider model catalogs in the repo.
- Do not require users to memorize a different everyday command than `opencode` for the secure path.

## Core Decision

This design chooses a single direct-provider path:

1. Provider secrets are managed outside git by the operator.
2. The OpenCode runtime is wrapped by `nono`.
3. `nono` proxy credential injection is the only supported credential delivery route.
4. Providers are supported only if they work within that route and pass the verification gate.

If this path fails the verification gate, the design is not accepted and must be redesigned rather than weakened implicitly.

This design distinguishes between:

- the **repo-supported secure path**: wrapped `opencode` under the reviewed `nono` profile, using only the supported providers and credential route defined here
- **out-of-scope manual use**: raw OpenCode invoked intentionally by full path, or user-defined providers outside this design

Only the repo-supported secure path is covered by the acceptance criteria in this document.

## Hard Gate: nono Suitability

This design is contingent on `nono` being suitable inside the current DevSpace workspace pod.

Minimum gate before trusting `nono` for this repo:

1. kernel enforcement works inside the pod
2. failures are fail-closed enough to trust operationally
3. proxy credential injection keeps real credentials out of agent bash scope
4. OpenCode remains usable through the proxy route
5. UiO custom provider routing works

The gate passes only when **all blocking rows** in the verification matrix pass. Advisory rows may remain follow-up work, but their status must be recorded explicitly.

### Verification matrix

| Check | Class | Example evidence / command | Pass condition |
| --- | --- | --- | --- |
| In-pod runtime | Blocking | install `nono`; launch wrapped `opencode`; smoke-check `opencode --version` and a trivial prompt under `nono` | starts cleanly without sandbox init failure |
| Kernel enforcement | Blocking | under `nono`, read/write sentinel files in CWD and attempt disallowed read/write outside policy | allowed paths work and disallowed paths fail reliably |
| Fail-closed behavior | Blocking | intentionally break profile, proxy config, and credential source | execution aborts instead of falling back silently |
| Network control | Blocking | from sandbox child, test loopback proxy access, intended allowed routes, and random external hosts | child can reach only loopback proxy and any explicitly verified auxiliary endpoints; direct child egress to upstream provider hosts is blocked for proxy-backed providers |
| Proxy secrecy | Blocking | inspect `env`, `/proc/*/environ`, logs, temp files, and shell-visible config while using dummy then real credentials | real credential never appears inside sandbox scope; only phantom-token or proxy-local routing material is visible |
| OpenCode usability | Blocking | smoke-test prompt, streaming response, file edit, and subagent call through wrapped `opencode` | normal workflow remains usable |
| UiO routing | Blocking | verify both yellow and red against `https://gpt.uio.no/api/v1` via proxy-backed requests | yellow and red providers both function through their separate routes |
| Provider-specific verification | Blocking | one auth/list/request smoke test per supported provider; for Copilot, include `GITHUB_TOKEN`-based evidence | each supported provider stays within the supported contract |
| Profile minimization | Advisory | compare stock profile vs repo-specific profile and retest denied extra paths | least-privilege repo profile identified |
| Reproducibility | Advisory | rerun the relevant checks after pod restart/reprovision | behavior remains stable across pod lifecycle |

All early verification should use dummy credentials first.

## Provider Eligibility and Target Supported Set

A provider is eligible for this design only if all of the following are true:

1. OpenCode can use it in this environment.
2. Authentication works without tracked repo secrets.
3. It can be routed through `nono` proxy credential injection.
4. It passes the relevant `nono` verification checks.

### What counts as "authentication works"

- `gpt-uio-yellow`: separate yellow credential, successful wrapped request through the yellow proxy route to `https://gpt.uio.no/api/v1`
- `gpt-uio-red`: separate red credential, successful wrapped request through the red proxy route to `https://gpt.uio.no/api/v1`
- `openai`: successful wrapped request through the OpenAI proxy route
- `anthropic`: successful wrapped request through the Anthropic API route using API-token auth only
- `github-copilot`: successful wrapped provider use with `GITHUB_TOKEN`; device-flow or `auth.json` alone does not satisfy secure-path support for this design

### Target supported providers

- `gpt-uio-yellow`
- `gpt-uio-red`
- `openai`
- `anthropic` (API only; no Claude Pro/Max subscription path)
- `github-copilot`

### Explicitly unsupported for this design

- Google/Gemini, because the documented OpenCode + `nono` proxy route is known not to work there
- any provider that requires falling back to plain env-credential exposure inside the sandbox

### Provider ownership rules

- **UiO providers**: the repo owns the integration template and the full current model lists.
- **Standard providers**: the repo owns the integration/auth contract plus repo-tracked model allowlists layered over the OpenCode-owned upstream catalog.

Operationally, "repo owns the integration/auth contract" means the repo owns:

- provider identifiers and naming
- base-URL or upstream-routing configuration
- credential-route names and auth-header/format expectations
- generated OpenCode configuration shape
- model visibility policy for that provider class
- verification commands and evidence expectations

It does **not** mean the repo owns secret values.

`github-copilot` is included in the target supported set because direct OpenCode authentication via `GITHUB_TOKEN` has been verified by the user, but it still remains contingent on successful `nono`-route verification for this design.

## Credential Delivery Contract

`nono` proxy credential injection is the only supported credential route.

For supported providers:

- the real credential must stay outside the agent sandbox
- the sandboxed OpenCode/agent process may see only proxy-local routing details and phantom-token material
- real credentials must not be present in ordinary agent bash scope

Unsupported steady-state routes:

- plain provider env vars exposed directly to agent bash scope
- `nono --env-credential` mode for supported providers
- `auth.json` as the credential source of truth for supported providers
- repo-tracked secret values

## Kubernetes Secret Management Contract

Operator-managed Kubernetes secrets remain the source of credential material for this workspace deployment.

The design does not require a system keyring inside the pod. It does require that any pre-sandbox credential access be confined to a narrowly defined non-interactive launch path.

Allowed pre-sandbox credential visibility is limited to:

- the Kubernetes secret delivery surface itself
- a dedicated non-interactive launch helper or wrapper that immediately hands the secret to `nono` proxy setup
- the `nono` supervisor / proxy setup path before the sandbox is applied

The following are explicitly forbidden as credential-bearing surfaces:

- interactive login shells
- shell startup files such as `.zshrc`, `.bashrc`, or prompt hooks
- persistent exported user environment variables intended for ordinary shell sessions
- repo files, `.env` files, or other agent-readable workspace files
- agent-readable `auth.json` content for supported providers

Success is therefore defined by both of the following:

- real credentials do not enter the sandbox scope
- real credentials are not exposed through ordinary interactive shell/startup/env surfaces before sandboxing

### Privilege separation and `sudo` handling (security-hardening add-on)

This design’s baseline contract focuses on reducing credential exposure in ordinary interactive shell scope while using `nono` as the secure runtime path.

Chosen direction: **mandatory two-user split**.

Single-user strict-wrapper-only direction is rejected for this slice.

A dedicated hardening add-on is now explicitly in scope for security review:

- separate the **owner/operator user** from the **agent runtime user**
- keep raw Kubernetes-mounted credential files readable only by the owner-controlled launch path
- run everyday agent workloads (including wrapped OpenCode) as a non-sudo runtime identity by default
- preserve a deliberate owner/operator path for credential rotation and maintenance

Identity semantics for this slice:

- owner/operator identity is the main sudo-capable workspace user: `vscode`.
- agent runtime identity is the default non-sudo identity for everyday OpenCode/agent workloads.

About `sudo` semantics in this design:

- `nono` kernel enforcement is expected to remain authoritative for sandboxed child behavior, including subprocesses invoked from inside the sandbox
- however, `sudo` behavior must be treated as **verification-required**, not assumed
- this repo therefore requires explicit contract evidence for `sudo` behavior in the current pod/runtime before calling this hardening complete

Security-review scope for this add-on includes:

1. whether user/identity split is implemented in a way that prevents agent-side direct reads of raw secret mounts
2. whether wrapped-launch credential handoff remains non-interactive and fail-closed
3. whether attempted privilege escalation paths (`sudo`, user switching, shell escape paths) are correctly blocked or intentionally constrained in the supported path

Required `sudo` outcome for supported-path acceptance:

- agent runtime `sudo` escalation to owner/root is blocked in the supported path
- if any environment-specific exception exists, it must be explicitly recorded as a rejected configuration for this slice rather than treated as acceptable drift

Required non-`sudo` escalation outcomes for supported-path acceptance:

- agent runtime user-switch attempts to owner/operator identity are blocked in the supported path
- shell-escape paths that attempt to bypass the agent-runtime boundary are blocked in the supported path

## OpenCode Configuration Contract

The OpenCode-facing configuration should stay minimal and provider-specific only where necessary.

### UiO providers

The repo should define two custom OpenCode providers:

- `gpt-uio-yellow`
- `gpt-uio-red`

Each must:

- use the UiO OpenAI-compatible endpoint shape
- remain separate because they use separate credentials
- carry a repo-tracked full current model list

### Standard providers

For:

- `openai`
- `anthropic`
- `github-copilot`

the repo should define the integration/auth contract needed to make the provider available under the chosen runtime path. The repo should not mirror their full model catalogs.

### Model visibility policy

- **UiO providers** use repo-tracked full current model lists.
- **Standard providers** use repo-tracked allowlists, expected to map to OpenCode provider filtering such as `whitelist`, so the workspace does not surface the full upstream model catalog by default.

This is required because provider-owned catalogs can be much broader than the sanctioned or intended set for this workspace, including the reduced UiO-provided GitHub Copilot model set.

### Model-policy governance

- Repo-tracked model policy is updated through normal reviewed repo changes.
- For UiO providers, "current" means the latest user-approved sanctioned UiO model inventory known at the time of the spec or plan update; it does **not** mean automatic mirroring of everything upstream may expose.
- For standard providers, allowlists are current when they match the latest user-approved supported model set for this workspace.

The design does not use `enabled_providers` as a global allowlist. Users may still choose other providers only through out-of-scope manual raw OpenCode use; those providers are not supported by this repo's secure path, acceptance criteria, or runbooks.

## OpenCode Launch Contract

The secure wrapped launch path must be the default user path.

Required behavior:

- normal `opencode` in PATH resolves to a wrapper that launches OpenCode under `nono`
- the wrapper should use the reviewed repo-specific `nono` profile
- raw/unwrapped OpenCode remains available only via the real binary's full absolute path
- the wrapper must be a real executable path entry, not merely a shell alias or shell function
- scripted and subprocess invocations that call `opencode` by name must resolve to the same wrapped executable through PATH

This design intentionally rejects a separate everyday command such as `nono-opencode`, because that would make accidental insecure launches too likely.

The wrapper does not need to make unwrapped launches impossible. It does need to make the secure path the normal muscle-memory path.

Verification for this contract must include observable shell evidence such as `command -v opencode` and `type -a opencode`, showing that the wrapped executable is resolved before the real binary.

## nono Configuration Contract

The repo should not rely blindly on the stock `always-further/opencode` profile as the final answer.

Instead, the supported design requires a reviewed repo-specific `nono` profile that defines:

- minimum filesystem access OpenCode needs
- minimum network access needed for provider/proxy routing
- explicit credential routes for each supported provider
- model-routing assumptions needed by the supported provider set
- fail-closed expectations validated by the matrix

### Network policy contract

The repo-specific profile should default-deny sandbox child egress.

Allowed from the sandbox child:

- loopback access to the local `nono` proxy
- any additional auxiliary endpoints strictly required for wrapped OpenCode operation and explicitly recorded by verification

Blocked from the sandbox child:

- direct outbound access to upstream provider hosts for proxy-backed providers
- random external hosts not declared in the repo-specific profile

The stock OpenCode profile is acceptable only as an early verification reference.

### Required credential-route targets

The repo-specific profile should define routes for:

- `openai`
- `anthropic`
- `github-copilot`
- `gpt-uio-yellow`
- `gpt-uio-red`

UiO routes must target:

- `https://gpt.uio.no/api/v1`

with separate credential identities for yellow vs red.

If a provider cannot be made to work through proxy injection in the repo-specific profile, it is not supported by this design.

## Operator Workflow

The operator workflow should remain host-controlled and simple:

1. choose which supported providers to enable for this workspace
2. provide or rotate the required secrets outside git
3. update the generated OpenCode + `nono` runtime configuration, including model allowlists where applicable
4. ensure the wrapped `opencode` launcher is the default in-pod command surface
5. restart or redeploy the workspace as needed
6. run verification checks

Provider enablement must have one observable source of truth: a single host-local enablement manifest referenced by the runbooks. Generated runtime configuration and verification output must match that manifest exactly.

### Provider-specific workflow notes

- **UiO yellow/red**
  - separate enablement
  - separate secret material
  - separate generated provider entries
  - repo-tracked full current model lists

- **OpenAI / Anthropic / GitHub Copilot**
  - operator-enabled only when needed
  - repo supplies integration/auth contract
  - repo supplies model allowlists rather than full mirrored catalogs

Enablement should remain an explicit operator choice rather than an implicit side effect of secret presence.

## Acceptance Criteria

The design is acceptable only when all of the following are true:

1. `nono` proxy injection is the only supported credential route.
2. All blocking verification-matrix rows pass, and advisory rows are recorded explicitly.
3. The target supported provider set is exactly:
   - `gpt-uio-yellow`
   - `gpt-uio-red`
   - `openai`
   - `anthropic` (API only)
   - `github-copilot`
4. Explicitly unsupported providers are excluded rather than partially supported.
5. Real provider credentials do not appear in agent bash scope for supported providers.
6. UiO yellow/red remain separate providers with separate credentials and repo-tracked full current model lists.
7. Standard providers use repo-owned integration/auth contracts plus repo-owned model allowlists, not full mirrored model catalogs.
8. Plain `opencode` resolves to the wrapped `nono` launch path by default, while raw OpenCode remains available only by full absolute path.
9. `command -v opencode` resolves to the wrapped executable and `type -a opencode` shows that wrapped executable before the real binary.
10. Provider enablement is host/operator controlled through a single observable host-local enablement manifest, and generated runtime configuration matches it.
11. No tracked repo file contains secret values.
12. If `nono` is found unsuitable in this pod environment, this design path is rejected rather than silently downgraded.
13. The privilege-separation + escalation-blocking add-on is implemented with passing contract evidence and dedicated security review sign-off.
14. For the supported path, escalation from agent runtime to owner/operator/root via `sudo`, user-switch attempts, and shell-escape bypass paths is blocked.

## Deferred Alternatives

If this design path proves inadequate, future work may explore broader brokering or gateway patterns. That work is explicitly deferred.

One plausible future direction is expansion of the separately planned GitHub-token broker into broader credential brokering, but that is downstream of the GitHub-token broker work and not part of this design.

Other explored ideas such as fail-open OpenCode sandbox plugins, nested agent-container wrappers, or unsupported direct env-var sanitization surfaces are not selected here.

## Open Questions

The remaining open questions are verification-driven rather than architecture-driven:

1. Does `nono` satisfy the hard gate inside this exact Kubernetes workspace pod?
2. Can the repo-specific `nono` profile be tightened below the stock OpenCode profile without breaking usability?
3. What is the exact custom credential-route shape needed for UiO yellow/red under the OpenCode provider configuration surface?
4. Does `github-copilot` work cleanly enough under the chosen proxy route to remain in the supported set after verification?
5. Is there any pod/runtime-specific edge case that prevents enforcing blocked escalation (`sudo`, user-switch, shell-escape bypass) from agent runtime for the supported path?

## Pragmatic Assessment

Current design score: **9/10**

Strong rows:

- DRY: one supported credential route instead of many half-supported ones
- orthogonality: credential hardening is separated cleanly from provider catalog ownership
- reversibility: provider support is gated by verification, not hard-wired into the repo forever
- broken-window prevention: weak fallback routes are rejected instead of normalized

Remaining work to reach 10/10:

1. Run the `nono` suitability matrix in this pod and record results.
2. Prove UiO routing and Copilot support under the selected proxy path.
3. Convert the old implementation plan into one that matches this single-path design.
