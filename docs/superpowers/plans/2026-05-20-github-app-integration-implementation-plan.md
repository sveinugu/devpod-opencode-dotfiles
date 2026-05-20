# GitHub App Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the executor implementation with Request Contract v1, close the remaining broker/auth preconditions, and add enforceable security, persona, and idempotency gates.

**Architecture:** Keep the broker-first path thin: Python + FastAPI executor, FastMCP thin client, Kubernetes projected ServiceAccount token auth with TokenReview, broker-issued authorization decisions that invoke an OPA sidecar as the policy evaluation engine, and OpenBao-only private-key custody. M1 remains single-replica with in-memory idempotency explicitly documented as process-lifetime only; M2 upgrades to Redis-backed durable dedupe with a minimum 24-hour retention window.

**Tech Stack:** Python, FastAPI, pytest, FastMCP, Kubernetes TokenRequest/TokenReview, OPA, OpenBao, Redis

---

This revision keeps the Request Contract v1 wire shape fixed while closing the review-blocking preconditions, adding explicit prod security gates, and extending verification to negative-path TokenReview/OPA behavior, cross-identity idempotency, and broker-path persona output.

## Scope declaration

Broker-first only; local-CSI fallback deferred to follow-up plan.

- This plan covers only the broker-mediated GitHub App integration path.
- Local-CSI fallback flow is out of scope for this implementation and is deferred - track in follow-up plan.

## Changelog

- Added a scope declaration that makes this plan broker-first only and defers local-CSI fallback to a follow-up plan.
- Added Slice X for prod transport/replay/rate-limit/anomaly hardening with explicit failing-test-first tasks, acceptance criteria, and verification rows.
- Added Slice 0 as a required precondition-closure gate that records the chosen broker deployment boundary, stable-vs-dynamic TokenReview claims, and the Redis-backed M2 dedupe decision before Slice 1 may begin.
- Added prod security-enforcement tasks and tests for `token_return.enabled` fail-fast behavior, OpenBao-only private-key custody, response no-token-return coverage, and mandatory broker/executor log scanning.
- Added negative-path auth/policy test specifications for invalid projected ServiceAccount tokens and OPA denies, including required no-mutation and audit-log assertions.
- Added cross-identity idempotency coverage so the same `request_id` + `idempotency_key` from a different authenticated workload identity does not collide with the original request scope.
- Added serializer/internal-state labeling coverage and a broker-path end-to-end persona-body assertion so internal diagnostics and GitHub-visible persona markers are both verified from the outside in.
- Added slice ownership to every verification-matrix row, including `tests/e2e/test_health_readiness.py`, and expanded the matrix with concrete commands and expected outputs for the new gates.
- Replaced legacy response examples using `state`/`replayed` envelopes with Request Contract v1 response assertions from `docs/superpowers/specs/2026-05-20-github-app-integration-design.md` §8.1 so external responses are tested against the current contract shape.
- Added explicit acceptance criteria for contract shape, precondition closure, security guardrails, persona formatting, TokenReview/OPA denial handling, M1 in-memory idempotency lifetime, cross-identity scope, and M2 durable 24-hour dedupe retention.
- Updated the no-token-return spec to use neutral request IDs, forbid top-level token-style response keys, and scan with tightened secret-detection regex literals for PEM headers, `eyJ...` JWTs, and `gh[psoau]_...` GitHub tokens instead of broad dot-segment matching.
- Reworded policy authority so the broker is the authoritative PDP, with OPA invoked only as the policy evaluation engine that supplies the policy reason.
- Split the Slice 0 TokenReview claim contract into stable exact claims and dynamic pod claims validated by presence/shape rather than literal pod values.
- Updated the verification-matrix log-scan command to use tightened ripgrep secret-detection patterns and explicitly filter the allowed prod guardrail message `token_return.enabled must be false in prod`.
- Added a Slice 1 broker-first egress-bypass gate that proves workspace pods cannot call `api.github.com` directly when broker-first mode is enabled.

## Locked constraints

- External wire contract stays Request Contract v1 per `docs/superpowers/specs/2026-05-20-github-app-integration-design.md` §8.1; do not add top-level fields to external examples or responses.
- External broker/executor: Python + FastAPI.
- Agent-facing integration: FastMCP thin client only.
- AuthN/AuthZ: Kubernetes projected ServiceAccount tokens issued by TokenRequest, validated by TokenReview; the broker is the authoritative PDP and invokes the OPA sidecar as its policy evaluation engine.
- Secret custody: OpenBao is the only allowed GitHub App private-key source in prod-like environments.
- Security: no token-return flows.
- Idempotency: M1 is single-replica, in-memory only, and must document restart/loss-of-memory behavior; M2 must retain dedupe records for at least 24 hours and work across replicas.

