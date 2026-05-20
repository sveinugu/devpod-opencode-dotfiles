# GitHub App integration for opencode agents

Date: 2026-05-20
Status: Approved design for implementation planning
Scope: Agent-initiated GitHub actions across multiple repositories using a single GitHub App identity; webhook-driven automation and OpenCode Companion integration are excluded

## 1. Summary

This design defines a GitHub App integration for opencode agents that lets agents create pull requests and post issue or pull request comments across multiple repositories through a single GitHub App installation. GitHub should see one App identity. Agent personas are represented in comment and PR content plus local audit metadata, not as separate GitHub identities.

The preferred deployment model for DevPods on Kubernetes is:

1. DevPod workload authenticates to an external broker using a projected, audience-bound ServiceAccount token.
2. The external broker holds the GitHub App private key.
3. The broker mints GitHub App JWTs and installation tokens and performs GitHub API actions directly.
4. The DevPod receives structured results, not reusable GitHub tokens.

Fallback for isolated single-user DevPods: the GitHub App private key may be mounted into the DevPod as a file through CSI-backed secret delivery, and a local broker/helper may mint tokens locally.

## 2. Assumptions

- One GitHub App installation can be granted access to multiple target repositories.
- Personas are presentation-layer identity only; they are not separate GitHub principals.
- OpenCode Companion is explicitly out of scope and must not be used for credential handling, brokering, or authorization.
- DevPods default credential sharing is disabled, so GitHub App credentials must be delivered explicitly through Kubernetes/DevPod mechanisms.
- The first implementation is agent-initiated only; webhook listeners, background jobs, and autonomous event processing are out of scope.
- DevPods run on Kubernetes or on infrastructure where Kubernetes-style secret-delivery patterns are representative of the intended setup.

## 3. Problem statement

opencode agents need a safe, auditable way to act through one GitHub App across multiple repositories without relying on personal access tokens or per-persona bot accounts. The system must preserve a single GitHub-side identity while still recording which persona initiated each visible action. The design must work well with DevPods and avoid broad credential exposure inside workspace containers.

## 4. Goals and non-goals

### Goals

- Support issue comments, pull request comments, PR creation, and PR/issue metadata reads.
- Support multiple repositories through one GitHub App installation model.
- Keep the GitHub App private key out of the DevPod whenever practical.
- Attribute actions to personas in content/metadata and audit logs.
- Provide clear policy boundaries for allowed repos, actions, and personas.
- Keep rollback cheap and the implementation reversible.

### Non-goals

- Webhook receivers or background automation
- Per-persona GitHub accounts or GitHub Apps
- OAuth on-behalf-of-user flows as the primary architecture
- OpenCode Companion integration
- Long-lived GitHub tokens stored in the DevPod

## 5. DevPod findings that shape the design

The current repo and DevPod documentation support the following conclusions:

- This repo is a DevPod/OpenCode dotfiles setup, not an application service repo, so the design should focus on local tooling contracts and operational setup rather than a large standalone platform.
- The local Dockerfile already prepares file-based auth mounting patterns for OpenCode auth (`/home/vscode/.local/share/opencode/auth.json`), which makes file-mounted secret delivery a better fit than broad env-var injection.
- DevPod documents built-in forwarding for git, docker, ssh, and optional gpg credentials, but not arbitrary GitHub App private-key handling.
- DevPod on Kubernetes therefore depends on normal Kubernetes secret-delivery mechanisms for this design: projected ServiceAccount tokens, Secrets Store CSI Driver, Vault integrations, or equivalent external secret/broker patterns.

Design consequence: built-in DevPod git credential forwarding should not be used as the primary GitHub App authorization path.

## 6. Approaches considered

### Approach A — External broker performs GitHub actions (**recommended**)

DevPod workloads authenticate to an external broker using workload identity. The broker holds the GitHub App private key, mints installation tokens, and performs GitHub API actions directly.

**Pros**

- Best secret isolation
- Best auditability
- Strongest multi-tenant story for shared clusters or multiple agents
- Clean policy enforcement point

**Cons**

- Requires broker infrastructure
- Slightly more operational complexity than local-only helpers

### Approach B — DevPod-local minting with CSI-mounted private key

The GitHub App private key is mounted as a file into the DevPod. A local helper or broker mints App JWTs and installation tokens locally.

**Pros**

- Simpler initial setup in isolated environments
- No separate broker service required
- Good fallback for single-user DevPods

**Cons**

- Private key enters the workspace pod
- Weaker isolation in multi-agent or multi-user environments
- Harder to centralize audit and policy enforcement

### Approach C — Broker returns short-lived tokens to DevPod callers

