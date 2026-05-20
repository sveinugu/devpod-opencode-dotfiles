# GitHub App Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the executor implementation with Request Contract v1, close the remaining broker/auth preconditions, and add enforceable security, persona, and idempotency gates.

**Architecture:** Keep the broker-first path thin: Python + FastAPI executor, FastMCP thin client, Kubernetes projected ServiceAccount token auth with TokenReview, OPA sidecar policy, and OpenBao-only private-key custody. M1 remains single-replica with in-memory idempotency explicitly documented as process-lifetime only; M2 upgrades to Redis-backed durable dedupe with a minimum 24-hour retention window.

**Tech Stack:** Python, FastAPI, pytest, FastMCP, Kubernetes TokenRequest/TokenReview, OPA, OpenBao, Redis

---

This revision keeps the Request Contract v1 wire shape fixed while closing the review-blocking preconditions, adding explicit prod security gates, and extending verification to negative-path TokenReview/OPA behavior, cross-identity idempotency, and broker-path persona output.

## Changelog

- Added Slice 0 as a required precondition-closure gate that records the chosen broker deployment boundary, exact TokenReview claim set, and the Redis-backed M2 dedupe decision before Slice 1 may begin.
- Added prod security-enforcement tasks and tests for `token_return.enabled` fail-fast behavior, OpenBao-only private-key custody, response no-token-return coverage, and mandatory broker/executor log scanning.
- Added negative-path auth/policy test specifications for invalid projected ServiceAccount tokens and OPA denies, including required no-mutation and audit-log assertions.
- Added cross-identity idempotency coverage so the same `request_id` + `idempotency_key` from a different authenticated workload identity does not collide with the original request scope.
- Added serializer/internal-state labeling coverage and a broker-path end-to-end persona-body assertion so internal diagnostics and GitHub-visible persona markers are both verified from the outside in.
- Added slice ownership to every verification-matrix row, including `tests/e2e/test_health_readiness.py`, and expanded the matrix with concrete commands and expected outputs for the new gates.
- Replaced legacy response examples using `state`/`replayed` envelopes with Request Contract v1 response assertions from `docs/superpowers/specs/2026-05-20-github-app-integration-design.md` §8.1 so external responses are tested against the current contract shape.
- Added explicit acceptance criteria for contract shape, precondition closure, security guardrails, persona formatting, TokenReview/OPA denial handling, M1 in-memory idempotency lifetime, cross-identity scope, and M2 durable 24-hour dedupe retention.

## Locked constraints

- External wire contract stays Request Contract v1 per `docs/superpowers/specs/2026-05-20-github-app-integration-design.md` §8.1; do not add top-level fields to external examples or responses.
- External broker/executor: Python + FastAPI.
- Agent-facing integration: FastMCP thin client only.
- AuthN/AuthZ: Kubernetes projected ServiceAccount tokens issued by TokenRequest, validated by TokenReview; OPA sidecar is authoritative for policy.
- Secret custody: OpenBao is the only allowed GitHub App private-key source in prod-like environments.
- Security: no token-return flows.
- Idempotency: M1 is single-replica, in-memory only, and must document restart/loss-of-memory behavior; M2 must retain dedupe records for at least 24 hours and work across replicas.

## Security enforcement gates

- Prod-like startup must fail closed if `token_return.enabled=true`.
- Prod-like startup must fail closed if the GitHub App private-key provider resolves to anything other than OpenBao or if a local PEM path is configured.
- External API responses, captured outbound GitHub requests, and broker/executor logs must never include reusable GitHub tokens, JWTs, PEM material, or token-return fields.
- Slice ownership: Slice 1 owns these enforcement checks; Slice 2 depends on them for auth/error-path coverage.

## Implementation slices

### Slice 0: Precondition closure (required)

**Files:**
- Modify: `docs/superpowers/plans/2026-05-20-github-app-integration-implementation-plan.md`
- Modify: `deploy/github-app-executor/base/deployment.yaml`
- Modify: `services/github_app_executor/app/auth/token_review.py`
- Modify: `services/github_app_executor/app/idempotency/store.py`
- Modify: `docs/runbooks/github-app-executor.md`

