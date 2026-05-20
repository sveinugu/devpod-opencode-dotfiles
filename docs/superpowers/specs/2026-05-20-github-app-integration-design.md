# GitHub App integration for opencode agents

Date: 2026-05-20
Status: Draft design.
Planning gate: Approved for Phase 0 discovery planning while §18.1 preconditions remain unresolved. Full implementation planning is allowed only after those preconditions are resolved.
Scope: Agent-initiated GitHub actions across multiple repositories using a single GitHub App identity; webhook-driven automation and OpenCode Companion integration are excluded

## 1. Summary

This design defines a GitHub App integration for opencode agents that lets agents create pull requests and post issue or pull request comments across multiple repositories through a single GitHub App installation. GitHub should see one App identity. Agent personas are represented in comment and PR content plus local audit metadata, not as separate GitHub identities. For mutating actions, the external broker is the authoritative allow/deny policy decision point.

The preferred deployment model for DevPods on Kubernetes is:

1. DevPod workload authenticates to an external broker using a projected, audience-bound ServiceAccount token.
2. The external broker holds the GitHub App private key.
3. The external broker is the authoritative policy decision point for all mutating GitHub actions.
4. The broker mints GitHub App JWTs and installation tokens and performs GitHub API actions directly.
5. The DevPod receives structured results, not reusable GitHub tokens.

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

### Approach C — Broker returns tokens to DevPod callers

The broker authenticates the DevPod and returns either a broker-delegation token that the broker itself minted for tightly bounded local use or, less preferably, a raw GitHub installation token for direct GitHub use.

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

The system has five main boundaries: a DevPod-local agent request interface, a non-authoritative preflight validation layer, a workload-identity link from DevPod to an external broker, the external GitHub App broker, and GitHub itself. Agents submit explicit GitHub actions with repository, target object, persona, and payload. The DevPod validates request shape and presents workload identity to the broker. The broker is the authoritative policy decision point for mutating actions: it authenticates the DevPod, authorizes the repo/persona/action, formats persona-visible content, mints GitHub App authentication material, and performs the GitHub API call. GitHub records one App identity; persona attribution is carried in content and local audit logs.

## 8. Components

### 8.1 Agent-facing GitHub request interface

**Responsibility:** Accept structured GitHub action requests from agents.

**Interface:** Narrow operations such as `read-pr`, `comment-pr`, `comment-issue`, `create-pr` with explicit repo, target, persona, and payload. Broker-authorized and broker-audited reads are the recommended default path.

**Ownership:** DevPod local.

#### Request Contract v1 (normative)

All agent-facing operations in v1 use a shared structured envelope.

**Request envelope**

- `request_id` — required unique correlation identifier for every request
- `repo` — required repository identifier in `owner/name` form
- `action` — required action name from the supported v1 action set
- `persona` — required presentation-layer persona label
- `caller_identity` — optional informational caller label as observed by the DevPod-local interface before broker authentication
- `payload` — required action-specific body fields
- `idempotency_key` — required for mutating actions; optional for read-only actions

**Response envelope**

- `request_id` — echoes the request correlation identifier
- `status` — `ok` or `error`
- `result` — action-specific success payload, present only when `status=ok`
- `error` — structured error object, present only when `status=error`

**Error object**

- `code` — canonical error code
- `message` — human-readable, non-secret summary
- `retryable` — boolean
- `details` — optional structured diagnostics safe for logs

**Minimal canonical error codes**

- `POLICY_DENY`
- `INSTALLATION_NOT_FOUND`
- `GITHUB_PERMISSION_MISMATCH`
- `UPSTREAM_TIMEOUT`
- `INVALID_WORKLOAD_TOKEN`

**Normative rules**