The broker authenticates the DevPod, mints an installation token, and returns it to the caller for direct GitHub use.

**Pros**

- Easier transitional model if direct broker-executed actions are not ready
- Reuses existing GitHub CLI or curl workflows

**Cons**

- Worse containment and auditability than broker-executed actions
- Tokens can be copied, logged, or reused
- Splits policy enforcement and action execution across boundaries

### Recommendation

Use **Approach A** as the default. Keep **Approach B** as a documented fallback for isolated single-user DevPods. Treat **Approach C** as an exception path only.

## 7. Architecture

The system has five main boundaries: a DevPod-local agent request interface, a policy validation layer, a workload-identity link from DevPod to an external broker, the external GitHub App broker, and GitHub itself. Agents submit explicit GitHub actions with repository, target object, persona, and payload. The DevPod validates the request shape and presents workload identity to the broker. The broker authenticates the DevPod, authorizes the repo/persona/action, formats persona-visible content, mints GitHub App authentication material, and performs the GitHub API call. GitHub records one App identity; persona attribution is carried in content and local audit logs.

## 8. Components

### 8.1 Agent-facing GitHub request interface

**Responsibility:** Accept structured GitHub action requests from agents.

**Interface:** Narrow operations such as `read-pr`, `comment-pr`, `comment-issue`, `create-pr` with explicit repo, target, persona, and payload.

**Ownership:** DevPod local.

### 8.2 Policy and request validation layer

**Responsibility:** Validate required inputs, allowed action types, allowed personas, and allowed repositories.

**Interface:** Input is a structured request; output is allow/deny plus normalized parameters.

**Ownership:** DevPod local, optionally duplicated at the external broker.

### 8.3 Broker authentication identity

**Responsibility:** Present workload identity from the DevPod to the external broker.

**Interface:** Projected ServiceAccount token or equivalent workload identity token, audience-bound to the broker.

**Ownership:** DevPod local / Kubernetes platform.

### 8.4 External GitHub App broker

**Responsibility:** Authenticate DevPod workloads, enforce policy, hold the GitHub App private key, mint App JWTs and installation tokens, and perform GitHub API calls.

**Interface:** Narrow action endpoints returning structured results rather than generic tokens.

**Ownership:** External broker.

### 8.5 GitHub App installation

**Responsibility:** Provide GitHub-side identity and authorization across selected repositories.

**Interface:** Standard GitHub App JWT → installation token → API call flow.

**Ownership:** GitHub.

### 8.6 Persona attribution formatter

**Responsibility:** Embed persona identity into visible payloads and local metadata.

**Interface:** Accept normalized action data and persona label; emit final comment/PR payload.

**Ownership:** DevPod local or external broker; recommended at the broker if final payload assembly happens there.

### 8.7 Audit log

**Responsibility:** Record who requested what, for which repo/object, as which persona, and with what result.

**Interface:** Structured append-only events without secret contents.

**Ownership:** Prefer external broker as source of truth; local request logs are optional.

### 8.8 Optional local key mount fallback

**Responsibility:** Provide file-based private-key access inside an isolated DevPod if no external broker exists.

**Interface:** Mounted file path only.

**Ownership:** DevPod local / Kubernetes platform.

## 9. Data flows

### 9.1 Flow A — DevPod request to external broker, broker performs GitHub action (**default**)

**Inputs**

- repo/org
- target object (issue or PR)
- action type
- persona
- payload/body
- DevPod workload identity token

**Steps**

1. Agent submits a structured GitHub request.
2. DevPod-local validation checks request shape and local policy.
3. DevPod presents a projected, audience-bound ServiceAccount token to the broker.
4. Broker authenticates the workload and enforces repo/action/persona policy.
5. Broker formats final persona-visible content.
6. Broker mints a GitHub App JWT from the private key it holds.
7. Broker exchanges the JWT for an installation token.
8. Broker performs the GitHub API call.
9. Broker returns structured success/failure data.

**Who holds keys**

- GitHub App private key: external broker only
- ServiceAccount token: DevPod workload
- Installation token: external broker only

**Where tokens are minted**

- App JWT: external broker
- Installation token: external broker

**Audit records written**

- caller workload identity
- agent identifier if available
- persona
- repo/object/action
- request ID
- policy decision
- result or failure class

### 9.2 Flow B — DevPod-local request with CSI-mounted key and local minting (**fallback**)

**Inputs**

- repo/org
- target object
- action type
- persona
- payload/body

**Steps**

