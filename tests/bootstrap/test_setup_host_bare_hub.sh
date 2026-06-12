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
printf '#!/usr/bin/env bash\nexit 0\n' > "$checkout/install.sh"
chmod 600 "$checkout/install.sh"

git init "$checkout" >/dev/null 2>&1
(
  cd "$checkout"
  git add . >/dev/null 2>&1
  git -c user.name='Test User' -c user.email='test@example.com' commit -m 'fixture' >/dev/null 2>&1
  git branch -M main >/dev/null 2>&1
)

if [ -f "scripts/setup-host-bare-hub.sh" ]; then
  cp "scripts/setup-host-bare-hub.sh" "$checkout/scripts/setup-host-bare-hub.sh"
  chmod +x "$checkout/scripts/setup-host-bare-hub.sh"
fi

if [ -f "scripts/lib/ensure-bare-excludes.sh" ]; then
  mkdir -p "$checkout/scripts/lib"
  cp "scripts/lib/ensure-bare-excludes.sh" "$checkout/scripts/lib/ensure-bare-excludes.sh"
  chmod +x "$checkout/scripts/lib/ensure-bare-excludes.sh"
fi

if [ -f "scripts/lib/bare-excludes.list" ]; then
  mkdir -p "$checkout/scripts/lib"
  cp "scripts/lib/bare-excludes.list" "$checkout/scripts/lib/bare-excludes.list"
fi

if [ -f "scripts/verify-host-bare-hub.sh" ]; then
  cp "scripts/verify-host-bare-hub.sh" "$checkout/scripts/verify-host-bare-hub.sh"
  chmod +x "$checkout/scripts/verify-host-bare-hub.sh"
fi

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" \
    --hub-root "$hub_root" \
    --mode host \
    --github-user-name "Bootstrap User" \
    --github-user-email "bootstrap@example.com" \
    >"$tmpdir/out.txt"
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

grep -F 'gitdir: ./.bare' "$hub_root/.git" >/dev/null
fetch_refspec="$(git --git-dir="$hub_root/.bare" config --get remote.origin.fetch)"
[ "$fetch_refspec" = "+refs/heads/*:refs/remotes/origin/*" ]
user_name="$(git --git-dir="$hub_root/.bare" config --get user.name)"
user_email="$(git --git-dir="$hub_root/.bare" config --get user.email)"
[ "$user_name" = "Bootstrap User" ]
[ "$user_email" = "bootstrap@example.com" ]
exclude_file="$hub_root/.bare/info/exclude"
[ -f "$exclude_file" ] || {
  printf 'expected .bare/info/exclude to exist after setup\n' >&2
  exit 1
}
for pattern in '.envrc' '.envrc.local' '.envrc.bak.*' '.opencode/'; do
  grep -Fx "$pattern" "$exclude_file" >/dev/null || {
    printf 'expected %s in .bare/info/exclude\n' "$pattern" >&2
    exit 1
  }
done

printf 'manual-only\n' > "$exclude_file"
(
  cd "$checkout"
  printf 'Y\n' | bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" --mode host >"$tmpdir/out-reset.txt"
)
for pattern in '.envrc' '.envrc.local' '.envrc.bak.*' '.opencode/'; do
  grep -Fx "$pattern" "$exclude_file" >/dev/null || {
    printf 'expected setup reset to restore %s in .bare/info/exclude\n' "$pattern" >&2
    exit 1
  }
done
main_branch="$(git -C "$hub_root/main" rev-parse --abbrev-ref HEAD)"
[ "$main_branch" = "main" ]
install_mode_first="$(stat -c '%a' "$hub_root/main/install.sh")"
[ "$install_mode_first" = "700" ]

(
  cd "$checkout"
  printf 'Y\n' | bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" --mode host >"$tmpdir/out-second.txt"
)

install_mode_second="$(stat -c '%a' "$hub_root/main/install.sh")"
[ "$install_mode_second" = "700" ]

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

checkout_no_main="$tmpdir/dotfiles-checkout-no-main"
hub_root_no_main="$tmpdir/host-workspaces/dotfiles-no-main"
mkdir -p "$checkout_no_main/.config/opencode" "$checkout_no_main/scripts"
printf 'export TEST_ZSHRC=1\n' > "$checkout_no_main/.zshrc"
printf '{"ok":true}\n' > "$checkout_no_main/.config/opencode/opencode.jsonc"
printf '#!/usr/bin/env bash\nexit 0\n' > "$checkout_no_main/install.sh"
chmod 600 "$checkout_no_main/install.sh"
git init "$checkout_no_main" >/dev/null 2>&1
(
  cd "$checkout_no_main"
  git add . >/dev/null 2>&1
  git -c user.name='Test User' -c user.email='test@example.com' commit -m 'fixture' >/dev/null 2>&1
)
cp "$checkout/scripts/setup-host-bare-hub.sh" "$checkout_no_main/scripts/setup-host-bare-hub.sh"
chmod +x "$checkout_no_main/scripts/setup-host-bare-hub.sh"
mkdir -p "$checkout_no_main/scripts/lib"
cp "$checkout/scripts/lib/ensure-bare-excludes.sh" "$checkout_no_main/scripts/lib/ensure-bare-excludes.sh"
chmod +x "$checkout_no_main/scripts/lib/ensure-bare-excludes.sh"
cp "$checkout/scripts/lib/bare-excludes.list" "$checkout_no_main/scripts/lib/bare-excludes.list"

if (
  cd "$checkout_no_main"
  bash "./scripts/setup-host-bare-hub.sh" \
    --hub-root "$hub_root_no_main" \
    --mode host \
    --github-user-name "No Main User" \
    --github-user-email "nomain@example.com" \
    >"$tmpdir/no-main.out" 2>&1
); then
  printf 'expected main-only setup to fail when source checkout has no main branch\n' >&2
  exit 1
fi

grep -F 'refused: main branch not found in source checkout; main-only convention enforced' "$tmpdir/no-main.out" >/dev/null

printf 'PASS test_setup_host_bare_hub\n'