## Security enforcement gates

- Prod-like startup must fail closed if `token_return.enabled=true`.
- Prod-like startup must fail closed if the GitHub App private-key provider resolves to anything other than OpenBao or if a local PEM path is configured.
- External API responses must not expose top-level keys named `token`, `access_token`, `installation_token`, or `jwt`, and external responses, captured outbound GitHub requests, and broker/executor logs must never include PEM private-key headers, JWTs matching the `eyJ...` heuristic, or GitHub token prefixes matching `gh[psoau]_...`.
- When broker-first mode is enabled, workspace pods must be unable to call GitHub APIs directly; only the broker may hold GitHub egress.
- Slice ownership: Slice 1 owns these enforcement checks; Slice 2 depends on them for auth/error-path coverage.

## Implementation slices

### Slice 0: Precondition closure (required)

**Files:**
- Modify: `docs/superpowers/plans/2026-05-20-github-app-integration-implementation-plan.md`
- Create: `docs/deployment/auth.md` (planned artifact only)
- Create: `docs/deployment/broker_stack.md` (planned artifact only)
- Create: `docs/deployment/idempotency.md` (planned artifact only)
- Modify: `deploy/github-app-executor/base/deployment.yaml`
- Modify: `services/github_app_executor/app/auth/token_review.py`
- Modify: `services/github_app_executor/app/idempotency/store.py`
- Modify: `docs/runbooks/github-app-executor.md`

**Resolved decisions (must not drift without a spec+plan update):**

1. **Broker deployment boundary / stack:** `Broker-as-Pod with ingress`
   - **Rationale:** Matches the design’s in-cluster external broker boundary without introducing an extra identity layer or collapsing the trust boundary into the FastMCP client.
2. **Projected ServiceAccount token claim set used for TokenReview:**
   - **Stable exact claims (assert literally):**
     - `aud`: `["github-broker"]`
     - `iss`: `"https://kubernetes.default.svc.cluster.local"`
     - `kubernetes.io/serviceaccount/namespace`: `"devpod-workspaces"`
     - `kubernetes.io/serviceaccount/service-account.name`: `"opencode-agent"`
   - **Dynamic claims (assert presence/shape only):**
     - `kubernetes.io/pod/name`: present and matches `^workspace-[a-z0-9-]+$`
     - `kubernetes.io/pod/uid`: present and matches UUID shape `^[0-9a-f-]{36}$`
   - **Derived identity checks:**
     - TokenReview `status.user.username`: `"system:serviceaccount:devpod-workspaces:opencode-agent"`
     - TokenReview `status.user.groups`: `["system:serviceaccounts", "system:serviceaccounts:devpod-workspaces", "system:authenticated"]`
3. **M2 durable dedupe backend:** `Redis`
   - **Rationale:** Native TTL support makes the minimum 24-hour dedupe window explicit and cross-replica replay behavior simpler than a bespoke SQL retention job.

- [ ] Copy these exact decisions into explicit deployment decision docs at `docs/deployment/auth.md`, `docs/deployment/broker_stack.md`, and `docs/deployment/idempotency.md` before implementing later behavior changes (create these docs as Slice 0 artifacts if they do not exist).
- [ ] Stop and revise the design + plan together if any later slice requires a different broker boundary, claim set, or durable backend.
- [ ] Do not start Slice 1 until all three decision records above are preserved in code/config/docs touched by the implementation.

### Slice X: Security hardening and prod controls

**Files:**
- Create: `tests/integration/test_prod_transport_and_runtime_controls.py`
- Modify: `services/github_app_executor/app/main.py`
- Modify: `services/github_app_executor/app/security/transport.py`
- Modify: `services/github_app_executor/app/security/replay.py`
- Modify: `services/github_app_executor/app/security/rate_limit.py`
- Modify: `services/github_app_executor/app/audit/log.py`
- Modify: `services/github_app_executor/app/metrics.py`
- Modify: `docs/runbooks/github-app-executor.md`

