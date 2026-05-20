import uuid


def test_comment_body_uses_canonical_persona_markers(format_comment_body):
    rendered = format_comment_body(persona="reviewer", body="Please tighten the policy wording.")
    assert rendered.startswith("[Persona: reviewer]\n")
    assert rendered.endswith("\n\n— Posted by persona reviewer via GitHub App")


def test_broker_path_outbound_comment_body_contains_canonical_persona_markers(client, auth_headers, fake_github_client):
    response = client.post(
        "/v1/action",
        headers=auth_headers,
        json={
            "request_id": f"req_persona_broker_{uuid.uuid4().hex[:8]}",
            "repo": "octo-org/demo-repo",
            "action": "comment-pr",
            "persona": "reviewer",
            "idempotency_key": f"idem_persona_broker_{uuid.uuid4().hex[:8]}",
            "payload": {"pr_number": 42, "body": "Broker path persona check"},
        },
    )

    assert response.status_code == 201
    outbound = fake_github_client.last_request("/repos/octo-org/demo-repo/issues/42/comments")
    assert outbound is not None
    outbound_body = outbound["json"]["body"]
    assert outbound_body.startswith("[Persona: reviewer]\n")
    assert outbound_body.endswith("\n\n— Posted by persona reviewer via GitHub App")
