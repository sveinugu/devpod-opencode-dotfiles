# GitHub App Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the executor implementation with Request Contract v1, canonical persona formatting, and the explicit M1/M2 idempotency requirements.

**Architecture:** Keep the broker-first path thin: Python + FastAPI executor, FastMCP thin client, Kubernetes projected ServiceAccount token auth with TokenReview, OPA sidecar policy, and OpenBao-only private-key custody. M1 remains single-replica with in-memory idempotency explicitly documented as process-lifetime only; M2 upgrades to durable dedupe with a minimum 24-hour retention window.

**Tech Stack:** Python, FastAPI, pytest, FastMCP, Kubernetes TokenRequest/TokenReview, OPA, OpenBao

---

This overwrite removes the prior milestone-heavy/legacy-envelope plan and replaces it with a contract-first implementation plan that pins the external wire format, persona marker format, and idempotency behavior to testable assertions. It also narrows verification to concrete pytest and curl checks so implementers can prove compliance without relying on vague “works” claims.

## Changelog

- Replaced legacy response examples using `state`/`replayed` envelopes with Request Contract v1 response assertions from `docs/superpowers/specs/2026-05-20-github-app-integration-design.md` §8.1 so external responses are tested against the current contract shape.
- Added explicit acceptance criteria for contract shape, no-token-return behavior, persona formatting, M1 in-memory idempotency lifetime, and M2 durable 24-hour dedupe retention so each changed area has a verifiable pass/fail condition.
- Added pytest-like contract-test specifications for success/error envelopes, persona markers, M1 process-lifetime replay behavior, and M2 cross-replica retention behavior so execution can follow TDD from the outside in.
- Replaced vague verification language with exact test file paths, shell commands, expected HTTP status codes, and expected JSON fragments so verification is reproducible.
- Canonical spec file status: `docs/superpowers/specs/2026-05-20-github-app-integration-design.md` was found in this branch. The same path was not present on `main` when checked with `git show`, so this plan uses the branch-local §8.1 and §8.6 text as the current authoritative source; the user-provided fallback contract was **not** used.

## Locked constraints

- External broker/executor: Python + FastAPI.
- Agent-facing integration: FastMCP thin client only.
- AuthN/AuthZ: Kubernetes projected ServiceAccount tokens issued by TokenRequest, validated by TokenReview; OPA sidecar is authoritative for policy.
- Secret custody: OpenBao is the only allowed GitHub App private-key source.
- Security: no token-return flows.
- Idempotency: M1 is single-replica, in-memory only, and must document restart/loss-of-memory behavior; M2 must retain dedupe records for at least 24 hours and work across replicas.

## Implementation slices

### Slice 1: Lock the external contract and reject legacy envelopes

**Files:**
- Create: `tests/e2e/test_contract_envelope.py`
- Create: `tests/e2e/test_no_token_return.py`
- Modify: `services/github_app_executor/app/models.py`
- Modify: `services/github_app_executor/app/main.py`

- [ ] Write failing end-to-end tests that assert Request Contract v1 success and error envelopes for `POST /v1/action` and `GET /v1/status/{request_id}`.
- [ ] Verify the tests fail because the executor still emits any legacy `state`/`replayed` fields or wrong error-object fields.
- [ ] Implement the minimal response-model changes so external responses use only `request_id`, `status`, and exactly one of `result` or `error`.
- [ ] Add a regression test that fails if any external response contains GitHub tokens, JWTs, PEM material, or a token-return field.
- [ ] Re-run the contract tests and commit only after they pass.

### Slice 2: Pin canonical persona formatting

**Files:**
- Create: `tests/e2e/test_persona_format.py`
- Modify: `services/github_app_executor/app/github/client.py`
- Modify: `services/github_app_executor/app/formatting/persona.py`

