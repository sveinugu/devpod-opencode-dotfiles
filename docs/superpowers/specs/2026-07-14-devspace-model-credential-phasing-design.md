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

## Hard Gate: nono Suitability

This design is contingent on `nono` being suitable inside the current DevSpace workspace pod.

Minimum gate before trusting `nono` for this repo:

1. kernel enforcement works inside the pod
2. failures are fail-closed enough to trust operationally
3. proxy credential injection keeps real credentials out of agent bash scope
4. OpenCode remains usable through the proxy route
5. UiO custom provider routing works

### Verification matrix

| Check | What to test | Pass condition |
| --- | --- | --- |
| In-pod runtime | `nono` installs and launches `opencode` in this pod | starts cleanly without sandbox init failure |
| Kernel enforcement | allowed paths work, disallowed paths fail | policy is actually enforced in-container |
| Fail-closed behavior | broken profile, broken proxy, missing credential source | execution aborts instead of falling back silently |
| Network control | intended routes work, unintended routes fail | provider/proxy path reachable, random egress blocked as designed |
| Proxy secrecy | inspect env, shell, `/proc`, logs, temp files | real credential never appears inside sandbox scope |
| OpenCode usability | prompt, streaming, edits, subagents | normal workflow remains usable |
| UiO routing | custom route to `https://gpt.uio.no/api/v1` | yellow and red providers both function |
| Provider-specific verification | provider auth and requests under `nono` | provider stays within supported contract |
| Profile minimization | stock profile narrowed for repo needs | least-privilege repo profile identified |
| Reproducibility | restart/reprovision checks | behavior remains stable across pod lifecycle |

All early verification should use dummy credentials first.

## Provider Eligibility and Target Supported Set

A provider is eligible for this design only if all of the following are true:

1. OpenCode can use it in this environment.
2. Authentication works without tracked repo secrets.
3. It can be routed through `nono` proxy credential injection.
4. It passes the relevant `nono` verification checks.

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

The design does not require a system keyring inside the pod. Instead, secret material may be made available to the parent runtime that launches `nono`, provided the verification matrix shows that the real credentials do not enter the sandbox scope.

This design therefore assumes:

- Kubernetes secrets are still operator-managed and out of git
- secret values may be surfaced to the parent OpenCode/`nono` runtime in a way compatible with proxy injection
- success is defined by sandbox exposure behavior, not by whether the parent runtime briefly sees the credential

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

The design does not use `enabled_providers` as a global allowlist. Users may still choose other providers outside this design; those providers are simply not supported by this repo design path.

## OpenCode Launch Contract

The secure wrapped launch path must be the default user path.

Required behavior:

- normal `opencode` in PATH resolves to a wrapper that launches OpenCode under `nono`
- the wrapper should use the reviewed repo-specific `nono` profile
- raw/unwrapped OpenCode remains available only via the real binary's full absolute path

This design intentionally rejects a separate everyday command such as `nono-opencode`, because that would make accidental insecure launches too likely.

The wrapper does not need to make unwrapped launches impossible. It does need to make the secure path the normal muscle-memory path.

## nono Configuration Contract

The repo should not rely blindly on the stock `always-further/opencode` profile as the final answer.

Instead, the supported design requires a reviewed repo-specific `nono` profile that defines:

- minimum filesystem access OpenCode needs
- minimum network access needed for provider/proxy routing
- explicit credential routes for each supported provider
- model-routing assumptions needed by the supported provider set
- fail-closed expectations validated by the matrix

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
2. The `nono` verification gate passes at the required level.
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
9. Provider enablement is host/operator controlled.
10. No tracked repo file contains secret values.
11. If `nono` is found unsuitable in this pod environment, this design path is rejected rather than silently downgraded.

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