**Resolved decisions (must not drift without a spec+plan update):**

1. **Broker deployment boundary / stack:** `Broker-as-Pod with ingress`
   - **Rationale:** Matches the design’s in-cluster external broker boundary without introducing an extra identity layer or collapsing the trust boundary into the FastMCP client.
2. **Projected ServiceAccount token claim set used for TokenReview:**
   - `aud`: `["github-broker"]`
   - `iss`: `"https://kubernetes.default.svc.cluster.local"`
   - `sub`: `"system:serviceaccount:devpod-workspaces:opencode-agent"`
   - `kubernetes.io/serviceaccount/namespace`: `"devpod-workspaces"`
   - `kubernetes.io/serviceaccount/service-account.name`: `"opencode-agent"`
   - `kubernetes.io/serviceaccount/service-account.uid`: `"9f4f4b3f-7c6d-4c46-9c18-7d3b0a7e5b21"`
   - `kubernetes.io/pod/name`: `"workspace-7f9d8c6d4c-j8m2q"`
   - `kubernetes.io/pod/uid`: `"6b7c0e8d-2b2f-4b7e-b839-1d7f50633a72"`
   - TokenReview `status.user.username`: `"system:serviceaccount:devpod-workspaces:opencode-agent"`
   - TokenReview `status.user.uid`: `"9f4f4b3f-7c6d-4c46-9c18-7d3b0a7e5b21"`
   - TokenReview `status.user.groups`: `["system:serviceaccounts", "system:serviceaccounts:devpod-workspaces", "system:authenticated"]`
3. **M2 durable dedupe backend:** `Redis`
   - **Rationale:** Native TTL support makes the minimum 24-hour dedupe window explicit and cross-replica replay behavior simpler than a bespoke SQL retention job.

- [ ] Copy these exact decisions into the deployment/config/auth/idempotency files listed above before implementing later behavior changes.
- [ ] Stop and revise the design + plan together if any later slice requires a different broker boundary, claim set, or durable backend.
- [ ] Do not start Slice 1 until all three decision records above are preserved in code/config/docs touched by the implementation.

### Slice 1: Enforce prod security guardrails and external secrecy

**Files:**
- Create: `tests/integration/test_prod_security_guards.py`
- Modify: `tests/e2e/test_no_token_return.py`
- Modify: `services/github_app_executor/app/config.py`
- Modify: `services/github_app_executor/app/security/private_key_provider.py`
- Modify: `services/github_app_executor/app/main.py`
- Modify: `docs/runbooks/github-app-executor.md`

- [ ] Write a failing integration test that starts the executor with the prod profile and `token_return.enabled=true`, expecting startup to fail before serving requests.
- [ ] Verify that test fails for the right reason (startup succeeds or the wrong validation error is returned).
- [ ] Write failing integration tests that (a) prove the prod profile resolves the private-key provider to OpenBao and (b) fail startup if a local PEM path/provider is configured in prod.
- [ ] Extend `tests/e2e/test_no_token_return.py` so broker-path external responses and captured outbound GitHub request metadata prove that tokens/JWTs/PEM material never appear in the public API surface.
- [ ] Add a verification step that scans broker/executor logs for token, JWT, PEM, and `token_return` leaks and expects zero matches.
- [ ] Implement the minimum config-validation and provider-resolution changes needed to make the new security tests pass.
- [ ] Re-run the prod-security and no-token-return tests and commit only after the prod profile fails closed on forbidden token-return/local-PEM settings.

### Slice 2: Lock the external contract and auth/policy denials

**Files:**
- Create: `tests/e2e/test_contract_envelope.py`
- Create: `tests/integration/test_auth_policy_failures.py`
- Modify: `tests/e2e/test_health_readiness.py`
- Modify: `services/github_app_executor/app/models.py`
- Modify: `services/github_app_executor/app/main.py`
- Modify: `services/github_app_executor/app/auth/token_review.py`
- Modify: `services/github_app_executor/app/policy/opa.py`
- Modify: `services/github_app_executor/app/audit/log.py`