- DevPod-local validation may reject malformed requests before broker submission, but it is not authoritative for mutating-policy decisions.
- `caller_identity` is informational only and must not be used as an authoritative policy input.
- Authorization and authoritative audit identity must derive from authenticated workload identity validated by the broker from projected ServiceAccount token claims or equivalent workload identity claims.
- The external broker is authoritative for all allow/deny decisions on mutating GitHub actions.
- Read actions should also follow a broker-authorized and broker-audited path by default.
- Every mutating request must carry both `request_id` and `idempotency_key` so caller logs, broker audit logs, and GitHub-visible results can be correlated.
- `idempotency_key` uniqueness scope is `(caller workload identity, repo, action)`.
- Minimum dedupe retention window is 24 hours.
- Duplicate semantics must return the prior canonical result for the same semantic request; if the payload differs for the same dedupe key, reject with explicit error code `DUPLICATE_PAYLOAD_MISMATCH`.
- Audit logs must record both first-seen and dedupe-hit events keyed by `request_id` + `idempotency_key`.

#### Action payload schemas (v1)

The following compact schemas define the minimum payload shape for the initial action set.

**`read-pr`**

- `payload.pr_number` — integer, required

Example request:

```json
{
  "request_id": "req_01",
  "repo": "octo-org/demo-repo",
  "action": "read-pr",
  "persona": "reviewer",
  "payload": {
    "pr_number": 42
  }
}
```

Example response:

```json
{
  "request_id": "req_01",
  "status": "ok",
  "result": {
    "number": 42,
    "title": "Add broker-first auth path",
    "url": "https://github.com/octo-org/demo-repo/pull/42"
  }
}
```

**`comment-pr`**

- `payload.pr_number` — integer, required
- `payload.body` — string, required
- `idempotency_key` — required

Example request:

```json
{
  "request_id": "req_02",
  "repo": "octo-org/demo-repo",
  "action": "comment-pr",
  "persona": "reviewer",
  "idempotency_key": "idem_02",
  "payload": {
    "pr_number": 42,
    "body": "Please tighten the policy wording in section 8."
  }
}
```

Example response:

```json
{
  "request_id": "req_02",
  "status": "ok",
  "result": {
    "comment_id": 9001,
    "url": "https://github.com/octo-org/demo-repo/pull/42#issuecomment-9001"
  }
}
```

**`comment-issue`**

- `payload.issue_number` — integer, required
- `payload.body` — string, required
- `idempotency_key` — required

Example request:

```json
{
  "request_id": "req_03",
  "repo": "octo-org/demo-repo",
  "action": "comment-issue",
  "persona": "triager",
  "idempotency_key": "idem_03",
  "payload": {
    "issue_number": 17,
    "body": "Confirming this issue is in scope for the broker-first rollout."
  }
}
```

Example response:

```json
{
  "request_id": "req_03",
  "status": "ok",
  "result": {
    "comment_id": 9002,
    "url": "https://github.com/octo-org/demo-repo/issues/17#issuecomment-9002"
  }
}
```

**`create-pr`**

- `payload.base` — string, required
- `payload.head` — string, required
- `payload.title` — string, required
- `payload.body` — string, required
- `idempotency_key` — required

Example request:

```json
{
  "request_id": "req_04",
  "repo": "octo-org/demo-repo",
  "action": "create-pr",
  "persona": "implementer",
  "idempotency_key": "idem_04",
  "payload": {
    "base": "main",
    "head": "work/github-app-integration",
    "title": "Add broker-authoritative GitHub App path",
    "body": "Implements the broker-first GitHub App design."
  }
}
```

Example response:

```json
{
  "request_id": "req_04",
  "status": "ok",
  "result": {
    "number": 43,
    "url": "https://github.com/octo-org/demo-repo/pull/43"
  }
}
```

#### Action → GitHub permission matrix

The following matrix assumes the v1 REST endpoints named in this spec. It defines the minimum GitHub App permissions the implementation should request for each action and the deny-test that should prove the permission boundary is real.

| Action | GitHub endpoint(s) | Minimum GitHub App permissions | Suggested deny-test |
| --- | --- | --- | --- |
| `read-pr` | `GET /repos/{owner}/{repo}/pulls/{pull_number}` | `pull_requests: read` | Attempt `read-pr` against a repo outside the workload allowlist; expect `POLICY_DENY` and only broker audit evidence. |
| `comment-pr` | `POST /repos/{owner}/{repo}/issues/{issue_number}/comments` | `issues: write` | Remove or withhold `issues: write`, then submit `comment-pr`; expect `GITHUB_PERMISSION_MISMATCH` or broker-side deny before GitHub mutation. |
| `comment-issue` | `POST /repos/{owner}/{repo}/issues/{issue_number}/comments` | `issues: write` | Remove or withhold `issues: write`, then submit `comment-issue`; expect `GITHUB_PERMISSION_MISMATCH` or broker-side deny before GitHub mutation. |
| `create-pr` | `POST /repos/{owner}/{repo}/pulls` | `pull_requests: write` | Remove or withhold `pull_requests: write`, then submit `create-pr`; expect `GITHUB_PERMISSION_MISMATCH` or broker-side deny before GitHub mutation. |

