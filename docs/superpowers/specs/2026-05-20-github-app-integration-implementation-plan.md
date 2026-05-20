GitHub App Integration — Implementation Plan

Date: 2026-05-20

Project: GitHub App Integration Implementation Plan

Assumptions used:
- The in-cluster broker is the Python + FastAPI executor.
- M1 keeps single replica + in-memory idempotency/state.
- No token-return flows are allowed in M1-M4.
- OpenBao is the only secret source; CSI fallback is only for isolated single-user mode.
- Implementers may adjust internal interfaces if behavior-driven tests show a simpler shape, but must preserve Request Contract v1 semantics.

# GitHub App Integration Implementation Plan

## 1) High-level workstreams and milestones

| Milestone | Scope | Acceptance criteria | Deliverables | Owners |
|---|---|---|---|---|
| **M1 — Tracer-bullet executor** | In-cluster executor prototype with TokenReview authN, OPA sidecar authZ, OpenBao secret read, direct GitHub API execution, FastMCP thin client, single replica, in-memory idempotency | End-to-end tracer bullet passes: in-pod client → executor → TokenReview → OPA → OpenBao → GitHub stub/live sandbox; no token returned; denied repo/action produces no mutation | FastAPI executor, OPA sidecar policy bundle, K8s manifests, FastMCP client wrapper, e2e tests, CI, runbook | Backend, Platform, Security, QA |
| **M2 — Durable idempotency + HA** | Replace in-memory request/idempotency state with Redis/Postgres; support safe multi-replica behavior | Duplicate mutating requests across replicas return canonical prior result; replay mismatch rejected; no duplicate GitHub artifacts | Durable state store, migration docs, HA manifests, replay tests | Backend, Platform |
| **M3 — Operational hardening** | mTLS/service-mesh fit, audit exports, alerts, OpenBao rotation automation, stricter policy/admin tooling | Alerting fires on deny spikes/replay anomalies; rotation run tested; audit trail complete | Alert rules, dashboards, rotation docs/jobs, security review record | SRE, Security, Platform |
| **M4 — Expansion + rollout** | Additional actions, broader repo onboarding, production rollout playbook | New action types added without breaking v1 contract; staged rollout/rollback exercised | Expanded contract, rollout checklist, onboarding docs | Backend, Product/Infra, SRE |

**Pragmatic recommendation:** treat **M1 as the critical walking skeleton**. Do not generalize beyond one thin vertical slice until it works end-to-end.

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
