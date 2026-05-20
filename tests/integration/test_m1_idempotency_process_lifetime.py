import uuid

import pytest


@pytest.mark.integration
def test_m1_replay_returns_same_result_during_single_process(m1_live_server, auth_headers):
    request = {
        "request_id": f"req_m1_same_process_{uuid.uuid4().hex[:8]}",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": f"idem_m1_same_process_{uuid.uuid4().hex[:8]}",
        "payload": {"pr_number": 42, "body": "M1 replay smoke"},
    }

    first = m1_live_server.post("/v1/action", headers=auth_headers, json=request)
    replay = m1_live_server.post("/v1/action", headers=auth_headers, json=request)

    assert first.status_code == 201
    assert replay.status_code == 200
    assert replay.json() == first.json()
    assert m1_live_server.github_comment_count(request["request_id"]) == 1


@pytest.mark.integration
def test_m1_restart_clears_in_memory_dedupe(m1_live_server, auth_headers):
    request = {
        "request_id": f"req_m1_restart_{uuid.uuid4().hex[:8]}",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": f"idem_m1_restart_{uuid.uuid4().hex[:8]}",
        "payload": {"pr_number": 42, "body": "Process lifetime demo"},
    }

    first = m1_live_server.post("/v1/action", headers=auth_headers, json=request)
    m1_live_server.restart()
    second = m1_live_server.post("/v1/action", headers=auth_headers, json=request)

    assert first.status_code == 201
    assert second.status_code == 201
    assert second.json()["result"]["comment_id"] != first.json()["result"]["comment_id"]