Notes:

- `create-pr` in this v1 contract assumes the head branch already exists. If a future flow also pushes commits or creates branches through Git, that flow will need an additional permission review, likely including `contents` access.
- `comment-pr` in this spec means a timeline issue comment on a pull request, not a line-level review comment. If review comments are added later, they need a separate permission review.

### 8.2 Policy and request validation layer

**Responsibility:** Perform non-authoritative preflight validation of required inputs, supported action types, and obvious request-shape errors before broker submission.

**Interface:** Input is a structured request; output is reject-for-malformed-input or normalized request-for-broker.

**Ownership:** DevPod local for preflight only; the external broker is authoritative for mutating-policy decisions.

Preflight handling may enrich logs or operator UX, but it must not override broker-derived identity, authorization, or authoritative audit attribution.

### 8.3 Broker authentication identity

**Responsibility:** Present workload identity from the DevPod to the external broker.

**Interface:** Projected ServiceAccount token or equivalent workload identity token, audience-bound to the broker.

**Ownership:** DevPod local / Kubernetes platform.

### 8.4 External GitHub App broker

**Responsibility:** Authenticate DevPod workloads, make the authoritative allow/deny decision for mutating actions, hold the GitHub App private key, mint App JWTs and installation tokens, and perform GitHub API calls.

**Interface:** Narrow action endpoints returning structured results rather than generic tokens.

**Ownership:** External broker.

### 8.5 GitHub App installation

**Responsibility:** Provide GitHub-side identity and authorization across selected repositories.

**Interface:** Standard GitHub App JWT → installation token → API call flow.

**Ownership:** GitHub.

### 8.6 Persona attribution formatter

**Responsibility:** Embed persona identity into visible payloads and local metadata.

**Interface:** Accept normalized action data and persona label; emit final comment/PR payload conforming to the canonical persona formatting spec.

**Ownership:** DevPod local or external broker; recommended at the broker if final payload assembly happens there.

#### Canonical persona formatting spec v1

All visible persona attribution must follow one canonical format so broker-produced and locally formatted payloads stay consistent.

- **Prefix line:** `[Persona: <persona>]`
- **Signature block:** `— Posted by persona <persona> via GitHub App`

Normative rules:

- Both broker-side and local fallback formatters must emit the same canonical prefix and signature block.
- The canonical persona marker must appear in all mutating comment bodies and PR bodies created through this integration.
- If GitHub-visible metadata fields are later added, they must preserve this canonical visible marker rather than replace it.

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
2. DevPod-local preflight validation checks request shape and required fields only.
3. DevPod presents a projected, audience-bound ServiceAccount token to the broker.
4. Broker authenticates the workload and makes the authoritative repo/action/persona policy decision.
5. Broker formats final persona-visible content.
6. Broker mints a GitHub App JWT from the private key it holds.
7. Broker exchanges the JWT for an installation token.
8. Broker performs the GitHub API call.
9. Broker returns structured success/failure data.

This same broker-first pattern is the recommended path for read actions so reads remain broker-authorized and broker-audited by default.

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
2. DevPod-local preflight validation checks request shape and required fields only.
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

### 9.3 Flow C — DevPod receives a broker-returned token (**discouraged exception**)

**Inputs**

- repo/org
- intended operation context
- persona
- DevPod workload identity
- request ID

**Steps**

1. DevPod authenticates to the broker.
2. Broker makes the authoritative allow/deny decision for caller, repo, persona, and action.
3. Broker mints App JWT and installation token.
4. Broker returns either a broker-delegation token or, less preferably, a raw GitHub installation token.
5. DevPod uses it immediately for the intended GitHub action.
6. DevPod records the result locally.

**Why discouraged**

