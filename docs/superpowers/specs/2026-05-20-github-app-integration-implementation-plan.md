GitHub App Integration — Implementation Plan
Date: 2026-05-20
Project: GitHub App Integration Implementation Plan
Assumptions used:

- The in-cluster broker is the Python + FastAPI executor.
- M1 keeps single replica + in-memory idempotency/state.
- No token-return flows are allowed in M1-M4.
- OpenBao is the only secret source; CSI fallback is only for isolated single-user mode.
- Implementers may adjust internal interfaces if behavior-driven tests show a simpler shape, but must preserve Request
  Contract v1 semantics.

# GitHub App Integration Implementation Plan

## 1) High-level workstreams and milestones

| Milestone                         | Scope                                                                                                                                                                                 | Acceptance criteria                                                                                                                                                            | Deliverables                                                                                               | Owners                          |
|-----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|---------------------------------|
| **M1 — Tracer-bullet executor**   | In-cluster executor prototype with TokenReview authN, OPA sidecar authZ, OpenBao secret read, direct GitHub API execution, FastMCP thin client, single replica, in-memory idempotency | End-to-end tracer bullet passes: in-pod client → executor → TokenReview → OPA → OpenBao → GitHub stub/live sandbox; no token returned; denied repo/action produces no mutation | FastAPI executor, OPA sidecar policy bundle, K8s manifests, FastMCP client wrapper, e2e tests, CI, runbook | Backend, Platform, Security, QA |
| **M2 — Durable idempotency + HA** | Replace in-memory request/idempotency state with Redis/Postgres; support safe multi-replica behavior                                                                                  | Duplicate mutating requests across replicas return canonical prior result; replay mismatch rejected; no duplicate GitHub artifacts                                             | Durable state store, migration docs, HA manifests, replay tests                                            | Backend, Platform               |
| **M3 — Operational hardening**    | mTLS/service-mesh fit, audit exports, alerts, OpenBao rotation automation, stricter policy/admin tooling                                                                              | Alerting fires on deny spikes/replay anomalies; rotation run tested; audit trail complete                                                                                      | Alert rules, dashboards, rotation docs/jobs, security review record                                        | SRE, Security, Platform         |
| **M4 — Expansion + rollout**      | Additional actions, broader repo onboarding, production rollout playbook                                                                                                              | New action types added without breaking v1 contract; staged rollout/rollback exercised                                                                                         | Expanded contract, rollout checklist, onboarding docs                                                      | Backend, Product/Infra, SRE     |

**Pragmatic recommendation:** treat **M1 as the critical walking skeleton
**. Do not generalize beyond one thin vertical slice until it works end-to-end.
---

## 2) Detailed M1 task list

### Suggested M1 repo layout

- `services/github_app_executor/app/main.py`
- `services/github_app_executor/app/models.py`
- `services/github_app_executor/app/auth/token_review.py`
- `services/github_app_executor/app/policy/opa_client.py`
- `services/github_app_executor/app/secrets/openbao.py`
- `services/github_app_executor/app/github/client.py`
- `services/github_app_executor/app/idempotency/memory.py`
- `services/github_app_executor/app/state/memory.py`
- `services/github_app_executor/app/mcp/client.py`
- `deploy/github-app-executor/base/*.yaml`
- `deploy/github-app-executor/opa/policy.rego`
- `tests/e2e/test_comment_pr_tracer_bullet.py`
- `tests/integration/test_tokenreview_auth.py`
- `tests/integration/test_opa_policy.py`
- `tests/integration/test_openbao_secret_read.py`
- `tests/contract/test_action_api.py`

### M1 tasks

#### M1.1 — Write tracer-bullet tests first

- Write failing behavior tests for:
    - authorized `comment-pr`
    - denied repo
    - replay hit
    - payload mismatch replay
    - `read-pr`
- First tracer bullet: `POST /v1/action` then `GET /v1/status/{request_id}`
- Done when:
    - tests fail for missing implementation, not test bugs
    - each test includes explicit `request_id`
      **Example commands**

