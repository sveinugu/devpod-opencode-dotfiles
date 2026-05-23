# DevPod Alternatives, Secure Agent Workspaces, and GitHub App Integration Background

## Summary

This note captures the background and exploration findings behind a possible move away from DevPod for the dotfiles bare-hub-manager workflow. It is not a design or implementation spec. Its purpose is to summarize the user’s clarified requirements, the relevant assumptions from the existing plans, and the practical trade-offs between candidate workspace approaches so a later planner-owned design/spec can build on a shared context.

The central shift in understanding is that the original host-mounted bare-hub-manager idea was partly a workaround for DevPod limitations, especially around bare-cloning and worktree-oriented repository management. If a replacement can bootstrap or host bare Git repositories directly inside the cluster, the user is willing to abandon host-mounted source entirely. That is an important simplification, because it aligns better with the stronger security requirement that AI workspaces must not have direct write access to the host filesystem.

A second important clarification is that local and remote development serve different purposes. The user intends to continue doing normal development in local PyCharm and use Git push/pull as the main synchronization path. Remote PyCharm is primarily for inspecting agent activity, reviewing or correcting AI outputs, running tests, and occasionally editing directly in the secured agent workspace. This means the remote environment does not need to be optimized as a full-time primary IDE, but it does need to be secure, inspectable, and operationally practical.

## What Was Inspected

- `docs/superpowers/plans/2026-05-21-bare-hub-manager.md`
- `docs/superpowers/runbooks/host-bare-hub-bootstrap.md`
- `scripts/setup-host-bare-hub.sh`
- `scripts/verify-host-bare-hub.sh`
- Branch `github-app-integration`:
  - `docs/superpowers/plans/2026-05-20-github-app-integration-implementation-plan.md`
  - `docs/superpowers/plans/2026-05-20-github-app-integration-m2-durable-dedupe.md`
- Public docs/material for Coder, DevSpace, Eclipse Che, Daytona, Colima, k3d, kind, minikube, and Docker Desktop

## User Requirements

- Replace DevPod with a local-container-based alternative compatible with Colima + k3d.
- Preserve the bare-hub-manager concept or replace it with an equally capable cluster-native bare-clone/worktree model.
- Strong security boundary: AI workspaces should have no direct write access to host filesystems.
- Prefer pull-based, one-way backup or export from workspace/cluster to host.
- Support a separate GitHub App proxy/broker model for GitHub actions and personas.
- Support PyCharm connectivity, especially for remote inspection of agent workspaces.
- Keep the system practical on two Macs:
  - MacBook Pro M3 Max 48GB for interactive use
  - older Mac Mini M1 16GB mainly as a secure headless agent/workspace host
- Keep operational complexity reasonable for 1–2 secured workspaces, not a large multi-user platform.

## Key Findings

### Workspace alternatives

The exploration narrowed to three serious shapes:

- **Coder**: strongest full platform option, especially for remote IDE workflows and a polished workspace experience.
- **DevSpace**: strongest lightweight Kubernetes-native option, especially for local Colima + k3d and minimal platform overhead.
- **DIY workspace pod model**: strongest security/control option, but with the highest implementation and maintenance burden.

For this user’s scale and hardware, DevSpace consistently appeared to be the best fit when prioritizing low overhead, Colima + k3d compatibility, and bare-hub/worktree flexibility. Coder remained attractive mainly when optimizing for remote PyCharm/Gateway UX and a more productized platform.

### Security and isolation

The most important architectural conclusion is that host-mounted workspaces should not remain the default if strong AI isolation is required. The safer replacement pattern is to move source-of-truth workspace state into the cluster:

- workspace pods use PVC-backed storage
- bootstrap/init logic performs bare clone and worktree setup inside the cluster
- no `hostPath` mounts for agent workspaces
- host obtains exports/backups by pull, not by granting live write access

This change removes the main security objection to AI-assisted work: the agent can no longer silently modify host files that are simultaneously visible to local tools like PyCharm.

### GitHub App proxy / broker implications

The GitHub App plans reinforce a broker-first model rather than direct workspace-to-GitHub credentials. Relevant themes from those plans include:

- separate broker/executor responsibilities
- workload identity validation
- persona formatting and canonical action envelopes
- policy-deny paths and transport hardening
- idempotency and replay control
- durable dedupe using Redis for 24-hour retention across replicas

