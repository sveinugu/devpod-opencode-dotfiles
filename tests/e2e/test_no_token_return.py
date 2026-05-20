import json
import uuid


FORBIDDEN_TOP_LEVEL_KEYS = ("token", "access_token", "installation_token", "jwt")


def test_external_responses_do_not_return_tokens(client, auth_headers, assert_no_secret_like_material):
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": f"req_public_api_scrub_{uuid.uuid4().hex[:8]}",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": f"idem_public_api_scrub_{uuid.uuid4().hex[:8]}",
            "payload": {"pr_number": 42, "body": "Token scrub check"},
        },
    )

    assert response.status_code == 201
    body = response.json()
    for key in FORBIDDEN_TOP_LEVEL_KEYS:
        assert key not in body
    assert_no_secret_like_material(response.text)


def test_outbound_fake_github_recording_excludes_tokens(client, auth_headers, fake_github_client, assert_no_secret_like_material):
    request_id = f"req_public_api_scrub_broker_{uuid.uuid4().hex[:8]}"
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": request_id,
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": f"idem_public_api_scrub_broker_{uuid.uuid4().hex[:8]}",
            "payload": {"pr_number": 42, "body": "Outbound token scrub check"},
        },
    )

    assert response.status_code == 201
    outbound = fake_github_client.last_request("/repos/octo-org/demo-repo/issues/42/comments")
    assert outbound is not None
    assert_no_secret_like_material(response.text)
    assert_no_secret_like_material(json.dumps(outbound, sort_keys=True))
