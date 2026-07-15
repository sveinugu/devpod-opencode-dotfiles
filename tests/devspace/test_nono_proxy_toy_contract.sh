#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_nono_proxy_toy_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
nono_bin="${HUB_NONO_BIN:-nono}"

if ! command -v "$nono_bin" >/dev/null 2>&1; then
  if [ "$nono_bin" = "nono" ] && [ -x "$HOME/.local/bin/nono" ]; then
    nono_bin="$HOME/.local/bin/nono"
  else
    fail "nono executable is required for proxy toy contract"
  fi
fi

tmp_root="$(mktemp -d "$repo_root/.tmp-nono-proxy-toy-XXXXXX")"

cleanup_tmp_root() {
  if [ "${HUB_NONO_KEEP_TMP:-0}" = "1" ]; then
    printf 'info: preserving proxy-toy temp dir at %s\n' "$tmp_root" >&2
    return
  fi
  rm -rf "$tmp_root"
}

trap 'cleanup_tmp_root' EXIT

profile_path="$tmp_root/toy-profile.jsonc"
probe_script="$tmp_root/proxy-probe.sh"
header_log="$tmp_root/upstream-headers.log"
upstream_server_log="$tmp_root/upstream-server.log"
upstream_port_file="$tmp_root/upstream-port.txt"

cat >"$profile_path" <<'EOF'
{
  "meta": {
    "name": "nono-toy-proxy-contract"
  },
  "workdir": {
    "access": "readwrite"
  },
  "filesystem": {
    "allow": [
      "$WORKDIR"
    ]
  },
  "network": {
    "credentials": [
      "toy_proxy"
    ],
    "custom_credentials": {
      "toy_proxy": {
        "upstream": "http://127.0.0.1:{{UPSTREAM_PORT}}",
        "credential_key": "env://HUB_NONO_TOY_REAL_TOKEN",
        "env_var": "TOY_PROXY_API_KEY",
        "inject_header": "Authorization",
        "credential_format": "Bearer {}"
      }
    }
  }
}
EOF

cat >"$probe_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

base_url="${TOY_PROXY_BASE_URL:-}"
phantom_token="${TOY_PROXY_API_KEY:-}"
direct_upstream_url="${HUB_TOY_UPSTREAM_URL:-}"

[ -n "$base_url" ] || exit 21
[ -n "$phantom_token" ] || exit 22
[ -n "$direct_upstream_url" ] || exit 23

curl -fsS -H "Authorization: Bearer $phantom_token" "$base_url/v1/echo" >/dev/null

if curl -m 5 -fsS -H "Authorization: Bearer $phantom_token" "$direct_upstream_url/v1/echo" >/dev/null 2>&1; then
  printf 'proxy-toy:direct-bypass-succeeded\n'
  exit 24
fi

printf 'proxy-toy:proxy-route-succeeded-and-direct-bypass-blocked\n'
EOF
chmod +x "$probe_script"

python3 - "$header_log" "$upstream_port_file" >"$upstream_server_log" 2>&1 <<'PY' &
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

header_log = pathlib.Path(sys.argv[1])
port_file = pathlib.Path(sys.argv[2])

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        lines = [f"path={self.path}"]
        for key, value in self.headers.items():
            lines.append(f"{key}: {value}")
        header_log.write_text("\n".join(lines) + "\n", encoding="utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def log_message(self, fmt, *args):
        return

server = HTTPServer(("127.0.0.1", 0), Handler)
port_file.write_text(str(server.server_address[1]), encoding="utf-8")
server.serve_forever()
PY
server_pid="$!"

cleanup_server() {
  if kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap 'cleanup_server; cleanup_tmp_root' EXIT

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [ -s "$upstream_port_file" ]; then
    break
  fi
  sleep 0.2
done

[ -s "$upstream_port_file" ] || fail "upstream toy server did not publish port"
upstream_port="$(cat "$upstream_port_file")"

python3 - "$profile_path" "$upstream_port" <<'PY'
import pathlib
import sys

profile = pathlib.Path(sys.argv[1])
port = sys.argv[2]
content = profile.read_text(encoding="utf-8")
profile.write_text(content.replace("{{UPSTREAM_PORT}}", port), encoding="utf-8")
PY

upstream_url="http://127.0.0.1:$upstream_port"
real_token='REAL_PROXY_TOKEN_FOR_TOY_CONTRACT'
probe_output="$tmp_root/probe-output.log"

HUB_NONO_TOY_REAL_TOKEN="$real_token" \
HUB_TOY_UPSTREAM_URL="$upstream_url" \
"$nono_bin" run --profile "$profile_path" --allow "$tmp_root" -- "$probe_script" >"$probe_output" 2>&1 || fail "sandboxed probe failed: $(tr '\n' ' ' < "$probe_output")"

grep -F 'proxy-toy:proxy-route-succeeded-and-direct-bypass-blocked' "$probe_output" >/dev/null || fail "probe did not confirm proxy success and direct bypass block"

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if [ -s "$header_log" ]; then
    break
  fi
  sleep 0.2
done

[ -s "$header_log" ] || fail "toy upstream did not receive proxied request"
grep -F 'path=/v1/echo' "$header_log" >/dev/null || fail "toy upstream log missing expected request path"
grep -Ei "^authorization: Bearer ${real_token}$" "$header_log" >/dev/null || fail "toy upstream did not receive real injected authorization token"

printf 'PASS test_nono_proxy_toy_contract\n'