- [ ] Write failing end-to-end tests that assert Request Contract v1 success and error envelopes for `POST /v1/action` and `GET /v1/status/{request_id}`.
- [ ] Write a failing integration test where an invalid/expired/wrong-audience projected ServiceAccount token returns `INVALID_WORKLOAD_TOKEN`, performs no GitHub mutation, and writes an auth-failure audit event keyed by `request_id`.
- [ ] Write a failing integration test where OPA denies an otherwise well-formed mutating request, returns `POLICY_DENY`, performs no GitHub mutation, and writes a deny audit event including the validated workload identity.
- [ ] Verify all new contract/auth/policy tests fail for the expected missing behavior rather than fixture mistakes.
- [ ] Implement the smallest response-model, TokenReview, OPA, and audit-log changes needed to satisfy the contract and denial tests.
- [ ] Re-run the contract tests, auth/policy failure tests, and readiness smoke tests; commit only after negative-path tests prove no mutation and auditable deny behavior.

### Slice 3: Pin canonical persona formatting and internal-state labeling

**Files:**
- Modify: `tests/e2e/test_persona_format.py`
- Create: `tests/integration/test_internal_state_labeling.py`
- Modify: `services/github_app_executor/app/github/client.py`
- Modify: `services/github_app_executor/app/formatting/persona.py`
- Modify: `services/github_app_executor/app/serialization/responses.py`

- [ ] Write failing tests that assert every mutating comment/PR body starts with `[Persona: <persona>]` and ends with `— Posted by persona <persona> via GitHub App`.
- [ ] Add a broker-path end-to-end test that inspects the final outbound GitHub request body, not just formatter helpers, and fails unless the canonical persona markers are present in the emitted payload.
- [ ] Write a failing serializer/documentation test that any internal-only diagnostic fields appear only under `internal_state`, and every nested key is annotated with `(internal-only)`.
- [ ] Verify the persona and serializer tests fail until the canonical strings and internal-state nesting match the design.
- [ ] Implement the minimum formatting and serialization changes needed to make the broker-path and internal-state tests pass.
- [ ] Re-run the persona/internal-state tests and commit only after the broker-path output and serializer match §8.6 and the internal-only labeling rule.

### Slice 4: Document and enforce M1 in-memory idempotency semantics

**Files:**
- Modify: `tests/integration/test_m1_idempotency_process_lifetime.py`
- Modify: `services/github_app_executor/app/idempotency/memory.py`
- Modify: `services/github_app_executor/app/main.py`
- Modify: `services/github_app_executor/app/audit/log.py`
- Modify: `docs/runbooks/github-app-executor.md`

- [ ] Write failing tests for same-identity replay and payload-mismatch behavior using the same `request_id` and `idempotency_key`.
- [ ] Write a failing cross-identity test where the same `request_id` + `idempotency_key` is sent by a different authenticated workload identity; assert no dedupe collision, and either a new artifact is created for the authorized second caller or the request is rejected by policy before mutation.
- [ ] Add audit assertions that M1 first-seen, replay-hit, payload-mismatch, and cross-identity events all record the validated workload identity together with `request_id` and `idempotency_key`.
- [ ] Verify the idempotency tests fail until the dedupe key includes authenticated workload identity and the audit log captures that identity.
- [ ] Implement the smallest in-memory dedupe and audit-log change that satisfies replay, mismatch, and cross-identity scope tests.
- [ ] Add a smoke/integration test and runbook note showing that restarting the single M1 process clears dedupe memory and therefore ends the replay guarantee.
- [ ] Re-run the M1 tests and commit only after the process-lifetime limitation is explicitly documented.

### Slice 5: Implement M2 Redis-backed 24-hour dedupe retention

**Files:**
- Modify: `tests/integration/test_m2_idempotency_retention.py`
- Modify: `services/github_app_executor/app/idempotency/store.py`
- Modify: `deploy/github-app-executor/base/deployment.yaml`
- Modify: `docs/runbooks/github-app-executor.md`