- [ ] **TLS enforcement (failing test first):** Write a failing integration test proving that a plaintext `http://` request to a prod-like mutating endpoint never returns `200`, fails at connection/TLS setup, and emits an audit entry containing `transport-auth-failure`.
- [ ] Verify the TLS test fails for the expected reason (plaintext transport still reaches the handler, returns `200`, or the audit event is missing).
- [ ] Implement the minimum prod transport guard needed so mutating endpoints require TLS before request handling and always audit transport authentication failures as `transport-auth-failure`.
- [ ] **mTLS requirement (failing test first):** Write a failing integration test proving that a prod-like TLS request without a client certificate returns `403` or a transport-auth error, and records an audit event that notes a missing client cert.
- [ ] Verify the mTLS test fails for the expected reason (request is accepted without a client cert or the missing-cert audit event is absent).
- [ ] Implement the minimum client-certificate gate needed so prod-like mutating traffic requires mTLS and denies/audits missing client certificates.
- [ ] **Replay freshness (failing test first):** Write a failing integration test proving that a signed mutating request with a timestamp older than the configured freshness TTL is rejected with `REPLAY_TOO_OLD`, produces no GitHub mutation, and records the stale-timestamp decision.
- [ ] Verify the freshness test fails for the expected reason (stale timestamps are accepted, the wrong error code is returned, or a mutation still occurs).
- [ ] Implement the minimum timestamp-window validation needed so stale mutating requests fail closed with `REPLAY_TOO_OLD` before any GitHub side effect.
- [ ] **Nonce reuse (failing test first):** Write a failing integration test proving that resubmitting the same nonce for the same `idempotency_key` returns `DUPLICATE_NONCE`, performs no extra mutation, and is audited as a duplicate nonce event.
- [ ] Verify the nonce test fails for the expected reason (duplicate nonces are accepted, the wrong error code is returned, or the audit event is missing).
- [ ] Implement the minimum nonce ledger/check needed so duplicate nonces are rejected deterministically per authenticated mutating request scope.
- [ ] **Broker-side mutating rate limits (failing test first):** Write a failing integration/load test proving that sending more than the configured mutating-request limit in a short window yields `429` with `RATE_LIMIT_EXCEEDED`, creates no extra GitHub mutations beyond the allowed budget, and records the broker-side limiter decision.
- [ ] Verify the rate-limit test fails for the expected reason (all requests are accepted, the wrong error code/status is returned, or extra mutations slip through after the limit is exceeded).
- [ ] Implement the minimum broker-side mutating rate limiter needed so excess requests are rejected with `429`/`RATE_LIMIT_EXCEEDED` before mutation.
- [ ] **Anomaly alerting (failing test first):** Write a failing integration test proving that when denied mutating requests exceed the configured threshold within the configured window, the broker exports or logs an `anomaly_denies` signal with the aggregated count.
- [ ] Verify the anomaly test fails for the expected reason (deny spikes are not aggregated, the signal key is missing, or the exported/logged count is wrong).
- [ ] Implement the minimum deny-spike counter/export path needed so anomalous deny bursts emit `anomaly_denies` metrics/events without weakening normal request handling.
- [ ] Re-run the transport/replay/rate-limit/anomaly checks and commit only after the prod controls fail closed, emit the required audit/metric signals, and preserve zero-mutation guarantees on denied requests.

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
- [ ] Extend `tests/e2e/test_no_token_return.py` so neutral `request_id`/`idempotency_key` fixtures, broker-path external responses, and captured outbound GitHub request metadata prove that no top-level response keys named `token`, `access_token`, `installation_token`, or `jwt` are exposed and no tightened PEM/`eyJ...` JWT/`gh[psoau]_...` GitHub-token patterns appear in the public API surface.
- [ ] Add a verification step that uses ripgrep to scan broker/executor logs for the tightened PEM/`eyJ...` JWT/`gh[psoau]_...` GitHub-token patterns, explicitly filtering the exact allowed prod guardrail message `token_return.enabled must be false in prod`, and expects zero other matches.
- [ ] Add a failing broker-first egress-bypass gate that shells into the workspace pod, attempts `curl https://api.github.com/meta`, and fails unless the request is blocked with corresponding network-policy deny or iptables reject evidence.
- [ ] Implement the minimum config-validation, secret-scan, and broker-first egress enforcement needed to make the new security tests pass.
- [ ] Re-run the prod-security, no-token-return, and egress-bypass checks and commit only after the prod profile fails closed on forbidden token-return/local-PEM settings and direct workspace-to-GitHub egress is blocked.

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
- [ ] Write a failing integration test where the broker invokes OPA for an otherwise well-formed mutating request, returns `POLICY_DENY`, performs no GitHub mutation, and writes a deny audit event showing the broker issued the final decision while OPA supplied the policy reason.
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

1. **Assertion:** Slice 0 explicitly records the chosen broker stack as `Broker-as-Pod with ingress`, the stable exact TokenReview claims (`aud`, `iss`, namespace, serviceAccount name) plus the dynamic pod-claim shape checks listed above, and the `Redis` M2 dedupe backend choice.
2. **Assertion:** The plan text states that Slice 1 cannot begin until those three Slice 0 decisions are preserved in the implementation files listed for Slice 0.
3. **Assertion:** The plan contains the sentence: `Broker-first only; local-CSI fallback deferred to follow-up plan.`

