from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator


class ActionRequest(BaseModel):
    request_id: str
    repo: str
    action: str
    persona: str
    caller_identity: str | None = None
    payload: dict[str, Any]
    idempotency_key: str | None = None

    @model_validator(mode="after")
    def validate_mutating_action(self) -> "ActionRequest":
        if self.action in {"comment-pr", "comment-issue", "create-pr"} and not self.idempotency_key:
            raise ValueError("idempotency_key is required for mutating actions")
        return self


class ErrorEnvelope(BaseModel):
    code: str
    message: str
    retryable: bool
    details: dict[str, Any] = Field(default_factory=dict)


class SuccessEnvelope(BaseModel):
    request_id: str
    status: Literal["ok"] = "ok"
    result: dict[str, Any]


class FailureEnvelope(BaseModel):
    request_id: str
    status: Literal["error"] = "error"
    error: ErrorEnvelope