```bash
pytest tests/e2e/test_comment_pr_tracer_bullet.py -v
pytest tests/contract/test_action_api.py -v
```

#### M1.2 — Scaffold minimal FastAPI executor

- Implement only:
    - `POST /v1/action`
    - `GET /v1/status/{request_id}`
    - `GET /healthz`
    - `GET /readyz`
- Keep internal structure thin; no premature service layers.
- Done when:
    - contract tests pass for validation/state envelope
    - health endpoints work in-cluster
      **FastAPI skeleton**

```python
from enum import Enum
from typing import Any
from fastapi import FastAPI, Header, Response
from pydantic import BaseModel, Field

app = FastAPI()


class ActionName(str, Enum):
    read_pr = "read-pr"
    comment_pr = "comment-pr"
    comment_issue = "comment-issue"
    create_pr = "create-pr"


class ActionRequest(BaseModel):
    request_id: str = Field(min_length=1)
    repo: str = Field(pattern=r"^[^/]+/[^/]+$")
    action: ActionName
    persona: str = Field(min_length=1, max_length=64)
    payload: dict[str, Any]
    idempotency_key: str | None = None


@app.post("/v1/action")
async def post_action(
        request: ActionRequest,
        response: Response,
        authorization: str = Header(...)
):
    response.headers["Location"] = f"/v1/status/{request.request_id}"
    return {"request_id": request.request_id, "state": "received"}


@app.get("/v1/status/{request_id}")
async def get_status(request_id: str):
    return {
        "request_id": request_id,
        "state": "received",
        "result": None,
        "error": None,
    }
```

#### M1.3 — Add Kubernetes TokenReview authN

- Executor validates projected ServiceAccount JWTs via Kubernetes `TokenReview`.
- Cache positive auth results briefly (e.g. 30-60s) only if tests show need.
- Fail closed on:
    - invalid signature
    - wrong audience
    - expired token
    - missing namespace/serviceaccount claims
- Done when:
    - integration test with valid projected token passes
    - wrong-audience/expired token tests return `INVALID_WORKLOAD_TOKEN`

#### M1.4 — Add OPA sidecar authZ

- Run OPA as sidecar in M1.
- Rego inputs:
    - authenticated workload identity
    - repo
    - action
    - persona
- Rego output:
    - `allow: bool`
    - `reason: str`
- Done when:
    - deny paths never call GitHub adapter
    - policy tests cover allowed/denied repo-action-persona combos

#### M1.5 — Add OpenBao secret read

- Executor authenticates to OpenBao via Kubernetes auth.
- Read GitHub App private key and app ID from OpenBao only.
- Keep secret fetch in one adapter; no secrets in env vars.
- Done when:
    - integration test reads secret in-cluster/sandbox
    - logs contain no PEM/token material

#### M1.6 — Add direct GitHub execution path

- Implement minimal GitHub adapter for:
    - `read-pr`
    - `comment-pr`
    - `comment-issue`
    - `create-pr`
- Persona marker formatting must be canonical.
- No token-return endpoint anywhere.
- Done when:
    - tracer bullet posts one sandbox comment
    - denied and replay cases create no duplicate artifact

#### M1.7 — Add in-memory idempotency + request state

- Key by `(workload_identity, repo, action, idempotency_key)`
- Store:
    - normalized request hash
    - current state
    - terminal result/error
- Single replica only.
- Done when:
    - same request returns prior canonical result
    - changed payload returns `DUPLICATE_PAYLOAD_MISMATCH`

#### M1.8 — Add minimal FastMCP client integration

- Keep only:
    - `github_app_action`
    - `github_app_status`
- FastMCP client obtains projected SA token from mounted path and calls executor.
- No local companion, no laptop helper.
- Done when:
    - in-cluster FastMCP client can run tracer-bullet test
    - no GitHub token ever appears in client response

#### M1.9 — Add K8s manifests

- Deployment, Service, ServiceAccount, ConfigMap, SecretProviderClass/notes, NetworkPolicies, RBAC.
- Executor deployment must use `strategy: Recreate` in M1.
- Done when:
    - manifests render cleanly
    - policy and auth wiring verified in namespace