- Tokens can be copied or logged.
- Audit trails split across broker and DevPod.
- Generic tokens are easier to misuse than action-specific endpoints.
- GitHub installation tokens are not single-use; do not assume single-use cryptographic guarantees.

**Token semantics**

- **Broker-delegation token:** a short-lived token minted by the broker for local client use. If the broker returns this kind of token, a TTL of `<= 60 seconds` is acceptable. The broker-delegation token must be bound to `request_id`, the client must present `request_id` when using the token, the broker must log issuance and use, and the broker must flag reuse or delayed use outside the expected action window.
- **Raw GitHub installation token:** a GitHub-issued installation access token that the broker chooses to hand back to the DevPod. Do not claim a broker-controlled sub-minute TTL for this token type. GitHub controls the expiration of installation access tokens per its installation-auth flow, and the documented default is an expiration after one hour rather than an arbitrary per-issuance TTL chosen by the broker: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation

**If a broker-returned token path is used at all**

- Scope must be minimal.
- Issuance and use correlation is required.
- The broker must log `request_id` at issuance, and the client must present `request_id` when using the token.
- The broker must flag token reuse or delayed use outside the expected action window.
- Anomaly detection should monitor token issuance frequency, cross-repo reuse patterns, and use outside the expected action window.
- If the broker returns a raw GitHub installation token, compensating controls are required: issuance/use correlation, strict egress controls, action-binding where feasible, anomaly detection, and clear audit logging.
- Raw GitHub installation-token return mode is disabled by default in prod-like environments and may be enabled only via explicit exception configuration with mandatory audit tagging and compensating controls.

## 10. Auth flows

### 10.1 DevPod to broker

Preferred mechanism: projected ServiceAccount tokens with broker-specific audience.

For mutating actions, broker authorization remains authoritative even if the DevPod-local preflight layer already accepted the request.
Read actions should also be broker-authorized and broker-audited by default so policy and audit behavior stays consistent across read and write paths.

Broker checks should include:

- token issuer and signature validation
- audience matches the broker
- token freshness / expiry
- namespace, service account, and workload identity claims
- allowlist mapping from workload identity to allowed repos, personas, and actions

Authoritative identity for authorization and audit must derive from validated workload identity claims, not from caller-supplied labels.

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

### 12.1.1 Security controls (required for prod-like envs)

- Enforce TLS between DevPod workloads and the broker; prefer mTLS where the platform can support workload certificates cleanly.
- Validate workload token freshness and audience on every broker request; projected ServiceAccount token guidance comes from Kubernetes service-account and projected-volume documentation: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/ and https://kubernetes.io/docs/concepts/storage/projected-volumes/
- Add anti-replay protection through single-use nonces for mutating requests or strict freshness windows tied to `request_id` and `idempotency_key`.
- Apply broker-side rate limiting for mutating endpoints so one compromised workload cannot flood GitHub or the audit pipeline.
- Define a minimum GitHub App permission matrix per action using GitHub App permission and installation-auth guidance as the boundary reference: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app and https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation
- Require audit alerts for anomalous activity such as denied-policy spikes, unusual repo fan-out from one workload, repeated installation lookup failures, or abnormal mutating volume from one persona.
- In broker-first mode, deny DevPod direct egress to GitHub APIs by default so workloads cannot bypass broker policy and audit controls.
- If Flow C returns a raw GitHub installation token, restrict egress so the workload can reach only the required GitHub endpoints for the approved action whenever the platform can enforce that boundary.

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
8. Token-return exception path, if implemented, verifies broker-delegation-token binding behavior or raw-token compensating controls and records both issuance and use.

### 15.2 Failure-path verification

- invalid projected ServiceAccount token
- wrong audience
- missing or unreadable mounted key
- installation lookup failure
- GitHub permission mismatch
- transient network failure with bounded retry behavior

### 15.3 Verification matrix

For deny/no-mutation scenarios in this matrix, the test harness should include a deterministic request marker derived from `request_id` in any would-be GitHub-visible body or title, for example `[request_id:req_02]`. Suggested lookback window for GitHub post-checks is 2-5 minutes to cover normal API and audit lag. Unless otherwise noted, the acceptance criterion is zero matching GitHub-visible artifacts plus a correlated broker audit record for the same `request_id`.

