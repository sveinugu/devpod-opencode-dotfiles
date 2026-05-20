import argparse
import base64
import hashlib
import hmac
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
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


class _JsonHandler(BaseHTTPRequestHandler):
    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        return json.loads(raw.decode("utf-8"))

    def _write_json(self, status: int, body: dict):
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        return


def run_demo_once(persona: str = "reviewer", token_path: str = None):
    logs = {"broker": [], "opa": [], "github": []}
    sa_secret = "devpod-sa-secret"
    github_hmac_secret = "github-app-private-key-simulated"
    now = int(time.time())

    token_payload = {
        "iss": "kubernetes/serviceaccount",
        "aud": "github-broker",
        "exp": now + 3600,
        "kubernetes.io/serviceaccount/namespace": "devpod-workspaces",
        "kubernetes.io/serviceaccount/name": "workspace-agent",
    }
    projected_token = _encode_jwt(token_payload, sa_secret)
    if token_path:
        with open(token_path, "w", encoding="utf-8") as fp:
            fp.write(projected_token)

    class TokenReviewHandler(_JsonHandler):
        def do_POST(self):
            if self.path != "/tokenreview":
                self._write_json(404, {"error": "not found"})
                return
            body = self._read_json()
            token = body.get("token", "")
            try:
                payload = _decode_and_verify_jwt(token, sa_secret)
                aud_ok = payload.get("aud") == "github-broker"
                authenticated = aud_ok
                status = {
                    "authenticated": authenticated,
                    "user": {
                        "username": f"system:serviceaccount:{payload.get('kubernetes.io/serviceaccount/namespace')}:{payload.get('kubernetes.io/serviceaccount/name')}"
                    },
                    "claims": payload,
                }
            except Exception:
                status = {"authenticated": False}
            self._write_json(200, {"status": status})

    class OPAHandler(_JsonHandler):
        def do_POST(self):
            if self.path != "/v1/data/github/authz/allow":
                self._write_json(404, {"error": "not found"})
                return
            body = self._read_json()
            inp = body.get("input", {})
            ns = inp.get("namespace")
            sa = inp.get("serviceaccount")
            action = inp.get("action")
            repo = inp.get("repo")
            p = inp.get("persona")

            allowed = (
                ns == "devpod-workspaces"
                and sa == "workspace-agent"
                and action == "comment-pr"
                and repo == "octo-org/demo-repo"
                and p in {"reviewer", "implementer"}
            )
            logs["opa"].append(
                f"opa_decision request_id={inp.get('request_id')} namespace={ns} serviceaccount={sa} action={action} repo={repo} persona={p} allow={'true' if allowed else 'false'}"
            )
            self._write_json(200, {"result": allowed})

    class GithubMockHandler(_JsonHandler):
        counter = 9100

        def do_POST(self):
            if self.path != "/repos/octo-org/demo-repo/issues/42/comments":
                self._write_json(404, {"error": "not found"})
                return
            authz = self.headers.get("Authorization", "")
            body = self._read_json()
            GithubMockHandler.counter += 1
            cid = GithubMockHandler.counter
            logs["github"].append(
                "github_request path=/repos/octo-org/demo-repo/issues/42/comments "
                f"authorization={authz[:20]}... github_app_id=12345 installation_id=67890 posted_comment=true body={body.get('body','')}"
            )
            self._write_json(
                201,
                {
                    "id": cid,
                    "html_url": f"https://github.example/octo-org/demo-repo/issues/42#issuecomment-{cid}",
                },
            )

    class BrokerHandler(_JsonHandler):
        def do_POST(self):
            if self.path != "/actions/comment-pr":
                self._write_json(404, {"error": "not found"})
                return
            authz = self.headers.get("Authorization", "")
            body = self._read_json()
            req_id = body.get("request_id", "unknown")
            token = authz.replace("Bearer ", "", 1)
            token_source = "header"
            if not token and token_path and os.path.exists(token_path):
                with open(token_path, "r", encoding="utf-8") as fp:
                    token = fp.read().strip()
                token_source = "projected_file"

            tr_req = request.Request(
                f"http://127.0.0.1:{tokenreview_server.server_port}/tokenreview",
                data=json.dumps({"token": token}).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            tr_data = json.loads(request.urlopen(tr_req, timeout=3).read().decode("utf-8"))
            status = tr_data.get("status", {})
            if not status.get("authenticated"):
                logs["broker"].append(
                    f"broker_decision request_id={req_id} persona={body.get('persona')} allow=false reason=invalid_workload_token token_source={token_source}"
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
            opa_input = {
                "request_id": req_id,
                "namespace": claims.get("kubernetes.io/serviceaccount/namespace"),
                "serviceaccount": claims.get("kubernetes.io/serviceaccount/name"),
                "action": body.get("action"),
                "repo": body.get("repo"),
                "persona": body.get("persona"),
            }
            opa_req = request.Request(
                f"http://127.0.0.1:{opa_server.server_port}/v1/data/github/authz/allow",
                data=json.dumps({"input": opa_input}).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            opa_res = json.loads(request.urlopen(opa_req, timeout=3).read().decode("utf-8"))
            allow = bool(opa_res.get("result", False))
            logs["broker"].append(
                f"broker_decision request_id={req_id} persona={body.get('persona')} allow={'true' if allow else 'false'} namespace={opa_input['namespace']} serviceaccount={opa_input['serviceaccount']} token_source={token_source}"
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

            app_jwt = _encode_jwt({"iss": "12345", "iat": int(time.time()), "exp": int(time.time()) + 300}, github_hmac_secret)
            installation_token = f"inst_{hashlib.sha256(app_jwt.encode('utf-8')).hexdigest()[:16]}"
            persona_marker = f"[Persona: {body.get('persona')}]"
            signature = f"— Posted by persona {body.get('persona')} via GitHub App"
            final_comment = f"{persona_marker}\n{body.get('payload',{}).get('body','')}\n{signature}"

            gh_req = request.Request(
                f"http://127.0.0.1:{github_server.server_port}/repos/octo-org/demo-repo/issues/42/comments",
                data=json.dumps({"body": final_comment}).encode("utf-8"),
                headers={"Content-Type": "application/json", "Authorization": f"Bearer {installation_token}"},
                method="POST",
            )
            gh_res = json.loads(request.urlopen(gh_req, timeout=3).read().decode("utf-8"))
            self._write_json(
                200,
                {
                    "request_id": req_id,
                    "status": "ok",
                    "result": {"comment_id": gh_res["id"], "url": gh_res["html_url"]},
                },
            )

    tokenreview_server = ThreadingHTTPServer(("127.0.0.1", 0), TokenReviewHandler)
    opa_server = ThreadingHTTPServer(("127.0.0.1", 0), OPAHandler)
    github_server = ThreadingHTTPServer(("127.0.0.1", 0), GithubMockHandler)
    broker_server = ThreadingHTTPServer(("127.0.0.1", 0), BrokerHandler)

    servers = [tokenreview_server, opa_server, github_server, broker_server]
    threads = []
    for srv in servers:
        t = threading.Thread(target=srv.serve_forever, daemon=True)
        t.start()
        threads.append(t)

    req_payload = {
        "request_id": "req-phase0-1",
        "repo": "octo-org/demo-repo",
        "action": "comment-pr",
        "persona": persona,
        "idempotency_key": "idem-phase0-1",
        "payload": {"pr_number": 42, "body": "Tracer bullet from workspace pod."},
    }
    broker_req = request.Request(
        f"http://127.0.0.1:{broker_server.server_port}/actions/comment-pr",
        data=json.dumps(req_payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    if not token_path:
        broker_req.add_header("Authorization", f"Bearer {projected_token}")
    try:
        broker_raw = request.urlopen(broker_req, timeout=5).read().decode("utf-8")
        broker_response = json.loads(broker_raw)
    except HTTPError as exc:
        broker_response = json.loads(exc.read().decode("utf-8"))
        exc.close()
    except Exception as exc:
        raise RuntimeError(f"demo request failed: {exc}")
    finally:
        for srv in servers:
            srv.shutdown()
        for srv in servers:
            srv.server_close()

    return {
        "broker_response": broker_response,
        "broker_logs": logs["broker"],
        "opa_logs": logs["opa"],
        "github_logs": logs["github"],
        "ports": {
            "tokenreview": tokenreview_server.server_port,
            "opa": opa_server.server_port,
            "github_mock": github_server.server_port,
            "broker": broker_server.server_port,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Run Phase 0 broker POC once")
    parser.add_argument("--persona", default="reviewer")
    parser.add_argument(
        "--token-path",
        default="/var/run/secrets/opencode/broker-token",
        help="Projected ServiceAccount token file path",
    )
    args = parser.parse_args()

    token_dir = os.path.dirname(args.token_path)
    if token_dir:
        os.makedirs(token_dir, exist_ok=True)

    result = run_demo_once(persona=args.persona, token_path=args.token_path)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
