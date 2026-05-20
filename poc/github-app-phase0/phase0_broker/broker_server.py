import base64
import hashlib
import hmac
import json
import os
import ssl
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib import request


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("utf-8").rstrip("=")


def _encode_jwt(payload: dict, secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    p1 = _b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    p2 = _b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{p1}.{p2}".encode("utf-8")
    sig = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest()
    p3 = _b64url(sig)
    return f"{p1}.{p2}.{p3}"


def _decode_and_verify_jwt(token: str, secret: str) -> dict:
    p1, p2, p3 = token.split(".")
    signing_input = f"{p1}.{p2}".encode("utf-8")
    expected_sig = _b64url(hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256).digest())
    if not hmac.compare_digest(expected_sig, p3):
        raise ValueError("invalid signature")
    payload_raw = base64.urlsafe_b64decode(p2 + "=" * ((4 - len(p2) % 4) % 4))
    payload = json.loads(payload_raw)
    if payload.get("exp", 0) < int(time.time()):
        raise ValueError("expired token")
    return payload


def _post_json(url: str, payload: dict, headers: dict = None, context=None):
    req = request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", **(headers or {})},
        method="POST",
    )
    raw = request.urlopen(req, timeout=8, context=context).read().decode("utf-8")
    return json.loads(raw)


def _tokenreview_validate(token: str):
    review_url = os.environ.get(
        "K8S_TOKENREVIEW_URL",
        "https://kubernetes.default.svc/apis/authentication.k8s.io/v1/tokenreviews",
    )
    reviewer_token_path = os.environ.get("K8S_TOKEN_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/token")
    ca_path = os.environ.get("K8S_CA_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
    with open(reviewer_token_path, "r", encoding="utf-8") as fp:
        reviewer_token = fp.read().strip()
    context = ssl.create_default_context(cafile=ca_path)
    result = _post_json(
        review_url,
        {
            "apiVersion": "authentication.k8s.io/v1",
            "kind": "TokenReview",
            "spec": {"token": token, "audiences": [os.environ.get("BROKER_AUDIENCE", "github-broker")]},
        },
        headers={"Authorization": f"Bearer {reviewer_token}"},
        context=context,
    )
    return result.get("status", {})


def _jwks_sim_validate(token: str):
    # POC-only: in production this should validate with cluster JWKS and issuer metadata.
    secret = os.environ.get("POC_SA_HS256_SECRET", "devpod-sa-secret")
    payload = _decode_and_verify_jwt(token, secret)
    if payload.get("aud") != os.environ.get("BROKER_AUDIENCE", "github-broker"):
        return {"authenticated": False}
    return {"authenticated": True, "claims": payload}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(length).decode("utf-8")) if length else {}

    def _write_json(self, status: int, body: dict):
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self):
        if self.path != "/actions/comment-pr":
            self._write_json(404, {"error": "not found"})
            return

        body = self._read_json()
        req_id = body.get("request_id", "unknown")
        token_path = os.environ.get("WORKSPACE_TOKEN_PATH", "/var/run/secrets/opencode/broker-token")
        authz = self.headers.get("Authorization", "")
        token = authz.replace("Bearer ", "", 1)
        token_source = "header"
        if not token and os.path.exists(token_path):
            with open(token_path, "r", encoding="utf-8") as fp:
                token = fp.read().strip()
            token_source = "projected_file"

        mode = os.environ.get("TOKEN_VALIDATION_MODE", "tokenreview")
        try:
            if mode == "tokenreview":
                status = _tokenreview_validate(token)
            else:
                status = _jwks_sim_validate(token)
        except Exception as exc:
            print(f"broker_auth_error request_id={req_id} message={exc}", flush=True)
            status = {"authenticated": False}

        if not status.get("authenticated"):
            print(
                f"broker_decision request_id={req_id} persona={body.get('persona')} allow=false reason=invalid_workload_token token_source={token_source}",
                flush=True,
            )
            self._write_json(
                401,
                {
                    "request_id": req_id,
                    "status": "error",
                    "error": {"code": "INVALID_WORKLOAD_TOKEN", "message": "token rejected", "retryable": False},
                },
            )
            return

        claims = status.get("claims", {})
        inp = {
            "request_id": req_id,
            "namespace": claims.get("kubernetes.io/serviceaccount/namespace"),
            "serviceaccount": claims.get("kubernetes.io/serviceaccount/name"),
            "action": body.get("action"),
            "repo": body.get("repo"),
            "persona": body.get("persona"),
        }
        opa_url = os.environ.get("OPA_URL", "http://127.0.0.1:8181/v1/data/github/authz/allow")
        opa_result = _post_json(opa_url, {"input": inp})
        allow = bool(opa_result.get("result", False))
        print(
            f"broker_decision request_id={req_id} persona={body.get('persona')} allow={'true' if allow else 'false'} namespace={inp['namespace']} serviceaccount={inp['serviceaccount']} token_source={token_source}",
            flush=True,
        )

        if not allow:
            self._write_json(
                403,
                {
                    "request_id": req_id,
                    "status": "error",
                    "error": {"code": "POLICY_DENY", "message": "policy denied request", "retryable": False},
                },
            )
            return

        with open(os.environ.get("GITHUB_APP_PRIVATE_KEY_PATH", "/var/run/secrets/github-app/private-key.pem"), "r", encoding="utf-8") as fp:
            gh_key = fp.read().strip() or "poc-key"
        app_jwt = _encode_jwt(
            {"iss": os.environ.get("GITHUB_APP_ID", "12345"), "iat": int(time.time()), "exp": int(time.time()) + 300},
            gh_key,
        )
        installation_token = f"inst_{hashlib.sha256(app_jwt.encode('utf-8')).hexdigest()[:16]}"

        persona = body.get("persona")
        final_body = (
            f"[Persona: {persona}]\n{body.get('payload', {}).get('body', '')}\n"
            f"— Posted by persona {persona} via GitHub App"
        )
        gh_url = os.environ.get(
            "GITHUB_API_BASE_URL", "http://github-sim.default.svc.cluster.local:8082"
        ) + "/repos/octo-org/demo-repo/issues/42/comments"
        gh = _post_json(
            gh_url,
            {"body": final_body},
            headers={"Authorization": f"Bearer {installation_token}"},
        )
        self._write_json(
            200,
            {
                "request_id": req_id,
                "status": "ok",
                "result": {"comment_id": gh["id"], "url": gh["html_url"]},
            },
        )


def main():
    port = int(os.environ.get("BROKER_PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"broker_server listening on :{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
