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

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" >"$tmpdir/out.txt"
)

[ -d "$hub_root/.bare" ]
[ -d "$hub_root/main" ]
[ -d "$hub_root/work" ]
[ -d "$hub_root/repos" ]
[ -d "$hub_root/state/opencode/exported_sessions" ]
[ -d "$hub_root/tmp" ]

state_mode="$(stat -c '%a' "$hub_root/state")"
opencode_mode="$(stat -c '%a' "$hub_root/state/opencode")"
exports_mode="$(stat -c '%a' "$hub_root/state/opencode/exported_sessions")"

[ "$state_mode" = "700" ]
[ "$opencode_mode" = "700" ]
[ "$exports_mode" = "700" ]

git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" >"$tmpdir/out-second.txt"
)

[ -d "$hub_root/.bare" ]
[ -d "$hub_root/main" ]
git --git-dir="$hub_root/.bare" worktree list | grep -F "$hub_root/main" >/dev/null

grep -F "ok: ensured host bare-hub layout at $hub_root" "$tmpdir/out.txt" >/dev/null

printf 'PASS test_setup_host_bare_hub\n'