- **Scenario:** authorized broker-first PR comment
  - **Commands / harness:** submit a `comment-pr` request through the v1 request contract with `request_id` and `idempotency_key`
  - **Expected outcome:** broker authorizes, posts the comment, and returns `status=ok`
  - **Required evidence:** caller log with `request_id`, broker audit entry with the same `request_id`, GitHub comment URL or comment ID containing the expected persona marker
- **Scenario:** policy deny on disallowed repository
  - **Commands / harness:** submit a mutating request for a repo outside the workload allowlist
  - **Expected outcome:** broker returns `POLICY_DENY`; no GitHub mutation occurs
  - **No-mutation verification method:** caller harness queries the exact target GitHub surface within 5 minutes for the deterministic request marker (`GET /repos/{owner}/{repo}/issues/{issue_number}/comments` for comment actions or `GET /repos/{owner}/{repo}/pulls` for `create-pr`).
  - **Required evidence:** caller error response with `request_id`, broker deny audit event with the same `request_id`, zero matching artifacts in the 2-5 minute lookback window, and an explicit recorded acceptance of `no mutation observed`
- **Scenario:** invalid workload token
  - **Commands / harness:** replay a request with wrong audience or expired projected token in a controlled harness
  - **Expected outcome:** broker returns `INVALID_WORKLOAD_TOKEN`
  - **No-mutation verification method:** caller harness queries the same GitHub endpoint family that would have been mutated and searches for the deterministic request marker within 5 minutes.
  - **Required evidence:** caller error record with `request_id`, broker auth-failure audit event, zero matching GitHub-visible artifacts in the 2-5 minute lookback window, and acceptance of `no mutation observed`
- **Scenario:** installation lookup failure
  - **Commands / harness:** request an action against a repo not covered by the target installation
  - **Expected outcome:** broker returns `INSTALLATION_NOT_FOUND`
  - **No-mutation verification method:** caller harness queries for the deterministic request marker on the target issue-comment or pull-request surface within 5 minutes.
  - **Required evidence:** caller error response, broker audit event, upstream lookup failure evidence correlated by `request_id`, zero matching artifacts in the 2-5 minute lookback window, and acceptance of `no mutation observed`
- **Scenario:** GitHub permission mismatch
  - **Commands / harness:** run an action requiring a permission not granted to the GitHub App
  - **Expected outcome:** broker returns `GITHUB_PERMISSION_MISMATCH`
  - **No-mutation verification method:** caller harness queries the exact would-be mutation surface for the deterministic request marker within 5 minutes; broker audit pipeline may run the same check asynchronously as a secondary guard.
  - **Required evidence:** caller error response, broker audit event, captured upstream GitHub error correlated by `request_id`, zero matching artifacts in the 2-5 minute lookback window, and acceptance of `no mutation observed`
- **Scenario:** upstream timeout during a mutating action
  - **Commands / harness:** inject GitHub API timeout or broker-to-GitHub network fault in a controlled test
  - **Expected outcome:** bounded retry behavior, then `UPSTREAM_TIMEOUT` if unresolved; no blind duplicate mutation
  - **Post-check method:** broker audit pipeline queries the target GitHub surface for the deterministic request marker within 5 minutes and records whether zero or one matching artifact exists.
  - **Required evidence:** caller error response with `request_id`, broker retry log, and reconciliation record showing either zero matches or exactly one match with no duplicates; acceptance requires no more than one matching artifact
- **Scenario:** local CSI fallback comment path
  - **Commands / harness:** run the same request through the local-minting fallback in an isolated DevPod
  - **Expected outcome:** local helper posts the comment successfully and logs the request without leaking key material
  - **Required evidence:** caller/local log with `request_id`, local audit record, and GitHub comment URL or ID with the expected persona marker
- **Scenario:** persona-format parity across broker-first and local-CSI fallback paths
  - **Commands / harness:** submit equivalent mutating requests through both the broker-first path and the local-CSI fallback path, then compare the resulting canonical persona markers
  - **Expected outcome:** both paths produce the same canonical persona marker and preserve audit linkage via `request_id`
  - **Required evidence:** captured GitHub artifacts from both paths, broker/local audit records tied to `request_id`, and a comparison log showing identical persona markers