### Security enforcement

4. **Assertion:** Starting the executor in a prod-like profile with `token_return.enabled=true` exits non-zero before serving requests and emits a config-validation message containing `token_return.enabled must be false in prod`.
5. **Assertion:** Starting the executor in a prod-like profile resolves the private-key provider to OpenBao; configuring a local PEM path/provider in prod exits non-zero before serving requests and emits a validation message containing `prod profile requires OpenBao private key provider`.
6. **Assertion:** No external response body exposes top-level keys named `token`, `access_token`, `installation_token`, or `jwt`, and no external response body, captured outbound GitHub request body/metadata, or broker/executor log line contains PEM private-key headers, JWTs matching the `eyJ...` heuristic, or GitHub token prefixes matching `gh[psoau]_...`.
7. **Assertion:** When broker-first mode is enabled, a workspace pod cannot reach `https://api.github.com/meta` directly; the attempt exits non-zero and produces network-policy deny or iptables reject evidence showing the broker remains the only GitHub egress path.

### Security hardening and prod controls

8. **Assertion:** TLS enforcement: starting a client with plaintext (http) to mutating endpoints in prod-like profile results in connection refused or TLS handshake failure; verification command shows non-200 and audit log entry `transport-auth-failure`.
9. **Assertion:** mTLS requirement: client cert absence leads to 403/error and audit event noting missing client cert.
10. **Assertion:** Replay freshness: requests older than allowed freshness window (e.g., timestamp older than configurable TTL) are rejected with error code `REPLAY_TOO_OLD` and no GitHub mutation; test simulates stale timestamp.
11. **Assertion:** Nonce reuse: resubmitting same nonce for same idempotency_key returns `DUPLICATE_NONCE` and is audited.
12. **Assertion:** Rate limiting: sending >N mutating requests in short window returns 429 with error `RATE_LIMIT_EXCEEDED` and no extra mutations; add a test harness command using seq/curl or k6 simulation snippet (design-level) that asserts rate limiting.
13. **Assertion:** Anomaly signals: when denied requests spike above threshold X, a metric/event is exported (or logged) with key `anomaly_denies` and count; verification checks metrics endpoint or log contains the event.

### Contract and auth/policy denials

14. **Assertion:** Every successful external `POST /v1/action` response has top-level keys exactly `request_id`, `status`, and `result`; `status` equals `"ok"`; no top-level `error`, `state`, `replayed`, `token`, or `internal_state` key is present.
15. **Assertion:** Every successful external `GET /v1/status/{request_id}` response has top-level keys exactly `request_id`, `status`, and `result`; `status` equals `"ok"`; no legacy top-level keys are present.
16. **Assertion:** Every external error response has top-level keys exactly `request_id`, `status`, and `error`; `status` equals `"error"`; `error` has keys exactly `code`, `message`, `retryable`, and `details`.
17. **Assertion:** An invalid/expired/wrong-audience projected ServiceAccount token returns `status="error"`, `error.code="INVALID_WORKLOAD_TOKEN"`, produces no GitHub mutation, and writes an audit event containing the `request_id`, the failed TokenReview audience check, and an auth-deny decision.
18. **Assertion:** A policy-denied request records the stable exact TokenReview claims literally (`aud`, `iss`, namespace, serviceAccount name), validates dynamic pod claims by presence/shape only, and exposes the normalized workload identity without pinning literal pod values.
19. **Assertion:** A broker-issued policy deny returns `status="error"`, `error.code="POLICY_DENY"`, produces no GitHub mutation, and writes an audit event containing `request_id`, validated workload identity, `decision_source="broker"`, `policy_engine="opa"`, and the OPA policy reason.

### Internal-state labeling

20. **Assertion:** Any non-external diagnostic serializer output that includes internal fields nests them under one top-level `internal_state` object and labels every nested key with `(internal-only)`.

### Persona format

21. **Assertion:** Every mutating comment body and PR body emitted by the broker begins with `[Persona: <persona>]` on the first line.
22. **Assertion:** Every mutating comment body and PR body emitted by the broker ends with `— Posted by persona <persona> via GitHub App`.
23. **Assertion:** A broker-path end-to-end test that captures the final outbound GitHub request body proves the emitted payload, not just formatter helpers, contains the canonical persona markers.

### Idempotency

