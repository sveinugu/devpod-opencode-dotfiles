# DevSpace Model Credential Phasing Design

Date: 2026-07-14  
Status: Proposed  
Related: `docs/superpowers/specs/2026-05-23-devspace-bare-hub-workspace-design.md`, `docs/superpowers/explorations/2026-05-23-devpod-alternatives.md`

## Executive Summary

This design defines a two-phase path for handling model-provider API credentials in the current DevSpace workspace setup.

This document is an umbrella design for both phases. The next implementation plan should cover Phase 1 only. Phase 2 requires a separate follow-on plan after the broker endpoint contract and workspace-to-broker authentication contract are confirmed.

Phase 1 moves provider credentials out of repo-managed files, shell startup files, and PVC-backed workspace files and into Kubernetes Secret objects referenced by the workspace Deployment. This is an operational hardening step only. It improves storage, rotation, and accidental-leak posture, but it does not prevent code or agents running inside the workspace from accessing those credentials.

Phase 2 introduces a separate in-cluster broker/model-gateway service that alone holds the raw upstream provider credentials. OpenCode in the workspace talks to the broker through a narrow internal service boundary instead of talking directly to upstream model providers. This is the phase that corrects the trust boundary.

## Problem Statement

In the current workspace shape, OpenCode runs inside the same workspace trust boundary as the agent workload. If raw provider API keys are made directly available to that workspace, the workspace can use them and can likely extract them. Therefore:

- storing provider keys in repo files, dotfiles, shell config, or PVC-backed files is unacceptable
- injecting raw provider keys into the workspace can be a practical interim step, but it is not the final security boundary
- the end-state design must keep raw provider credentials outside the workspace

This design is intentionally honest about that distinction.

## Goals

- Remove model-provider API keys from tracked repo files, shell startup files, and PVC-backed workspace files.
- Keep OpenCode model access working during the transition.
- Make Phase 1 and Phase 2 intentionally compatible rather than competing designs.
- Document the security boundary truthfully: Phase 1 is operational hardening; Phase 2 is trust-boundary correction.
- Preserve the repo's existing preference for a separate broker-style service that does not share the workspace PVC.
- Keep the first usable slice simple and low-risk.

## Non-Goals

- Do not claim that Phase 1 prevents workspace agents from reading or using provider credentials.
- Do not require a general secret-management platform beyond Kubernetes Secrets in Phase 1.
- Do not design a full multi-tenant model platform in this slice.
- Do not require all possible broker hardening controls in the first Phase 2 slice.
- Do not require provider-specific implementation details beyond what is needed to define the contract.

## Current-State Constraints

- The workspace is currently a simple Kubernetes `Deployment` with one PVC and no secret injection.
- OpenCode currently runs inside the workspace pod.
- The repo's workspace design already prefers a future separate broker/service boundary and explicitly says such a broker should not share the workspace PVC.
- The user wants a two-phase deployment path: Kubernetes Secrets first, broker second.

## Core Decisions

- Phase 1 uses namespace-scoped Kubernetes Secret objects as the only supported source of raw provider credentials for direct workspace access.
- Phase 1 injects provider credentials into the workspace pod using the simplest OpenCode-compatible mechanism, expected to be standard environment variables via `secretKeyRef`.
- Phase 1 documentation and manifests may contain secret names, key names, and examples, but never secret values.
- Phase 1 startup must fail clearly when required secret references are configured but missing.
- Phase 2 moves raw provider credentials out of the workspace entirely and into a separate broker/model-gateway service.
- Phase 2 keeps the broker as a separate Deployment/service with its own credential source and no shared workspace PVC.
- The OpenCode-facing configuration surface should stay as small and provider-agnostic as possible so the Phase 1 → Phase 2 migration is mostly an endpoint/auth-target change.

## Phase 1: Workspace Kubernetes Secrets

### Purpose and security posture

Phase 1 is a cleanup and operational-hardening phase.

It improves the system by ensuring raw provider keys are no longer kept in:

- tracked repo files
- shell startup files such as `.zshrc`
- `state/hub/etc/install.env`
- ad hoc dotfiles or config files on the workspace PVC

Phase 1 does **not** attempt to protect provider credentials from code running inside the workspace. If OpenCode and agents in the workspace need direct provider access, the workspace can still use those credentials.

### Secret contract

Phase 1 should standardize on one Kubernetes Secret object per enabled provider.

Recommended naming pattern:

- `opencode-provider-<provider>`

Examples:

- `opencode-provider-openai`
- `opencode-provider-anthropic`
- `opencode-provider-openrouter`

Within each secret, the required data key should match the environment variable name expected by the provider integration.

Examples:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `OPENROUTER_API_KEY`

Only providers that are actually enabled need corresponding secrets.

### Deployment contract

The workspace Deployment should reference only secret names and secret key names. It must not embed provider credential values.

Because the current expected integration path for OpenCode/provider clients is standard environment variables, Phase 1 should inject the secret values into the pod environment using `secretKeyRef`.

This choice is made for compatibility and simplicity, not because environment variables are a strong secrecy boundary inside the workspace.

### Runbook contract

Phase 1 runbooks should document:

- how to create provider secrets outside git
- the required secret naming pattern
- the required key names inside each secret
- how to rotate a provider secret
- how to restart or redeploy the workspace so the new value is picked up
- how to verify that the workspace can still use the configured provider

The runbook must also state plainly that Phase 1 removes secrets from normal files but does not prevent workspace-local access to the secret values.

### Failure behavior

If the workspace Deployment is configured to require a provider secret and that secret or key is missing, startup should fail in a clear and diagnosable way.

