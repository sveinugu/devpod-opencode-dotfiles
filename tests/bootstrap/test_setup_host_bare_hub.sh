#!/usr/bin/env bash
set -euo pipefail

# Host-only contract test.
# This script is intended to be run on the HOST from inside a normal dotfiles checkout,
# before DevPod starts. The bootstrap script under test must live inside that checkout:
#   <checkout>/scripts/setup-host-bare-hub.sh
# It must derive the source checkout from its own location and therefore must NOT require
# a --source-checkout parameter.

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

checkout="$tmpdir/dotfiles-checkout"
hub_root="$tmpdir/host-workspaces/dotfiles"

mkdir -p "$checkout/.config/opencode" "$checkout/scripts" "$tmpdir/host-workspaces"

printf 'export TEST_ZSHRC=1\n' > "$checkout/.zshrc"
printf '{"ok":true}\n' > "$checkout/.config/opencode/opencode.jsonc"

git init "$checkout" >/dev/null 2>&1
(
  cd "$checkout"
  git add . >/dev/null 2>&1
  git -c user.name='Test User' -c user.email='test@example.com' commit -m 'fixture' >/dev/null 2>&1
)

if [ -f "scripts/setup-host-bare-hub.sh" ]; then
  cp "scripts/setup-host-bare-hub.sh" "$checkout/scripts/setup-host-bare-hub.sh"
  chmod +x "$checkout/scripts/setup-host-bare-hub.sh"
fi

if [ -f "scripts/verify-host-bare-hub.sh" ]; then
  cp "scripts/verify-host-bare-hub.sh" "$checkout/scripts/verify-host-bare-hub.sh"
  chmod +x "$checkout/scripts/verify-host-bare-hub.sh"
fi

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" --mode host >"$tmpdir/out.txt"
)

(
  cd "$checkout"
  bash "./scripts/verify-host-bare-hub.sh" --hub-root "$hub_root" --format json >"$tmpdir/verify-first.json"
)

python3 - "$tmpdir/verify-first.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], "r", encoding="utf-8"))
if not payload.get("ok"):
    print("expected verifier to pass on first bootstrap run", file=sys.stderr)
    sys.exit(1)
PY

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" --mode host >"$tmpdir/out-second.txt"
)

(
  cd "$checkout"
  bash "./scripts/verify-host-bare-hub.sh" --hub-root "$hub_root" --format json >"$tmpdir/verify-second.json"
)

python3 - "$tmpdir/verify-second.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], "r", encoding="utf-8"))
if not payload.get("ok"):
    print("expected verifier to pass on second bootstrap run", file=sys.stderr)
    sys.exit(1)
PY

grep -F "ok: ensured host bare-hub layout at $hub_root" "$tmpdir/out.txt" >/dev/null

printf 'PASS test_setup_host_bare_hub\n'