24. **Assertion:** In M1, replaying the same mutating request with the same authenticated workload identity, `repo`, `action`, `request_id`, and `idempotency_key` during one live process returns the original canonical success result and does not create a second GitHub artifact.
25. **Assertion:** In M1, replaying the same `request_id` and `idempotency_key` with a semantically different payload returns `status="error"`, `error.code="DUPLICATE_PAYLOAD_MISMATCH"`, and creates no additional GitHub artifact.
26. **Assertion:** In M1, sending the same `request_id` and `idempotency_key` from a different authenticated workload identity does not collide with the original dedupe record; an authorized second identity produces a distinct artifact, while an unauthorized second identity is rejected by policy before mutation.
27. **Assertion:** In M1, restarting the single replica clears the in-memory dedupe store, and the runbook states that replay protection is limited to the lifetime of that process.
28. **Assertion:** In M2, replaying the same mutating request on a different replica at any time before 24 hours have elapsed returns the original canonical result and creates no duplicate GitHub artifact.
29. **Assertion:** In M2, a same-key/different-payload replay submitted within 24 hours returns `DUPLICATE_PAYLOAD_MISMATCH` across replicas.
30. **Assertion:** M1 and M2 audit logs record first-seen, replay-hit, payload-mismatch, and cross-identity events keyed by `request_id` + `idempotency_key` + validated workload identity.

### Verification matrix items

31. **Assertion:** Every verification-matrix row below names the slice that introduces/owns the referenced test file path.
32. **Assertion:** `tests/integration/test_prod_transport_and_runtime_controls.py`, `tests/integration/test_prod_security_guards.py`, `tests/e2e/test_no_token_return.py`, `tests/e2e/test_contract_envelope.py`, `tests/integration/test_auth_policy_failures.py`, `tests/e2e/test_health_readiness.py`, `tests/e2e/test_persona_format.py`, `tests/integration/test_internal_state_labeling.py`, `tests/integration/test_m1_idempotency_process_lifetime.py`, and `tests/integration/test_m2_idempotency_retention.py` each pass with exit code `0` when their listed verification commands are run.

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
import json
import re


FORBIDDEN_TOP_LEVEL_KEYS = ("token", "access_token", "installation_token", "jwt")
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
    re.compile(r"\bgh[psoau]_[A-Za-z0-9_-]{7,}\b"),
)


def assert_no_top_level_secret_keys(body: dict):
    for key in FORBIDDEN_TOP_LEVEL_KEYS:
        assert key not in body, key


def assert_no_secret_like_material(serialized: str):
    for pattern in SECRET_PATTERNS:
        assert pattern.search(serialized) is None, pattern.pattern


def test_external_responses_never_return_reusable_tokens(client, auth_headers):
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_public_api_scrub",
            "repo": "octo-org/demo-repo",
            "action": "read-pr",
            "persona": "reviewer",
            "payload": {"pr_number": 42},
        },
    )

    body = response.json()
    assert_no_top_level_secret_keys(body)
    assert_no_secret_like_material(response.text)


def test_broker_path_public_api_and_outbound_metadata_exclude_tokens(github_recorder, broker_client, auth_headers):
    response = broker_client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_public_api_scrub_broker_path",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_public_api_scrub_broker_path",
            "payload": {"pr_number": 42, "body": "Token scrub check"},
        },
    )

    outbound = github_recorder.last_request("/repos/octo-org/demo-repo/issues/42/comments")
    assert response.status_code == 201
    body = response.json()
    assert_no_top_level_secret_keys(body)
    assert_no_secret_like_material(response.text)
    assert_no_secret_like_material(json.dumps(outbound, sort_keys=True))
```

### `tests/e2e/test_contract_envelope.py`

```python
def test_post_action_success_envelope(client, auth_headers):
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_contract_ok_1",
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
    assert body["request_id"] == "req_contract_ok_1"
    assert body["status"] == "ok"
    assert set(body["result"].keys()) == {"comment_id", "url"}
    assert "state" not in body
    assert "replayed" not in body
    assert "error" not in body
    assert "internal_state" not in body


def test_post_action_payload_mismatch_error_envelope(client, auth_headers):
    request = {
        "request_id": "req_contract_conflict_1",
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
    create = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": "req_contract_status_1",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": "idem_contract_ok",
            "payload": {"pr_number": 42, "body": "Please tighten the policy wording."},
        },
    )
    assert create.status_code == 201

    response = client.get("/v1/status/req_contract_status_1", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"request_id", "status", "result"}
    assert body["request_id"] == "req_contract_status_1"
    assert body["status"] == "ok"
