#!/usr/bin/env bash
set -euo pipefail

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

cp "scripts/setup-host-bare-hub.sh" "$checkout/scripts/setup-host-bare-hub.sh"
cp "scripts/verify-host-bare-hub.sh" "$checkout/scripts/verify-host-bare-hub.sh"
mkdir -p "$checkout/scripts/lib"
cp "scripts/lib/ensure-bare-excludes.sh" "$checkout/scripts/lib/ensure-bare-excludes.sh"
chmod +x "$checkout/scripts/setup-host-bare-hub.sh" "$checkout/scripts/verify-host-bare-hub.sh"
chmod +x "$checkout/scripts/lib/ensure-bare-excludes.sh"

(
  cd "$checkout"
  bash "./scripts/setup-host-bare-hub.sh" \
    --hub-root "$hub_root" \
    --mode host \
    --github-user-name "Verifier User" \
    --github-user-email "verifier@example.com" \
    >/dev/null
)

install_mode_good="$(stat -c '%a' "$hub_root/main/install.sh")"
[ "$install_mode_good" = "700" ]

(
  cd "$checkout"
  bash "./scripts/verify-host-bare-hub.sh" --hub-root "$hub_root" --format json >"$tmpdir/verify-good.json"
)

python3 - "$tmpdir/verify-good.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
if not payload.get('ok'):
    print('expected verifier to pass for valid hub', file=sys.stderr)
    sys.exit(1)
if not any(c.get('id') == 'bare.exclude' and c.get('ok') is True for c in payload.get('checks', [])):
    print('expected bare.exclude check to pass', file=sys.stderr)
    sys.exit(1)
PY

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

rm -f "$hub_root/tmp/.devpodignore"
if (
  cd "$checkout"
  bash "./scripts/verify-host-bare-hub.sh" --hub-root "$hub_root" --format json >"$tmpdir/verify-missing-ignore.json"
); then
  printf 'expected verifier to fail when .devpodignore missing\n' >&2
  exit 1
fi

python3 - "$tmpdir/verify-missing-ignore.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
if payload.get('ok'):
    print('expected verifier payload ok=false for missing .devpodignore', file=sys.stderr)
    sys.exit(1)
if not any(c.get('id') == 'devpodignore.present' and c.get('ok') is False for c in payload.get('checks', [])):
    print('expected devpodignore.present check to fail', file=sys.stderr)
    sys.exit(1)
PY

(
  cd "$checkout"
  printf 'Y\n' | bash "./scripts/setup-host-bare-hub.sh" --hub-root "$hub_root" --mode host >/dev/null
)

install_mode_after_repair="$(stat -c '%a' "$hub_root/main/install.sh")"
[ "$install_mode_after_repair" = "700" ]

chmod 755 "$hub_root/work"
if (
  cd "$checkout"
  bash "./scripts/verify-host-bare-hub.sh" --hub-root "$hub_root" --format json >"$tmpdir/verify-perms.json"
); then
  printf 'expected verifier to fail on permission mismatch\n' >&2
  exit 1
fi

python3 - "$tmpdir/verify-perms.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
if payload.get('ok'):
    print('expected verifier payload ok=false for permission mismatch', file=sys.stderr)
    sys.exit(1)
if not any(c.get('id') == 'perms.host' and c.get('ok') is False for c in payload.get('checks', [])):
    print('expected perms.host check to fail', file=sys.stderr)
    sys.exit(1)
PY

printf 'PASS test_verify_host_bare_hub\n'