- [ ] Write a failing integration/manual test that submits the first mutating request on replica A and replays it on replica B within the 24-hour window.
- [ ] Verify that test fails until the Redis-backed dedupe store preserves the canonical result across replicas.
- [ ] Add a second failing test for same-key/different-payload rejection returning `DUPLICATE_PAYLOAD_MISMATCH` within the retention window.
- [ ] Add audit assertions that cross-replica first-seen, replay-hit, and payload-mismatch events are keyed by `request_id` + `idempotency_key` + validated workload identity.
- [ ] Implement the minimum Redis-backed durable-store behavior needed to satisfy both tests and document the 24-hour TTL configuration.
- [ ] Re-run the M2 tests and commit only after the Redis TTL is explicitly visible in code/config/docs.

## Acceptance criteria

### Preconditions

1. **Assertion:** Slice 0 explicitly records the chosen broker stack as `Broker-as-Pod with ingress`, the exact projected ServiceAccount token claim set listed above, and the `Redis` M2 dedupe backend choice.
2. **Assertion:** The plan text states that Slice 1 cannot begin until those three Slice 0 decisions are preserved in the implementation files listed for Slice 0.

### Security enforcement

3. **Assertion:** Starting the executor in a prod-like profile with `token_return.enabled=true` exits non-zero before serving requests and emits a config-validation message containing `token_return.enabled must be false in prod`.
4. **Assertion:** Starting the executor in a prod-like profile resolves the private-key provider to OpenBao; configuring a local PEM path/provider in prod exits non-zero before serving requests and emits a validation message containing `prod profile requires OpenBao private key provider`.
5. **Assertion:** No external response body, captured outbound GitHub request body/metadata, or broker/executor log line contains GitHub installation tokens, App JWTs, PEM material, or a token-return field.

### Contract and auth/policy denials

6. **Assertion:** Every successful external `POST /v1/action` response has top-level keys exactly `request_id`, `status`, and `result`; `status` equals `"ok"`; no top-level `error`, `state`, `replayed`, `token`, or `internal_state` key is present.
7. **Assertion:** Every successful external `GET /v1/status/{request_id}` response has top-level keys exactly `request_id`, `status`, and `result`; `status` equals `"ok"`; no legacy top-level keys are present.
8. **Assertion:** Every external error response has top-level keys exactly `request_id`, `status`, and `error`; `status` equals `"error"`; `error` has keys exactly `code`, `message`, `retryable`, and `details`.
9. **Assertion:** An invalid/expired/wrong-audience projected ServiceAccount token returns `status="error"`, `error.code="INVALID_WORKLOAD_TOKEN"`, produces no GitHub mutation, and writes an audit event containing the `request_id`, the failed TokenReview audience check, and an auth-deny decision.
10. **Assertion:** An OPA-denied mutating request returns `status="error"`, `error.code="POLICY_DENY"`, produces no GitHub mutation, and writes an audit event containing `request_id`, validated workload identity, deny decision, and policy reason.

### Internal-state labeling

11. **Assertion:** Any non-external diagnostic serializer output that includes internal fields nests them under one top-level `internal_state` object and labels every nested key with `(internal-only)`.

### Persona format

12. **Assertion:** Every mutating comment body and PR body emitted by the broker begins with `[Persona: <persona>]` on the first line.
13. **Assertion:** Every mutating comment body and PR body emitted by the broker ends with `— Posted by persona <persona> via GitHub App`.
14. **Assertion:** A broker-path end-to-end test that captures the final outbound GitHub request body proves the emitted payload, not just formatter helpers, contains the canonical persona markers.

### Idempotency