- [ ] Write failing tests that assert every mutating comment/PR body starts with `[Persona: <persona>]` and ends with `— Posted by persona <persona> via GitHub App`.
- [ ] Verify the tests fail for both broker-first formatting and any local fallback formatter until the canonical strings match §8.6 exactly.
- [ ] Implement the minimum formatting change needed to make broker-first output canonical.
- [ ] Re-run the persona tests and keep them green before touching idempotency behavior.

### Slice 3: Document and enforce M1 in-memory idempotency semantics

**Files:**
- Create: `tests/integration/test_m1_idempotency_process_lifetime.py`
- Modify: `services/github_app_executor/app/idempotency/memory.py`
- Modify: `services/github_app_executor/app/main.py`
- Modify: `docs/runbooks/github-app-executor.md`

- [ ] Write failing tests for identical replay and payload-mismatch behavior using the same `request_id` and `idempotency_key`.
- [ ] Verify the identical-replay test fails before the in-memory store returns the prior canonical result.
- [ ] Implement the smallest in-memory dedupe change that satisfies the replay and mismatch tests.
- [ ] Add a smoke/integration test and runbook note showing that restarting the single M1 process clears dedupe memory and therefore ends the replay guarantee.
- [ ] Re-run the M1 tests and commit only after the process-lifetime limitation is explicitly documented.

### Slice 4: Design-gate M2 durable 24-hour dedupe retention

**Files:**
- Create: `tests/integration/test_m2_idempotency_retention.py`
- Modify: `services/github_app_executor/app/idempotency/store.py`
- Modify: `deploy/github-app-executor/base/deployment.yaml`
- Modify: `docs/runbooks/github-app-executor.md`

- [ ] Write a failing integration/manual test that submits the first mutating request on replica A and replays it on replica B within the 24-hour window.
- [ ] Verify the test fails until the durable dedupe store preserves the canonical result across replicas.
- [ ] Add a second failing test for same-key/different-payload rejection returning `DUPLICATE_PAYLOAD_MISMATCH` within the retention window.
- [ ] Implement the minimum durable-store behavior needed to satisfy both tests and document the retention configuration.
- [ ] Re-run the M2 tests and commit only after the retention window is explicitly visible in code/config/docs.

## Acceptance criteria

### Contract

1. **Assertion:** Every successful external `POST /v1/action` response has top-level keys exactly `request_id`, `status`, and `result`; `status` equals `"ok"`; no top-level `error`, `state`, `replayed`, `token`, or `internal_state` key is present.
2. **Assertion:** Every successful external `GET /v1/status/{request_id}` response has top-level keys exactly `request_id`, `status`, and `result`; `status` equals `"ok"`; no legacy top-level keys are present.
3. **Assertion:** Every external error response has top-level keys exactly `request_id`, `status`, and `error`; `status` equals `"error"`; `error` has keys exactly `code`, `message`, `retryable`, and `details`.
4. **Assertion:** No external response body contains GitHub installation tokens, App JWTs, PEM material, or any token-return field.
5. **Assertion:** Any non-external diagnostic example that includes internal fields nests them under one top-level `internal_state` object and labels every nested field with `(internal-only)`.

### Idempotency

6. **Assertion:** In M1, replaying the same mutating request with the same authenticated workload identity, `repo`, `action`, `request_id`, and `idempotency_key` during one live process returns the original canonical success result and does not create a second GitHub artifact.
7. **Assertion:** In M1, replaying the same `request_id` and `idempotency_key` with a semantically different payload returns `status="error"`, `error.code="DUPLICATE_PAYLOAD_MISMATCH"`, and creates no additional GitHub artifact.
8. **Assertion:** In M1, restarting the single replica clears the in-memory dedupe store, and the runbook states that replay protection is limited to the lifetime of that process.
9. **Assertion:** In M2, replaying the same mutating request on a different replica at any time before 24 hours have elapsed returns the original canonical result and creates no duplicate GitHub artifact.
10. **Assertion:** In M2, a same-key/different-payload replay submitted within 24 hours returns `DUPLICATE_PAYLOAD_MISMATCH` across replicas.

### Persona format

