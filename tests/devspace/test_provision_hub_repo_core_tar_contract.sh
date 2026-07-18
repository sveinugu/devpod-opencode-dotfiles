#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_provision_hub_repo_core_tar_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cfg="$repo_root/devspace.yaml"
hub_core="$repo_root/scripts/lib/hub-repo-core.sh"

[ -f "$cfg" ] || fail 'devspace.yaml not found'
[ -f "$hub_core" ] || fail 'scripts/lib/hub-repo-core.sh not found'

tar_line="$(grep -F 'tar cf - -C scripts' "$cfg" || true)"
[ -n "$tar_line" ] || fail 'devspace provision tar command not found'

mapfile -t sourced_helpers < <(grep -Eo 'hub-repo-core-[^"]+\.sh' "$hub_core" | sort -u)
[ "${#sourced_helpers[@]}" -gt 0 ] || fail 'hub-repo-core.sh should source at least one partitioned helper'

for helper in "${sourced_helpers[@]}"; do
  if ! grep -F "lib/$helper" <<<"$tar_line" >/dev/null; then
    fail "provision tar command must include scripts/lib/$helper because hub-repo-core.sh sources it"
  fi
done

printf 'PASS test_provision_hub_repo_core_tar_contract\n'
