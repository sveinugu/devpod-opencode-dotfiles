#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'PY'
import argparse
import json
import os
import stat
import subprocess
import sys


def fail_usage(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(2)


parser = argparse.ArgumentParser(add_help=False)
parser.add_argument("--hub-root")
parser.add_argument("--format", default="human")
args, extra = parser.parse_known_args()

if extra:
    fail_usage("usage: scripts/verify-host-bare-hub.sh --hub-root /absolute/path [--format human|json]")

hub_root = args.hub_root or ""
if not hub_root or not hub_root.startswith("/"):
    fail_usage("usage: scripts/verify-host-bare-hub.sh --hub-root /absolute/path [--format human|json]")

out_format = args.format
if out_format not in {"human", "json"}:
    fail_usage("usage: scripts/verify-host-bare-hub.sh --hub-root /absolute/path [--format human|json]")

checks = []
warnings = []


def add_check(check_id: str, ok: bool, message: str) -> None:
    checks.append({"id": check_id, "ok": ok, "message": message})


required_dirs = [
    ".bare",
    "main",
    "work",
    "repos",
    "state/opencode/exported_sessions",
    "tmp",
]

missing = []
for rel in required_dirs:
    target = os.path.join(hub_root, rel)
    if not os.path.isdir(target):
        missing.append(rel)

add_check(
    "dirs.exist",
    len(missing) == 0,
    "required directories exist" if not missing else f"missing directories: {', '.join(missing)}",
)

bare_dir = os.path.join(hub_root, ".bare")
bare_ok = False
if os.path.isdir(bare_dir):
    try:
        out = subprocess.check_output(
            ["git", f"--git-dir={bare_dir}", "rev-parse", "--is-bare-repository"],
            stderr=subprocess.STDOUT,
            text=True,
        ).strip()
        bare_ok = out == "true"
    except subprocess.CalledProcessError as exc:
        warnings.append(f"git bare check failed: {exc.output.strip()}")

add_check("bare.valid", bare_ok, ".bare is a usable bare git dir" if bare_ok else ".bare is not a usable bare git dir")

main_wt = os.path.join(hub_root, "main")
worktree_ok = False
if os.path.isdir(bare_dir):
    try:
        out = subprocess.check_output(
            ["git", f"--git-dir={bare_dir}", "worktree", "list", "--porcelain"],
            stderr=subprocess.STDOUT,
            text=True,
        )
        worktree_ok = any(line.strip() == f"worktree {main_wt}" for line in out.splitlines())
    except subprocess.CalledProcessError as exc:
        warnings.append(f"git worktree check failed: {exc.output.strip()}")

add_check(
    "main.worktree",
    worktree_ok,
    "main is attached as a worktree" if worktree_ok else "main is not attached as a worktree",
)

devpodignore_required = [
    ".devpodignore",
    "main/.devpodignore",
    "work/.devpodignore",
    "repos/.devpodignore",
    "tmp/.devpodignore",
]
missing_ignore = []
for rel in devpodignore_required:
    target = os.path.join(hub_root, rel)
    if not os.path.isfile(target):
        missing_ignore.append(rel)

add_check(
    "devpodignore.present",
    len(missing_ignore) == 0,
    ".devpodignore files present" if not missing_ignore else f"missing .devpodignore files: {', '.join(missing_ignore)}",
)

bad_modes = []
for root, dirnames, filenames in os.walk(hub_root):
    for name in dirnames:
        target = os.path.join(root, name)
        mode = stat.S_IMODE(os.lstat(target).st_mode)
        if mode != 0o700:
            bad_modes.append(f"dir {target} mode {mode:04o} expected 0700")

    for name in filenames:
        target = os.path.join(root, name)
        mode = stat.S_IMODE(os.lstat(target).st_mode)
        if mode not in (0o600, 0o700):
            bad_modes.append(f"file {target} mode {mode:04o} expected 0600 or 0700")

add_check(
    "perms.host",
    len(bad_modes) == 0,
    "host permissions satisfy policy" if not bad_modes else "; ".join(bad_modes[:10]),
)

ok = all(item["ok"] for item in checks)
payload = {
    "ok": ok,
    "hub_root": hub_root,
    "checks": checks,
    "warnings": warnings,
}

if out_format == "json":
    print(json.dumps(payload, indent=2, sort_keys=False))
else:
    print(f"hub-root: {hub_root}")
    print("result: PASS" if ok else "result: FAIL")
    for item in checks:
        status = "PASS" if item["ok"] else "FAIL"
        print(f"[{status}] {item['id']}: {item['message']}")
    for warning in warnings:
        print(f"[WARN] {warning}")

sys.exit(0 if ok else 1)
PY