11. **Assertion:** Every mutating comment body and PR body emitted by the broker begins with `[Persona: <persona>]` on the first line.
12. **Assertion:** Every mutating comment body and PR body emitted by the broker ends with `— Posted by persona <persona> via GitHub App`.
13. **Assertion:** Broker-first formatting and the isolated single-user fallback formatter emit the same canonical persona marker strings for the same persona input.

### Verification matrix items

14. **Assertion:** `tests/e2e/test_contract_envelope.py`, `tests/e2e/test_no_token_return.py`, `tests/e2e/test_persona_format.py`, `tests/integration/test_m1_idempotency_process_lifetime.py`, and `tests/integration/test_m2_idempotency_retention.py` each pass with exit code `0` when their listed verification commands are run.
15. **Assertion:** `curl` verification for `/healthz` returns HTTP `200` with body `{"status":"ok"}`.
16. **Assertion:** `curl` verification for `/readyz` returns HTTP `200` with body containing `"status":"ok"`, `"token_review":"ok"`, `"opa":"ok"`, and `"openbao":"ok"`.

## Contract-test specifications

### `tests/e2e/test_contract_envelope.py`

```python
import re


def test_post_action_success_envelope(client, auth_headers):
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_contract_ok",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_contract_ok",
            "payload": {
                "pr_number": 42,
                "body": "Please tighten the policy wording.",
            },
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert set(body.keys()) == {"request_id", "status", "result"}
    assert body["request_id"] == "req_contract_ok"
    assert body["status"] == "ok"
    assert set(body["result"].keys()) == {"comment_id", "url"}
    assert isinstance(body["result"]["comment_id"], int)
    assert body["result"]["url"] == "https://github.com/octo-org/demo-repo/pull/42#issuecomment-9001"
    assert "state" not in body
    assert "replayed" not in body
    assert "error" not in body


def test_post_action_payload_mismatch_error_envelope(client, auth_headers):
    request = {
        "request_id": "req_contract_conflict",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_contract_conflict",
        "payload": {
            "pr_number": 42,
            "body": "Original body",
        },
    }
    client.post("/v1/action", headers=auth_headers, json=request)

    conflict = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            **request,
            "payload": {
                "pr_number": 42,
                "body": "Changed body",
            },
        },
    )

    assert conflict.status_code == 409
    body = conflict.json()
    assert set(body.keys()) == {"request_id", "status", "error"}
    assert body["request_id"] == "req_contract_conflict"
    assert body["status"] == "error"
    assert body["error"] == {
        "code": "DUPLICATE_PAYLOAD_MISMATCH",
        "message": "A prior request with this request_id and idempotency_key used a different payload.",
        "retryable": False,
        "details": {
            "mismatch_field": "payload.body",
        },
    }
    assert "result" not in body


def test_status_lookup_success_envelope(client, auth_headers):
    response = client.get("/v1/status/req_contract_ok", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"request_id", "status", "result"}
    assert body["request_id"] == "req_contract_ok"
    assert body["status"] == "ok"
    assert set(body["result"].keys()) >= {"comment_id", "url"}
```

### `tests/e2e/test_no_token_return.py`

```python
def test_external_responses_never_return_reusable_tokens(client, auth_headers):
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_no_token",
            "repo": "octo-org/demo-repo",
            "action": "read-pr",
            "persona": "reviewer",
            "payload": {"pr_number": 42},
        },
    )

    serialized = response.text.lower()
    assert "token" not in serialized
    assert "jwt" not in serialized
    assert "private_key" not in serialized
    assert "-----begin" not in serialized
```

### `tests/e2e/test_persona_format.py`

