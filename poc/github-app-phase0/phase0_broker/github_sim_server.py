import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    counter = 9200

    def log_message(self, fmt, *args):
        return

    def do_POST(self):
        if self.path != "/repos/octo-org/demo-repo/issues/42/comments":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8")) if length else {}
        Handler.counter += 1
        cid = Handler.counter
        authz = self.headers.get("Authorization", "")
        print(
            f"github_request path={self.path} authorization={authz[:20]}... github_app_id=12345 installation_id=67890 posted_comment=true body={body.get('body','')}",
            flush=True,
        )
        payload = {
            "id": cid,
            "html_url": f"https://github.example/octo-org/demo-repo/issues/42#issuecomment-{cid}",
        }
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def main():
    port = int(os.environ.get("GITHUB_SIM_PORT", "8082"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"github_sim_server listening on :{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