1. Agent submits a structured request.
2. DevPod-local validation checks request shape and local policy.
3. Local formatter applies persona markers.
4. Local helper reads the GitHub App private key from a CSI-mounted file.
5. Local helper mints a GitHub App JWT.
6. Local helper exchanges the JWT for an installation token.
7. Local helper performs the GitHub API call.
8. Local helper returns structured results.

**Who holds keys**

- GitHub App private key: DevPod pod via mounted file
- Installation token: DevPod pod

**Where tokens are minted**

- App JWT: DevPod local
- Installation token: DevPod local

**Audit records written**

- agent/persona/repo/action/result
- request ID
- local failure classes

**Important constraint**

Use only for isolated single-user DevPods, because the private key enters the workspace pod.

### 9.3 Flow C — DevPod receives a very short-lived token (**discouraged exception**)

**Inputs**

- repo/org
- intended operation context
- persona
- DevPod workload identity

**Steps**

1. DevPod authenticates to the broker.
2. Broker validates caller, repo, persona, and action.
3. Broker mints App JWT and installation token.
4. Broker returns a very short-lived token to the DevPod.
5. DevPod uses it immediately for one GitHub action.
6. DevPod records the result locally.

**Why discouraged**

- Tokens can be copied or logged.
- Audit trails split across broker and DevPod.
- Generic tokens are easier to misuse than action-specific endpoints.

**If used at all**

- TTL must be very short.
- Scope must be minimal.
- Issuance and use must both be audited.

## 10. Auth flows

### 10.1 DevPod to broker

Preferred mechanism: projected ServiceAccount tokens with broker-specific audience.

Broker checks should include:

- token issuer and signature validation
- audience matches the broker
- token freshness / expiry
- namespace, service account, and workload identity claims
- allowlist mapping from workload identity to allowed repos, personas, and actions

Recommended pattern:

- separate ServiceAccounts for distinct trust domains
- avoid one shared identity across unrelated DevPods
- fail closed on any identity mismatch

### 10.2 Broker to GitHub

- Broker uses the GitHub App private key to mint a short-lived App JWT.
- Broker exchanges the JWT for an installation token.
- Broker uses the installation token immediately and discards it.
- Broker never persists reusable GitHub tokens to disk.

### 10.3 Local-minting fallback

- Use file-based secret delivery only.
- Do not inject the GitHub App private key broadly via environment variables by default.
- Restrict read access to the mounted key material as tightly as the platform allows.

### 10.4 Recommended token lifetimes and scopes

- ServiceAccount token: short-lived, projected, audience-bound to broker
- Installation token: GitHub default short-lived token only, used ephemerally
- GitHub App key: long-lived secret managed outside the DevPod when practical
- Repo scope: only repositories granted to the installation
- Action scope: narrower policy at the broker than GitHub permissions whenever possible

## 11. Error handling and rollback

### 11.1 Authentication failures

Examples:

- invalid or expired ServiceAccount token
- wrong audience
- broker rejects workload identity

Behavior:

- fail closed
- return a clear, non-secret authorization error
- no repeated retries for hard auth denials
- log denial reason in audit records

### 11.2 Repo or persona not allowed

Behavior:

- reject before contacting GitHub
- return actionable policy error
- write a denied-policy audit event

### 11.3 Network failures

Behavior:

- bounded retries with short backoff for idempotent reads
- for writes, retry only if success can be disproven or if idempotency markers are available
- if final state is uncertain, require a read-before-retry reconciliation step

### 11.4 Token exchange or GitHub upstream failures

Examples:

- invalid private key
- installation not found
- insufficient permissions
- transient GitHub outage

Behavior:

- classify errors explicitly
- retry only transient 5xx or timeout failures in a bounded way
- do not log JWTs or tokens

### 11.5 Rollback behavior

- comments are append-only unless explicit delete behavior is later approved
- PR creation failures with uncertain state must reconcile by querying GitHub before retrying
- every mutating request should carry a correlation/request ID for audit and reconciliation

## 12. Security and auditability

### 12.1 Security principles

- Prefer broker-held GitHub App private keys over DevPod-local key storage.
- Prefer file mounts over env-var injection for any secret that must enter a DevPod.
- Prefer broker-executed actions over returning tokens.
- Use projected, audience-bound ServiceAccount tokens for workload-to-broker auth.
- Enforce repo/persona/action policy independently from GitHub permission scopes.

### 12.2 Multi-tenant risks

Major risks:

- multiple agents or users sharing a DevPod pod
- mounted key material readable by unintended processes
- generic token issuance increasing blast radius

Mitigations:

- one trust domain per DevPod where possible
- separate ServiceAccounts for separate trust domains
- external broker as default
- local key mounts only in isolated single-user pods
- structured audit logs at the broker
- no raw secret or token logging