```

### `tests/integration/test_auth_policy_failures.py`

```python
import re

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
    assert body["error"]["details"]["decision_source"] == "broker"
    assert body["error"]["details"]["policy_engine"] == "opa"
    assert github_recorder.count("req_policy_deny") == 0

    audit = broker_server.audit_event("req_policy_deny")
    assert audit["decision"] == "policy_deny"
    assert audit["decision_source"] == "broker"
    assert audit["policy_engine"] == "opa"
    assert audit["validated_workload_identity"] == "system:serviceaccount:devpod-workspaces:opencode-agent"
    assert audit["policy_reason"] == "repo_not_allowed"

    claims = audit["token_review"]["claims"]
    assert claims["aud"] == ["github-broker"]
    assert claims["iss"] == "https://kubernetes.default.svc.cluster.local"
    assert claims["kubernetes.io/serviceaccount/namespace"] == "devpod-workspaces"
    assert claims["kubernetes.io/serviceaccount/service-account.name"] == "opencode-agent"
    assert re.fullmatch(r"workspace-[a-z0-9-]+", claims["kubernetes.io/pod/name"])
    assert re.fullmatch(r"[0-9a-f-]{36}", claims["kubernetes.io/pod/uid"])
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

### `tests/integration/test_idempotency_scope.py`