15. **Assertion:** In M1, replaying the same mutating request with the same authenticated workload identity, `repo`, `action`, `request_id`, and `idempotency_key` during one live process returns the original canonical success result and does not create a second GitHub artifact.
16. **Assertion:** In M1, replaying the same `request_id` and `idempotency_key` with a semantically different payload returns `status="error"`, `error.code="DUPLICATE_PAYLOAD_MISMATCH"`, and creates no additional GitHub artifact.
17. **Assertion:** In M1, sending the same `request_id` and `idempotency_key` from a different authenticated workload identity does not collide with the original dedupe record; an authorized second identity produces a distinct artifact, while an unauthorized second identity is rejected by policy before mutation.
18. **Assertion:** In M1, restarting the single replica clears the in-memory dedupe store, and the runbook states that replay protection is limited to the lifetime of that process.
19. **Assertion:** In M2, replaying the same mutating request on a different replica at any time before 24 hours have elapsed returns the original canonical result and creates no duplicate GitHub artifact.
20. **Assertion:** In M2, a same-key/different-payload replay submitted within 24 hours returns `DUPLICATE_PAYLOAD_MISMATCH` across replicas.
21. **Assertion:** M1 and M2 audit logs record first-seen, replay-hit, payload-mismatch, and cross-identity events keyed by `request_id` + `idempotency_key` + validated workload identity.

### Verification matrix items

22. **Assertion:** Every verification-matrix row below names the slice that introduces/owns the referenced test file path.
23. **Assertion:** `tests/integration/test_prod_security_guards.py`, `tests/e2e/test_no_token_return.py`, `tests/e2e/test_contract_envelope.py`, `tests/integration/test_auth_policy_failures.py`, `tests/e2e/test_health_readiness.py`, `tests/e2e/test_persona_format.py`, `tests/integration/test_internal_state_labeling.py`, `tests/integration/test_m1_idempotency_process_lifetime.py`, and `tests/integration/test_m2_idempotency_retention.py` each pass with exit code `0` when their listed verification commands are run.

## Contract-test specifications

### `tests/integration/test_prod_security_guards.py`

```python
import pytest


@pytest.mark.integration
def test_prod_startup_rejects_token_return_enabled(start_executor):
    result = start_executor(
        profile="prod",
        overrides={"token_return": {"enabled": True}},
    )

    assert result.exit_code != 0
    assert "token_return.enabled must be false in prod" in result.stderr
    assert "Application startup complete" not in result.stdout + result.stderr


@pytest.mark.integration
def test_prod_profile_resolves_private_key_provider_to_openbao(start_executor):
    result = start_executor(
        profile="prod",
        overrides={
            "github_app": {
                "private_key_provider": "openbao",
                "openbao_mount": "kv/github-app",
                "openbao_key": "private-key",
            }
        },
    )

    assert result.exit_code == 0
    assert "private_key_provider=openbao" in result.stdout


@pytest.mark.integration
def test_prod_profile_rejects_local_pem_private_key_provider(start_executor, tmp_path):
    pem = tmp_path / "github-app.pem"
    pem.write_text("-----BEGIN PRIVATE KEY-----\nnot-a-real-key\n-----END PRIVATE KEY-----\n")

    result = start_executor(
        profile="prod",
        overrides={
            "github_app": {
                "private_key_provider": "local-pem",
                "private_key_path": str(pem),
            }
        },
    )

    assert result.exit_code != 0
    assert "prod profile requires OpenBao private key provider" in result.stderr
    assert str(pem) in result.stderr
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


def test_broker_path_public_api_and_outbound_metadata_exclude_tokens(github_recorder, broker_client, auth_headers):
    response = broker_client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_no_token_broker_path",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_no_token_broker_path",
            "payload": {"pr_number": 42, "body": "Token scrub check"},
        },
    )

    outbound = github_recorder.last_request("/repos/octo-org/demo-repo/issues/42/comments")
    assert response.status_code == 201
    assert "token" not in response.text.lower()
    assert "authorization" not in outbound["json"]
    assert "jwt" not in str(outbound).lower()
    assert "-----begin" not in str(outbound).lower()
```

### `tests/e2e/test_contract_envelope.py`

```python
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
    assert "state" not in body
    assert "replayed" not in body
    assert "error" not in body
    assert "internal_state" not in body


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
    assert body["status"] == "error"
    assert body["error"]["code"] == "DUPLICATE_PAYLOAD_MISMATCH"
    assert set(body["error"].keys()) == {"code", "message", "retryable", "details"}


def test_status_lookup_success_envelope(client, auth_headers):
    response = client.get("/v1/status/req_contract_ok", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"request_id", "status", "result"}
    assert body["request_id"] == "req_contract_ok"
    assert body["status"] == "ok"
```

