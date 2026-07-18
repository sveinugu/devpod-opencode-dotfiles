#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL test_provision_hub_repo_core_tar_contract: %s\n' "$1" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
cfg="$repo_root/devspace.yaml"
hub_core="$repo_root/scripts/lib/hub-repo-core.sh"
bare_exclude_helper="$repo_root/scripts/lib/ensure-bare-excludes.sh"
bare_exclude_list="$repo_root/scripts/lib/bare-excludes.list"

[ -f "$cfg" ] || fail 'devspace.yaml not found'
[ -f "$hub_core" ] || fail 'scripts/lib/hub-repo-core.sh not found'
[ -f "$bare_exclude_helper" ] || fail 'scripts/lib/ensure-bare-excludes.sh not found'
[ -f "$bare_exclude_list" ] || fail 'scripts/lib/bare-excludes.list not found'

tar_line="$(grep -F 'tar cf - -C scripts' "$cfg" || true)"
[ -n "$tar_line" ] || fail 'devspace provision tar command not found'

mapfile -t sourced_helpers < <(grep -Eo 'hub-repo-core-[^"]+\.sh' "$hub_core" | sort -u)
[ "${#sourced_helpers[@]}" -gt 0 ] || fail 'hub-repo-core.sh should source at least one partitioned helper'

for helper in "${sourced_helpers[@]}"; do
  if ! grep -F "lib/$helper" <<<"$tar_line" >/dev/null; then
    fail "provision tar command must include scripts/lib/$helper because hub-repo-core.sh sources it"
  fi
done

for runtime_dependency in ensure-bare-excludes.sh bare-excludes.list; do
  if ! grep -F "lib/$runtime_dependency" <<<"$tar_line" >/dev/null; then
    fail "provision tar command must include scripts/lib/$runtime_dependency because hub-repo-core bootstrap uses it at runtime"
  fi
done

printf 'PASS test_provision_hub_repo_core_tar_contract\n'
