import uuid


def test_post_action_success_envelope(client, auth_headers):
    request_id = f"req_contract_ok_{uuid.uuid4().hex[:8]}"
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": request_id,
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": f"idem_{uuid.uuid4().hex[:8]}",
            "payload": {"pr_number": 42, "body": "Please tighten this wording."},
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert set(body.keys()) == {"request_id", "status", "result"}
    assert body["request_id"] == request_id
    assert body["status"] == "ok"
    assert set(body["result"].keys()) == {"comment_id", "url"}
    assert "error" not in body
    assert "internal_state" not in body


def test_post_action_payload_mismatch_error_envelope(client, auth_headers):
    request_id = f"req_contract_conflict_{uuid.uuid4().hex[:8]}"
    idempotency_key = f"idem_{uuid.uuid4().hex[:8]}"
    request = {
        "request_id": request_id,
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": "reviewer",
        "idempotency_key": idempotency_key,
        "payload": {"pr_number": 42, "body": "Original body"},
    }

    first = client.post("/v1/action", headers=auth_headers, json=request)
    assert first.status_code == 201

    conflict = client.post(
        "/v1/action",
        headers=auth_headers,
        json={**request, "payload": {"pr_number": 42, "body": "Changed body"}},
    )

    assert conflict.status_code == 409
    body = conflict.json()
    assert set(body.keys()) == {"request_id", "status", "error"}
    assert body["status"] == "error"
    assert set(body["error"].keys()) == {"code", "message", "retryable", "details"}
    assert body["error"]["code"] == "DUPLICATE_PAYLOAD_MISMATCH"


def test_status_lookup_success_envelope(client, auth_headers):
    request_id = f"req_contract_status_{uuid.uuid4().hex[:8]}"
    create = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": request_id,
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": f"idem_{uuid.uuid4().hex[:8]}",
            "payload": {"pr_number": 42, "body": "Status lookup setup"},
        },
    )
    assert create.status_code == 201

    response = client.get(f"/v1/status/{request_id}", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"request_id", "status", "result"}
    assert body["request_id"] == request_id
    assert body["status"] == "ok"