### `tests/integration/test_auth_policy_failures.py`

```python
import pytest


@pytest.mark.integration
def test_invalid_workload_token_returns_invalid_workload_token_and_no_mutation(
    broker_server,
    github_recorder,
    expired_auth_headers,
):
    response = broker_server.post(
        "/v1/action",
        headers=expired_auth_headers,
        json={
            "request_id": "req_invalid_workload_token",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_invalid_workload_token",
            "payload": {"pr_number": 42, "body": "Should never post"},
        },
    )

    assert response.status_code == 401
    body = response.json()
    assert body["status"] == "error"
    assert body["error"]["code"] == "INVALID_WORKLOAD_TOKEN"
    assert github_recorder.count("req_invalid_workload_token") == 0

    audit = broker_server.audit_event("req_invalid_workload_token")
    assert audit["decision"] == "authn_deny"
    assert audit["token_review"]["audiences"] == ["github-broker"]
    assert audit["validated_workload_identity"] is None


@pytest.mark.integration
def test_opa_deny_returns_policy_deny_and_no_mutation(
    broker_server,
    github_recorder,
    auth_headers,
):
    response = broker_server.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_policy_deny",
            "repo": "octo-org/forbidden-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_policy_deny",
            "payload": {"pr_number": 42, "body": "Should be denied"},
        },
    )

    assert response.status_code == 403
    body = response.json()
    assert body["status"] == "error"
    assert body["error"]["code"] == "POLICY_DENY"
    assert github_recorder.count("req_policy_deny") == 0

    audit = broker_server.audit_event("req_policy_deny")
    assert audit["decision"] == "policy_deny"
    assert audit["validated_workload_identity"] == "system:serviceaccount:devpod-workspaces:opencode-agent"
    assert audit["policy_reason"] == "repo_not_allowed"
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


def test_pr_body_matches_canonical_persona_regex(format_pr_body):
    rendered = format_pr_body(
        persona="implementer",
        body="Implements the broker-first GitHub App path.",
    )

    assert re.fullmatch(
        r"\[Persona: implementer\]\n(?s:.*)\n\n— Posted by persona implementer via GitHub App",
        rendered,
    )


def test_broker_path_outbound_comment_body_contains_canonical_persona_markers(
    broker_client,
    auth_headers,
    github_recorder,
):
    response = broker_client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_persona_broker_path",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_persona_broker_path",
            "payload": {"pr_number": 42, "body": "Broker path persona check"},
        },
    )

    outbound = github_recorder.last_request("/repos/octo-org/demo-repo/issues/42/comments")
    assert response.status_code == 201
    assert outbound["json"]["body"].startswith("[Persona: reviewer]\n")
    assert outbound["json"]["body"].endswith(
        "\n\n— Posted by persona reviewer via GitHub App"
    )
```

### `tests/integration/test_internal_state_labeling.py`