These details support the same broad conclusion reached in exploration: GitHub actions should remain mediated through a narrow internal service boundary, with short-lived credentials and strong identity/policy checks. The workspace platform choice does not remove the need for this broker model. It mainly determines how easy it is to host and secure that broker alongside the workspaces.

### PyCharm workflow

The user clarified that local PyCharm remains the primary development environment. Remote PyCharm is mainly an inspection and intervention tool for agent workspaces. This is helpful because it lowers the burden on the remote workspace UX:

- local PyCharm can remain fast and human-trusted
- remote PyCharm only needs to be good enough for inspection, tests, and occasional edits
- this makes a leaner DevSpace + cluster-native workspace model more attractive than a heavier platform purely for IDE polish

## Guiding Principles

1. **Prefer cluster-native state over host mounts for AI workspaces.**  
   If AI code can write to the workspace, that workspace should live inside the cluster, not on the host.

2. **Keep host interaction pull-only where possible.**  
   Backups, exports, and recovery should be initiated by the host, not pushed from the workspace into host filesystems.

3. **Treat Git as the main synchronization boundary for human work.**  
   Local development should flow through normal commit/push/pull patterns rather than shared live filesystems.

4. **Preserve the broker-first GitHub model.**  
   GitHub App credentials, persona logic, webhook handling, and idempotent mutation control should stay in a dedicated internal service, not inside agent workspaces.

5. **Optimize for the actual scale: one or two workspaces, not a platform at large-team scale.**  
   Extra control-plane complexity should be justified by concrete user benefit.

6. **Separate interactive and headless roles by machine.**  
   The M3 laptop is the better place for interactive remote inspection; the M1 Mini is better treated as a secure background workspace/agent host.

7. **Prefer simple operational shapes that can later be hardened incrementally.**  
   PVC-backed workspaces plus init/bootstrap logic are easier to reason about than prematurely introducing many new services.

## Recommended Short-Term Approach

The best short-term direction is to move from host-mounted bare-hub workspaces to a **cluster-native, PVC-backed workspace model** that still preserves the bare-hub/worktree concept. In practice, that means a workspace pod with persistent storage, plus bootstrap logic that performs bare cloning and worktree setup inside the cluster. DevSpace appears to be the best near-term fit for this because it keeps the Kubernetes developer workflow simple, adds little control-plane overhead, and does not force a source-management abstraction that conflicts with the bare-hub model.

The GitHub App integration should remain a separate broker/proxy service inside the cluster, following the security and idempotency ideas from the inspected GitHub App plans. The workspace should call that broker through narrow, authenticated internal paths. Human development should stay local-first through Git, while remote PyCharm is used mainly to inspect and occasionally intervene in the agent workspace. This preserves the user’s preferred workflow while closing the host-write risk that prompted the security concern.

## Suggested Next Steps

- Define a minimal cluster-native workspace shape: PVC, init/bootstrap logic, workspace container, no `hostPath`.
- Define the remote-access path for inspection: remote PyCharm/Gateway or SSH-based remote access, but only to the in-cluster workspace.
- Reframe the bare-hub-manager plan so “host-first mount into DevPod” becomes “cluster-native bare-hub bootstrap into workspace PVC.”
- Keep the GitHub App broker/proxy as a separate pod/service and align it with the existing broker-first/idempotent design direction.
- Produce a planner-owned design/spec that separates:
  - workspace bootstrap/storage
  - remote IDE access
  - GitHub broker integration
  - backup/export and recovery flow

## Open Questions & Risks

- Should the remote inspection path use full JetBrains Gateway-style access, or a simpler SSH-based remote workspace model?
- Is one PVC-backed shared hub enough, or should different repos/worktrees be split across multiple volumes for operational safety?
- How much of the current bare-hub-manager plan should be preserved verbatim versus reframed around in-cluster bootstrap?
- Local webhook exposure into a laptop-hosted cluster may still be awkward; this should be minimized unless truly required.
- The M1 Mini can host secure workspaces well, but interactive remote IDE performance there will likely remain secondary to the M3 laptop.
- DevSpace looks actively maintained today, but unlike a full platform, it leaves more architectural responsibility with the repo and operator.

If you approve this draft, I can hand it off to the planner as candidate background text for committing later.

$ses_1aa1ce991ffeqDiVKv8LnmHGYm <your reply>