### 12.3 Audit requirements

Audit records should capture:

- timestamp and request ID
- caller workload identity
- agent identifier when available
- persona
- repo, object, and action
- allow/deny decision
- upstream GitHub result or error class

Audit records must not capture:

- private key contents
- JWTs
- installation tokens

## 13. DevPod and Kubernetes secret-delivery options

### 13.1 Preferred default

Use an external broker plus projected ServiceAccount tokens from DevPods.

Rationale:

- keeps GitHub App key out of workspace pods
- aligns well with DevPod on Kubernetes
- strongest audit and multi-tenant story

### 13.2 Supported fallback

Use Secrets Store CSI Driver, Vault CSI, or equivalent file-based secret delivery to mount the GitHub App private key into the DevPod only for isolated single-user setups.

### 13.3 Not recommended as default

- broad env-var injection of GitHub App private keys
- using DevPod’s built-in git credential forwarding as GitHub App authorization
- long-lived reusable tokens stored in the DevPod

## 14. Recommended DevPod/Kubernetes configuration choices

- Use projected ServiceAccount tokens with an explicit broker audience.
- Give distinct DevPod trust domains distinct ServiceAccounts.
- Prefer external secret managers plus CSI or broker patterns over plain env-var injection.
- If the private key must reach the DevPod, mount it as a file, not an env var.
- Restrict network access so only approved workloads can reach the broker.
- Keep broker endpoints narrow and action-specific.
- Rotate underlying secret-manager material on a normal ops cadence and rely on GitHub short-lived installation tokens at runtime.

## 15. Testing strategy

The implementation plan should use behavior-focused verification rather than low-level unit-only checks.

### 15.1 Core verification scenarios

1. DevPod workload can authenticate to the broker using projected ServiceAccount identity.
2. Authorized workload can read PR metadata from an allowed repository.
3. Authorized workload can post a PR comment with the expected persona marker.
4. Authorized workload can create a PR with the expected persona metadata.
5. Disallowed repo/persona/action combinations are rejected before GitHub mutation.
6. Broker audit log records the correct persona, repo, action, and result.
7. Local-minting fallback works only when configured with a valid CSI-mounted key.
8. Token-return exception path, if implemented, issues very short-lived tokens and records both issuance and use.

### 15.2 Failure-path verification

- invalid projected ServiceAccount token
- wrong audience
- missing or unreadable mounted key
- installation lookup failure
- GitHub permission mismatch
- transient network failure with bounded retry behavior

## 16. Success criteria

This design is successful when the future implementation can demonstrate all of the following:

1. Agents can act across multiple repositories using one GitHub App installation model.
2. GitHub sees one App identity, not separate persona accounts.
3. Persona identity is visible in content/metadata and captured in audit logs.
4. The preferred implementation keeps the GitHub App private key out of the DevPod.
5. DevPod workloads authenticate to the broker using short-lived workload identity.
6. Mutating actions are governed by explicit repo/persona/action policy.
7. Failures are understandable, auditable, and do not leak secrets.
8. The design remains implementable as a single focused plan without requiring webhook automation.

## 17. Scope check for planning

This spec is intentionally scoped for one implementation plan:

- one external broker path as the default
- one local-minting fallback path
- a narrow initial action set (read metadata, comment, create PR)

Deferred work:

- webhook ingestion
- background automation
- automatic event handling
- per-persona GitHub identities
- generalized forge-provider support

## 18. Remaining unknowns

These do not block planning, but they should be resolved during implementation planning or environment validation:

1. Exact broker deployment location and technology stack
2. Exact Kubernetes claims available in the projected ServiceAccount token in the target cluster
3. Exact repository-to-installation mapping model if the GitHub App is installed at org scope with selective repo access
4. Exact persona formatting convention for comments and PR bodies

These unknowns are recorded here so the implementation plan can turn them into concrete tasks instead of leaving them implicit.

## 19. Short next steps

1. Confirm the broker trust model and projected ServiceAccount token claims available in the target DevPod cluster.
2. Define the narrow request contract for read/comment/create PR operations.
3. Decide the persona formatting convention for visible GitHub payloads and audit records.
4. Write the implementation plan for the broker-first path and the local CSI fallback path.

## 20. Trade-offs summary

- **Broker-first** costs more operationally but gives better isolation, auditability, and multi-tenant safety.
- **Local minting** is simpler in isolated setups but weakens secret isolation.
- **Returning tokens** may ease transition but is less safe and should stay exceptional.
- **One App identity** simplifies GitHub auth and repo scaling, but persona attribution must be solved in content and auditing instead of GitHub identity.
