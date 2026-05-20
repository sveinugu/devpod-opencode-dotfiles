import uuid

import pytest


@pytest.mark.integration
def test_m1_cross_identity_idempotency(m1_live_server, auth_headers):
    # send a request with one identity, then send the same idempotency
    # key but with a different identity header and ensure the server
    # treats them as distinct (i.e., performs the action again).
    request = {
        "request_id": f"req_m1_cross_identity_{uuid.uuid4().hex[:8]}",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": f"idem_m1_cross_identity_{uuid.uuid4().hex[:8]}",
        "payload": {"pr_number": 42, "body": "Cross identity demo"},
    }

    first = m1_live_server.post("/v1/action", headers=auth_headers, json=request)

    # create a different identity header by copying and mutating the base
    other_identity = dict(auth_headers)
    other_identity["X-Workload-Identity"] = "devpod-workspaces/other-agent"

    second = m1_live_server.post("/v1/action", headers=other_identity, json=request)

    assert first.status_code == 201
    assert second.status_code == 201
    # ensure the underlying GitHub comment was created twice
    assert m1_live_server.github_comment_count(request["request_id"]) == 2