```python
import pytest


@pytest.mark.integration
def test_same_key_different_repo_action(m1_live_server, auth_headers):
    base = {
        "request_id": "req_scope_1",
        "idempotency_key": "idem_scope_shared",
        "persona": "reviewer",
        "payload": {"pr_number": 1, "body": "Scope validation comment"},
    }

    a = {**base, "repo": "org/repo-a", "action": "comment-pr"}
    b = {**base, "repo": "org/repo-b", "action": "comment-pr"}
    c = {**base, "repo": "org/repo-a", "action": "merge-pr"}

    r1 = m1_live_server.post("/v1/action", headers=auth_headers, json=a)
    r2 = m1_live_server.post("/v1/action", headers=auth_headers, json=b)
    r3 = m1_live_server.post("/v1/action", headers=auth_headers, json=c)

    assert r1.status_code == 201
    assert r2.status_code == 201
    assert r3.status_code == 201
    assert m1_live_server.github_comment_count("req_scope_1") == 3
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
| Slice X | TLS enforcement for mutating endpoints | `tests/integration/test_prod_transport_and_runtime_controls.py` | `sh -c "code=$(curl -sS -o /tmp/plain-http.out -w '%{http_code}\n' -H 'Content-Type: application/json' -d '{\"request_id\":\"req_tls_plaintext\",\"repo\":\"octo-org/demo-repo\",\"action\":\"comment-pr\",\"persona\":\"reviewer\",\"idempotency_key\":\"idem_tls_plaintext\",\"payload\":{\"pr_number\":42,\"body\":\"plaintext should fail\"}}' http://127.0.0.1:8443/v1/action 2>/tmp/plain-http.err || true); test \"$code\" != \"200\" && rg -n 'transport-auth-failure' var/log/github-app-executor/audit.log"` | `curl` prints a non-`200` code or fails before HTTP completes; audit log scan prints a `transport-auth-failure` entry and exits `0` |
| Slice X | mTLS requirement for mutating endpoints | `tests/integration/test_prod_transport_and_runtime_controls.py` | `sh -c "code=$(curl -sk -o /tmp/mtls-missing-cert.out -w '%{http_code}\n' --cacert certs/ca.crt -H 'Content-Type: application/json' -d '{\"request_id\":\"req_mtls_missing_cert\",\"repo\":\"octo-org/demo-repo\",\"action\":\"comment-pr\",\"persona\":\"reviewer\",\"idempotency_key\":\"idem_mtls_missing_cert\",\"payload\":{\"pr_number\":42,\"body\":\"missing cert should fail\"}}' https://127.0.0.1:8443/v1/action 2>/tmp/mtls-missing-cert.err || true); test \"$code\" = \"403\" -o \"$code\" = \"000\" && rg -n 'missing client cert' var/log/github-app-executor/audit.log"` | `curl` prints `403` or transport error code `000`; audit log scan prints a missing-client-cert event and exits `0` |
| Slice X | Replay freshness stale-timestamp rejection | `tests/integration/test_prod_transport_and_runtime_controls.py` | `pytest tests/integration/test_prod_transport_and_runtime_controls.py::test_stale_timestamp_is_rejected_with_replay_too_old -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice X | Nonce reuse rejection | `tests/integration/test_prod_transport_and_runtime_controls.py` | `pytest tests/integration/test_prod_transport_and_runtime_controls.py::test_duplicate_nonce_is_rejected_and_audited -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice X | Broker-side mutating rate limits | `tests/integration/test_prod_transport_and_runtime_controls.py` | `RATE_LIMIT_N=5 sh -c "seq 1 6 | xargs -I{} -P6 curl -sk --cert certs/client.pem --key certs/client-key.pem --cacert certs/ca.crt -o /tmp/rate-limit-{}.json -w '%{http_code}\n' -H 'Content-Type: application/json' -d '{\"request_id\":\"req_rate_limit_{}\",\"repo\":\"octo-org/demo-repo\",\"action\":\"comment-pr\",\"persona\":\"reviewer\",\"idempotency_key\":\"idem_rate_limit_{}\",\"payload\":{\"pr_number\":42,\"body\":\"rate limit check {}\"}}' https://127.0.0.1:8443/v1/action | tee /tmp/rate-limit.codes && grep -q '^429$' /tmp/rate-limit.codes && rg -n 'RATE_LIMIT_EXCEEDED' /tmp/rate-limit-*.json"` | Output includes at least one `429`; at least one response body contains `RATE_LIMIT_EXCEEDED`; command exits `0` only when the limiter trips |
| Slice X | Anomaly deny-spike signal export | `tests/integration/test_prod_transport_and_runtime_controls.py` | `sh -c "curl -sS http://127.0.0.1:9090/metrics | tee /tmp/github-app.metrics | rg '^anomaly_denies(\{.*\})? [1-9][0-9]*$' || rg -n 'anomaly_denies' var/log/github-app-executor/audit.log"` | Metrics output or log scan prints an `anomaly_denies` line with a positive count and exits `0` |
| Slice 1 | Prod token-return config guard | `tests/integration/test_prod_security_guards.py` | `pytest tests/integration/test_prod_security_guards.py::test_prod_startup_rejects_token_return_enabled -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 1 | Prod OpenBao provider resolution | `tests/integration/test_prod_security_guards.py` | `pytest tests/integration/test_prod_security_guards.py::test_prod_profile_resolves_private_key_provider_to_openbao -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 1 | Prod local-PEM rejection | `tests/integration/test_prod_security_guards.py` | `pytest tests/integration/test_prod_security_guards.py::test_prod_profile_rejects_local_pem_private_key_provider -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 1 | No-token-return regression | `tests/e2e/test_no_token_return.py` | `pytest tests/e2e/test_no_token_return.py -q` | Exit `0`; output contains `2 passed` |
| Slice 1 | Broker/executor log leak scan | `tests/e2e/test_no_token_return.py` | `sh -c 'ls var/log/github-app-executor/*.log >/dev/null || (echo "no logs" >&2; exit 1); matches=$(rg -n -e "-----BEGIN (?:RSA |EC |OPENSSH |)PRIVATE KEY-----" -e "\bgh[psoau]_[A-Za-z0-9_-]{7,}\b" -e "\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b" var/log/github-app-executor/*.log | grep -v "token_return.enabled must be false in prod" || true); if [ -n "$matches" ]; then echo "$matches"; exit 1; else exit 0; fi'` | Exit `0` if no forbidden patterns found; if forbidden patterns are found the command prints matching lines and exits non-zero. |
| Slice 1 | Broker-first workspace egress bypass gate | `tests/integration/test_prod_security_guards.py` | `sh -c "kubectl exec -n devpod-workspaces pod/workspace-pod -- sh -lc 'curl -sS --connect-timeout 5 --max-time 10 https://api.github.com/meta' >/tmp/workspace-egress.out 2>/tmp/workspace-egress.err && exit 1 || true && evidence=$(kubectl get events -n devpod-workspaces --field-selector reason=NetworkPolicyDenied --sort-by=.lastTimestamp | rg 'workspace-pod|NetworkPolicyDenied|DENIED|REJECT|api.github.com|443' || true); if [ -z \"$evidence\" ]; then evidence=$(kubectl logs -n kube-system -l k8s-app=cilium --since=1m | rg 'workspace-pod|DROP|REJECT|DENIED|api.github.com|443' || true); fi; if [ -n \"$evidence\" ]; then printf '%s\n' \"$evidence\"; exit 0; else exit 1; fi"` | `curl` fails (non-`200` or connection refused) and the evidence command prints deny logs or network-policy event lines and exits `0` |
| Slice 2 | Success contract envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_post_action_success_envelope -q` | Exit `0`; output contains `1 passed` |
| Slice 2 | Error contract envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_post_action_payload_mismatch_error_envelope -q` | Exit `0`; output contains `1 passed` |
| Slice 2 | Status envelope | `tests/e2e/test_contract_envelope.py` | `pytest tests/e2e/test_contract_envelope.py::test_status_lookup_success_envelope -q` | Exit `0`; output contains `1 passed` |
| Slice 2 | Invalid workload token deny/no mutation | `tests/integration/test_auth_policy_failures.py` | `pytest tests/integration/test_auth_policy_failures.py::test_invalid_workload_token_returns_invalid_workload_token_and_no_mutation -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 2 | Broker-issued policy deny via OPA | `tests/integration/test_auth_policy_failures.py` | `pytest tests/integration/test_auth_policy_failures.py::test_opa_deny_returns_policy_deny_and_no_mutation -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 2 | Health endpoint | `tests/e2e/test_health_readiness.py` | `curl -sS -o /tmp/healthz.json -w '%{http_code}\n' http://127.0.0.1:8000/healthz && jq -e '.status == "ok"' /tmp/healthz.json` | First command prints `200`; `jq` exits `0` and prints `true` |
| Slice 2 | Readiness endpoint | `tests/e2e/test_health_readiness.py` | `curl -sS -o /tmp/readyz.json -w '%{http_code}\n' http://127.0.0.1:8000/readyz && jq -e '.status == "ok" and .token_review == "ok" and .opa == "ok" and .openbao == "ok"' /tmp/readyz.json` | First command prints `200`; `jq` exits `0` and prints `true` |
| Slice 2 | Success curl smoke | `tests/e2e/test_contract_envelope.py` | `curl -sS -o /tmp/action-ok.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{"request_id":"req_contract_ok_1","repo":"octo-org/demo-repo","action":"comment-pr","persona":"reviewer","idempotency_key":"idem_contract_ok","payload":{"pr_number":42,"body":"Please tighten the policy wording."}}' http://127.0.0.1:8000/v1/action && jq -e '.request_id == "req_contract_ok_1" and .status == "ok" and (.result | has("comment_id")) and (.result | has("url"))' /tmp/action-ok.json` | First command prints `201`; `jq` exits `0` and prints `true` |
| Slice 2 | Error curl smoke | `tests/e2e/test_contract_envelope.py` | `sh -c "curl -sS -o /tmp/action-orig.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{\"request_id\":\"req_contract_conflict_1\",\"repo\":\"octo-org/demo-repo\",\"action\":\"comment-pr\",\"persona\":\"reviewer\",\"idempotency_key\":\"idem_contract_conflict\",\"payload\":{\"pr_number\":42,\"body\":\"Original body\"}}' http://127.0.0.1:8000/v1/action && curl -sS -o /tmp/action-conflict.json -w '%{http_code}\n' -H 'Authorization: Bearer VALID_TOKEN' -H 'Content-Type: application/json' -d '{\"request_id\":\"req_contract_conflict_1\",\"repo\":\"octo-org/demo-repo\",\"action\":\"comment-pr\",\"persona\":\"reviewer\",\"idempotency_key\":\"idem_contract_conflict\",\"payload\":{\"pr_number\":42,\"body\":\"Changed body\"}}' http://127.0.0.1:8000/v1/action && jq -e '.request_id == \"req_contract_conflict_1\" and .status == \"error\" and .error.code == \"DUPLICATE_PAYLOAD_MISMATCH\" and (.error.retryable == false)' /tmp/action-conflict.json"` | First command prints `201`; second prints `409`; `jq` exits `0` and prints `true` |
| Slice 3 | Persona marker tests | `tests/e2e/test_persona_format.py` | `pytest tests/e2e/test_persona_format.py -q` | Exit `0`; output contains `3 passed` |
| Slice 3 | Internal-state labeling | `tests/integration/test_internal_state_labeling.py` | `pytest tests/integration/test_internal_state_labeling.py -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | M1 same-process replay | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_replay_returns_canonical_result_during_single_process -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | M1 cross-identity scope | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_same_request_id_and_idempotency_key_do_not_collide_across_workload_identities -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | M1 restart limitation | `tests/integration/test_m1_idempotency_process_lifetime.py` | `pytest tests/integration/test_m1_idempotency_process_lifetime.py::test_m1_restart_demonstrates_in_memory_lifetime_limit -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 4 | Idempotency scope by repo/action | `tests/integration/test_idempotency_scope.py` | `pytest tests/integration/test_idempotency_scope.py -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 5 | M2 24h replay retention | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_m2_replay_is_retained_for_24h_across_replicas -q -m integration` | Exit `0`; output contains `1 passed` |
| Slice 5 | M2 mismatch rejection | `tests/integration/test_m2_idempotency_retention.py` | `pytest tests/integration/test_m2_idempotency_retention.py::test_m2_payload_mismatch_is_rejected_within_24h -q -m integration` | Exit `0`; output contains `1 passed` |

## Remaining open questions and next steps

- No unresolved planning preconditions remain in this revision; if infra or security owners need a different broker boundary, TokenReview claim set, or durable dedupe backend, revise the design and this plan together before implementation.
- Next step: implement Slice 0 acknowledgements first, then Slice X security hardening, then execute Slices 1-5 in order with TDD and per-slice verification.