- **Scenario:** replay or duplication attempt detection
  - **Commands / harness:** replay the same mutating request with identical `request_id` and `idempotency_key`
  - **Expected outcome:** broker rejects the replay and logs an anomaly
  - **Post-check method:** broker audit pipeline queries the original target GitHub surface for the deterministic request marker within 5 minutes and confirms that only the original artifact exists.
  - **Required evidence:** broker audit entry showing replay rejection, anomaly alert or equivalent signal, correlation to the original `request_id`, and acceptance of `exactly one original artifact, no duplicate artifact`
- **Scenario:** broker-delegation token return path
  - **Commands / harness:** request a broker-delegation token for a single approved action, then redeem it once with the matching `request_id`; repeat with the same token after the expected action window
  - **Expected outcome:** first use succeeds, replay or delayed reuse is rejected, and the broker records issuance and both use attempts
  - **Required evidence:** broker issuance log tied to `request_id`, successful first-use record, rejected replay or delayed-use record, and anomaly signal for the second use
- **Scenario:** raw GitHub installation token return path
  - **Commands / harness:** request a raw installation token through the exception path, perform the approved action, and attempt one out-of-policy follow-up that should be blocked by compensating controls
  - **Expected outcome:** the approved action is correlated to issuance, the follow-up is blocked or flagged, and the broker records raw-token issuance plus downstream action correlation
  - **Required evidence:** broker issuance log tied to `request_id`, strict-egress or action-binding evidence for the blocked or flagged follow-up, anomaly or policy signal for the attempted misuse, and audit records that correlate token issuance to observed use
- **Scenario:** egress deny enforcement in broker-first mode
  - **Commands / harness:** from the DevPod, attempt a direct GitHub API call such as `curl https://api.github.com`
  - **Expected outcome:** network access is blocked or rejected and the bypass attempt is observable
  - **Required evidence:** network policy logs or firewall logs showing the block plus broker-side audit or monitoring evidence of the attempted bypass path

## 16. Success criteria

This design is successful when the future implementation can demonstrate all of the following:

1. Agents can act across multiple repositories using one GitHub App installation model.
2. GitHub sees one App identity, not separate persona accounts.
3. Persona identity is visible in content/metadata and captured in audit logs.
4. The preferred implementation keeps the GitHub App private key out of the DevPod.
5. DevPod workloads authenticate to the broker using short-lived workload identity.
6. Mutating actions are governed by broker-authoritative repo/persona/action policy.
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

Planning precondition: if the must-decide unknowns in section 18 remain unresolved, implementation planning should begin with a Phase 0 discovery plan rather than a full build plan.

## 18. Remaining unknowns

### 18.1 Must decide before implementation planning

1. Exact broker deployment boundary and technology stack, because the trust boundary and operational model affect the implementation plan shape.
2. Exact Kubernetes claims available in the projected ServiceAccount token in the target cluster, because broker authentication and policy mapping depend on those claims.

### 18.2 Can resolve during implementation

1. Exact repository-to-installation mapping model if the GitHub App is installed at org scope with selective repo access.

Persona formatting is no longer an open question; section 8.6 is the source of truth for the canonical persona formatting spec.

These unknowns are recorded explicitly so the implementation plan can separate hard preconditions from normal implementation tasks.

## 19. Short next steps

1. Confirm the broker trust model and projected ServiceAccount token claims available in the target DevPod cluster.
2. If those preconditions are unresolved, write a Phase 0 discovery plan before the full implementation plan.
3. Finalize and adopt the v1 request contract defined in §8.1 (ownership assignment and field validation).
4. Write the implementation plan for the broker-first path and the local CSI fallback path.

## 20. Trade-offs summary

- **Broker-first** costs more operationally but gives better isolation, auditability, and multi-tenant safety.
- **Local minting** is simpler in isolated setups but weakens secret isolation.
- **Returning broker-delegation tokens** may ease transition and can be bounded tightly, but returning raw GitHub installation tokens is materially weaker and should stay exceptional.
- **One App identity** simplifies GitHub auth and repo scaling, but persona attribution must be solved in content and auditing instead of GitHub identity.
