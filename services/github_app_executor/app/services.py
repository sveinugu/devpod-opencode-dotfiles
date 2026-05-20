from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import json
from typing import Any


class OpenBaoPrivateKeyResolverStub:
    def __init__(self, profile: str = "test") -> None:
        self.profile = profile

    def resolve(self, provider: str, local_pem_path: str | None = None) -> str:
        if self.profile in {"prod", "staging", "production"} and provider != "openbao":
            raise ValueError("prod profile requires OpenBao private key provider")
        if self.profile in {"prod", "staging", "production"} and local_pem_path:
            raise ValueError("prod profile requires OpenBao private key provider")
        return "openbao:stubbed-key-ref"


class WorkloadIdentityValidator:
    @staticmethod
    def validate(headers: dict[str, str]) -> str:
        identity = headers.get("x-workload-identity")
        if not identity:
            raise ValueError("INVALID_WORKLOAD_TOKEN")
        if identity.count("/") != 1:
            raise ValueError("INVALID_WORKLOAD_TOKEN")
        namespace, service_account = identity.split("/", maxsplit=1)
        if not namespace or not service_account:
            raise ValueError("INVALID_WORKLOAD_TOKEN")
        return f"system:serviceaccount:{namespace}:{service_account}"


class PolicyClientStub:
    def __init__(self) -> None:
        self._forced_deny_code: str | None = None
        self._forced_reason: str = "repo_not_allowed"

    def set_deny(self, code: str = "POLICY_DENY", reason: str = "repo_not_allowed") -> None:
        self._forced_deny_code = code
        self._forced_reason = reason

    def clear(self) -> None:
        self._forced_deny_code = None
        self._forced_reason = "repo_not_allowed"

    def evaluate(self, *, workload_identity: str, repo: str, action: str, persona: str) -> tuple[bool, str | None, str | None]:
        if self._forced_deny_code:
            return False, self._forced_deny_code, self._forced_reason
        return True, None, None


class FakeGitHubClient:
    def __init__(self) -> None:
        self.outbound: list[dict[str, Any]] = []
        self._next_comment_id = 9000

    def post_comment(self, *, request_id: str, repo: str, pr_number: int, body: str) -> dict[str, Any]:
        self._next_comment_id += 1
        path = f"/repos/{repo}/issues/{pr_number}/comments"
        response = {
            "comment_id": self._next_comment_id,
            "url": f"https://github.com/{repo}/pull/{pr_number}#issuecomment-{self._next_comment_id}",
        }
        self.outbound.append(
            {
                "request_id": request_id,
                "path": path,
                "json": {"body": body},
                "response": response,
            }
        )
        return response

    def last_request(self, path: str) -> dict[str, Any] | None:
        for item in reversed(self.outbound):
            if item["path"] == path:
                return item
        return None


@dataclass(frozen=True)
class IdempotencyRecord:
    payload_hash: str
    canonical_result: dict[str, Any]


class InMemoryIdempotencyStore:
    def __init__(self) -> None:
        self._records: dict[tuple[str, str, str, str], IdempotencyRecord] = {}

    @staticmethod
    def payload_hash(payload: dict[str, Any]) -> str:
        normalized = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        return sha256(normalized.encode("utf-8")).hexdigest()

    def get(self, *, workload_identity: str, repo: str, action: str, idempotency_key: str) -> IdempotencyRecord | None:
        return self._records.get((workload_identity, repo, action, idempotency_key))

    def put(self, *, workload_identity: str, repo: str, action: str, idempotency_key: str, payload_hash: str, canonical_result: dict[str, Any]) -> None:
        self._records[(workload_identity, repo, action, idempotency_key)] = IdempotencyRecord(
            payload_hash=payload_hash,
            canonical_result=canonical_result,
        )