#### M1.10 — Add CI + security hardening

- CI stages:
    - contract/e2e tests
    - OPA tests
    - manifest validation
    - lint/type/security scans
- Security hardening:
    - non-root container
    - read-only root fs
    - drop all capabilities
    - resource limits
    - egress restrictions
    - request/audit correlation by `request_id`
- Done when:
    - CI passes
    - deployment checklist signed off by Security + Platform

### Example M1 CI/test commands

```bash
pytest tests/contract/test_action_api.py -v
pytest tests/integration/test_tokenreview_auth.py -v
pytest tests/integration/test_opa_policy.py -v
pytest tests/integration/test_openbao_secret_read.py -v
pytest tests/e2e/test_comment_pr_tracer_bullet.py -v
opa test deploy/github-app-executor/opa -v
ruff check services/github_app_executor tests
mypy services/github_app_executor
bandit -r services/github_app_executor
pip-audit
kustomize build deploy/github-app-executor/base | kubeconform -strict -summary
```

---

## 3) REST API contract and FastMCP integration points

### Endpoints

| Endpoint                      | Purpose                          | Semantics                                                                    |
|-------------------------------|----------------------------------|------------------------------------------------------------------------------|
| `POST /v1/action`             | Submit one GitHub action request | Sync for fast completion; may return `202` if still executing                |
| `GET /v1/status/{request_id}` | Poll request state/result        | Returns current or terminal state                                            |
| `GET /healthz`                | Liveness                         | No dependency checks                                                         |
| `GET /readyz`                 | Readiness                        | Confirms K8s API, OPA, OpenBao config reachable enough for service readiness |

### `POST /v1/action` request schema

```json
{
  "request_id": "req_123",
  "repo": "owner/name",
  "action": "comment-pr",
  "persona": "reviewer",
  "payload": {
    "pr_number": 42,
    "body": "Looks good."
  },
  "idempotency_key": "idem_123"
}
```

### Action-specific payloads

- `read-pr`: `{ "pr_number": int }`
- `comment-pr`: `{ "pr_number": int, "body": string }`
- `comment-issue`: `{ "issue_number": int, "body": string }`
- `create-pr`: `{ "base": string, "head": string, "title": string, "body": string }`

### `POST /v1/action` response schema

```json
{
  "request_id": "req_123",
  "state": "succeeded",
  "replayed": false,
  "result": {
    "url": "https://github.com/owner/name/pull/42#issuecomment-1"
  },
  "error": null
}
```

### `GET /v1/status/{request_id}` response schema

```json
{
  "request_id": "req_123",
  "state": "executing",
  "replayed": false,
  "result": null,
  "error": null
}
```

### HTTP semantics

- `200 OK`: read completed synchronously, or status lookup successful
- `201 Created`: mutation completed synchronously and created artifact
- `202 Accepted`: request accepted but still executing; `Location` header required
- `400 Bad Request`: malformed contract
- `401 Unauthorized`: missing/invalid bearer token before TokenReview success
- `403 Forbidden`: OPA deny → `POLICY_DENY`
- `404 Not Found`: unknown `request_id` on status lookup
- `409 Conflict`: `DUPLICATE_PAYLOAD_MISMATCH`
- `422 Unprocessable Entity`: valid JSON, unsupported/invalid action payload
- `502/504`: upstream GitHub/OpenBao/K8s timeout/failure

### Error codes

- `VALIDATION_ERROR`
- `INVALID_WORKLOAD_TOKEN`
- `POLICY_DENY`
- `INSTALLATION_NOT_FOUND`
- `GITHUB_PERMISSION_MISMATCH`
- `UPSTREAM_TIMEOUT`
- `DUPLICATE_PAYLOAD_MISMATCH`
- `INTERNAL_ERROR`

### Request state model

`RECEIVED -> AUTHENTICATED -> AUTHORIZED -> EXECUTING -> SUCCEEDED|FAILED`
Rules:

- replay with identical normalized payload: return prior terminal response with `replayed=true`
- replay with changed normalized payload: return `FAILED` + `DUPLICATE_PAYLOAD_MISMATCH`
- no token material ever included in `result`

### FastMCP integration points

Keep M1 minimal:

1. **Tool:** `github_app_action`
    - input: Request Contract v1
    - behavior: reads projected SA token, calls `POST /v1/action`
2. **Tool:** `github_app_status`
    - input: `request_id`
    - behavior: calls `GET /v1/status/{request_id}`
      Pragmatic guidance:

- Do **not** create separate MCP tools per action in M1 unless behavior tests show the generic tool is too awkward.
- Internal DTO names may change; external contract semantics may not.

---

## 4) Testing strategy

### Order of testing

1. **Tracer-bullet e2e first**
2. Integration tests
3. Contract tests
4. Focused unit tests only where they protect boundary logic

### Test layers

| Layer                 | Priority | Purpose                                                     |
|-----------------------|----------|-------------------------------------------------------------|
| **E2E tracer-bullet** | Highest  | Prove full path works end-to-end                            |
| **Integration**       | High     | TokenReview, OPA, OpenBao, GitHub adapter boundaries        |
| **Contract**          | High     | Request/response and error semantics                        |
| **Unit**              | Low      | Hash normalization, persona formatting, idempotency helpers |

### Required tracer-bullet scenarios

- authorized `comment-pr` end-to-end
- denied repo/action/persona causes no GitHub mutation
- identical replay returns canonical prior result
- changed replay returns `DUPLICATE_PAYLOAD_MISMATCH`
- `read-pr` works without idempotency requirement
- FastMCP client path works in-cluster

### Verification matrix tied to spec

| Spec area                                     | Proof test                                           |
|-----------------------------------------------|------------------------------------------------------|
| Request Contract v1                           | `tests/contract/test_action_api.py`                  |
| Projected SA auth via TokenReview             | `tests/integration/test_tokenreview_auth.py`         |
| OPA authoritative mutating authZ              | `tests/integration/test_opa_policy.py`               |
| OpenBao-only secret custody                   | `tests/integration/test_openbao_secret_read.py`      |
| Broker/executor performs GitHub call directly | `tests/e2e/test_comment_pr_tracer_bullet.py`         |
| No token-return flow                          | contract assertion on all responses + e2e log scan   |
| Single-replica idempotency                    | `tests/e2e/test_replay_behavior.py`                  |
| CSI fallback isolated only                    | `tests/integration/test_csi_fallback_single_user.py` |

### Behavior-first test examples

- `test_authorized_comment_pr_returns_created_and_persists_status`
- `test_denied_repo_returns_policy_deny_and_no_comment_created`
- `test_same_request_replays_canonical_result_without_second_mutation`
- `test_changed_payload_with_same_idempotency_key_returns_conflict`

---

## 5) Deployment plan sketches

### A. Projected ServiceAccount token mount

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opencode-agent
spec:
  template:
    spec:
      serviceAccountName: opencode-agent
      automountServiceAccountToken: false
      containers:
        - name: agent
          image: ghcr.io/example/opencode-agent:dev
          volumeMounts:
            - name: executor-token
              mountPath: /var/run/secrets/opencode
              readOnly: true
      volumes:
        - name: executor-token
          projected:
            sources:
              - serviceAccountToken:
                  path: executor-token
                  audience: github-app-executor
                  expirationSeconds: 3600
```

### B. NetworkPolicy deny egress with DNS allowance

(For workspace pods: only DNS + executor access; no direct GitHub egress.)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: opencode-agent-egress
spec:
  podSelector:
    matchLabels:
      app: opencode-agent
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: github-app-system
          podSelector:
            matchLabels:
              app: github-app-executor
      ports:
        - protocol: TCP
          port: 8443
```

### C. TokenReview RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: github-app-executor
  namespace: github-app-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: github-app-executor-tokenreview