```python
import re


def test_comment_body_uses_canonical_persona_markers(format_comment_body):
    rendered = format_comment_body(
        persona="reviewer",
        body="Please tighten the policy wording in section 8.",
    )

    assert rendered.startswith("[Persona: reviewer]\n")
    assert rendered.endswith("\n\n— Posted by persona reviewer via GitHub App")
    assert rendered == (
        "[Persona: reviewer]\n"
        "Please tighten the policy wording in section 8.\n\n"
        "— Posted by persona reviewer via GitHub App"
    )


def test_pr_body_matches_canonical_persona_regex(format_pr_body):
    rendered = format_pr_body(
        persona="implementer",
        body="Implements the broker-first GitHub App path.",
    )

    assert re.fullmatch(
        r"\[Persona: implementer\]\n(?s:.*)\n\n— Posted by persona implementer via GitHub App",
        rendered,
    )
```

### `tests/integration/test_m1_idempotency_process_lifetime.py`

```python
import pytest


@pytest.mark.integration
def test_m1_replay_returns_canonical_result_during_single_process(m1_live_server, auth_headers):
    request = {
        "request_id": "req_m1_same_process",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m1_same_process",
        "payload": {
            "pr_number": 42,
            "body": "M1 replay smoke",
        },
    }

    first = m1_live_server.post("/v1/action", headers=auth_headers, json=request)
    replay = m1_live_server.post("/v1/action", headers=auth_headers, json=request)

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json() == first.json()
    assert m1_live_server.github_comment_count("req_m1_same_process") == 1


@pytest.mark.integration
def test_m1_restart_demonstrates_in_memory_lifetime_limit(m1_live_server, auth_headers):
    request = {
        "request_id": "req_m1_restart_limit",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m1_restart_limit",
        "payload": {
            "pr_number": 42,
            "body": "Process lifetime demo",
        },
    }

    first = m1_live_server.post("/v1/action", headers=auth_headers, json=request)
    m1_live_server.restart()
    after_restart = m1_live_server.post("/v1/action", headers=auth_headers, json=request)

    assert first.status_code == 201
    assert after_restart.status_code == 201
    assert after_restart.json()["status"] == "ok"
    assert after_restart.json()["result"]["comment_id"] != first.json()["result"]["comment_id"]
```

### `tests/integration/test_m2_idempotency_retention.py`

```python
import pytest


@pytest.mark.integration
def test_m2_replay_is_retained_for_24h_across_replicas(m2_cluster, auth_headers):
    request = {
        "request_id": "req_m2_cross_replica",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_cross_replica",
        "payload": {
            "pr_number": 42,
            "body": "Cross replica replay",
        },
    }

    first = m2_cluster.replica("a").post("/v1/action", headers=auth_headers, json=request, now="2026-05-20T10:00:00Z")
    replay = m2_cluster.replica("b").post("/v1/action", headers=auth_headers, json=request, now="2026-05-21T09:59:59Z")

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json() == first.json()
    assert m2_cluster.github_comment_count("req_m2_cross_replica") == 1


@pytest.mark.integration
def test_m2_payload_mismatch_is_rejected_within_24h(m2_cluster, auth_headers):
    original = {
        "request_id": "req_m2_payload_mismatch",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_m2_payload_mismatch",
        "payload": {
            "pr_number": 42,
            "body": "Original durable payload",
        },
    }
    changed = {
        **original,
        "payload": {
            "pr_number": 42,
            "body": "Changed durable payload",
        },
    }

    m2_cluster.replica("a").post("/v1/action", headers=auth_headers, json=original, now="2026-05-20T10:00:00Z")
    mismatch = m2_cluster.replica("b").post("/v1/action", headers=auth_headers, json=changed, now="2026-05-20T11:00:00Z")

    assert mismatch.status_code == 409
    assert mismatch.json()["status"] == "error"
    assert mismatch.json()["error"]["code"] == "DUPLICATE_PAYLOAD_MISMATCH"
    assert m2_cluster.github_comment_count("req_m2_payload_mismatch") == 1
```

### Internal-only labeling example for non-external diagnostics

```json
{
  "internal_state": {
    "dedupe_hit (internal-only)": true,
    "store_backend (internal-only)": "memory",
    "normalized_request_hash (internal-only)": "sha256:..."
  }
}
```