For Phase 1, the acceptable fail-fast mechanism is Kubernetes-level startup failure from a required secret reference, for example a pod that does not start because a non-optional `secretKeyRef` points at a missing Secret or key and surfaces a `CreateContainerConfigError`-style misconfiguration.

The design intent is fail-fast misconfiguration rather than a partially working workspace with hidden credential drift. App-level validation may add a clearer message later, but it does not replace the required Kubernetes-level failure mode for the first slice.

### Acceptance boundary

Phase 1 is successful when:

- no provider API key needs to live in tracked repo files, shell startup files, or PVC-backed workspace files
- the workspace can still use the configured providers after secret injection
- missing or misnamed secret references fail in a diagnosable way
- the create, rotate, and verify flow is documented in runbooks

Phase 1 is **not** successful merely because secrets moved to Kubernetes if the documentation implies that workspace agents can no longer access them. The spec must remain explicit that this is not the security guarantee of Phase 1.

## Phase 2: Brokered Model Access

### Purpose and security posture

Phase 2 is the actual trust-boundary correction.

In Phase 2, the workspace no longer needs raw provider API keys. Instead, a separate broker/model-gateway service holds the upstream credentials and exposes a narrow internal API for model access.

This is the phase that satisfies the security goal that workspace agents must never have direct access to raw provider API keys.

### Broker shape

The broker should run as a separate Kubernetes Deployment/service inside the cluster.

The broker:

- holds raw upstream provider credentials
- talks to upstream model providers
- exposes a cluster-local endpoint for OpenCode/workspace use
- does not share the workspace PVC

The broker endpoint should be chosen so OpenCode can use it with minimal config change. The preferred Phase 2 target is an OpenAI-compatible internal endpoint, but Phase 2 implementation must not start until a follow-on plan freezes the exact endpoint contract against the confirmed OpenCode configuration surface.

### Credential contract

Raw provider credentials must exist only on the broker side in Phase 2.

The workspace:

- must not require raw provider API keys
- must not persist fallback provider keys in local files
- should authenticate to the broker through a narrow cluster-local mechanism

The exact authentication mechanism for the first broker slice is deferred to the Phase 2 follow-on plan, which must freeze the workspace-to-broker auth contract before implementation. Whatever mechanism is chosen should fit the existing cluster model and must not require sharing the raw upstream provider credentials with the workspace.

### Minimum broker responsibilities

The first Phase 2 slice should enforce at least:

- upstream credential isolation
- central rotation of upstream provider secrets
- provider/model allowlisting
- basic request/audit visibility

Additional hardening such as quotas, stronger replay protection, or tighter network policy can be layered on later unless the implementation plan identifies one of them as necessary for the first safe slice.

### Workspace contract

The workspace/OpenCode configuration should change from direct-provider configuration to broker-endpoint configuration.

The migration should be intentionally small:

- change endpoint/auth target
- remove direct provider secret references from the workspace Deployment
- keep the remaining OpenCode-facing configuration surface as stable as possible

### Acceptance boundary

Phase 2 is successful when:

- the workspace no longer needs raw provider API keys
- the broker alone holds the upstream provider credentials
- OpenCode can still reach the required models through the broker
- the broker boundary is documented as the new credential trust boundary

## Migration Contract

Phase 1 and Phase 2 are intentionally staged, not competing.

The migration contract is:

1. Clean up direct credential placement first.
2. Keep secret names, provider labels, and OpenCode-facing config understandable and minimal.
3. Replace direct provider access with broker access later without forcing a broad workspace redesign.
4. Remove direct provider secret references from the workspace once the broker path is working.

This keeps the first slice useful while preserving a clear upgrade path to the actual security destination.

## Alternatives Considered

### Store secrets in workspace files

Rejected.

This is the weakest shape. It risks accidental commit, backup persistence, and broad workspace-file visibility while providing no meaningful security advantage.

### Treat Phase 1 Kubernetes Secrets as the final design

Rejected.

Kubernetes Secrets improve operational handling, but if the workspace itself is not trusted with raw provider keys, Phase 1 cannot be the final security boundary.

### Jump directly to the broker and skip Phase 1

Deferred.

This would produce the cleanest end state, but it leaves current credential placement unaddressed while the broker is being designed and implemented. The chosen phased path gives immediate operational cleanup without pretending it solves the full trust problem.

## Phase Structure

The next implementation plan should cover only Phase 1. Phase 2 remains design-approved but plan-deferred until the broker endpoint and auth contracts are frozen.

### Phase 1

- define provider secret naming and key contract
- update workspace Deployment to consume provider secrets
- document create, rotate, and verify flow
- remove any direct provider-key dependency on repo-managed or PVC-backed files

### Phase 2

- add separate broker Deployment/service
- move upstream provider credentials to broker-only storage
- point OpenCode/workspace traffic at broker endpoint
- remove raw provider credentials from workspace Deployment

## Open Questions For Planning

The following are intentionally left for planning, with items 2-4 specifically deferred to the separate Phase 2 follow-on plan:

1. Exact initial provider set to support in Phase 1
2. Exact OpenCode configuration contract for using an internal broker endpoint
3. Exact first-slice broker auth mechanism
4. Whether direct workspace egress to provider endpoints should be blocked in the first broker slice or immediately after it
5. Exact rollout and rollback checks for secret rotation and broker cutover

## Pragmatic Assessment

Current design score: **8.5/10**

Remaining work to reach 10/10 is mostly about tightening the first implementation slice rather than changing the architecture:

1. Build one tracer slice for Phase 1 with one provider secret and an explicit failure mode for a missing secret.
2. Confirm the exact OpenCode internal-endpoint configuration contract before Phase 2 implementation.
3. Make the broker cutover and rollback checks explicit in the implementation plan.
