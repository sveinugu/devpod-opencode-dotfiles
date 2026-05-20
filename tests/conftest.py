import re

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.services import FakeGitHubClient, InMemoryIdempotencyStore, PolicyClientStub


@pytest.fixture
def auth_headers() -> dict[str, str]:
    return {"X-Workload-Identity": "devpod-workspaces/opencode-agent"}


@pytest.fixture
def auth_headers_identity_b() -> dict[str, str]:
    """Alternate identity headers for cross-identity tests."""
    return {"X-Workload-Identity": "devpod-workspaces/other-agent"}


@pytest.fixture
def fake_github_client() -> FakeGitHubClient:
    return FakeGitHubClient()


@pytest.fixture
def policy_client() -> PolicyClientStub:
    return PolicyClientStub()


@pytest.fixture
def idempotency_store() -> InMemoryIdempotencyStore:
    return InMemoryIdempotencyStore()


@pytest.fixture
def app(fake_github_client: FakeGitHubClient, policy_client: PolicyClientStub, idempotency_store: InMemoryIdempotencyStore):
    return create_app(
        github_client=fake_github_client,
        policy_client=policy_client,
        idempotency_store=idempotency_store,
        profile="test",
    )


@pytest.fixture
def client(app):
    return TestClient(app)


@pytest.fixture
def format_comment_body():
    from app.formatting import format_comment_body

    return format_comment_body


class M1LiveServerHarness:
    def __init__(self) -> None:
        self.github_client = FakeGitHubClient()
        self.policy_client = PolicyClientStub()
        self._build()

    def _build(self) -> None:
        self.idempotency_store = InMemoryIdempotencyStore()
        app = create_app(
            github_client=self.github_client,
            policy_client=self.policy_client,
            idempotency_store=self.idempotency_store,
            profile="test",
        )
        self.client = TestClient(app)

    def post(self, path: str, headers: dict[str, str], json: dict):
        return self.client.post(path, headers=headers, json=json)

    def get(self, path: str, headers: dict[str, str]):
        return self.client.get(path, headers=headers)

    def restart(self) -> None:
        self._build()

    def github_comment_count(self, request_id: str) -> int:
        return len([entry for entry in self.github_client.outbound if entry["request_id"] == request_id])


@pytest.fixture
def m1_live_server() -> M1LiveServerHarness:
    return M1LiveServerHarness()


def _assert_no_secret_like_material(serialized: str):
    patterns = (
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |)?PRIVATE KEY-----"),
        re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
        re.compile(r"\bgh[psoau]_[A-Za-z0-9_-]{7,}\b"),
    )
    for pattern in patterns:
        assert pattern.search(serialized) is None, pattern.pattern


@pytest.fixture
def assert_no_secret_like_material():
    return _assert_no_secret_like_material