## Verification matrix

| Area | Test file path | Command | Expected output |
| --- | --- | --- | --- |
| Success contract envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_post_action_success_envelope -q` | Exit `0`; output contains `1 passed` |
| Error contract envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_post_action_payload_mismatch_error_envelope -q` | Exit `0`; output contains `1 passed` |
| Status envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_status_lookup_success_envelope -q` | Exit `0`; output contains `1 passed` |
| No token-return regression | `tests/e2e/test_no_token_return.py` | `pytest tests/e2e/test_no_token_return.py -q` | Exit `0`; output contains `1 passed` |
| Persona marker literals | `tests/e2e/test_persona_format.py` | `pytest tests/e2e/test_persona_format.py -q` | Exit `0`; output contains `2 passed` |
| M1 same-process replay | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_replay_returns_canonical_result_during_single_process -q -m integration` | Exit `0`; output contains `1 passed` |
| M1 restart limitation | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_restart_demonstrates_in_memory_lifetime_limit -q -m integration` | Exit `0`; output contains `1 passed` |
| M2 24h replay retention | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_m2_replay_is_retained_for_24h_across_replicas -q -m integration` | Exit `0`; output contains `1 passed` |
| M2 mismatch rejection | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_m2_payload_mismatch_is_rejected_within_24h -q -m integration` | Exit `0`; output contains `1 passed` |
| Health endpoint | `tests/e2e/test_health_readiness.py` | `curl -sS -o /tmp/healthz.json -w '%{http_code}\n' http://127.0.0.1:8000/healthz && jq -e '.status == "ok"' /tmp/healthz.json` | First command prints `200`; `jq` exits `0` and prints `true` |
| Readiness endpoint | `tests/e2e/test_health_readiness.py` | `curl -sS -o /tmp/readyz.json -w '%{http_code}\n' http://127.0.0.1:8000/readyz && jq -e '.status == "ok" and .token_review == "ok" and .opa == "ok" and .openbao == "ok"' /tmp/readyz.json` | First command prints `200`; `jq` exits `0` and prints `true` |
| Success curl smoke | `tests/e2e/test_contract_envelope.py` | `curl -sS -o /tmp/action-ok.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{"request_id":"req_contract_ok","repo":"octo-org/demo-repo","action":"comment-pr","persona":"reviewer","idempotency_key":"idem_contract_ok","payload":{"pr_number":42,"body":"Please tighten the policy wording."}}' http://127.0.0.1:8000/v1/action && jq -e '.request_id == "req_contract_ok" and .status == "ok" and (.result | has("comment_id")) and (.result | has("url"))' /tmp/action-ok.json` | First command prints `201`; `jq` exits `0` and prints `true` |
| Error curl smoke | `tests/e2e/test_contract_envelope.py` | `curl -sS -o /tmp/action-conflict.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{"request_id":"req_contract_conflict","repo":"octo-org/demo-repo","action":"comment-pr","persona":"reviewer","idempotency_key":"idem_contract_conflict","payload":{"pr_number":42,"body":"Changed body"}}' http://127.0.0.1:8000/v1/action && jq -e '.request_id == "req_contract_conflict" and .status == "error" and .error.code == "DUPLICATE_PAYLOAD_MISMATCH" and (.error.retryable == false)' /tmp/action-conflict.json` | First command prints `409`; `jq` exits `0` and prints `true` |

## Remaining open questions and next steps

- The spec path required by the request is present in this branch but absent on `main`; confirm whether `main` should be updated or whether this branch-local spec is now the canonical Request Contract v1 source.
- Confirm the exact projected ServiceAccount token claims available in the target cluster so TokenReview assertions can match real namespace/service-account fields.
- Choose the durable M2 dedupe backend (Redis vs. Postgres) before implementing cross-replica retention, but do not change the external envelope or persona-format assertions.
- Next step: implement Slice 1 first with TDD, then progress in order through Slices 2-4.