rules:
  - apiGroups: [ "authentication.k8s.io" ]
    resources: [ "tokenreviews" ]
    verbs: [ "create" ]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: github-app-executor-tokenreview
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: github-app-executor-tokenreview
subjects:
  - kind: ServiceAccount
    name: github-app-executor
    namespace: github-app-system
```

### D. OpenBao integration notes

- Use Kubernetes auth for executor → OpenBao.
- Bind OpenBao role to:
    - namespace `github-app-system`
    - ServiceAccount `github-app-executor`
- Store:
    - GitHub App private key PEM
    - GitHub App ID
    - installation mapping/config
- M1: use one narrow secret path, e.g. `kv/github-app/m1`
- CSI fallback:
    - allowed only for isolated single-user deployments
    - separate overlay/manifests
    - explicitly blocked in shared DevPod clusters

### E. Helm/Kustomize suggestion

- Kustomize for M1 base + overlays (`dev`, `sandbox`, `single-user-csi`)
- Optional Helm only if the executor becomes a reusable platform component across clusters
- Prefer Kustomize first: less abstraction, lower custom-code overhead

### F. Rollout / rollback

- M1 rollout: `strategy: Recreate` to preserve single-replica idempotency guarantees
- Pre-rollout:
    - disable client traffic or drain requests
    - confirm no in-flight nonterminal requests
- Rollback:
    - `kubectl rollout undo deployment/github-app-executor`
    - re-run tracer bullet
    - accept that in-memory nonterminal state is lost in M1; document this explicitly
- M2 removes this limitation with durable state

---

## 6) Security checklist

### Transport

- [ ] TLS required between clients and executor
- [ ] mTLS preferred if service mesh/workload certs already exist
- [ ] No plaintext intra-cluster exceptions without explicit risk signoff

### Identity/authN/authZ

- [ ] Projected SA tokens only
- [ ] Audience bound to executor
- [ ] TokenReview validates issuer/audience/expiry
- [ ] OPA sidecar is authoritative for mutating allow/deny
- [ ] Deny by default

### Secret custody

- [ ] GitHub App private key stored in OpenBao only
- [ ] Executor reads secret at runtime; no env-var secret injection
- [ ] CSI fallback isolated single-user only
- [ ] Secret value never logged

### OpenBao ACLs

- [ ] Executor role can read only GitHub App secret path(s)
- [ ] No list/write/delete on secret paths for runtime role
- [ ] Separate admin policy for rotation
- [ ] Audit device enabled for auth + secret reads

### Audit rules

- [ ] Every request logs `request_id`
- [ ] Log workload identity, repo, action, persona, policy result, GitHub result class
- [ ] Log replay-hit and payload-mismatch events
- [ ] Never log JWTs, installation tokens, PEM, comment body if sensitive

### Key rotation steps

1. Generate/import new GitHub App private key
2. Store new key version in OpenBao
3. Reload executor or trigger secret refresh
4. Run sandbox tracer bullet
5. Revoke old key in GitHub App settings
6. Confirm OpenBao audit + executor logs show new version use
7. Update runbook timestamp

### SRE on-call considerations

- Alert on:
    - TokenReview failure spikes
    - OPA deny spikes
    - OpenBao auth/read failures
    - GitHub timeout spikes
    - replay/payload-mismatch anomalies
- Dashboard panels:
    - request volume by action
    - success/deny/error ratio
    - executor latency
    - OpenBao latency/error rate
    - GitHub upstream failure rate
- Runbook must include:
    - how to disable mutations quickly
    - how to rotate key
    - how to verify no token-return regression

---

## 7) Time estimates and overall timeline

### M1 task estimates

| Task                             | Estimate |
|----------------------------------|---------:|
| M1.1 tracer-bullet tests         |   2 days |
| M1.2 FastAPI scaffold            |    1 day |
| M1.3 TokenReview authN           |   2 days |
| M1.4 OPA sidecar authZ           |   2 days |
| M1.5 OpenBao integration         |   2 days |
| M1.6 GitHub adapter              |   2 days |
| M1.7 in-memory idempotency/state | 1.5 days |
| M1.8 FastMCP thin client         |    1 day |
| M1.9 manifests + policies + RBAC |   2 days |
| M1.10 CI + hardening + runbook   |   2 days |

**M1 total:** ~17.5 engineering days (~3.5 weeks with review/coordination)

### M2-M4 estimates

| Milestone                              |  Estimate |
|----------------------------------------|----------:|
| M2 durable idempotency + multi-replica |   2 weeks |
| M3 hardening + audit/rotation/alerts   | 1.5 weeks |
| M4 action expansion + staged rollout   | 1.5 weeks |

**Overall timeline:** ~8.5 weeks

### Critical path (**M1-critical**)

**Tracer-bullet tests → TokenReview authN → OPA sidecar authZ → OpenBao read → GitHub execution → single-replica
deployment → e2e verification**
Do not parallelize around this path until the tracer bullet is green.
---

## 8) PR and code review workflow

### Subagent workflow

- **senior-implementer**
    - owns execution of each milestone/task
    - must follow TDD with behavior-first tests
    - handles reviewer feedback using `receiving-code-review`
- **code-reviewer**
    - review after:
        1. M1 tracer bullet
        2. TokenReview + OPA merge point
        3. OpenBao + GitHub execution merge point
        4. pre-merge final PR

### PR slicing

- PR1: tracer-bullet tests + skeleton contract
- PR2: TokenReview + OPA + deny-path tests
- PR3: OpenBao + GitHub execution + replay logic
- PR4: manifests + FastMCP + CI + runbook

### Review loop rule

- Up to **4 rounds**
- Fix all critical/important issues before next round
- Minor issues can roll into the next PR only if explicitly tracked

### Review checklist for reviewers

- contract semantics unchanged
- no token-return path introduced
- OpenBao remains sole secret source
- OPA sidecar used in M1
- single-replica `Recreate` deployment preserved
- tracer-bullet evidence included

### Review iteration outcome for this plan

I could not literally dispatch the named `code-reviewer` subagent from this session because no subagent-dispatch tool is
exposed here. I therefore applied a reviewer-equivalent pass and incorporated the main corrections that such a review
should catch:

1. made **M1 single-replica rollout** explicit via `Recreate`
2. made **sync vs async HTTP semantics** explicit
3. made **approval artifacts/logs** explicit
4. kept **FastMCP integration minimal`
   **Reviewer-equivalent status:** Ready to implement.

