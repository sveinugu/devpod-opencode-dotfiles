from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Header, HTTPException, Response

from app.formatting import format_comment_body
from app.models import ActionRequest, ErrorEnvelope, FailureEnvelope, SuccessEnvelope
from app.services import (
    FakeGitHubClient,
    InMemoryIdempotencyStore,
    OpenBaoPrivateKeyResolverStub,
    PolicyClientStub,
    WorkloadIdentityValidator,
)


def _error_response(status_code: int, request_id: str, code: str, message: str, retryable: bool = False, details: dict[str, Any] | None = None):
    envelope = FailureEnvelope(
        request_id=request_id,
        error=ErrorEnvelope(code=code, message=message, retryable=retryable, details=details or {}),
    )
    return Response(content=envelope.model_dump_json(), media_type="application/json", status_code=status_code)


def create_app(
    *,
    github_client: FakeGitHubClient | None = None,
    policy_client: PolicyClientStub | None = None,
    idempotency_store: InMemoryIdempotencyStore | None = None,
    profile: str = "dev",
    token_return_enabled: bool = False,
    private_key_provider: str = "openbao",
    local_pem_path: str | None = None,
) -> FastAPI:
    if profile in {"prod", "staging", "production"} and token_return_enabled:
        raise RuntimeError("token_return.enabled must be false in prod")

    resolver = OpenBaoPrivateKeyResolverStub(profile=profile)
    resolver.resolve(provider=private_key_provider, local_pem_path=local_pem_path)

    app = FastAPI(title="github-app-executor")
    app.state.github_client = github_client or FakeGitHubClient()
    app.state.policy_client = policy_client or PolicyClientStub()
    app.state.idempotency_store = idempotency_store or InMemoryIdempotencyStore()
    app.state.status_by_request_id = {}

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/readyz")
    def readyz() -> dict[str, Any]:
        return {
            "status": "ok",
            "dependencies": {
                "token_review": "placeholder",
                "opa": "placeholder",
                "openbao": "placeholder",
            },
        }

    @app.post("/v1/action")
    def post_action(request: ActionRequest, x_workload_identity: str | None = Header(default=None)):
        headers = {"x-workload-identity": x_workload_identity or ""}
        try:
            workload_identity = WorkloadIdentityValidator.validate(headers)
        except ValueError:
            return _error_response(
                401,
                request.request_id,
                "INVALID_WORKLOAD_TOKEN",
                "workload identity header missing or invalid",
            )

        allowed, deny_code, deny_reason = app.state.policy_client.evaluate(
            workload_identity=workload_identity,
            repo=request.repo,
            action=request.action,
            persona=request.persona,
        )
        if not allowed:
            return _error_response(
                403,
                request.request_id,
                deny_code or "POLICY_DENY",
                "request denied by policy",
                details={"decision_source": "broker", "policy_engine": "opa", "reason": deny_reason},
            )

        if request.action != "comment-pr":
            return _error_response(
                400,
                request.request_id,
                "UNSUPPORTED_ACTION",
                "tracer-bullet supports only comment-pr",
            )

        if request.idempotency_key is None:
            raise HTTPException(status_code=422, detail="idempotency_key required")

        payload_hash = app.state.idempotency_store.payload_hash(request.payload)
        existing = app.state.idempotency_store.get(
            workload_identity=workload_identity,
            repo=request.repo,
            action=request.action,
            idempotency_key=request.idempotency_key,
        )
        if existing:
            if existing.payload_hash != payload_hash:
                return _error_response(
                    409,
                    request.request_id,
                    "DUPLICATE_PAYLOAD_MISMATCH",
                    "same idempotency key was used with different payload",
                    details={"idempotency_scope": f"{workload_identity}|{request.repo}|{request.action}"},
                )
            envelope = SuccessEnvelope(request_id=request.request_id, result=existing.canonical_result)
            app.state.status_by_request_id[request.request_id] = envelope.model_dump()
            return Response(content=envelope.model_dump_json(), media_type="application/json", status_code=200)

        pr_number = int(request.payload["pr_number"])
        comment_body = format_comment_body(persona=request.persona, body=str(request.payload["body"]))
        result = app.state.github_client.post_comment(
            request_id=request.request_id,
            repo=request.repo,
            pr_number=pr_number,
            body=comment_body,
        )

        app.state.idempotency_store.put(
            workload_identity=workload_identity,
            repo=request.repo,
            action=request.action,
            idempotency_key=request.idempotency_key,
            payload_hash=payload_hash,
            canonical_result=result,
        )
        envelope = SuccessEnvelope(request_id=request.request_id, result=result)
        app.state.status_by_request_id[request.request_id] = envelope.model_dump()
        return Response(content=envelope.model_dump_json(), media_type="application/json", status_code=201)

    @app.get("/v1/status/{request_id}")
    def get_status(request_id: str, x_workload_identity: str | None = Header(default=None)):
        headers = {"x-workload-identity": x_workload_identity or ""}
        try:
            WorkloadIdentityValidator.validate(headers)
        except ValueError:
            return _error_response(
                401,
                request_id,
                "INVALID_WORKLOAD_TOKEN",
                "workload identity header missing or invalid",
            )

        status = app.state.status_by_request_id.get(request_id)
        if status is None:
            return _error_response(404, request_id, "NOT_FOUND", "request_id not found", details={})
        return status

    return app


app = create_app()
