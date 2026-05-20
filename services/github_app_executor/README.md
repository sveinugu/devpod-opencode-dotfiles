# GitHub App Executor (M1 tracer-bullet)

Minimal FastAPI executor implementing Request Contract v1 for:

- `POST /v1/action` (supports `comment-pr` only in M1 tracer-bullet)
- `GET /v1/status/{request_id}`
- `GET /healthz`
- `GET /readyz`

This tracer-bullet intentionally uses process-local in-memory idempotency.