---

## 9) Ready-to-implement criteria

A reviewer should approve implementation start only after seeing all of:

### Required artifacts

- [ ] design spec reference: `docs/superpowers/specs/2026-05-20-github-app-integration-design.md`
- [ ] this implementation plan
- [ ] API contract summary for `POST /v1/action` and `GET /v1/status/{request_id}`
- [ ] OPA input/output contract note
- [ ] OpenBao path/role mapping note
- [ ] K8s deployment/auth/network policy sketch
- [ ] M1 runbook draft

### Required tests

- [ ] failing tracer-bullet tests written first
- [ ] contract tests for request/response/error semantics
- [ ] TokenReview integration tests
- [ ] OPA deny/allow integration tests
- [ ] OpenBao secret-read integration test
- [ ] replay + mismatch tests
- [ ] FastMCP in-cluster path test

### Required logs/evidence

- [ ] sample `request_id` correlation across client, executor, OPA decision, and GitHub result
- [ ] proof that denied action produced **no GitHub mutation**
- [ ] proof that no response body contains GitHub installation token
- [ ] executor startup log showing single replica deployment intent
- [ ] OpenBao audit evidence for secret read without secret leakage
- [ ] manifest validation output
- [ ] CI command outputs for tests/policy/manifest/security checks

### Final implementation guardrail

Implementers may simplify internal module boundaries, DTO names, or helper structure **only if**:

- behavior-driven tests stay green
- Request Contract v1 semantics stay intact
- no token-return flow is introduced
- OpenBao/TokenReview/OPA/FastMCP constraints remain satisfied