```python
import pytest


@pytest.mark.integration
def test_diagnostic_serializer_nests_internal_fields_under_internal_state(response_serializer):
    serialized = response_serializer.render_diagnostic(
        request_id="req_internal_state",
        result={"comment_id": 9001, "url": "https://github.com/octo-org/demo-repo/pull/42#issuecomment-9001"},
        internal_state={
            "dedupe_hit": True,
            "store_backend": "memory",
            "normalized_request_hash": "sha256:abc123",
        },
    )

    assert set(serialized.keys()) == {"request_id", "status", "result", "internal_state"}
    assert serialized["internal_state"] == {
        "dedupe_hit (internal-only)": True,
        "store_backend (internal-only)": "memory",
        "normalized_request_hash (internal-only)": "sha256:abc123",
    }
    assert "dedupe_hit" not in serialized["result"]
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
    audit = m1_live_server.audit_events("req_m1_same_process")
    assert [event["decision"] for event in audit] == ["first_seen", "replay_hit"]


@pytest.mark.integration
def test_m1_same_request_id_and_idempotency_key_do_not_collide_across_workload_identities(
    m1_live_server,
    auth_headers_for,
):
    request = {
        "request_id": "req_identity_scope",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": "idem_identity_scope",
        "payload": {
            "pr_number": 42,
            "body": "Identity scope check",
        },
    }

    first = m1_live_server.post(
        "/v1/action",
        headers=auth_headers_for("system:serviceaccount:devpod-workspaces:opencode-agent-a"),
        json=request,
    )
    second = m1_live_server.post(
        "/v1/action",
        headers=auth_headers_for("system:serviceaccount:devpod-workspaces:opencode-agent-b"),
        json=request,
    )

    assert first.status_code == 201
    assert second.status_code in {201, 403}
    if second.status_code == 201:
        assert second.json()["result"]["comment_id"] != first.json()["result"]["comment_id"]
        assert m1_live_server.github_comment_count("req_identity_scope") == 2
    else:
        assert second.json()["error"]["code"] == "POLICY_DENY"
        assert m1_live_server.github_comment_count("req_identity_scope") == 1

    identities = {
        event["validated_workload_identity"]
        for event in m1_live_server.audit_events("req_identity_scope")
    }
    assert identities >= {
        "system:serviceaccount:devpod-workspaces:opencode-agent-a",
        "system:serviceaccount:devpod-workspaces:opencode-agent-b",
    }


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

    first = m2_cluster.replica("a").post(
        "/v1/action",
        headers=auth_headers,
        json=request,
        now="2026-05-20T10:00:00Z",
    )
    replay = m2_cluster.replica("b").post(
        "/v1/action",
        headers=auth_headers,
        json=request,
        now="2026-05-21T09:59:59Z",
    )

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json() == first.json()
    assert m2_cluster.github_comment_count("req_m2_cross_replica") == 1

    audit = m2_cluster.audit_events("req_m2_cross_replica")
    assert [event["decision"] for event in audit] == ["first_seen", "replay_hit"]


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

    m2_cluster.replica("a").post(
        "/v1/action",
        headers=auth_headers,
        json=original,
        now="2026-05-20T10:00:00Z",
    )
    mismatch = m2_cluster.replica("b").post(
        "/v1/action",
        headers=auth_headers,
        json=changed,
        now="2026-05-20T11:00:00Z",
    )

    assert mismatch.status_code == 409
    assert mismatch.json()["status"] == "error"
    assert mismatch.json()["error"]["code"] == "DUPLICATE_PAYLOAD_MISMATCH"
    assert m2_cluster.github_comment_count("req_m2_payload_mismatch") == 1

    audit = m2_cluster.audit_event("req_m2_payload_mismatch", decision="payload_mismatch")
    assert audit["validated_workload_identity"] == "system:serviceaccount:devpod-workspaces:opencode-agent"
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

| Owner slice | Area | Test file path | Command | Expected output |
| --- | --- | --- | --- | --- |
| Slice 1 | Prod token-return config guard | `tests/integration/test_prod_security_guards.py` | `pytest tests/integration/test_prod_security_guards.py::test_prod_startup_rejects_token_return_enabled -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 1 | Prod OpenBao provider resolution | `tests/integration/test_prod_security_guards.py` | `pytest tests/integration/test_prod_security_guards.py::test_prod_profile_resolves_private_key_provider_to_openbao -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 1 | Prod local-PEM rejection | `tests/integration/test_prod_security_guards.py` | `pytest tests/integration/test_prod_security_guards.py::test_prod_profile_rejects_local_pem_private_key_provider -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 1 | No-token-return regression | `tests/e2e/test_no_token_return.py` | `pytest tests/e2e/test_no_token_return.py -q` | Exit `0`; output contains `2 passed` |
| Slice 1 | Broker/executor log leak scan | `tests/e2e/test_no_token_return.py` | `! rg -n -i '(jwt|-----BEGIN [A-Z ]+PRIVATE KEY-----|token_return|installation[_-]?token|x-access-token)' var/log/github-app-executor/*.log` | Exit `0`; no output |
| Slice 2 | Success contract envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_post_action_success_envelope -q` | Exit `0`; output contains `1 passed` |
| Slice 2 | Error contract envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_post_action_payload_mismatch_error_envelope -q` | Exit `0`; output contains `1 passed` |
| Slice 2 | Status envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_status_lookup_success_envelope -q` | Exit `0`; output contains `1 passed` |
| Slice 2 | Invalid workload token deny/no mutation | `tests/integration/test_auth_policy_failures.py` | `pytest tests/integration/test_auth_policy_failures.py::test_invalid_workload_token_returns_invalid_workload_token_and_no_mutation -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 2 | OPA deny/no mutation | `tests/integration/test_auth_policy_failures.py` | `pytest tests/integration/test_auth_policy_failures.py::test_opa_deny_returns_policy_deny_and_no_mutation -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 2 | Health endpoint | `tests/e2e/test_health_readiness.py` | `curl -sS -o /tmp/healthz.json -w '%{http_code}\n' http://127.0.0.1:8000/healthz && jq -e '.status == "ok"' /tmp/healthz.json` | First command prints `200`; `jq` exits `0` and prints `true` |
| Slice 2 | Readiness endpoint | `tests/e2e/test_health_readiness.py` | `curl -sS -o /tmp/readyz.json -w '%{http_code}\n' http://127.0.0.1:8000/readyz && jq -e '.status == "ok" and .token_review == "ok" and .opa == "ok" and .openbao == "ok"' /tmp/readyz.json` | First command prints `200`; `jq` exits `0` and prints `true` |
| Slice 2 | Success curl smoke | `tests/e2e/test_contract_envelope.py` | `curl -sS -o /tmp/action-ok.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{"request_id":"req_contract_ok","repo":"octo-org/demo-repo","action":"comment-pr","persona":"reviewer","idempotency_key":"idem_contract_ok","payload":{"pr_number":42,"body":"Please tighten the policy wording."}}' http://127.0.0.1:8000/v1/action && jq -e '.request_id == "req_contract_ok" and .status == "ok" and (.result | has("comment_id")) and (.result | has("url"))' /tmp/action-ok.json` | First command prints `201`; `jq` exits `0` and prints `true` |
| Slice 2 | Error curl smoke | `tests/e2e/test_contract_envelope.py` | `curl -sS -o /tmp/action-conflict.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{"request_id":"req_contract_conflict","repo":"octo-org/demo-repo","action":"comment-pr","persona":"reviewer","idempotency_key":"idem_contract_conflict","payload":{"pr_number":42,"body":"Changed body"}}' http://127.0.0.1:8000/v1/action && jq -e '.request_id == "req_contract_conflict" and .status == "error" and .error.code == "DUPLICATE_PAYLOAD_MISMATCH" and (.error.retryable == false)' /tmp/action-conflict.json` | First command prints `409`; `jq` exits `0` and prints `true` |
| Slice 3 | Persona marker tests | `tests/e2e/test_persona_format.py` | `pytest tests/e2e/test_persona_format.py -q` | Exit `0`; output contains `3 passed` |
| Slice 3 | Internal-state labeling | `tests/integration/test_internal_state_labeling.py` | `pytest tests/integration/test_internal_state_labeling.py -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | M1 same-process replay | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_replay_returns_canonical_result_during_single_process -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | M1 cross-identity scope | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_same_request_id_and_idempotency_key_do_not_collide_across_workload_identities -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | M1 restart limitation | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_restart_demonstrates_in_memory_lifetime_limit -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 5 | M2 24h replay retention | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_m2_replay_is_retained_for_24h_across_replicas -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 5 | M2 mismatch rejection | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_m2_payload_mismatch_is_rejected_within_24h -q -m integration` | Exit `0`; output contains `1 passed` |

## Remaining open questions and next steps

- No unresolved planning preconditions remain in this revision; if infra or security owners need a different broker boundary, TokenReview claim set, or durable dedupe backend, revise the design and this plan together before implementation.
- Next step: implement Slice 0 acknowledgements first, then execute Slices 1-5 in order with TDD and per-slice verification.
